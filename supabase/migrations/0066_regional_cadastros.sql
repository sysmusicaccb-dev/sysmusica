-- ============================================================================
-- 0066 — Administrador Regional passa a ver e aprovar os Cadastros Pendentes da região dele
--
-- Sem estas duas permissões o item "Cadastros" não aparece no menu e o botão "Link de cadastro da região" some.
-- NÃO inclui cadastros.configurar (prazo dos pedidos): esse continua só do administrador global.
-- A abrangência continua valendo no banco: ele só enxerga e aprova pedidos da região dele.
-- Seguro rodar mais de uma vez. Para desfazer: 0066_reverter.sql
-- (Se a 0055 for rodada de novo, rode esta de novo em seguida.)
-- ============================================================================
do $$
declare v_id uuid;
begin
  select id into v_id from public.grupos where nome = 'Administrador Regional';
  if v_id is null then raise exception 'Grupo Administrador Regional não encontrado; nada foi alterado.'; end if;
  if (select count(*) from public.permissoes where codigo in ('cadastros.visualizar', 'cadastros.aprovar')) <> 2 then
    raise exception 'Permissões de cadastro não encontradas; nada foi alterado.';
  end if;
  insert into public.grupo_permissoes (grupo_id, permissao_codigo)
  values (v_id, 'cadastros.visualizar'), (v_id, 'cadastros.aprovar')
  on conflict do nothing;
end $$;

-- Conferência: o grupo agora tem as duas (e continua sem a de configurar o prazo)
select gp.permissao_codigo
  from public.grupo_permissoes gp join public.grupos g on g.id = gp.grupo_id
 where g.nome = 'Administrador Regional' and gp.permissao_codigo like 'cadastros.%'
 order by 1;
