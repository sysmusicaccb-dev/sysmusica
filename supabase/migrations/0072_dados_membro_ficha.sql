-- ============================================================================
-- Sysmusica — 0072: dados do cadastro da pessoa para preencher as fichas sozinhas
-- O que faz: cria dados_do_membro_para_ficha(membro) — devolve nome, Casa de Oração, cargo, instrumento, categoria,
--            nascimento, cidade/bairro e os dados pessoais do cadastro musical (estado civil, sexo, telefone, e-mail,
--            endereço, batismo...). NÃO devolve CPF, QR nem os documentos anexados.
-- Quem pode: quem tem fichas.criar e a pessoa precisa estar na região (abrangência) de quem pergunta.
-- Seguro rodar mais de uma vez. Para desfazer: 0072_reverter.sql
-- ============================================================================
create or replace function public.dados_do_membro_para_ficha(p_membro uuid)
returns jsonb
language plpgsql stable security definer set search_path = public
as $f$
declare
  v_m public.membros;
  v_c jsonb;
begin
  perform public.exigir_permissao('fichas.criar');
  select * into v_m from public.membros m where m.id = p_membro and m.excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;
  if not public.ficha_visivel(v_m.casa_oracao_id) then
    raise exception 'Esta pessoa está fora da sua abrangência.' using errcode = '42501';
  end if;

  -- dados pessoais do cadastro musical (tabela protegida), sem documentos e sem datas internas
  select to_jsonb(c) - 'membro_id' - 'criado_em' - 'atualizado_em' - 'documento_frente_path' - 'documento_verso_path'
    into v_c
    from public.membros_cadastro c
   where c.membro_id = p_membro;

  return jsonb_build_object(
           'nome', v_m.nome,
           'casa_oracao_id', v_m.casa_oracao_id,
           'casa_nome', (select c.nome from public.casas_oracao c where c.id = v_m.casa_oracao_id),
           'cargo', (select g.nome from public.cargos g where g.id = v_m.cargo_id),
           'instrumento_id', v_m.instrumento_id,
           'instrumento_nome', (select i.nome from public.instrumentos i where i.id = v_m.instrumento_id),
           'categoria', v_m.categoria,
           'data_nascimento', v_m.data_nascimento,
           'cidade', v_m.cidade,
           'bairro', v_m.bairro
         ) || coalesce(v_c, '{}'::jsonb);
end
$f$;
revoke all on function public.dados_do_membro_para_ficha(uuid) from public, anon;
grant execute on function public.dados_do_membro_para_ficha(uuid) to authenticated;

do $$
begin
  if to_regprocedure('public.dados_do_membro_para_ficha(uuid)') is null then
    raise exception 'Verificação falhou: função dados_do_membro_para_ficha ausente.';
  end if;
end
$$;
