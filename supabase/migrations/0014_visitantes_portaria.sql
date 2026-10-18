-- =====================================================================
-- SysMúsica — Migração 0014: cadastro rápido de visitante na portaria
--   * Permissão nova "portaria.cadastrar_visitante" (o Administrador recebe).
--   * O atendente cadastra, dentro da tela da Portaria, o irmão de outra região (ou sem cadastro):
--     nome completo, cargo/ministério, instrumento (opcional) e de onde vem. O visitante vira membro
--     da COMUM da portaria em atendimento (e só a região dela o enxerga), marcado como visitante, com
--     QR Code próprio. Sem CPF obrigatório. Cada cadastro fica na auditoria.
--   * O banco confere tudo: permissão, portaria aprovada, abrangência de quem atende, nome completo,
--     cargo, instrumento e duplicidade do nome na mesma comum.
-- Requer as migrações 0008 e 0012. Idempotente, uma única transação.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.exigir_acesso_atendimento(uuid)') is null
     or to_regprocedure('public.comum_na_abrangencia(uuid)') is null
     or to_regprocedure('public.cartao_membro(uuid,uuid)') is null then
    raise exception 'Aplique primeiro as migrações 0008 e 0012.';
  end if;
end $$;

-- 1) PERMISSÃO (igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts); só o Administrador recebe
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('portaria.cadastrar_visitante', 'Portaria', 'Cadastrar visitante',
   'Cadastrar na portaria o visitante (irmão de outra região ou sem cadastro) na comum da portaria em atendimento')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
from public.grupos g cross join public.permissoes p
where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- 2) MARCA DE VISITANTE (para relatórios futuros; o cliente não lê nem grava esta coluna diretamente)
alter table public.membros add column if not exists visitante boolean not null default false;

-- 3) OPÇÕES DO FORMULÁRIO (cargos e instrumentos; quem atende pode não ter acesso às telas de cadastro)
create or replace function public.opcoes_visitante()
returns table (tipo text, id uuid, nome text, permite_instrumento boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('portaria.cadastrar_visitante');
  return query
    select 'CARGO'::text, c.id, c.nome, c.permite_instrumento from public.cargos c
    union all
    select 'INSTRUMENTO'::text, i.id, i.nome, false from public.instrumentos i
    order by 1, 3;
end;
$$;

-- 4) CADASTRAR O VISITANTE (devolve o id do novo membro)
create or replace function public.cadastrar_visitante(
  p_portaria_id uuid, p_nome text, p_cargo_id uuid, p_instrumento_id uuid, p_igreja text, p_cidade text
)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_p       public.portarias;
  v_comum   text;
  v_nome    text := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  v_igreja  text := nullif(btrim(coalesce(p_igreja, '')), '');
  v_cidade  text := nullif(btrim(coalesce(p_cidade, '')), '');
  v_permite boolean;
  v_id      uuid;
begin
  perform public.exigir_permissao('portaria.cadastrar_visitante');
  perform public.exigir_acesso_atendimento(p_portaria_id);   -- aprovada e dentro da abrangência de quem atende

  select * into v_p from public.portarias p where p.id = p_portaria_id;
  select c.nome into v_comum from public.comuns c where c.id = v_p.comum_id;
  if v_comum is null then
    raise exception 'A comum desta portaria não foi encontrada.';
  end if;

  if char_length(v_nome) < 5 or char_length(v_nome) > 120 or position(' ' in v_nome) = 0 then
    raise exception 'Digite o nome completo do visitante (nome e sobrenome).';
  end if;

  select c.permite_instrumento into v_permite from public.cargos c where c.id = p_cargo_id;
  if not found then
    raise exception 'Escolha o cargo ou ministério do visitante.';
  end if;

  if p_instrumento_id is not null then
    if not v_permite then
      raise exception 'Este cargo não usa instrumento.';
    end if;
    if not exists (select 1 from public.instrumentos i where i.id = p_instrumento_id) then
      raise exception 'Instrumento não encontrado.';
    end if;
  end if;

  if v_igreja is null and v_cidade is null then
    raise exception 'Informe de onde o visitante vem (igreja, cidade, estado ou país).';
  end if;
  if (v_igreja is not null and char_length(v_igreja) > 80) or (v_cidade is not null and char_length(v_cidade) > 80) then
    raise exception 'Igreja e cidade podem ter no máximo 80 caracteres.';
  end if;

  if exists (
    select 1 from public.membros m
    where m.comum_id = v_p.comum_id and m.excluido_em is null
      and public.normalizar_texto(m.nome) = public.normalizar_texto(v_nome)
  ) then
    raise exception 'Já existe um membro com este nome nesta comum. Busque pelo nome completo em vez de cadastrar de novo.';
  end if;

  insert into public.membros (nome, congregacao, cargo_id, instrumento_id, status, comum_id, cidade, bairro, visitante)
  values (v_nome, v_comum, p_cargo_id, p_instrumento_id, 'Ativo', v_p.comum_id, v_cidade, v_igreja, true)
  returning id into v_id;

  perform public.registrar_auditoria('visitante_cadastrado', 'membro', v_id,
            jsonb_build_object('portaria_id', p_portaria_id, 'comum_id', v_p.comum_id,
                               'igreja_origem', v_igreja, 'cidade_origem', v_cidade));
  return v_id;
end;
$$;

-- 5) CARTÃO DE CONFERÊNCIA DE UM MEMBRO JÁ CONHECIDO (usado logo depois de cadastrar o visitante)
create or replace function public.cartao_do_membro(p_portaria_id uuid, p_membro_id uuid)
returns table (
  membro_id uuid, nome text, congregacao text, cargo text, instrumento text,
  cidade text, bairro text, status text, foto_path text, ja_registrado_em timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_acesso_atendimento(p_portaria_id);
  return query select * from public.cartao_membro(p_portaria_id, p_membro_id);
end;
$$;

-- 6) PERMISSÕES DE EXECUÇÃO
revoke all on function
  public.opcoes_visitante(), public.cadastrar_visitante(uuid, text, uuid, uuid, text, text),
  public.cartao_do_membro(uuid, uuid)
  from public, anon;
grant execute on function
  public.opcoes_visitante(), public.cadastrar_visitante(uuid, text, uuid, uuid, text, text),
  public.cartao_do_membro(uuid, uuid)
  to authenticated;

-- 7) VERIFICAÇÃO DE SEGURANÇA: o Administrador precisa ter recebido a permissão e a consulta precisa funcionar.
--    Se falhar, a migração INTEIRA é desfeita (nada fica alterado).
do $$
declare
  v_admin uuid;
begin
  select u.id into v_admin
  from public.usuarios u join public.grupos g on g.id = u.grupo_id
  where g.sistema and g.nome = 'Administrador' and u.ativo
  limit 1;

  if v_admin is null then
    return;  -- ainda não há administrador: nada a verificar
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  if not public.tem_permissao('portaria.cadastrar_visitante') then
    raise exception 'Verificação falhou: o Administrador não recebeu a permissão de cadastrar visitante. Nada foi alterado.';
  end if;
  perform count(*) from public.opcoes_visitante();
  perform set_config('request.jwt.claims', '', true);
end $$;

commit;
