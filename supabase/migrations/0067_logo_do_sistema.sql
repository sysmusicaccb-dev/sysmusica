-- ============================================================================
-- 0067 — Logo do sistema trocável (só o Master, o mesmo dos "Nomes do menu")
-- Cria: bucket público "marca" (png, jpg, webp, svg; até 1 MB), a tabela marca_sistema (UMA linha) e as funções
-- marca_do_sistema (qualquer pessoa, até sem login: a tela de entrada usa), salvar_marca_do_sistema e
-- restaurar_marca_padrao (só o Master). Sem linha na tabela vale a clave de sol padrão do sistema.
-- Seguro rodar mais de uma vez. Para desfazer: 0067_reverter.sql
-- ============================================================================

-- Bucket público: a imagem precisa abrir para quem ainda não entrou (tela de login)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('marca', 'marca', true, 1048576, array['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'])
on conflict (id) do update
   set public = true,
       file_size_limit = 1048576,
       allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'];

-- Só o Master envia, troca ou apaga arquivos desse bucket (a leitura é pública pelo próprio bucket)
drop policy if exists marca_master_inserir on storage.objects;
create policy marca_master_inserir on storage.objects for insert to authenticated
  with check (bucket_id = 'marca' and public.usuario_master());
drop policy if exists marca_master_atualizar on storage.objects;
create policy marca_master_atualizar on storage.objects for update to authenticated
  using (bucket_id = 'marca' and public.usuario_master())
  with check (bucket_id = 'marca' and public.usuario_master());
drop policy if exists marca_master_apagar on storage.objects;
create policy marca_master_apagar on storage.objects for delete to authenticated
  using (bucket_id = 'marca' and public.usuario_master());

-- A logo atual (no máximo uma linha)
create table if not exists public.marca_sistema (
  id             int primary key default 1 check (id = 1),
  caminho        text not null check (caminho ~ '^logo-[0-9a-f]{32}\.(png|jpg|webp|svg)$'),
  tipo           text not null check (tipo in ('image/png', 'image/jpeg', 'image/webp', 'image/svg+xml')),
  largura        int  not null check (largura between 64 and 2048),
  altura         int  not null check (altura between 64 and 2048),
  tamanho_bytes  int  not null check (tamanho_bytes between 1 and 1048576),
  atualizado_em  timestamptz not null default now(),
  atualizado_por uuid
);
alter table public.marca_sistema enable row level security;
revoke all on public.marca_sistema from anon, authenticated; -- só pelas funções abaixo

-- Qualquer pessoa lê (a tela de login também): devolve null quando vale a clave de sol padrão
create or replace function public.marca_do_sistema()
returns jsonb
language sql stable security definer set search_path = public
as $$
  select jsonb_build_object(
           'caminho', m.caminho, 'tipo', m.tipo, 'largura', m.largura, 'altura', m.altura,
           'tamanho_bytes', m.tamanho_bytes, 'versao', (extract(epoch from m.atualizado_em) * 1000)::bigint)
    from public.marca_sistema m where m.id = 1;
$$;
revoke all on function public.marca_do_sistema() from public;
grant execute on function public.marca_do_sistema() to anon, authenticated;

-- Só o Master: grava os dados da imagem que acabou de ser enviada. Devolve o caminho da anterior (para apagar).
create or replace function public.salvar_marca_do_sistema(
  p_caminho text, p_tipo text, p_largura int, p_altura int, p_tamanho int)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_antigo text;
begin
  if not public.usuario_master() then
    raise exception 'Somente o administrador Master pode trocar a logo do sistema.' using errcode = '42501';
  end if;
  if p_tipo is null or p_tipo not in ('image/png', 'image/jpeg', 'image/webp', 'image/svg+xml') then
    raise exception 'Tipo de arquivo não aceito. Use PNG, JPG, WEBP ou SVG.' using errcode = '22023';
  end if;
  if p_largura is null or p_altura is null or p_largura not between 64 and 2048 or p_altura not between 64 and 2048 then
    raise exception 'A imagem deve ter entre 64 e 2048 pixels de largura e de altura.' using errcode = '22023';
  end if;
  if p_tamanho is null or p_tamanho not between 1 and 1048576 then
    raise exception 'A imagem deve ter no máximo 1 MB.' using errcode = '22023';
  end if;
  if p_caminho is null or p_caminho !~ '^logo-[0-9a-f]{32}\.(png|jpg|webp|svg)$' then
    raise exception 'Nome de arquivo inválido.' using errcode = '22023';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'marca' and o.name = p_caminho) then
    raise exception 'O arquivo não foi encontrado no armazenamento. Envie a imagem de novo.' using errcode = '22023';
  end if;

  select caminho into v_antigo from public.marca_sistema where id = 1;
  insert into public.marca_sistema (id, caminho, tipo, largura, altura, tamanho_bytes, atualizado_em, atualizado_por)
  values (1, p_caminho, p_tipo, p_largura, p_altura, p_tamanho, now(), (select auth.uid()))
  on conflict (id) do update
     set caminho = excluded.caminho, tipo = excluded.tipo, largura = excluded.largura, altura = excluded.altura,
         tamanho_bytes = excluded.tamanho_bytes, atualizado_em = now(), atualizado_por = (select auth.uid());

  perform public.registrar_auditoria('logo_trocada', 'marca', null,
            jsonb_build_object('tipo', p_tipo, 'largura', p_largura, 'altura', p_altura, 'tamanho_bytes', p_tamanho));
  return case when v_antigo is distinct from p_caminho then v_antigo end;
end
$$;
revoke all on function public.salvar_marca_do_sistema(text, text, int, int, int) from public, anon;
grant execute on function public.salvar_marca_do_sistema(text, text, int, int, int) to authenticated;

-- Só o Master: volta para a clave de sol padrão. Devolve o caminho da imagem que estava valendo (para apagar).
create or replace function public.restaurar_marca_padrao()
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_antigo text;
begin
  if not public.usuario_master() then
    raise exception 'Somente o administrador Master pode trocar a logo do sistema.' using errcode = '42501';
  end if;
  delete from public.marca_sistema where id = 1 returning caminho into v_antigo;
  if v_antigo is not null then
    perform public.registrar_auditoria('logo_restaurada', 'marca', null, '{}'::jsonb);
  end if;
  return v_antigo;
end
$$;
revoke all on function public.restaurar_marca_padrao() from public, anon;
grant execute on function public.restaurar_marca_padrao() to authenticated;
