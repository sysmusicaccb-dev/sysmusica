-- ============================================================================
-- Sysmusica — 0071: lista de Casas de Oração para o preenchimento das fichas
-- Por quê: candidato a músico, aluno do GEM e beneficiário de instrumento podem ainda NÃO estar no cadastro;
--          nesses casos a ficha precisa de uma Casa de Oração escolhida na hora.
-- O que faz: cria listar_casas_para_ficha() — só as Casas da região de quem pergunta (mesma regra das fichas).
-- Seguro rodar mais de uma vez. Para desfazer: 0071_reverter.sql
-- ============================================================================
create or replace function public.listar_casas_para_ficha()
returns table(id uuid, nome text)
language plpgsql stable security definer set search_path = public
as $f$
begin
  perform public.exigir_permissao('fichas.criar');
  return query
    select c.id, c.nome
      from public.casas_oracao c
     where public.ficha_visivel(c.id)
     order by c.nome
     limit 1000;
end
$f$;
revoke all on function public.listar_casas_para_ficha() from public, anon;
grant execute on function public.listar_casas_para_ficha() to authenticated;

do $$
begin
  if to_regprocedure('public.listar_casas_para_ficha()') is null then
    raise exception 'Verificação falhou: função listar_casas_para_ficha ausente.';
  end if;
end
$$;
