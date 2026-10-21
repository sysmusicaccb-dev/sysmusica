-- =====================================================================
-- SysMúsica — Migração 0037: dados de uma Casa de Oração para o formulário de evento
--
-- Devolve nome e cidade de UMA casa de oração, respeitando a abrangência do usuário
-- (mesma regra do seletor de casas). A tela de eventos usa para preencher a Cidade
-- quando a pessoa escolhe a Casa de Oração. NÃO altera nenhuma tabela.
-- =====================================================================

create or replace function public.dados_casa_oracao(p_casa_oracao uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v jsonb;
begin
  -- Fora da abrangência do usuário (ou id vazio): devolve nulo; a tela pede a cidade manualmente.
  if p_casa_oracao is null or not public.casa_oracao_na_abrangencia(p_casa_oracao) then
    return null;
  end if;

  select jsonb_build_object('id', c.id, 'nome', c.nome, 'cidade', c.cidade, 'bairro', c.bairro)
    into v
    from public.casas_oracao c
   where c.id = p_casa_oracao;

  return v;
end;
$$;

-- Só usuários logados chamam (nunca anônimos).
revoke all on function public.dados_casa_oracao(uuid) from public;
revoke all on function public.dados_casa_oracao(uuid) from anon;
grant execute on function public.dados_casa_oracao(uuid) to authenticated;
