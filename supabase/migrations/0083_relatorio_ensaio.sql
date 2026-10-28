-- 0083: Relatório do Ensaio (folha visual). Uma função só de LEITURA que junta, para um evento:
--   * os números do painel (Ministério, Músicos, Organistas, famílias e instrumentos) — mesma conta do painel_ao_vivo;
--   * os dados do ensaio (quem atendeu, palavra, encarregados, hino de abertura, hinos executados, campos extras).
-- Quem pode: quem tem painel.visualizar ou relatorios.visualizar, dentro da própria abrangência.
-- Não altera nada no banco além de criar a função. Seguro rodar mais de uma vez. Rodar ANTES do push.

create or replace function public.relatorio_ensaio(p_evento_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $f$
declare
  v_e      record;
  v_d      public.dados_ensaio;
  v_painel jsonb;
  v_dados  jsonb;
begin
  if not public.tem_alguma_permissao(array['painel.visualizar', 'relatorios.visualizar']) then
    raise exception 'Você não tem permissão para esta operação.' using errcode = '42501';
  end if;
  if not public.evento_na_abrangencia(p_evento_id) then
    raise exception 'Evento indisponível para você.' using errcode = '42501';
  end if;

  select e.id, e.tipo, e.tipo_evento_id, e.data_evento, e.local, e.cidade, c.nome as casa, t.modelo_ensaio
    into v_e
    from public.eventos e
    left join public.casas_oracao c on c.id = e.casa_oracao_id
    left join public.tipos_evento t on t.id = e.tipo_evento_id
   where e.id = p_evento_id and e.excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;

  -- Números do painel (cópia da conta do painel_ao_vivo, sem exigir painel.visualizar)
  with base as (
    select pr.toca, pr.linha_codigo, m.categoria, cg.nome as cargo,
           coalesce(pr.instrumento_id, m.instrumento_id) as instrumento_efetivo
      from public.presencas pr
      join public.membros m on m.id = pr.membro_id
      left join public.cargos cg on cg.id = m.cargo_id
     where pr.evento_id = p_evento_id and pr.excluido_em is null and pr.status = 'Presente'
    union all
    select a.toca, a.linha_codigo, null::text, null::text, a.instrumento_id
      from public.presencas_avulsas a
     where a.evento_id = p_evento_id and a.excluido_em is null
  ), calc as (
    select b.toca, i.nome as instrumento_nome, i.familia_id,
           coalesce(b.linha_codigo, public.classificar_linha(b.cargo, b.categoria, i.nome)) as linha,
           b.instrumento_efetivo
      from base b
      left join public.instrumentos i on i.id = b.instrumento_efetivo
  ), por_linha as (
    select l.codigo, l.bloco, l.rotulo, l.ordem, l.selecionavel, count(c.linha) as qtd
      from public.linhas_painel l
      left join calc c on c.linha = l.codigo
     group by l.codigo, l.bloco, l.rotulo, l.ordem, l.selecionavel
  ), toca as (
    select c.instrumento_nome, c.familia_id
      from calc c
      join public.linhas_painel l on l.codigo = c.linha
     where c.instrumento_efetivo is not null
       and not public.instrumento_e_orgao(c.instrumento_nome)
       and (c.toca is true or (c.toca is null and l.toca_sempre))
  ), por_familia as (
    select coalesce(f.nome, 'Sem família') as familia, count(*) as qtd
      from toca t left join public.familias f on f.id = t.familia_id
     group by 1
  ), por_instrumento as (
    select coalesce(f.nome, 'Sem família') as familia, t.instrumento_nome as instrumento, count(*) as qtd
      from toca t left join public.familias f on f.id = t.familia_id
     group by 1, 2
  )
  select jsonb_build_object(
           'total', (select count(*) from calc),
           'linhas', coalesce((select jsonb_agg(jsonb_build_object('codigo', p.codigo, 'bloco', p.bloco,
                                    'rotulo', p.rotulo, 'ordem', p.ordem, 'qtd', p.qtd, 'selecionavel', p.selecionavel)
                                    order by p.ordem)
                                 from por_linha p where p.selecionavel or p.qtd > 0), '[]'::jsonb),
           'instrumentos', coalesce((select jsonb_agg(jsonb_build_object('familia', f.familia, 'qtd', f.qtd)
                                    order by f.familia) from por_familia f), '[]'::jsonb),
           'instrumentos_detalhe', coalesce((select jsonb_agg(jsonb_build_object('familia', i.familia,
                                    'instrumento', i.instrumento, 'qtd', i.qtd)
                                    order by i.familia, i.qtd desc, i.instrumento) from por_instrumento i), '[]'::jsonb))
    into v_painel;

  -- Dados do ensaio (só quando o tipo do evento tem perfil de ensaio)
  if v_e.modelo_ensaio is not null then
    select * into v_d from public.dados_ensaio d where d.evento_id = p_evento_id;
    if v_d.id is not null then
      v_dados := jsonb_build_object(
        'atende_cargo', v_d.atende_cargo, 'atende_nome', v_d.atende_nome, 'palavra', v_d.palavra,
        'extras', coalesce(v_d.extras, '{}'::jsonb),
        'abertura', (select jsonb_build_object('categoria', h.categoria, 'numero', h.numero, 'nome', h.nome)
                       from public.hinos h where h.id = v_d.hino_abertura_id),
        'encarregados', (select coalesce(jsonb_agg(jsonb_build_object('ordem', x.ordem, 'nome', x.nome, 'cidade_uf', x.cidade_uf, 'cargo', x.cargo)
                                                   order by x.ordem), '[]'::jsonb)
                           from public.dados_ensaio_encarregados x where x.dados_ensaio_id = v_d.id),
        'hinos', (select coalesce(jsonb_agg(jsonb_build_object('categoria', h.categoria, 'numero', h.numero, 'nome', h.nome)
                                            order by dh.ordem), '[]'::jsonb)
                    from public.dados_ensaio_hinos dh join public.hinos h on h.id = dh.hino_id
                   where dh.dados_ensaio_id = v_d.id));
    end if;
  end if;

  return jsonb_build_object(
    'evento', jsonb_build_object('id', v_e.id, 'tipo', v_e.tipo, 'data_evento', v_e.data_evento, 'local', v_e.local,
                                 'cidade', v_e.cidade, 'casa_oracao', v_e.casa, 'modelo_ensaio', v_e.modelo_ensaio),
    'config', case when v_e.modelo_ensaio is null then null else public.config_ensaio_do_tipo(v_e.tipo_evento_id) end,
    'dados', v_dados,
    'painel', v_painel,
    'atualizado_em', now());
end;
$f$;

-- Só quem está logado pode chamar (a função confere a permissão por dentro)
revoke all on function public.relatorio_ensaio(uuid) from public, anon;
grant execute on function public.relatorio_ensaio(uuid) to authenticated;
