-- =====================================================================
-- SysMúsica — Migração 0008: atendimento da portaria (QR Code, busca pelo nome, fotografia)
--   * Fotografia do membro em armazenamento PRIVADO (limite de 2 MB; JPEG, PNG ou WebP), visível
--     por URL temporária. Só quem tem a permissão membros.foto envia, troca ou remove.
--   * Consulta do membro para conferência (por QR Code ou por nome completo): o banco só devolve
--     dados depois de validar o acesso à portaria (aprovada + dentro da abrangência do usuário) e
--     a mensagem de negação não revela nada de outras portarias.
--   * Lista de entradas recentes da portaria.
-- Requer a migração 0007. Idempotente, uma única transação.
-- =====================================================================
begin;

do $$
begin
  if to_regclass('public.portarias') is null then
    raise exception 'Aplique primeiro a migração 0007_portarias.sql.';
  end if;
end $$;

-- 1) PERMISSÃO NOVA (igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts); só o Administrador recebe
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('membros.foto', 'Membros', 'Fotografia', 'Cadastrar, trocar e remover a fotografia dos membros')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
from public.grupos g cross join public.permissoes p
where g.sistema and g.nome = 'Administrador' and p.codigo = 'membros.foto'
on conflict do nothing;

-- 2) FOTOGRAFIA: coluna + bucket privado + regras de acesso
alter table public.membros add column if not exists foto_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos-membros', 'fotos-membros', false, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "fotos_membros_leitura" on storage.objects;
create policy "fotos_membros_leitura" on storage.objects
  for select to authenticated
  using (bucket_id = 'fotos-membros'
         and public.tem_alguma_permissao(array['membros.foto', 'membros.visualizar', 'portaria.registrar']));

drop policy if exists "fotos_membros_envio" on storage.objects;
create policy "fotos_membros_envio" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'fotos-membros' and public.tem_permissao('membros.foto'));

drop policy if exists "fotos_membros_troca" on storage.objects;
create policy "fotos_membros_troca" on storage.objects
  for update to authenticated
  using (bucket_id = 'fotos-membros' and public.tem_permissao('membros.foto'))
  with check (bucket_id = 'fotos-membros' and public.tem_permissao('membros.foto'));

drop policy if exists "fotos_membros_exclusao" on storage.objects;
create policy "fotos_membros_exclusao" on storage.objects
  for delete to authenticated
  using (bucket_id = 'fotos-membros' and public.tem_permissao('membros.foto'));

-- Membros para a tela de fotografias (exige membros.foto)
create or replace function public.listar_membros_para_foto()
returns table (id uuid, nome text, congregacao text, foto_path text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('membros.foto');
  return query
    select m.id, m.nome, m.congregacao, m.foto_path
    from public.membros m
    where m.excluido_em is null
    order by m.nome;
end;
$$;

-- Guarda o caminho da foto já enviada; devolve o caminho anterior para a tela apagar o arquivo antigo
create or replace function public.definir_foto_membro(p_membro_id uuid, p_path text)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_antigo text;
begin
  perform public.exigir_permissao('membros.foto');

  -- O arquivo precisa ficar na pasta do próprio membro e existir de fato no armazenamento
  if p_path is null or p_path not like (p_membro_id::text || '/%') or position('..' in p_path) > 0 then
    raise exception 'Caminho de fotografia inválido.';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'fotos-membros' and o.name = p_path) then
    raise exception 'A fotografia enviada não foi encontrada. Tente enviar novamente.';
  end if;

  select m.foto_path into v_antigo
  from public.membros m where m.id = p_membro_id and m.excluido_em is null for update;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;

  update public.membros set foto_path = p_path where id = p_membro_id;

  perform public.registrar_auditoria('foto_definida', 'membro', p_membro_id,
            jsonb_build_object('caminho', p_path));
  return v_antigo;
end;
$$;

-- Remove a referência da foto; devolve o caminho antigo para a tela apagar o arquivo
create or replace function public.remover_foto_membro(p_membro_id uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_antigo text;
begin
  perform public.exigir_permissao('membros.foto');

  select m.foto_path into v_antigo
  from public.membros m where m.id = p_membro_id and m.excluido_em is null for update;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;

  update public.membros set foto_path = null where id = p_membro_id;

  perform public.registrar_auditoria('foto_removida', 'membro', p_membro_id, '{}'::jsonb);
  return v_antigo;
end;
$$;

-- 3) ATENDIMENTO DA PORTARIA
-- Confere o acesso à portaria: permissão de registrar, portaria aprovada e dentro da abrangência.
-- A mesma mensagem vale para "não existe" e "sem acesso": não revela dados de outras portarias.
create or replace function public.exigir_acesso_atendimento(p_portaria_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_p public.portarias;
begin
  perform public.exigir_permissao('portaria.registrar');
  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found or v_p.status <> 'APROVADA' or not public.cidade_na_abrangencia(v_p.cidade) then
    raise exception 'Portaria indisponível para você.' using errcode = '42501';
  end if;
end;
$$;

-- Dados do membro para a conferência na portaria (inclui se já foi registrado nesta portaria)
create or replace function public.cartao_membro(p_portaria_id uuid, p_membro_id uuid)
returns table (
  membro_id uuid, nome text, congregacao text, cargo text, instrumento text,
  cidade text, bairro text, status text, foto_path text, ja_registrado_em timestamptz
)
language sql stable security definer set search_path = public as $$
  select m.id, m.nome, m.congregacao, c.nome, i.nome, m.cidade, m.bairro, m.status, m.foto_path,
         (select min(pr.hora_entrada) from public.presencas pr
           where pr.membro_id = m.id and pr.portaria_id = p_portaria_id and pr.excluido_em is null)
  from public.membros m
  left join public.cargos c on c.id = m.cargo_id
  left join public.instrumentos i on i.id = m.instrumento_id
  where m.id = p_membro_id and m.excluido_em is null
$$;

-- Localiza o membro pelo conteúdo lido do QR Code (SYSMUSICA:1:<código>).
-- QR Code substituído por um novo deixa de ser reconhecido.
create or replace function public.buscar_membro_por_qr(p_portaria_id uuid, p_codigo text)
returns table (
  membro_id uuid, nome text, congregacao text, cargo text, instrumento text,
  cidade text, bairro text, status text, foto_path text, ja_registrado_em timestamptz
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_texto  text := btrim(coalesce(p_codigo, ''));
  v_secret uuid;
  v_id     uuid;
begin
  perform public.exigir_acesso_atendimento(p_portaria_id);

  if v_texto !~* '^SYSMUSICA:1:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception 'QR Code inválido: este não é um QR Code do SysMúsica.';
  end if;
  v_secret := substring(v_texto from 13)::uuid;   -- depois de "SYSMUSICA:1:"

  select m.id into v_id from public.membros m where m.qr_secret = v_secret and m.excluido_em is null;
  if not found then
    raise exception 'QR Code não reconhecido ou já substituído por um novo. Peça o QR Code atual ou busque pelo nome.';
  end if;

  return query select * from public.cartao_membro(p_portaria_id, v_id);
end;
$$;

-- Localiza membros pelo NOME COMPLETO (nome e sobrenome; ignora acento e maiúsculas); no máximo 6
create or replace function public.buscar_membros_por_nome(p_portaria_id uuid, p_nome text)
returns table (
  membro_id uuid, nome text, congregacao text, cargo text, instrumento text,
  cidade text, bairro text, status text, foto_path text, ja_registrado_em timestamptz
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_nome text := public.normalizar_texto(btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g')));
begin
  perform public.exigir_acesso_atendimento(p_portaria_id);

  -- Exige nome e sobrenome: impede "folhear" a lista de membros pela busca
  if char_length(v_nome) < 8 or array_length(string_to_array(v_nome, ' '), 1) < 2 then
    raise exception 'Digite o nome completo do membro (nome e sobrenome).';
  end if;

  return query
    select c.*
    from public.membros m
    cross join lateral public.cartao_membro(p_portaria_id, m.id) c
    where m.excluido_em is null
      and public.normalizar_texto(m.nome) like
          '%' || replace(replace(replace(v_nome, '\', '\\'), '%', '\%'), '_', '\_') || '%'
    order by m.nome
    limit 6;
end;
$$;

-- Últimas entradas registradas na portaria (e o total), para a tela de atendimento
create or replace function public.entradas_da_portaria(p_portaria_id uuid)
returns table (
  presenca_id uuid, membro_nome text, status text, hora_entrada timestamptz, origem text, total bigint
)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_acesso_atendimento(p_portaria_id);
  return query
    select pr.id, m.nome, pr.status, pr.hora_entrada, pr.origem, count(*) over ()
    from public.presencas pr
    join public.membros m on m.id = pr.membro_id
    where pr.portaria_id = p_portaria_id and pr.excluido_em is null
    order by pr.hora_entrada desc
    limit 30;
end;
$$;

-- 4) PERMISSÕES DE EXECUÇÃO
revoke all on function
  public.exigir_acesso_atendimento(uuid), public.cartao_membro(uuid, uuid)
  from public, anon, authenticated;

revoke all on function
  public.buscar_membro_por_qr(uuid, text), public.buscar_membros_por_nome(uuid, text),
  public.entradas_da_portaria(uuid), public.listar_membros_para_foto(),
  public.definir_foto_membro(uuid, text), public.remover_foto_membro(uuid)
  from public, anon;
grant execute on function
  public.buscar_membro_por_qr(uuid, text), public.buscar_membros_por_nome(uuid, text),
  public.entradas_da_portaria(uuid), public.listar_membros_para_foto(),
  public.definir_foto_membro(uuid, text), public.remover_foto_membro(uuid)
  to authenticated;

commit;
