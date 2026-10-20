-- 0036: Relatório de presença de uma portaria (impressão).
-- Uma função só entrega tudo pronto: dados do evento, da portaria, resumo e a lista de presentes
-- agrupada pelas mesmas linhas do Painel ao vivo (Ancião, Oficializado, Examinadora...), com subtotais.
-- Entram os membros presentes E as entradas sem cadastro. Respeita a permissão e a abrangência do usuário.
-- Rode no Supabase SQL Editor ANTES do git push.

do $$
begin
  if to_regclass('public.linhas_painel') is null
     or to_regprocedure('public.classificar_linha(text,text,text)') is null
     or to_regprocedure('public.evento_na_abrangencia(uuid)') is null
     or to_regprocedure('public.tem_permissao(text)') is null
     or to_regclass('public.presencas_avulsas') is null then
    raise exception 'Faltam objetos das migrações anteriores (painel ao vivo / entradas sem cadastro). Nada foi alterado.';
  end if;
end $$;

create or replace function public.relatorio_presenca_portaria(p_portaria uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_po     record;
  v_evento jsonb;
  v_dados  jsonb;
begin
  if not (public.tem_permissao('portaria.visualizar') or public.tem_permissao('portarias.visualizar')) then
    raise exception 'Você não tem permissão para ver este relatório.' using errcode = '42501';
  end if;

  select po.id, po.status, po.evento_id, po.criada_em, po.decidida_em,
         uc.nome as criador, ud.nome as decisor
    into v_po
    from public.portarias po
    left join public.usuarios uc on uc.id = po.criada_por
    left join public.usuarios ud on ud.id = po.decidida_por
   where po.id = p_portaria and po.excluido_em is null;
  if v_po.id is null then
    raise exception 'Portaria não encontrada.';
  end if;
  if not public.evento_na_abrangencia(v_po.evento_id) then
    raise exception 'Relatório indisponível para você.' using errcode = '42501';
  end if;

  select jsonb_build_object('id', e.id, 'tipo', e.tipo, 'local', e.local, 'data_evento', e.data_evento,
                            'cidade', e.cidade, 'finalidade', fi.nome, 'casa_oracao', c.nome,
                            'setor', s.nome, 'regiao', r.nome, 'cancelado', e.cancelado_em is not null)
    into v_evento
    from public.eventos e
    left join public.finalidades_evento fi on fi.id = e.finalidade_id
    left join public.casas_oracao c on c.id = e.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.regioes r on r.id = s.regiao_id
   where e.id = v_po.evento_id;

  with base as (
    -- membros cadastrados com presença
    select m.nome, cg.nome as cargo, pr.hora_entrada, pr.toca, pr.linha_codigo, m.categoria,
           coalesce(pr.instrumento_id, m.instrumento_id) as instrumento_id,
           coalesce(co.nome, nullif(m.congregacao, '')) as origem, false as sem_cadastro
      from public.presencas pr
      join public.membros m on m.id = pr.membro_id
      left join public.cargos cg on cg.id = m.cargo_id
      left join public.casas_oracao co on co.id = m.origem_casa_oracao_id
     where pr.evento_id = v_po.evento_id and pr.excluido_em is null and pr.status = 'Presente'
    union all
    -- entradas SEM cadastro (a linha e o instrumento já vêm escolhidos na Portaria)
    select null::text, null::text, a.hora_entrada, a.toca, a.linha_codigo, null::text, a.instrumento_id,
           coalesce(co.nome, nullif(a.origem_texto, '')), true
      from public.presencas_avulsas a
      left join public.casas_oracao co on co.id = a.origem_casa_oracao_id
     where a.evento_id = v_po.evento_id and a.excluido_em is null
  ), calc as (
    select b.*, i.nome as instrumento, i.familia_id,
           coalesce(b.linha_codigo, public.classificar_linha(b.cargo, b.categoria, i.nome)) as linha
      from base b
      left join public.instrumentos i on i.id = b.instrumento_id
  ), grupos as (
    select l.codigo, l.bloco, l.rotulo, l.ordem, g.qtd, g.itens
      from public.linhas_painel l
      join lateral (
        select count(*) as qtd,
               jsonb_agg(jsonb_build_object('nome', c.nome, 'cargo', c.cargo, 'instrumento', c.instrumento,
                                            'toca', c.toca, 'origem', c.origem, 'entrada', c.hora_entrada,
                                            'sem_cadastro', c.sem_cadastro)
                         order by c.sem_cadastro, c.nome, c.hora_entrada) as itens
          from calc c where c.linha = l.codigo
      ) g on g.qtd > 0
  ), por_bloco as (
    select gr.bloco, sum(gr.qtd) as qtd, min(gr.ordem) as ordem from grupos gr group by gr.bloco
  ), por_familia as (
    -- quem toca, por família (mesma regra do Painel ao vivo; órgão fica com as organistas)
    select coalesce(f.nome, 'Sem família') as familia, count(*) as qtd
      from calc c
      join public.linhas_painel l on l.codigo = c.linha
      left join public.familias f on f.id = c.familia_id
     where c.instrumento_id is not null
       and not public.instrumento_e_orgao(c.instrumento)
       and (c.toca is true or (c.toca is null and l.toca_sempre))
     group by 1
  )
  select jsonb_build_object(
           'total', (select count(*) from calc),
           'sem_cadastro', (select count(*) from calc where sem_cadastro),
           'blocos', coalesce((select jsonb_agg(jsonb_build_object('bloco', b.bloco, 'qtd', b.qtd) order by b.ordem)
                                 from por_bloco b), '[]'::jsonb),
           'familias', coalesce((select jsonb_agg(jsonb_build_object('familia', f.familia, 'qtd', f.qtd) order by f.familia)
                                   from por_familia f), '[]'::jsonb),
           'grupos', coalesce((select jsonb_agg(jsonb_build_object('codigo', g.codigo, 'bloco', g.bloco, 'rotulo', g.rotulo,
                                                                   'qtd', g.qtd, 'itens', g.itens) order by g.ordem)
                                 from grupos g), '[]'::jsonb))
    into v_dados;

  return v_dados || jsonb_build_object(
    'evento', v_evento,
    'portaria', jsonb_build_object('status', v_po.status, 'criada_por', v_po.criador, 'criada_em', v_po.criada_em,
                                   'decidida_por', v_po.decisor, 'decidida_em', v_po.decidida_em),
    'gerado_em', now());
end;
$fn$;

revoke all on function public.relatorio_presenca_portaria(uuid) from public, anon;
grant execute on function public.relatorio_presenca_portaria(uuid) to authenticated;

do $$
begin
  if to_regprocedure('public.relatorio_presenca_portaria(uuid)') is null then
    raise exception 'A função do relatório não foi criada.';
  end if;
  raise notice 'OK: relatório de presença da portaria instalado.';
end $$;
