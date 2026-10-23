-- 0055 — O grupo "Administrador Regional" passa a ter, embutidas, as permissões de
-- Secretaria + Aprovadores de portarias + Portaria (além de usuários e estrutura da região).
-- Nada além do que o Jerrivan já tinha somando esses grupos: não dá acesso global, Backup, Grupos nem Auditoria.
-- Assim o "chefe da região" não precisa de outros grupos marcados e pode conceder esses mesmos grupos aos usuários dele.
-- Seguro rodar mais de uma vez.

begin;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select r.id, gp.permissao_codigo
  from public.grupos r
  join public.grupos o on o.nome in ('Secretaria', 'Aprovadores de portarias', 'Portaria')
  join public.grupo_permissoes gp on gp.grupo_id = o.id
 where r.nome = 'Administrador Regional'
on conflict do nothing;

do $$
declare v_id uuid;
begin
  select id into v_id from public.grupos where nome = 'Administrador Regional';
  if v_id is null then raise exception 'Grupo Administrador Regional não encontrado (rode a 0054).'; end if;
  if exists (select 1 from public.grupo_permissoes
              where grupo_id = v_id
                and (permissao_codigo = 'acesso.global' or permissao_codigo like 'backup.%'
                     or permissao_codigo like 'grupos.%' or permissao_codigo = 'auditoria.visualizar')) then
    raise exception 'Verificação falhou: o Administrador Regional não pode ter acesso global, backup, grupos ou auditoria.';
  end if;
  if not exists (select 1 from public.grupo_permissoes where grupo_id = v_id and permissao_codigo = 'portarias.aprovar') then
    raise exception 'Verificação falhou: permissões de portaria não copiadas.';
  end if;
end $$;

commit;
