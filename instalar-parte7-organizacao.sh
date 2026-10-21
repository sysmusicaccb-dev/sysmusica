#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 7: nova Organização (Estado › RRM › RA › ADM › Setor › Casa de Oração)
#
#  ATENÇÃO: rode ANTES o SQL supabase/migrations/0039_organizacao_rrm_ra_adm.sql no Supabase (SQL Editor).
#  Este instalador troca as telas (Organização, Vínculos, Visitante, Relatórios, Backup, Auditoria)
#  e cria o arquivo da migração na pasta supabase/migrations (para o histórico do projeto).
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-parte7-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && bash instalar-parte7-ilustracoes.sh
# Log:  /tmp/instalar-parte7.log
# =============================================================================

LOG=/tmp/instalar-parte7.log
BKP=/tmp/bkp-parte7-$(date +%Y%m%d-%H%M%S)
RAIZ="$(pwd)"

(
[ -f package.json ] && [ -d src ] || { echo "ERRO: rode dentro da pasta sysmusica (onde está o package.json)."; exit 1; }
mkdir -p "$BKP"
export BKP RAIZ

echo "== 1/3  Conferindo e aplicando as alterações =="
# (se o SQL 0039 ainda não foi rodado no Supabase, o sistema ficará fora do ar até rodar)
python3 - <<'PYSCRIPT'
import os, shutil, sys, hashlib

RAIZ = os.environ["RAIZ"]
BKP = os.environ["BKP"]

# (arquivo, trecho antigo, trecho novo) — cada "antigo" precisa existir EXATAMENTE 1 vez no arquivo.
# Os trechos usam \n; o instalador converte para o fim de linha do próprio arquivo (CRLF ou LF).
EDITS = [
    ("src/modules/organizacao/components/FormularioNo.tsx",
     r''' * SysMúsica — Formulário de um item da organização (estado, região, setor ou casa de oração), novo ou em edição.''',
     r''' * SysMúsica — Formulário de um item da organização (estado, RRM, RA, ADM, setor ou casa de oração), novo ou em edição.'''),
    ("src/modules/organizacao/components/FormularioNo.tsx",
     r''' * Em item novo, o "pai" (estado, região ou setor) vem de onde o botão + foi clicado. Para mudar uma''',
     r''' * Em item novo, o "pai" (estado, RRM, RA, ADM ou setor) vem de onde o botão + foi clicado. Para mudar uma'''),
    ("src/modules/organizacao/components/FormularioNo.tsx",
     r'''placeholder={nivel === "SETOR" ? "Ex: Setor 6" : nivel === "CASA_ORACAO" ? "Ex: Central Itinga" : "Nome"}''',
     r'''placeholder={
            {
              ESTADO: "Ex: Bahia",
              RRM: "Ex: Vitória da Conquista",
              RA: "Ex: Jequié",
              ADM: "Ex: Ipiaú",
              SETOR: "Ex: Setor 1",
              CASA_ORACAO: "Ex: Central Itinga",
            }[nivel]
          }'''),
    ("src/app/(painel)/administracao/organizacao/page.tsx",
     r''' * SysMúsica — Página /administracao/organizacao: estados, regiões, setores e casas de oração.''',
     r''' * SysMúsica — Página /administracao/organizacao: Estado › RRM › RA › ADM › Setor (opcional) › Casa de Oração.'''),
    ("src/app/(painel)/administracao/organizacao/page.tsx",
     r''' * Cadastro pelo sistema (sem código fixo), com ativar/inativar e transferência de casa de oração entre setores.''',
     r''' * Cadastro pelo sistema (sem código fixo), com ativar/inativar e transferência de casa de oração entre ADMs e setores.'''),
    ("src/app/(painel)/administracao/organizacao/page.tsx",
     r'''descricao="Estados, regiões, setores e casas de oração. O acesso dos usuários aos dados segue esta estrutura."''',
     r'''descricao="Estado › RRM › RA › ADM › Setor (opcional) › Casa de Oração. O acesso dos usuários aos dados segue esta estrutura."'''),
    ("src/app/(painel)/administracao/organizacao/page.tsx",
     r'''"A casa de oração e as portarias dela passam a valer para o setor escolhido."''',
     r'''"A casa de oração e as portarias dela passam a valer para o destino escolhido (ADM ou setor)."'''),
    ("src/modules/organizacao/services/organizacao.ts",
     r''' * SysMúsica — Serviço de dados da organização (Estado > Região > Setor > Casa de Oração) e dos vínculos dos usuários.''',
     r''' * SysMúsica — Serviço de dados da organização (Estado › RRM › RA › ADM › Setor › Casa de Oração) e dos vínculos dos usuários.'''),
    ("src/modules/organizacao/services/organizacao.ts",
     r'''/** Muda uma casa de oração de setor (fica no histórico e na auditoria). */
export async function transferirCasaOracao(casaOracaoId: string, setorId: string, justificativa: string): Promise<void> {''',
     r'''/** Muda uma casa de oração de local: o destino é uma ADM (fica sem setor) ou um setor (fica no histórico e na auditoria). */
export async function transferirCasaOracao(casaOracaoId: string, destinoId: string, justificativa: string): Promise<void> {'''),
    ("src/modules/organizacao/services/organizacao.ts",
     r'''    p_setor: setorId,
''',
     r'''    p_destino: destinoId,
'''),
    ("src/modules/administracao/components/FormularioVinculos.tsx",
     r''' * O usuário pode ser ligado a um estado, região, setor ou casa de oração: o acesso desce em cascata (um setor''',
     r''' * O usuário pode ser ligado a um estado, RRM, RA, ADM, setor ou casa de oração: o acesso desce em cascata (uma ADM'''),
    ("src/modules/administracao/components/FormularioVinculos.tsx",
     r'''import { chaveVinculo, FILHO_DE, filhosDe, lerChaveVinculo, ROTULO_NIVEL } from "@/modules/organizacao/regras";''',
     r'''import { chaveVinculo, filhosDe, filhosDoNo, lerChaveVinculo, ROTULO_NIVEL } from "@/modules/organizacao/regras";'''),
    ("src/modules/administracao/components/FormularioVinculos.tsx",
     r'''    const nivelFilho = FILHO_DE[no.nivel];
    const filhos = nivelFilho ? filhosDe(arvore, no.id, nivelFilho) : [];
''',
     r'''    const filhos = filhosDoNo(arvore, no); // na ADM: setores e casas de oração sem setor
'''),
    ("src/modules/administracao/components/FormularioVinculos.tsx",
     r'''        Marcar um setor inclui todas as casas de oração dele; marcar uma região inclui todos os setores. Sem nenhuma
        marcação, não vê nada.''',
     r'''        Marcar um nível inclui tudo que está abaixo dele: a ADM inclui os setores e as casas de oração dela; a RA inclui
        as ADMs; a RRM inclui as RAs; o estado inclui tudo. Sem nenhuma marcação, não vê nada.'''),
    ("src/app/(painel)/administracao/usuarios/page.tsx",
     r'''descricao: "Estado, região, setor ou casa de oração que o usuário pode ver e usar.",''',
     r'''descricao: "Estado, RRM, RA, ADM, setor ou casa de oração que o usuário pode ver e usar.",'''),
    ("src/modules/atendimento/components/FormularioVisitante.tsx",
     r''' * (Estado > Região > Setor > Casa de Oração, cadastrados em Organização): nada de origem digitada à mão.''',
     r''' * (Estado › RRM › RA › ADM › Setor (opcional) › Casa de Oração, cadastrados em Organização): nada de origem digitada à mão.'''),
    ("src/modules/atendimento/components/FormularioVisitante.tsx",
     r'''  const [regiaoId, setRegiaoId] = useState("");
  const [setorId, setSetorId] = useState("");
''',
     r'''  const [rrmId, setRrmId] = useState("");
  const [raId, setRaId] = useState("");
  const [admId, setAdmId] = useState("");
  const [setorId, setSetorId] = useState("");
'''),
    ("src/modules/atendimento/components/FormularioVisitante.tsx",
     r'''  const regioes = estadoId ? filhosDe(origens, estadoId, "REGIAO") : [];
  const setores = regiaoId ? filhosDe(origens, regiaoId, "SETOR") : [];
  const casasOracao = setorId ? filhosDe(origens, setorId, "CASA_ORACAO") : [];

  // Ao trocar um nível, limpa os de baixo
  function trocarEstado(id: string) {
    setEstadoId(id);
    setRegiaoId("");
    setSetorId("");
    setCasaOracaoId("");
  }''',
     r'''  const rrms = estadoId ? filhosDe(origens, estadoId, "RRM") : [];
  const ras = rrmId ? filhosDe(origens, rrmId, "RA") : [];
  const adms = raId ? filhosDe(origens, raId, "ADM") : [];
  const setores = admId ? filhosDe(origens, admId, "SETOR") : [];
  // Com setor escolhido: as casas do setor; sem setor: as casas ligadas direto à ADM
  const casasOracao = admId ? filhosDe(origens, setorId || admId, "CASA_ORACAO") : [];

  // Ao trocar um nível, limpa os de baixo
  function trocarEstado(id: string) {
    setEstadoId(id);
    setRrmId("");
    setRaId("");
    setAdmId("");
    setSetorId("");
    setCasaOracaoId("");
  }
  function trocarRrm(id: string) {
    setRrmId(id);
    setRaId("");
    setAdmId("");
    setSetorId("");
    setCasaOracaoId("");
  }
  function trocarRa(id: string) {
    setRaId(id);
    setAdmId("");
    setSetorId("");
    setCasaOracaoId("");
  }
  function trocarAdm(id: string) {
    setAdmId(id);
    setSetorId("");
    setCasaOracaoId("");
  }
  function trocarSetor(id: string) {
    setSetorId(id);
    setCasaOracaoId("");
  }'''),
    ("src/modules/atendimento/components/FormularioVisitante.tsx",
     r'''        <div className="space-y-1.5">
          <label htmlFor="regiao-visitante" className="text-xs font-medium text-slate-600">
            Região
          </label>
          <select
            id="regiao-visitante"
            value={regiaoId}
            onChange={(e) => trocarRegiao(e.target.value)}
            disabled={salvando || !estadoId}
            className={classeInput}
          >
            <option value="">Selecione a região</option>
            {regioes.map((item) => (
              <option key={item.id} value={item.id}>
                {item.nome}
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-1.5">
          <label htmlFor="setor-visitante" className="text-xs font-medium text-slate-600">
            Setor
          </label>
          <select
            id="setor-visitante"
            value={setorId}
            onChange={(e) => trocarSetor(e.target.value)}
            disabled={salvando || !regiaoId}
            className={classeInput}
          >
            <option value="">Selecione o setor</option>
            {setores.map((item) => (
              <option key={item.id} value={item.id}>
                {item.nome}
              </option>
            ))}
          </select>
        </div>
''',
     r'''        <div className="space-y-1.5">
          <label htmlFor="rrm-visitante" className="text-xs font-medium text-slate-600">
            RRM (Reunião Regional Ministerial)
          </label>
          <select
            id="rrm-visitante"
            value={rrmId}
            onChange={(e) => trocarRrm(e.target.value)}
            disabled={salvando || !estadoId}
            className={classeInput}
          >
            <option value="">Selecione a RRM</option>
            {rrms.map((item) => (
              <option key={item.id} value={item.id}>
                {item.nome}
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-1.5">
          <label htmlFor="ra-visitante" className="text-xs font-medium text-slate-600">
            RA (Regional Administrativa)
          </label>
          <select
            id="ra-visitante"
            value={raId}
            onChange={(e) => trocarRa(e.target.value)}
            disabled={salvando || !rrmId}
            className={classeInput}
          >
            <option value="">Selecione a RA</option>
            {ras.map((item) => (
              <option key={item.id} value={item.id}>
                {item.nome}
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-1.5">
          <label htmlFor="adm-visitante" className="text-xs font-medium text-slate-600">
            ADM (Administração)
          </label>
          <select
            id="adm-visitante"
            value={admId}
            onChange={(e) => trocarAdm(e.target.value)}
            disabled={salvando || !raId}
            className={classeInput}
          >
            <option value="">Selecione a ADM</option>
            {adms.map((item) => (
              <option key={item.id} value={item.id}>
                {item.nome}
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-1.5">
          <label htmlFor="setor-visitante" className="text-xs font-medium text-slate-600">
            Setor (opcional)
          </label>
          <select
            id="setor-visitante"
            value={setorId}
            onChange={(e) => trocarSetor(e.target.value)}
            disabled={salvando || !admId}
            className={classeInput}
          >
            <option value="">Sem setor (casas ligadas direto à ADM)</option>
            {setores.map((item) => (
              <option key={item.id} value={item.id}>
                {item.nome}
              </option>
            ))}
          </select>
        </div>
'''),
    ("src/modules/atendimento/components/FormularioVisitante.tsx",
     r'''disabled={salvando || !setorId}
            className={classeInput}
          >
            <option value="">Selecione a casa de oração</option>''',
     r'''disabled={salvando || !admId}
            className={classeInput}
          >
            <option value="">Selecione a casa de oração</option>'''),
    ("src/modules/atendimento/components/FormularioVisitante.tsx",
     r'''          A cidade e a igreja de origem são preenchidas por esta escolha. Se a origem não aparecer na lista,''',
     r'''          A cidade e a igreja de origem são preenchidas por esta escolha. Sem setor escolhido, aparecem as casas ligadas direto à ADM. Se a origem não aparecer na lista,'''),
    ("src/modules/relatorios/regras.ts",
     r'''    regiao: nomeDe("REGIAO", filtros.regiaoId),''',
     r'''    regiao: nomeDe("RA", filtros.regiaoId), // o filtro "regiao" dos relatórios é a RA'''),
    ("src/modules/relatorios/regras.ts",
     r'''partes.push(`Região: ${rotulos.regiao}`);''',
     r'''partes.push(`RA: ${rotulos.regiao}`);'''),
    ("src/modules/relatorios/regras.ts",
     r'''{ id: "localizacao", rotulo: "Região, setor e casa de oração" },''',
     r'''{ id: "localizacao", rotulo: "RA, setor e casa de oração" },'''),
    ("src/modules/relatorios/regras.ts",
     r'''/** Regiões para escolher (com o estado na frente se houver mais de um estado). */
export function opcoesRegiao(nos: NoOrganizacao[]): OpcaoSelecao[] {
  const estados = nos.filter((no) => no.nivel === "ESTADO");
  const nomeDoEstado = new Map(estados.map((estado) => [estado.id, estado.nome] as const));
  return nos
    .filter((no) => no.nivel === "REGIAO")
    .map((regiao) => {
      const estado = regiao.parent_id ? nomeDoEstado.get(regiao.parent_id) : undefined;
      return { id: regiao.id, rotulo: estados.length > 1 && estado ? `${estado} › ${regiao.nome}` : regiao.nome };
    })
    .sort(porRotulo);
}

/** Setores da região escolhida (vazio sem região). */
export function opcoesSetor(nos: NoOrganizacao[], regiaoId: string): OpcaoSelecao[] {
  return regiaoId ? filhosDe(nos, regiaoId, "SETOR").map((no) => ({ id: no.id, rotulo: no.nome })) : [];
}

/** Casas de Oração do setor escolhido (vazio sem setor). */
export function opcoesCasaOracao(nos: NoOrganizacao[], setorId: string): OpcaoSelecao[] {
  return setorId ? filhosDe(nos, setorId, "CASA_ORACAO").map((no) => ({ id: no.id, rotulo: no.nome })) : [];
}
''',
     r'''/** RAs para escolher (com o estado na frente se houver mais de um estado). */
export function opcoesRegiao(nos: NoOrganizacao[]): OpcaoSelecao[] {
  const estados = nos.filter((no) => no.nivel === "ESTADO");
  const porId = new Map(nos.map((no) => [no.id, no] as const));
  return nos
    .filter((no) => no.nivel === "RA")
    .map((ra) => {
      const rrm = ra.parent_id ? porId.get(ra.parent_id) : undefined;
      const estado = rrm?.parent_id ? porId.get(rrm.parent_id) : undefined;
      return { id: ra.id, rotulo: estados.length > 1 && estado ? `${estado.nome} › ${ra.nome}` : ra.nome };
    })
    .sort(porRotulo);
}

/** Setores da RA escolhida, com o nome da ADM na frente ("Setor 1" existe em várias ADMs). Vazio sem RA. */
export function opcoesSetor(nos: NoOrganizacao[], regiaoId: string): OpcaoSelecao[] {
  if (!regiaoId) return [];
  return filhosDe(nos, regiaoId, "ADM")
    .flatMap((adm) => filhosDe(nos, adm.id, "SETOR").map((setor) => ({ id: setor.id, rotulo: `${adm.nome} › ${setor.nome}` })))
    .sort(porRotulo);
}

/**
 * Casas de Oração para escolher: as do setor escolhido; sem setor, todas as da RA (as ligadas direto à ADM
 * e as que estão dentro de setores). Vazio sem RA.
 */
export function opcoesCasaOracao(nos: NoOrganizacao[], regiaoId: string, setorId: string): OpcaoSelecao[] {
  const comoOpcao = (no: NoOrganizacao) => ({ id: no.id, rotulo: no.nome });
  if (setorId) return filhosDe(nos, setorId, "CASA_ORACAO").map(comoOpcao);
  if (!regiaoId) return [];
  return filhosDe(nos, regiaoId, "ADM")
    .flatMap((adm) => [
      ...filhosDe(nos, adm.id, "CASA_ORACAO"),
      ...filhosDe(nos, adm.id, "SETOR").flatMap((setor) => filhosDe(nos, setor.id, "CASA_ORACAO")),
    ])
    .map(comoOpcao)
    .sort(porRotulo);
}
'''),
    ("src/modules/relatorios/regras.ts",
     r'''/** A estrutura Estado > Região > Setor > Casa de Oração em linhas (com os filtros de região e setor). */
export function linhasOrganizacao(
  nos: NoOrganizacao[],
  filtro: { regiaoId: string; setorId: string }
): LinhaRelatorio[] {
  const linhas: LinhaRelatorio[] = [];
  const filtrando = filtro.regiaoId !== "" || filtro.setorId !== "";
  const situacao = (no: NoOrganizacao) => (no.ativo === false ? "Inativo" : "Ativo");

  const montar = (
    no: NoOrganizacao,
    caminho: { estado?: string; regiao?: string; setor?: string; casa_oracao?: string }
  ): LinhaRelatorio => ({
    nivel: ROTULO_NIVEL[no.nivel],
    estado: caminho.estado ?? "",
    regiao: caminho.regiao ?? "",
    setor: caminho.setor ?? "",
    casa_oracao: caminho.casa_oracao ?? "",
    situacao: situacao(no),
    cidade: no.cidade ?? "",
    bairro: no.bairro ?? "",
    membros: no.nivel === "CASA_ORACAO" ? String(no.qtd_membros ?? 0) : "",
    itens: no.nivel === "CASA_ORACAO" ? "" : String(no.qtd_filhos ?? 0),
  });

  for (const estado of filhosDe(nos, null, "ESTADO")) {
    if (!filtrando) linhas.push(montar(estado, { estado: estado.nome }));

    for (const regiao of filhosDe(nos, estado.id, "REGIAO")) {
      if (filtro.regiaoId && regiao.id !== filtro.regiaoId) continue;
      if (!filtro.setorId) linhas.push(montar(regiao, { estado: estado.nome, regiao: regiao.nome }));

      for (const setor of filhosDe(nos, regiao.id, "SETOR")) {
        if (filtro.setorId && setor.id !== filtro.setorId) continue;
        const caminho = { estado: estado.nome, regiao: regiao.nome, setor: setor.nome };
        linhas.push(montar(setor, caminho));

        for (const casaOracao of filhosDe(nos, setor.id, "CASA_ORACAO")) {
          linhas.push(montar(casaOracao, { ...caminho, casa_oracao: casaOracao.nome }));
        }
      }
    }
  }

  // Casas de Oração que ainda não têm setor
  if (!filtrando) {
    for (const casaOracao of filhosDe(nos, null, "CASA_ORACAO")) {
      linhas.push(montar(casaOracao, { casa_oracao: casaOracao.nome }));
    }
  }
  return linhas;
}
''',
     r'''/** A estrutura Estado › RRM › RA › ADM › Setor › Casa de Oração em linhas (com os filtros de RA e de setor). */
export function linhasOrganizacao(
  nos: NoOrganizacao[],
  filtro: { regiaoId: string; setorId: string }
): LinhaRelatorio[] {
  const linhas: LinhaRelatorio[] = [];
  const filtrando = filtro.regiaoId !== "" || filtro.setorId !== "";
  const situacao = (no: NoOrganizacao) => (no.ativo === false ? "Inativo" : "Ativo");

  // "regiao" é a RA (o nome da coluna é mantido para os relatórios e as exportações já salvas)
  type Caminho = { estado?: string; rrm?: string; regiao?: string; adm?: string; setor?: string; casa_oracao?: string };
  const montar = (no: NoOrganizacao, caminho: Caminho): LinhaRelatorio => ({
    nivel: ROTULO_NIVEL[no.nivel],
    estado: caminho.estado ?? "",
    rrm: caminho.rrm ?? "",
    regiao: caminho.regiao ?? "",
    adm: caminho.adm ?? "",
    setor: caminho.setor ?? "",
    casa_oracao: caminho.casa_oracao ?? "",
    situacao: situacao(no),
    cidade: no.cidade ?? "",
    bairro: no.bairro ?? "",
    membros: no.nivel === "CASA_ORACAO" ? String(no.qtd_membros ?? 0) : "",
    itens: no.nivel === "CASA_ORACAO" ? "" : String(no.qtd_filhos ?? 0),
  });

  for (const estado of filhosDe(nos, null, "ESTADO")) {
    if (!filtrando) linhas.push(montar(estado, { estado: estado.nome }));

    for (const rrm of filhosDe(nos, estado.id, "RRM")) {
      if (!filtrando) linhas.push(montar(rrm, { estado: estado.nome, rrm: rrm.nome }));

      for (const ra of filhosDe(nos, rrm.id, "RA")) {
        if (filtro.regiaoId && ra.id !== filtro.regiaoId) continue;
        const caminhoRa = { estado: estado.nome, rrm: rrm.nome, regiao: ra.nome };
        if (!filtro.setorId) linhas.push(montar(ra, caminhoRa));

        for (const adm of filhosDe(nos, ra.id, "ADM")) {
          const caminhoAdm = { ...caminhoRa, adm: adm.nome };
          if (!filtro.setorId) linhas.push(montar(adm, caminhoAdm));

          for (const setor of filhosDe(nos, adm.id, "SETOR")) {
            if (filtro.setorId && setor.id !== filtro.setorId) continue;
            const caminhoSetor = { ...caminhoAdm, setor: setor.nome };
            linhas.push(montar(setor, caminhoSetor));
            for (const casaOracao of filhosDe(nos, setor.id, "CASA_ORACAO")) {
              linhas.push(montar(casaOracao, { ...caminhoSetor, casa_oracao: casaOracao.nome }));
            }
          }

          // Casas de Oração ligadas direto à ADM (sem setor): não aparecem quando se filtra por um setor
          if (!filtro.setorId) {
            for (const casaOracao of filhosDe(nos, adm.id, "CASA_ORACAO")) {
              linhas.push(montar(casaOracao, { ...caminhoAdm, casa_oracao: casaOracao.nome }));
            }
          }
        }
      }
    }
  }
  return linhas;
}
'''),
    ("src/modules/relatorios/regras.test.ts",
     r'''Período: 01/10/2026 a 18/10/2026 · Região: Salvador · Presença: Presente''',
     r'''Período: 01/10/2026 a 18/10/2026 · RA: Salvador · Presença: Presente'''),
    ("src/modules/relatorios/regras.test.ts",
     r'''// Bahia > Salvador (Setor 1, Setor 2) e Jequié (Setor 1); casas de oração: Itinga e Caique em Salvador/Setor 1, Central em Jequié/Setor 1, Solta sem setor
const nos: NoOrganizacao[] = [
  { nivel: "ESTADO", id: "e1", parent_id: null, nome: "Bahia", ativo: true, qtd_filhos: 2 },
  { nivel: "REGIAO", id: "r1", parent_id: "e1", nome: "Salvador", ativo: true, qtd_filhos: 2 },
  { nivel: "REGIAO", id: "r2", parent_id: "e1", nome: "Jequié", ativo: true, qtd_filhos: 1 },
  { nivel: "SETOR", id: "s1", parent_id: "r1", nome: "Setor 1", ativo: true, qtd_filhos: 2 },
  { nivel: "SETOR", id: "s2", parent_id: "r1", nome: "Setor 2", ativo: true, qtd_filhos: 0 },
  { nivel: "SETOR", id: "s3", parent_id: "r2", nome: "Setor 1", ativo: true, qtd_filhos: 1 },
  { nivel: "CASA_ORACAO", id: "c1", parent_id: "s1", nome: "Itinga", ativo: true, qtd_membros: 7, cidade: "Lauro de Freitas" },
  { nivel: "CASA_ORACAO", id: "c2", parent_id: "s1", nome: "Caique", ativo: false, qtd_membros: 2 },
  { nivel: "CASA_ORACAO", id: "c3", parent_id: "s3", nome: "Central", ativo: true, qtd_membros: 4 },
  { nivel: "CASA_ORACAO", id: "c4", parent_id: null, nome: "Solta", ativo: true, qtd_membros: 0 },
];

describe("opções dos filtros de organização", () => {
  it("lista regiões, setores da região e casas de oração do setor", () => {
    expect(opcoesRegiao(nos).map((o) => o.rotulo)).toEqual(["Jequié", "Salvador"]);
    expect(opcoesSetor(nos, "r1").map((o) => o.rotulo)).toEqual(["Setor 1", "Setor 2"]);
    expect(opcoesSetor(nos, "")).toEqual([]);
    expect(opcoesCasaOracao(nos, "s1").map((o) => o.rotulo)).toEqual(["Caique", "Itinga"]);
    expect(opcoesCasaOracao(nos, "")).toEqual([]);
  });

  it("coloca o estado na frente da região quando há mais de um estado", () => {
    const maisUmEstado: NoOrganizacao[] = [...nos, { nivel: "ESTADO", id: "e2", parent_id: null, nome: "Sergipe" }];
    expect(opcoesRegiao(maisUmEstado).map((o) => o.rotulo)).toContain("Bahia › Salvador");
  });
});

describe("linhasOrganizacao", () => {
  it("traz a estrutura inteira, na ordem, com as casas de oração sem setor no fim", () => {
    const linhas = linhasOrganizacao(nos, { regiaoId: "", setorId: "" });
    expect(linhas.map((l) => `${l.nivel}:${l.casa_oracao || l.setor || l.regiao || l.estado}`)).toEqual([
      "Estado:Bahia",
      "Região:Jequié",
      "Setor:Setor 1",
      "Casa de Oração:Central",
      "Região:Salvador",
      "Setor:Setor 1",
      "Casa de Oração:Caique",
      "Casa de Oração:Itinga",
      "Setor:Setor 2",
      "Casa de Oração:Solta",
    ]);
  });

  it("preenche situação, membros e cidade da casa de oração", () => {
    const linhas = linhasOrganizacao(nos, { regiaoId: "", setorId: "" });
    const itinga = linhas.find((l) => l.casa_oracao === "Itinga");
    expect(itinga).toMatchObject({ situacao: "Ativo", membros: "7", cidade: "Lauro de Freitas", regiao: "Salvador" });
    expect(linhas.find((l) => l.casa_oracao === "Caique")?.situacao).toBe("Inativo");
  });

  it("filtra por região e por setor (separando o Setor 1 de cada região)", () => {
    const daRegiao = linhasOrganizacao(nos, { regiaoId: "r1", setorId: "" });
    expect(daRegiao.some((l) => l.regiao === "Jequié")).toBe(false);
    expect(daRegiao.some((l) => l.nivel === "Estado")).toBe(false);

    const doSetor = linhasOrganizacao(nos, { regiaoId: "", setorId: "s3" });
    expect(doSetor.map((l) => l.nivel)).toEqual(["Setor", "Casa de Oração"]);
    expect(doSetor[1].casa_oracao).toBe("Central");
  });
});
''',
     r'''// Bahia > RRM Salvador > RA Salvador > ADM Centro (Setor 1: Itinga e Caique · Setor 2)
//       > RRM Vitória da Conquista > RA Jequié > ADM Ipiaú (Setor 1: Central · casa "Solta" ligada direto à ADM, sem setor)
const nos: NoOrganizacao[] = [
  { nivel: "ESTADO", id: "e1", parent_id: null, nome: "Bahia", ativo: true, qtd_filhos: 2 },
  { nivel: "RRM", id: "m1", parent_id: "e1", nome: "Salvador", ativo: true, qtd_filhos: 1 },
  { nivel: "RRM", id: "m2", parent_id: "e1", nome: "Vitória da Conquista", ativo: true, qtd_filhos: 1 },
  { nivel: "RA", id: "r1", parent_id: "m1", nome: "Salvador", ativo: true, qtd_filhos: 1 },
  { nivel: "RA", id: "r2", parent_id: "m2", nome: "Jequié", ativo: true, qtd_filhos: 1 },
  { nivel: "ADM", id: "a1", parent_id: "r1", nome: "Centro", ativo: true, qtd_filhos: 2 },
  { nivel: "ADM", id: "a2", parent_id: "r2", nome: "Ipiaú", ativo: true, qtd_filhos: 2 },
  { nivel: "SETOR", id: "s1", parent_id: "a1", nome: "Setor 1", ativo: true, qtd_filhos: 2 },
  { nivel: "SETOR", id: "s2", parent_id: "a1", nome: "Setor 2", ativo: true, qtd_filhos: 0 },
  { nivel: "SETOR", id: "s3", parent_id: "a2", nome: "Setor 1", ativo: true, qtd_filhos: 1 },
  { nivel: "CASA_ORACAO", id: "c1", parent_id: "s1", nome: "Itinga", ativo: true, qtd_membros: 7, cidade: "Lauro de Freitas" },
  { nivel: "CASA_ORACAO", id: "c2", parent_id: "s1", nome: "Caique", ativo: false, qtd_membros: 2 },
  { nivel: "CASA_ORACAO", id: "c3", parent_id: "s3", nome: "Central", ativo: true, qtd_membros: 4 },
  { nivel: "CASA_ORACAO", id: "c4", parent_id: "a2", nome: "Solta", ativo: true, qtd_membros: 0 },
];

describe("opções dos filtros de organização", () => {
  it("lista RAs, setores da RA (com a ADM na frente) e casas de oração", () => {
    expect(opcoesRegiao(nos).map((o) => o.rotulo)).toEqual(["Jequié", "Salvador"]);
    expect(opcoesSetor(nos, "r1").map((o) => o.rotulo)).toEqual(["Centro › Setor 1", "Centro › Setor 2"]);
    expect(opcoesSetor(nos, "")).toEqual([]);
    expect(opcoesCasaOracao(nos, "r1", "s1").map((o) => o.rotulo)).toEqual(["Caique", "Itinga"]);
    expect(opcoesCasaOracao(nos, "", "")).toEqual([]);
  });

  it("sem setor escolhido, as casas são todas as da RA (inclusive as ligadas direto à ADM)", () => {
    expect(opcoesCasaOracao(nos, "r2", "").map((o) => o.rotulo)).toEqual(["Central", "Solta"]);
    expect(opcoesCasaOracao(nos, "r1", "").map((o) => o.rotulo)).toEqual(["Caique", "Itinga"]);
  });

  it("coloca o estado na frente da RA quando há mais de um estado", () => {
    const maisUmEstado: NoOrganizacao[] = [...nos, { nivel: "ESTADO", id: "e2", parent_id: null, nome: "Sergipe" }];
    expect(opcoesRegiao(maisUmEstado).map((o) => o.rotulo)).toContain("Bahia › Salvador");
  });
});

describe("linhasOrganizacao", () => {
  const nomeDaLinha = (l: Record<string, string>) =>
    `${l.nivel}:${l.casa_oracao || l.setor || l.adm || l.regiao || l.rrm || l.estado}`;

  it("traz a estrutura inteira, na ordem, com as casas de oração sem setor no fim de cada ADM", () => {
    const linhas = linhasOrganizacao(nos, { regiaoId: "", setorId: "" });
    expect(linhas.map(nomeDaLinha)).toEqual([
      "Estado:Bahia",
      "RRM:Salvador",
      "RA:Salvador",
      "ADM:Centro",
      "Setor:Setor 1",
      "Casa de Oração:Caique",
      "Casa de Oração:Itinga",
      "Setor:Setor 2",
      "RRM:Vitória da Conquista",
      "RA:Jequié",
      "ADM:Ipiaú",
      "Setor:Setor 1",
      "Casa de Oração:Central",
      "Casa de Oração:Solta",
    ]);
  });

  it("preenche o caminho, a situação, os membros e a cidade da casa de oração", () => {
    const linhas = linhasOrganizacao(nos, { regiaoId: "", setorId: "" });
    const itinga = linhas.find((l) => l.casa_oracao === "Itinga");
    expect(itinga).toMatchObject({
      situacao: "Ativo",
      membros: "7",
      cidade: "Lauro de Freitas",
      rrm: "Salvador",
      regiao: "Salvador",
      adm: "Centro",
      setor: "Setor 1",
    });
    expect(linhas.find((l) => l.casa_oracao === "Caique")?.situacao).toBe("Inativo");
    // casa ligada direto à ADM: sem setor no caminho
    expect(linhas.find((l) => l.casa_oracao === "Solta")).toMatchObject({ adm: "Ipiaú", setor: "" });
  });

  it("filtra por RA e por setor (separando o Setor 1 de cada ADM)", () => {
    const daRa = linhasOrganizacao(nos, { regiaoId: "r1", setorId: "" });
    expect(daRa.some((l) => l.regiao === "Jequié")).toBe(false);
    expect(daRa.some((l) => l.nivel === "Estado" || l.nivel === "RRM")).toBe(false);
    expect(linhasOrganizacao(nos, { regiaoId: "r2", setorId: "" }).some((l) => l.casa_oracao === "Solta")).toBe(true);

    const doSetor = linhasOrganizacao(nos, { regiaoId: "", setorId: "s3" });
    expect(doSetor.map((l) => l.nivel)).toEqual(["Setor", "Casa de Oração"]);
    expect(doSetor[1].casa_oracao).toBe("Central");
  });
});
'''),
    ("src/modules/relatorios/components/FiltrosDoRelatorio.tsx",
     r''' * SysMúsica — Filtros do relatório. Mostra só os filtros do tipo escolhido. Região, setor e casa de oração são''',
     r''' * SysMúsica — Filtros do relatório. Mostra só os filtros do tipo escolhido. RA, setor e casa de oração são'''),
    ("src/modules/relatorios/components/FiltrosDoRelatorio.tsx",
     r'''<Campo id="rel-regiao" rotulo="Região">''',
     r'''<Campo id="rel-regiao" rotulo="RA (Regional Administrativa)">'''),
    ("src/modules/relatorios/components/FiltrosDoRelatorio.tsx",
     r'''<option value="">Todas as regiões</option>''',
     r'''<option value="">Todas as RAs</option>'''),
    ("src/modules/relatorios/components/FiltrosDoRelatorio.tsx",
     r'''<option value="">{valores.regiaoId ? "Todos os setores" : "Escolha a região primeiro"}</option>''',
     r'''<option value="">{valores.regiaoId ? "Todos os setores" : "Escolha a RA primeiro"}</option>'''),
    ("src/modules/relatorios/components/FiltrosDoRelatorio.tsx",
     r'''disabled={desabilitado || !valores.setorId}''',
     r'''disabled={desabilitado || !valores.regiaoId}'''),
    ("src/modules/relatorios/components/FiltrosDoRelatorio.tsx",
     r'''<option value="">{valores.setorId ? "Todas as casas de oração" : "Escolha o setor primeiro"}</option>''',
     r'''<option value="">{valores.regiaoId ? "Todas as casas de oração" : "Escolha a RA primeiro"}</option>'''),
    ("src/modules/relatorios/components/FiltrosDoRelatorio.tsx",
     r'''{opcoesCasaOracao(organizacao, valores.setorId).map((opcao) => (''',
     r'''{opcoesCasaOracao(organizacao, valores.regiaoId, valores.setorId).map((opcao) => ('''),
    ("src/app/(painel)/relatorios/page.tsx",
     r'''Cada pessoa recebe só o que a sua região permite.''',
     r'''Cada pessoa recebe só o que a sua abrangência permite.'''),
    ("src/modules/backup/tabelas.ts",
     r'''  | "estados"
  | "regioes"
  | "setores"
  | "casas_oracao"
''',
     r'''  | "estados"
  | "rrms"
  | "ras"
  | "adms"
  | "setores"
  | "casas_oracao"
'''),
    ("src/modules/backup/tabelas.ts",
     r'''  tabela("regioes", "Regiões", "organizacao", { referencias: [{ coluna: "estado_id", tabela: "estados" }] }),
  tabela("setores", "Setores", "organizacao", { referencias: [{ coluna: "regiao_id", tabela: "regioes" }] }),
  tabela("casas_oracao", "Casas de Oração", "organizacao", { referencias: [{ coluna: "setor_id", tabela: "setores" }] }),
''',
     r'''  tabela("rrms", "RRMs (Reunião Regional Ministerial)", "organizacao", { referencias: [{ coluna: "estado_id", tabela: "estados" }] }),
  tabela("ras", "RAs (Regional Administrativa)", "organizacao", { referencias: [{ coluna: "rrm_id", tabela: "rrms" }] }),
  tabela("adms", "ADMs (Administração)", "organizacao", { referencias: [{ coluna: "ra_id", tabela: "ras" }] }),
  tabela("setores", "Setores", "organizacao", { referencias: [{ coluna: "adm_id", tabela: "adms" }] }),
  tabela("casas_oracao", "Casas de Oração", "organizacao", {
    referencias: [
      { coluna: "adm_id", tabela: "adms" },
      { coluna: "setor_id", tabela: "setores" },
    ],
  }),
'''),
    ("src/modules/backup/tabelas.ts",
     r'''    descricao: "Estados, regiões, setores e casas de oração",
    tabelas: ["estados", "regioes", "setores", "casas_oracao"],''',
     r'''    descricao: "Estados, RRMs, RAs, ADMs, setores e casas de oração",
    tabelas: ["estados", "rrms", "ras", "adms", "setores", "casas_oracao"],'''),
    ("src/modules/auditoria/regras.ts",
     r'''  estado: "Estado",
  regiao: "Região",
''',
     r'''  estado: "Estado",
  rrm: "RRM",
  ra: "RA",
  adm: "ADM",
  regiao: "Região",
'''),
    ("src/modules/auditoria/regras.ts",
     r'''  regiao_id: "Região",
  estado_id: "Estado",
''',
     r'''  regiao_id: "Região",
  rrm_id: "RRM",
  ra_id: "RA",
  adm_id: "ADM",
  adm_anterior: "ADM anterior",
  adm_novo: "ADM nova",
  estado_id: "Estado",
'''),
    ("src/modules/relatorios/catalogo.ts",
     r'''{ id: "regiao", rotulo: "Região", padrao: false },
      { id: "setor", rotulo: "Setor", padrao: false },
      { id: "casa_oracao", rotulo: "Casa de Oração do evento", padrao: false },''',
     r'''{ id: "regiao", rotulo: "RA", padrao: false },
      { id: "setor", rotulo: "Setor", padrao: false },
      { id: "casa_oracao", rotulo: "Casa de Oração do evento", padrao: false },'''),
    ("src/modules/relatorios/catalogo.ts",
     r'''casa de oração, setor e região.''',
     r'''casa de oração, setor e RA.'''),
    ("src/modules/relatorios/catalogo.ts",
     r'''{ id: "familia", rotulo: "Família do instrumento", padrao: false },
      { id: "regiao", rotulo: "Região", padrao: false },''',
     r'''{ id: "familia", rotulo: "Família do instrumento", padrao: false },
      { id: "regiao", rotulo: "RA", padrao: false },'''),
    ("src/modules/relatorios/catalogo.ts",
     r'''{ id: "regiao", rotulo: "Região", padrao: false },
      { id: "cidade", rotulo: "Cidade", padrao: false },
    ],''',
     r'''{ id: "regiao", rotulo: "RA", padrao: false },
      { id: "cidade", rotulo: "Cidade", padrao: false },
    ],'''),
    ("src/modules/relatorios/catalogo.ts",
     r'''titulo: "Regiões, setores e casas de oração",
    descricao: "A estrutura organizacional completa, com situação e quantidade de membros.",''',
     r'''titulo: "Estrutura da Organização",
    descricao: "A estrutura completa (estado, RRM, RA, ADM, setores e casas de oração), com situação e quantidade de membros.",'''),
    ("src/modules/relatorios/catalogo.ts",
     r'''      { id: "regiao", rotulo: "Região", padrao: true },
      { id: "setor", rotulo: "Setor", padrao: true },
      { id: "casa_oracao", rotulo: "Casa de Oração", padrao: true },''',
     r'''      { id: "rrm", rotulo: "RRM", padrao: true },
      { id: "regiao", rotulo: "RA", padrao: true },
      { id: "adm", rotulo: "ADM", padrao: true },
      { id: "setor", rotulo: "Setor", padrao: true },
      { id: "casa_oracao", rotulo: "Casa de Oração", padrao: true },'''),
    ("src/modules/relatorios/catalogo.ts",
     r'''rotulo: "Região › Setor"''',
     r'''rotulo: "RA › ADM › Setor"'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    "supabase/migrations/0039_organizacao_rrm_ra_adm.sql": r'''-- =============================================================================
-- SysMúsica — 0039: nova árvore da Organização
--
--   ESTADO › RRM › RA › ADM › [Setor] › Casa de Oração
--
--   RRM = Reunião Regional Ministerial   RA = Regional Administrativa   ADM = Administração
--   O Setor é OPCIONAL: uma casa de oração pode ficar ligada direto à ADM.
--
-- O que muda no banco
--   - tabelas novas: rrms e adms; "regioes" passa a se chamar "ras" (as regiões de hoje são RAs)
--   - setores passam a ficar dentro de uma ADM; casas_oracao ganham adm_id (obrigatório) e setor_id vira opcional
--   - usuario_vinculos aceita os níveis RRM, RA e ADM (REGIAO vira RA)
--   - a regra de abrangência (casa_oracao_na_minha_abrangencia) e todas as funções da hierarquia são reescritas
--
-- Dados de teste existentes
--   - a região "Jequié" vira RA dentro da RRM "Vitória da Conquista" e ganha a ADM "Ipiaú"
--   - as demais regiões ficam numa RRM provisória "(a definir)" e cada uma ganha uma ADM provisória
--     "ADM <nome> (a definir)"; renomeie ou mova pela tela Organização depois
--   - setores e casas continuam onde estavam (dentro da ADM da própria região)
--
-- Segurança: a migração roda numa transação única. Antes e depois ela compara, usuário por usuário, QUAIS casas de
-- oração cada um enxerga; se qualquer resultado mudar, ela aborta e nada é alterado.
--
-- Rodar UMA vez no SQL Editor do Supabase, ANTES do git push.
-- =============================================================================
begin;

-- Durante a migração a auditoria linha a linha fica pausada (as mudanças abaixo são estruturais)
select set_config('sysmusica.restaurando', 'sim', true);

-- ---------------------------------------------------------------------------
-- 0. Conferências e "fotografia" do acesso ANTES da mudança
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from public.casas_oracao c where c.setor_id is null) then
    raise exception 'Há casa(s) de oração sem setor. Ligue-as a um setor (Organização › transferir) antes de rodar esta migração.';
  end if;
end $$;

create temp table _vis_antes on commit drop as
select v.usuario_id, c.id as casa_id
from public.usuario_vinculos v
cross join public.casas_oracao c
join public.setores s on s.id = c.setor_id
join public.regioes r on r.id = s.regiao_id
join public.estados e on e.id = r.estado_id
where c.ativo and s.ativo and r.ativo and e.ativo
  and ((v.nivel = 'CASA_ORACAO' and v.alvo_id = c.id)
    or (v.nivel = 'SETOR'       and v.alvo_id = s.id)
    or (v.nivel = 'REGIAO'      and v.alvo_id = r.id)
    or (v.nivel = 'ESTADO'      and v.alvo_id = e.id));

create temp table _qtd_antes on commit drop as
select (select count(*) from public.estados)       as estados,
       (select count(*) from public.regioes)       as regioes,
       (select count(*) from public.setores)       as setores,
       (select count(*) from public.casas_oracao)  as casas,
       (select count(*) from public.usuario_vinculos) as vinculos;

-- ---------------------------------------------------------------------------
-- 1. RRM (nova)
-- ---------------------------------------------------------------------------
create table public.rrms (
  id        uuid primary key default gen_random_uuid(),
  estado_id uuid not null references public.estados (id),
  nome      text not null,
  descricao text,
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);
alter table public.rrms enable row level security;
revoke all on table public.rrms from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. As regiões de hoje viram RAs (ligadas a uma RRM)
-- ---------------------------------------------------------------------------
alter table public.regioes add column rrm_id uuid;

-- Jequié fica na RRM "Vitória da Conquista"
insert into public.rrms (estado_id, nome)
select distinct r.estado_id, 'Vitória da Conquista'
from public.regioes r
where public.normalizar_texto(r.nome) = public.normalizar_texto('Jequié');

update public.regioes r
   set rrm_id = m.id
  from public.rrms m
 where m.estado_id = r.estado_id and m.nome = 'Vitória da Conquista'
   and public.normalizar_texto(r.nome) = public.normalizar_texto('Jequié');

-- As demais ficam numa RRM provisória (uma por estado)
insert into public.rrms (estado_id, nome)
select distinct r.estado_id, '(a definir)' from public.regioes r where r.rrm_id is null;

update public.regioes r
   set rrm_id = m.id
  from public.rrms m
 where r.rrm_id is null and m.estado_id = r.estado_id and m.nome = '(a definir)';

alter table public.regioes drop column estado_id;            -- a chave estrangeira antiga sai junto
alter table public.regioes alter column rrm_id set not null;
alter table public.regioes add constraint ras_rrm_id_fkey foreign key (rrm_id) references public.rrms (id);
alter table public.regioes rename to ras;
alter table public.ras rename constraint regioes_pkey to ras_pkey;

-- ---------------------------------------------------------------------------
-- 3. ADM (nova): uma por RA existente, para abrigar os setores e as casas atuais
-- ---------------------------------------------------------------------------
create table public.adms (
  id        uuid primary key default gen_random_uuid(),
  ra_id     uuid not null references public.ras (id),
  nome      text not null,
  descricao text,
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);
alter table public.adms enable row level security;
revoke all on table public.adms from public, anon, authenticated;

insert into public.adms (ra_id, nome)
select r.id,
       case when public.normalizar_texto(r.nome) = public.normalizar_texto('Jequié')
            then 'Ipiaú'
            else left('ADM ' || r.nome || ' (a definir)', 80) end
from public.ras r;

-- ---------------------------------------------------------------------------
-- 4. Setores passam a ficar dentro de uma ADM
-- ---------------------------------------------------------------------------
alter table public.setores add column adm_id uuid;
update public.setores s set adm_id = a.id from public.adms a where a.ra_id = s.regiao_id;
alter table public.setores alter column adm_id set not null;
alter table public.setores add constraint setores_adm_id_fkey foreign key (adm_id) references public.adms (id);
alter table public.setores drop column regiao_id;            -- a chave estrangeira antiga sai junto

-- ---------------------------------------------------------------------------
-- 5. Casas de oração: ADM obrigatória, setor opcional
-- ---------------------------------------------------------------------------
alter table public.casas_oracao add column adm_id uuid;
update public.casas_oracao c set adm_id = s.adm_id from public.setores s where s.id = c.setor_id;
alter table public.casas_oracao alter column adm_id set not null;
alter table public.casas_oracao add constraint casas_oracao_adm_id_fkey foreign key (adm_id) references public.adms (id);

alter table public.casas_oracao_historico add column adm_anterior uuid;
alter table public.casas_oracao_historico add column adm_novo uuid;

create index if not exists casas_oracao_adm_id_idx on public.casas_oracao (adm_id);
create index if not exists setores_adm_id_idx on public.setores (adm_id);
create index if not exists adms_ra_id_idx on public.adms (ra_id);
create index if not exists ras_rrm_id_idx on public.ras (rrm_id);

-- O setor de uma casa precisa ser da MESMA ADM da casa (nenhuma rota consegue gravar o contrário)
create or replace function public.casas_oracao_valida_hierarquia()
returns trigger language plpgsql set search_path to 'public' as $$
begin
  if new.setor_id is not null
     and not exists (select 1 from public.setores s where s.id = new.setor_id and s.adm_id = new.adm_id) then
    raise exception 'O setor escolhido não pertence à ADM desta casa de oração.';
  end if;
  return new;
end;
$$;

create trigger trg_casas_oracao_hierarquia
  before insert or update of adm_id, setor_id on public.casas_oracao
  for each row execute function public.casas_oracao_valida_hierarquia();

-- Um setor não muda de ADM (isso deixaria as casas dele em outra ADM)
create or replace function public.setores_bloqueia_troca_de_adm()
returns trigger language plpgsql set search_path to 'public' as $$
begin
  if new.adm_id is distinct from old.adm_id then
    raise exception 'Um setor não pode mudar de ADM. Crie o setor na ADM de destino e transfira as casas de oração.';
  end if;
  return new;
end;
$$;

create trigger trg_setores_sem_troca_de_adm
  before update of adm_id on public.setores
  for each row execute function public.setores_bloqueia_troca_de_adm();

-- Auditoria das tabelas novas (mesma função das demais)
create trigger trg_auditar after insert or update or delete on public.rrms
  for each row execute function public.auditar_tabela();
create trigger trg_auditar after insert or update or delete on public.adms
  for each row execute function public.auditar_tabela();

-- ---------------------------------------------------------------------------
-- 6. Vínculos de usuário: novos níveis (REGIAO vira RA)
-- ---------------------------------------------------------------------------
alter table public.usuario_vinculos drop constraint usuario_vinculos_nivel_check;
update public.usuario_vinculos set nivel = 'RA' where nivel = 'REGIAO';
alter table public.usuario_vinculos add constraint usuario_vinculos_nivel_check
  check (nivel in ('ESTADO', 'RRM', 'RA', 'ADM', 'SETOR', 'CASA_ORACAO'));

-- ---------------------------------------------------------------------------
-- 7. Regra de abrangência: o ponto central de segurança
--    Quem tem vínculo em QUALQUER nível enxerga tudo abaixo dele. Qualquer item inativo no caminho bloqueia.
-- ---------------------------------------------------------------------------
create or replace function public.casa_oracao_na_minha_abrangencia(p_casa_oracao uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select p_casa_oracao is not null and exists (
    select 1
    from public.casas_oracao c
    join public.adms a   on a.id  = c.adm_id
    join public.ras ra   on ra.id = a.ra_id
    join public.rrms rr  on rr.id = ra.rrm_id
    join public.estados e on e.id = rr.estado_id
    left join public.setores s on s.id = c.setor_id
    join public.usuario_vinculos v
      on v.usuario_id = (select auth.uid())
     and ((v.nivel = 'CASA_ORACAO' and v.alvo_id = c.id)
       or (v.nivel = 'SETOR'       and v.alvo_id = s.id)
       or (v.nivel = 'ADM'         and v.alvo_id = a.id)
       or (v.nivel = 'RA'          and v.alvo_id = ra.id)
       or (v.nivel = 'RRM'         and v.alvo_id = rr.id)
       or (v.nivel = 'ESTADO'      and v.alvo_id = e.id))
    where c.id = p_casa_oracao
      and c.ativo and a.ativo and ra.ativo and rr.ativo and e.ativo
      and (c.setor_id is null or s.ativo)
  )
$$;

-- Rótulos legíveis
create or replace function public.rotulo_setor(p_casa_oracao uuid)
returns text
language sql stable security definer set search_path to 'public'
as $$
  select concat_ws(' › ', ra.nome, a.nome, s.nome)
  from public.casas_oracao c
  join public.adms a  on a.id  = c.adm_id
  join public.ras ra  on ra.id = a.ra_id
  left join public.setores s on s.id = c.setor_id
  where c.id = p_casa_oracao
$$;

create or replace function public.rotulo_vinculo(p_nivel text, p_alvo uuid)
returns text
language sql stable security definer set search_path to 'public'
as $$
  select case p_nivel
    when 'ESTADO' then (select e.nome from public.estados e where e.id = p_alvo)
    when 'RRM' then (select concat_ws(' › ', e.nome, rr.nome)
                       from public.rrms rr join public.estados e on e.id = rr.estado_id where rr.id = p_alvo)
    when 'RA'  then (select concat_ws(' › ', rr.nome, ra.nome)
                       from public.ras ra join public.rrms rr on rr.id = ra.rrm_id where ra.id = p_alvo)
    when 'ADM' then (select concat_ws(' › ', ra.nome, a.nome)
                       from public.adms a join public.ras ra on ra.id = a.ra_id where a.id = p_alvo)
    when 'SETOR' then (select concat_ws(' › ', ra.nome, a.nome, s.nome)
                         from public.setores s join public.adms a on a.id = s.adm_id
                         join public.ras ra on ra.id = a.ra_id where s.id = p_alvo)
    when 'CASA_ORACAO' then (select concat_ws(' › ', ra.nome, a.nome, s.nome, c.nome)
                               from public.casas_oracao c
                               join public.adms a on a.id = c.adm_id
                               join public.ras ra on ra.id = a.ra_id
                               left join public.setores s on s.id = c.setor_id
                              where c.id = p_alvo)
  end
$$;

-- ---------------------------------------------------------------------------
-- 8. Listagens da árvore
-- ---------------------------------------------------------------------------
-- Árvore completa (tela de Organização e vínculos). parent_id: estado -> nulo; RRM -> estado; RA -> RRM; ADM -> RA;
-- setor -> ADM; casa de oração -> setor (se tiver) ou ADM.
create or replace function public.listar_organizacao()
returns table (nivel text, id uuid, parent_id uuid, nome text, descricao text, ativo boolean,
               cidade text, bairro text, qtd_filhos bigint, qtd_membros bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  perform public.exigir_alguma_permissao(array['organizacao.visualizar', 'usuarios.vinculos', 'usuarios.editar']);
  return query
    select 'ESTADO'::text, e.id, null::uuid, e.nome, null::text, e.ativo, null::text, null::text,
           (select count(*) from public.rrms x where x.estado_id = e.id), 0::bigint
    from public.estados e
    union all
    select 'RRM'::text, rr.id, rr.estado_id, rr.nome, rr.descricao, rr.ativo, null::text, null::text,
           (select count(*) from public.ras x where x.rrm_id = rr.id), 0::bigint
    from public.rrms rr
    union all
    select 'RA'::text, ra.id, ra.rrm_id, ra.nome, ra.descricao, ra.ativo, null::text, null::text,
           (select count(*) from public.adms x where x.ra_id = ra.id), 0::bigint
    from public.ras ra
    union all
    select 'ADM'::text, a.id, a.ra_id, a.nome, a.descricao, a.ativo, null::text, null::text,
           (select count(*) from public.setores x where x.adm_id = a.id)
           + (select count(*) from public.casas_oracao x where x.adm_id = a.id and x.setor_id is null), 0::bigint
    from public.adms a
    union all
    select 'SETOR'::text, s.id, s.adm_id, s.nome, s.descricao, s.ativo, null::text, null::text,
           (select count(*) from public.casas_oracao x where x.setor_id = s.id), 0::bigint
    from public.setores s
    union all
    select 'CASA_ORACAO'::text, c.id, coalesce(c.setor_id, c.adm_id), c.nome, null::text, c.ativo, c.cidade, c.bairro, 0::bigint,
           (select count(*) from public.membros m where m.casa_oracao_id = c.id and m.excluido_em is null)
    from public.casas_oracao c;
end;
$$;

-- Só o que o usuário pode usar (seletor de casa de oração). Quem tem acesso total vê tudo que está ativo.
create or replace function public.listar_organizacao_para_selecao()
returns table (nivel text, id uuid, parent_id uuid, nome text)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_total boolean;
begin
  if not public.tem_acesso() then
    raise exception 'Sem acesso.' using errcode = '42501';
  end if;
  v_total := public.tem_acesso_total_organizacao();

  return query
    with ok as (
      select c.id as casa_id, c.nome as casa_nome, c.setor_id as setor_id, c.adm_id as adm_id
      from public.casas_oracao c
      where c.ativo and (v_total or public.casa_oracao_na_minha_abrangencia(c.id))
    ),
    sset as (
      select s.id as setor_id, s.adm_id as adm_id, s.nome as setor_nome
      from public.setores s
      where s.ativo and (v_total or s.id in (select ok.setor_id from ok))
    ),
    aset as (
      select a.id as adm_id, a.ra_id as ra_id, a.nome as adm_nome
      from public.adms a
      where a.ativo and (v_total or a.id in (select ok.adm_id from ok))
    ),
    raset as (
      select ra.id as ra_id, ra.rrm_id as rrm_id, ra.nome as ra_nome
      from public.ras ra
      where ra.ativo and (v_total or ra.id in (select aset.ra_id from aset))
    ),
    rrset as (
      select rr.id as rrm_id, rr.estado_id as estado_id, rr.nome as rrm_nome
      from public.rrms rr
      where rr.ativo and (v_total or rr.id in (select raset.rrm_id from raset))
    ),
    eset as (
      select e.id as estado_id, e.nome as estado_nome
      from public.estados e
      where e.ativo and (v_total or e.id in (select rrset.estado_id from rrset))
    )
    select 'ESTADO'::text, eset.estado_id, null::uuid, eset.estado_nome from eset
    union all
    select 'RRM'::text, rrset.rrm_id, rrset.estado_id, rrset.rrm_nome from rrset
    union all
    select 'RA'::text, raset.ra_id, raset.rrm_id, raset.ra_nome from raset
    union all
    select 'ADM'::text, aset.adm_id, aset.ra_id, aset.adm_nome from aset
    union all
    select 'SETOR'::text, sset.setor_id, sset.adm_id, sset.setor_nome from sset
    union all
    select 'CASA_ORACAO'::text, ok.casa_id, coalesce(ok.setor_id, ok.adm_id), ok.casa_nome from ok;
end;
$$;

-- Origens possíveis de um visitante (tudo que está ativo no caminho inteiro)
create or replace function public.listar_origens_visitante()
returns table (nivel text, id uuid, parent_id uuid, nome text)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  perform public.exigir_permissao('portaria.cadastrar_visitante');
  return query
    select 'ESTADO'::text, e.id, null::uuid, e.nome
      from public.estados e where e.ativo
    union all
    select 'RRM'::text, rr.id, rr.estado_id, rr.nome
      from public.rrms rr join public.estados e on e.id = rr.estado_id
     where rr.ativo and e.ativo
    union all
    select 'RA'::text, ra.id, ra.rrm_id, ra.nome
      from public.ras ra
      join public.rrms rr on rr.id = ra.rrm_id
      join public.estados e on e.id = rr.estado_id
     where ra.ativo and rr.ativo and e.ativo
    union all
    select 'ADM'::text, a.id, a.ra_id, a.nome
      from public.adms a
      join public.ras ra on ra.id = a.ra_id
      join public.rrms rr on rr.id = ra.rrm_id
      join public.estados e on e.id = rr.estado_id
     where a.ativo and ra.ativo and rr.ativo and e.ativo
    union all
    select 'SETOR'::text, s.id, s.adm_id, s.nome
      from public.setores s
      join public.adms a on a.id = s.adm_id
      join public.ras ra on ra.id = a.ra_id
      join public.rrms rr on rr.id = ra.rrm_id
      join public.estados e on e.id = rr.estado_id
     where s.ativo and a.ativo and ra.ativo and rr.ativo and e.ativo
    union all
    select 'CASA_ORACAO'::text, c.id, coalesce(c.setor_id, c.adm_id), c.nome
      from public.casas_oracao c
      join public.adms a on a.id = c.adm_id
      join public.ras ra on ra.id = a.ra_id
      join public.rrms rr on rr.id = ra.rrm_id
      join public.estados e on e.id = rr.estado_id
      left join public.setores s on s.id = c.setor_id
     where c.ativo and a.ativo and ra.ativo and rr.ativo and e.ativo and (c.setor_id is null or s.ativo);
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Cadastro, edição, exclusão e transferência
-- ---------------------------------------------------------------------------
create or replace function public.salvar_organizacao(
  p_nivel text, p_id uuid, p_parent uuid, p_nome text, p_descricao text, p_ativo boolean, p_cidade text, p_bairro text)
returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_novo   boolean := p_id is null;
  v_nome   text    := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  v_desc   text    := nullif(btrim(coalesce(p_descricao, '')), '');
  v_cidade text    := nullif(btrim(coalesce(p_cidade, '')), '');
  v_bairro text    := nullif(btrim(coalesce(p_bairro, '')), '');
  v_id     uuid;
  v_pai    uuid;
  v_setor  uuid;
  v_adm    uuid;
begin
  if p_nivel is null or p_nivel not in ('ESTADO', 'RRM', 'RA', 'ADM', 'SETOR', 'CASA_ORACAO') then
    raise exception 'Nível inválido.';
  end if;
  if v_novo then
    perform public.exigir_permissao('organizacao.criar');
  else
    perform public.exigir_permissao('organizacao.editar');
  end if;

  if char_length(v_nome) < 2 or char_length(v_nome) > 80 then
    raise exception 'O nome deve ter entre 2 e 80 caracteres.';
  end if;
  if v_desc is not null and char_length(v_desc) > 200 then
    raise exception 'A descrição pode ter no máximo 200 caracteres.';
  end if;
  if (v_cidade is not null and char_length(v_cidade) > 80) or (v_bairro is not null and char_length(v_bairro) > 80) then
    raise exception 'Cidade e bairro podem ter no máximo 80 caracteres.';
  end if;

  if p_nivel = 'ESTADO' then
    if exists (select 1 from public.estados x
                where x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe um estado com este nome.';
    end if;
    if v_novo then
      insert into public.estados (nome) values (v_nome) returning id into v_id;
    else
      update public.estados set nome = v_nome, ativo = coalesce(p_ativo, ativo) where id = p_id returning id into v_id;
    end if;

  elsif p_nivel = 'RRM' then
    v_pai := case when v_novo then p_parent else (select x.estado_id from public.rrms x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.estados e where e.id = v_pai) then
      raise exception 'Escolha o estado da RRM.';
    end if;
    if exists (select 1 from public.rrms x
                where x.estado_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma RRM com este nome neste estado.';
    end if;
    if v_novo then
      insert into public.rrms (estado_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.rrms set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  elsif p_nivel = 'RA' then
    v_pai := case when v_novo then p_parent else (select x.rrm_id from public.ras x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.rrms r where r.id = v_pai) then
      raise exception 'Escolha a RRM da RA.';
    end if;
    if exists (select 1 from public.ras x
                where x.rrm_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma RA com este nome nesta RRM.';
    end if;
    if v_novo then
      insert into public.ras (rrm_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.ras set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  elsif p_nivel = 'ADM' then
    v_pai := case when v_novo then p_parent else (select x.ra_id from public.adms x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.ras r where r.id = v_pai) then
      raise exception 'Escolha a RA da ADM.';
    end if;
    if exists (select 1 from public.adms x
                where x.ra_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma ADM com este nome nesta RA.';
    end if;
    if v_novo then
      insert into public.adms (ra_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.adms set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  elsif p_nivel = 'SETOR' then
    v_pai := case when v_novo then p_parent else (select x.adm_id from public.setores x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.adms a where a.id = v_pai) then
      raise exception 'Escolha a ADM do setor.';
    end if;
    if exists (select 1 from public.setores x
                where x.adm_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe um setor com este nome nesta ADM.';
    end if;
    if v_novo then
      insert into public.setores (adm_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.setores set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  else  -- CASA_ORACAO: o "pai" de uma casa nova é uma ADM (casa sem setor) ou um setor
    if v_novo then
      if p_parent is not null and exists (select 1 from public.setores s where s.id = p_parent) then
        v_setor := p_parent;
        select s.adm_id into v_adm from public.setores s where s.id = p_parent;
      elsif p_parent is not null and exists (select 1 from public.adms a where a.id = p_parent) then
        v_setor := null;
        v_adm := p_parent;
      else
        raise exception 'Escolha a ADM (ou o setor) da casa de oração.';
      end if;
    else
      select c.adm_id, c.setor_id into v_adm, v_setor from public.casas_oracao c where c.id = p_id;
    end if;
    if exists (select 1 from public.casas_oracao x
                where x.adm_id is not distinct from v_adm and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma casa de oração com este nome nesta ADM.';
    end if;
    if v_novo then
      insert into public.casas_oracao (adm_id, setor_id, nome, cidade, bairro)
      values (v_adm, v_setor, v_nome, v_cidade, v_bairro)
      returning id into v_id;
    else
      update public.casas_oracao set nome = v_nome, cidade = v_cidade, bairro = v_bairro, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;
  end if;

  if v_id is null then
    raise exception 'Cadastro não encontrado.';
  end if;

  perform public.registrar_auditoria(
    case when v_novo then 'organizacao_criada' else 'organizacao_alterada' end,
    'organizacao', v_id,
    jsonb_build_object('nivel', p_nivel, 'nome', v_nome, 'ativo', p_ativo));
  return v_id;
end;
$$;

create or replace function public.excluir_organizacao(p_nivel text, p_id uuid)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_nome text;
  v_qtd  bigint;
  v_qtd2 bigint;
begin
  perform public.exigir_permissao('organizacao.excluir');

  if p_nivel is null or p_nivel not in ('ESTADO', 'RRM', 'RA', 'ADM', 'SETOR', 'CASA_ORACAO') then
    raise exception 'Nível inválido.';
  end if;

  -- Trava o item e lê o nome (para as mensagens e a auditoria)
  if p_nivel = 'ESTADO' then
    select e.nome into v_nome from public.estados e where e.id = p_id for update;
  elsif p_nivel = 'RRM' then
    select r.nome into v_nome from public.rrms r where r.id = p_id for update;
  elsif p_nivel = 'RA' then
    select r.nome into v_nome from public.ras r where r.id = p_id for update;
  elsif p_nivel = 'ADM' then
    select a.nome into v_nome from public.adms a where a.id = p_id for update;
  elsif p_nivel = 'SETOR' then
    select s.nome into v_nome from public.setores s where s.id = p_id for update;
  else
    select c.nome into v_nome from public.casas_oracao c where c.id = p_id for update;
  end if;
  if v_nome is null then
    raise exception 'Cadastro não encontrado.';
  end if;

  -- Usuários vinculados a este item perderiam o acesso sem aviso: a exclusão é bloqueada
  select count(*) into v_qtd from public.usuario_vinculos v where v.nivel = p_nivel and v.alvo_id = p_id;
  if v_qtd > 0 then
    raise exception '"%" ainda tem % usuário(s) vinculado(s). Retire o vínculo em Administração > Usuários antes de excluir.',
      v_nome, v_qtd;
  end if;

  if p_nivel = 'ESTADO' then
    select count(*) into v_qtd from public.rrms x where x.estado_id = p_id;
    if v_qtd > 0 then
      raise exception 'O estado "%" ainda tem % RRM(s). Exclua as RRMs antes.', v_nome, v_qtd;
    end if;
    delete from public.estados where id = p_id;

  elsif p_nivel = 'RRM' then
    select count(*) into v_qtd from public.ras x where x.rrm_id = p_id;
    if v_qtd > 0 then
      raise exception 'A RRM "%" ainda tem % RA(s). Exclua as RAs antes.', v_nome, v_qtd;
    end if;
    delete from public.rrms where id = p_id;

  elsif p_nivel = 'RA' then
    select count(*) into v_qtd from public.adms x where x.ra_id = p_id;
    if v_qtd > 0 then
      raise exception 'A RA "%" ainda tem % ADM(s). Exclua as ADMs antes.', v_nome, v_qtd;
    end if;
    delete from public.ras where id = p_id;

  elsif p_nivel = 'ADM' then
    select count(*) into v_qtd from public.setores x where x.adm_id = p_id;
    select count(*) into v_qtd2 from public.casas_oracao x where x.adm_id = p_id;
    if v_qtd > 0 or v_qtd2 > 0 then
      raise exception 'A ADM "%" ainda tem % setor(es) e % casa(s) de oração. Transfira ou exclua antes.', v_nome, v_qtd, v_qtd2;
    end if;
    delete from public.adms where id = p_id;

  elsif p_nivel = 'SETOR' then
    select count(*) into v_qtd from public.casas_oracao x where x.setor_id = p_id;
    if v_qtd > 0 then
      raise exception 'O setor "%" ainda tem % casa(s) de oração. Transfira as casas de oração para outro local antes de excluir.', v_nome, v_qtd;
    end if;
    delete from public.setores where id = p_id;

  else  -- CASA_ORACAO
    select count(*) into v_qtd from public.membros x where x.casa_oracao_id = p_id and x.excluido_em is null;
    if v_qtd > 0 then
      raise exception 'A casa de oração "%" ainda tem % membro(s). Mude os membros para outra casa de oração (ou exclua-os) antes.', v_nome, v_qtd;
    end if;
    select count(*) into v_qtd from public.eventos x where x.casa_oracao_id = p_id and x.excluido_em is null;
    if v_qtd > 0 then
      raise exception 'A casa de oração "%" ainda tem % evento(s). Mude a casa de oração dos eventos (ou exclua-os) antes.', v_nome, v_qtd;
    end if;
    select count(*) into v_qtd from public.portarias x where x.casa_oracao_id = p_id;
    if v_qtd > 0 then
      raise exception 'A casa de oração "%" tem % portaria(s) no histórico e não pode ser excluída. Use Inativar.', v_nome, v_qtd;
    end if;

    -- Membros e eventos já excluídos (exclusão lógica) deixam de apontar para a casa de oração
    perform set_config('sysmusica.org_excluindo', 'sim', true);
    update public.membros set casa_oracao_id = null where casa_oracao_id = p_id;
    update public.eventos set casa_oracao_id = null where casa_oracao_id = p_id;
    perform set_config('sysmusica.org_excluindo', '', true);

    delete from public.casas_oracao where id = p_id;
  end if;

  perform public.registrar_auditoria('organizacao_excluida', 'organizacao', p_id,
            jsonb_build_object('nivel', p_nivel, 'nome', v_nome));
end;
$$;

-- Transferência: o destino pode ser um SETOR (a casa entra nele) ou uma ADM (a casa fica sem setor)
drop function if exists public.transferir_casa_oracao(uuid, uuid, text);
create function public.transferir_casa_oracao(p_casa_oracao uuid, p_destino uuid, p_justificativa text)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_c     public.casas_oracao;
  v_setor uuid;
  v_adm   uuid;
  v_just  text := nullif(btrim(coalesce(p_justificativa, '')), '');
begin
  perform public.exigir_permissao('organizacao.transferir');

  select * into v_c from public.casas_oracao c where c.id = p_casa_oracao for update;
  if not found then
    raise exception 'Casa de Oração não encontrada.';
  end if;

  if exists (select 1 from public.setores s join public.adms a on a.id = s.adm_id
              where s.id = p_destino and s.ativo and a.ativo) then
    v_setor := p_destino;
    select s.adm_id into v_adm from public.setores s where s.id = p_destino;
  elsif exists (select 1 from public.adms a where a.id = p_destino and a.ativo) then
    v_setor := null;
    v_adm := p_destino;
  else
    raise exception 'Escolha uma ADM ou um setor ativo de destino.';
  end if;

  if v_c.adm_id is not distinct from v_adm and v_c.setor_id is not distinct from v_setor then
    raise exception 'A casa de oração já está neste local.';
  end if;
  if v_just is not null and char_length(v_just) > 300 then
    raise exception 'A justificativa pode ter no máximo 300 caracteres.';
  end if;
  if exists (select 1 from public.casas_oracao x
              where x.adm_id = v_adm and x.id <> p_casa_oracao
                and public.normalizar_texto(x.nome) = public.normalizar_texto(v_c.nome)) then
    raise exception 'O destino já tem uma casa de oração com este nome.';
  end if;

  update public.casas_oracao set adm_id = v_adm, setor_id = v_setor where id = p_casa_oracao;
  -- As portarias seguem a casa de oração do evento: só o rótulo precisa ser atualizado
  update public.portarias p set cidade = public.rotulo_setor(p.casa_oracao_id)
   where p.casa_oracao_id = p_casa_oracao and p.excluido_em is null;

  insert into public.casas_oracao_historico
    (casa_oracao_id, setor_anterior, setor_novo, adm_anterior, adm_novo, usuario_id, justificativa)
  values (p_casa_oracao, v_c.setor_id, v_setor, v_c.adm_id, v_adm, (select auth.uid()), v_just);

  perform public.registrar_auditoria('casa_oracao_transferida', 'casa_oracao', p_casa_oracao,
            jsonb_build_object('setor_anterior', v_c.setor_id, 'setor_novo', v_setor,
                               'adm_anterior', v_c.adm_id, 'adm_novo', v_adm, 'justificativa', v_just));
end;
$$;
revoke all on function public.transferir_casa_oracao(uuid, uuid, text) from public, anon;
grant execute on function public.transferir_casa_oracao(uuid, uuid, text) to authenticated;

-- Vínculos do usuário
create or replace function public.definir_vinculos(p_usuario uuid, p_vinculos jsonb)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_item  jsonb;
  v_nivel text;
  v_alvo  uuid;
  v_lista jsonb := coalesce(p_vinculos, '[]'::jsonb);
  v_ok    boolean;
begin
  perform public.exigir_permissao('usuarios.vinculos');

  if not exists (select 1 from public.usuarios u where u.id = p_usuario) then
    raise exception 'Usuário não encontrado.';
  end if;
  if jsonb_typeof(v_lista) <> 'array' then
    raise exception 'Vínculos inválidos.';
  end if;

  delete from public.usuario_vinculos where usuario_id = p_usuario;

  for v_item in select * from jsonb_array_elements(v_lista) loop
    v_nivel := v_item ->> 'nivel';
    v_alvo  := (v_item ->> 'alvo_id')::uuid;
    v_ok := case v_nivel
      when 'ESTADO' then exists (select 1 from public.estados x where x.id = v_alvo)
      when 'RRM'    then exists (select 1 from public.rrms x where x.id = v_alvo)
      when 'RA'     then exists (select 1 from public.ras x where x.id = v_alvo)
      when 'ADM'    then exists (select 1 from public.adms x where x.id = v_alvo)
      when 'SETOR'  then exists (select 1 from public.setores x where x.id = v_alvo)
      when 'CASA_ORACAO' then exists (select 1 from public.casas_oracao x where x.id = v_alvo)
      else false
    end;
    if not v_ok then
      raise exception 'Vínculo inválido: o cadastro escolhido não existe mais.';
    end if;
    insert into public.usuario_vinculos (usuario_id, nivel, alvo_id) values (p_usuario, v_nivel, v_alvo)
    on conflict do nothing;
  end loop;

  perform public.registrar_auditoria('vinculos_definidos', 'usuario', p_usuario,
            jsonb_build_object('vinculos', v_lista));
end;
$$;

-- ---------------------------------------------------------------------------
-- 10. Portaria: busca de origem e cadastro de visitante
-- ---------------------------------------------------------------------------
create or replace function public.buscar_localidades(p_termo text)
returns table (comum_id uuid, nome text, caminho text)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_t text := regexp_replace(public.normalizar_texto(coalesce(p_termo, '')), '[%_\\]', '', 'g');
begin
  perform public.exigir_permissao('portaria.registrar');
  if char_length(v_t) < 2 then
    return;
  end if;
  return query
    select c.id, c.nome, concat_ws(' › ', e.nome, ra.nome, a.nome, s.nome)
      from public.casas_oracao c
      join public.adms a on a.id = c.adm_id
      join public.ras ra on ra.id = a.ra_id
      join public.rrms rr on rr.id = ra.rrm_id
      join public.estados e on e.id = rr.estado_id
      left join public.setores s on s.id = c.setor_id
     where c.ativo and a.ativo and ra.ativo and rr.ativo and e.ativo and (c.setor_id is null or s.ativo)
       and (public.normalizar_texto(c.nome) like v_t || '%' or public.normalizar_texto(c.nome) like '% ' || v_t || '%')
     order by (public.normalizar_texto(c.nome) like v_t || '%') desc, c.nome
     limit 15;
end;
$$;

create or replace function public.cadastrar_visitante(
  p_portaria_id uuid, p_nome text, p_cargo_id uuid, p_instrumento_id uuid,
  p_origem_casa_oracao_id uuid, p_membro_id uuid, p_foto_path text)
returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_p          public.portarias;
  v_casa_oracao      text;
  v_nome       text := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  v_origem     record;
  v_permite    boolean;
  v_exige      boolean;
  v_nome_cargo text;
  v_id         uuid;
begin
  perform public.exigir_permissao('portaria.cadastrar_visitante');
  perform public.exigir_acesso_atendimento(p_portaria_id);   -- aprovada e dentro da abrangência de quem atende

  select * into v_p from public.portarias p where p.id = p_portaria_id;
  select c.nome into v_casa_oracao from public.casas_oracao c where c.id = v_p.casa_oracao_id;
  if v_casa_oracao is null then
    raise exception 'A casa de oração desta portaria não foi encontrada.';
  end if;

  if p_membro_id is null or exists (select 1 from public.membros m where m.id = p_membro_id) then
    raise exception 'Não foi possível cadastrar: identificador inválido. Tente novamente.';
  end if;
  perform public.validar_foto_membro(p_membro_id, p_foto_path);   -- foto obrigatória

  if char_length(v_nome) < 5 or char_length(v_nome) > 120 or position(' ' in v_nome) = 0 then
    raise exception 'Digite o nome completo do visitante (nome e sobrenome).';
  end if;

  select c.permite_instrumento, c.exige_instrumento, c.nome into v_permite, v_exige, v_nome_cargo
  from public.cargos c where c.id = p_cargo_id;
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
  elsif coalesce(v_exige, false) then
    raise exception 'O cargo % exige o instrumento. Escolha o instrumento na lista.', v_nome_cargo;
  end if;

  -- A origem precisa ser uma casa de oração cadastrada e ativa, com ADM, RA, RRM e estado ativos (setor, se houver, ativo)
  select c.nome as casa_oracao, c.cidade as cidade, ra.nome as regiao into v_origem
  from public.casas_oracao c
  join public.adms a on a.id = c.adm_id
  join public.ras ra on ra.id = a.ra_id
  join public.rrms rr on rr.id = ra.rrm_id
  join public.estados e on e.id = rr.estado_id
  left join public.setores s on s.id = c.setor_id
  where c.id = p_origem_casa_oracao_id and c.ativo and a.ativo and ra.ativo and rr.ativo and e.ativo
    and (c.setor_id is null or s.ativo);
  if not found then
    raise exception 'Escolha a igreja de origem na lista (estado, RRM, RA, ADM, setor e casa de oração). Se ela não aparecer, peça a um administrador para cadastrá-la em Organização.';
  end if;

  if exists (
    select 1 from public.membros m
    where m.casa_oracao_id = v_p.casa_oracao_id and m.excluido_em is null
      and public.normalizar_texto(m.nome) = public.normalizar_texto(v_nome)
  ) then
    raise exception 'Já existe um membro com este nome nesta casa de oração. Busque pelo nome completo em vez de cadastrar de novo.';
  end if;

  insert into public.membros
    (id, nome, congregacao, cargo_id, instrumento_id, status, casa_oracao_id, cidade, bairro, visitante,
     origem_casa_oracao_id, foto_path)
  values
    (p_membro_id, v_nome, v_casa_oracao, p_cargo_id, p_instrumento_id, 'Ativo', v_p.casa_oracao_id,
     coalesce(v_origem.cidade, v_origem.regiao), v_origem.casa_oracao, true, p_origem_casa_oracao_id, p_foto_path)
  returning id into v_id;

  perform public.registrar_auditoria('visitante_cadastrado', 'membro', v_id,
            jsonb_build_object('portaria_id', p_portaria_id, 'casa_oracao_id', v_p.casa_oracao_id,
                               'origem_casa_oracao_id', p_origem_casa_oracao_id, 'rotulo', v_nome));
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 11. Relatórios (as colunas e os parâmetros continuam os mesmos: "regiao" agora é a RA)
-- ---------------------------------------------------------------------------
create or replace function public.relatorio_eventos(
  p_inicio timestamptz, p_fim timestamptz, p_regiao uuid, p_setor uuid, p_casa_oracao uuid, p_limite integer)
returns table (tipo text, data_evento timestamptz, local_evento text, finalidade text, cidade text, regiao text,
               setor text, casa_oracao text, registros bigint, presentes bigint, portaria text, total bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_lim int := least(greatest(coalesce(p_limite, 5000), 1), 20000);
begin
  perform public.exigir_permissao('eventos.visualizar');

  return query
    select ev.tipo, ev.data_evento, ev.local, fi.nome, ev.cidade,
           r.nome, s.nome, c.nome,
           (select count(*) from public.presencas pr
             where pr.evento_id = ev.id and pr.excluido_em is null),
           (select count(*) from public.presencas pr
             where pr.evento_id = ev.id and pr.excluido_em is null and pr.status = 'Presente'),
           (select case po.status when 'APROVADA' then 'Aprovada' when 'PENDENTE_APROVACAO' then 'Pendente'
                                  when 'REJEITADA' then 'Rejeitada' end
              from public.portarias po
             where po.evento_id = ev.id and po.excluido_em is null
             order by po.criada_em desc limit 1),
           count(*) over ()
    from public.eventos ev
    left join public.finalidades_evento fi on fi.id = ev.finalidade_id
    left join public.casas_oracao c on c.id = ev.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.adms a on a.id = c.adm_id
    left join public.ras r on r.id = a.ra_id
    where ev.excluido_em is null
      and public.casa_oracao_na_abrangencia(ev.casa_oracao_id)
      and (p_inicio is null or ev.data_evento >= p_inicio)
      and (p_fim is null or ev.data_evento < p_fim)
      and (p_regiao is null or r.id = p_regiao)
      and (p_setor is null or s.id = p_setor)
      and (p_casa_oracao is null or c.id = p_casa_oracao)
    order by ev.data_evento desc, ev.id
    limit v_lim;
end;
$$;

create or replace function public.relatorio_membros(
  p_regiao uuid, p_setor uuid, p_casa_oracao uuid, p_cargo uuid, p_instrumento uuid,
  p_status text, p_visitante text, p_limite integer)
returns table (nome text, cargo text, instrumento text, familia text, regiao text, setor text, casa_oracao text,
               cidade text, bairro text, status text, visitante boolean, data_nascimento date,
               cadastrado_em timestamptz, cpf_parcial text, total bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_lim int := least(greatest(coalesce(p_limite, 5000), 1), 20000);
  v_cpf boolean;
begin
  perform public.exigir_permissao('membros.visualizar');
  v_cpf := public.tem_permissao('membros.cpf');

  return query
    select m.nome, ca.nome, i.nome, f.nome, r.nome, s.nome, c.nome,
           m.cidade, m.bairro, m.status, m.visitante, m.data_nascimento,
           m.data_cadastro,
           case when v_cpf then m.cpf_mascarado end,
           count(*) over ()
    from public.membros m
    left join public.casas_oracao c on c.id = m.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.adms a on a.id = c.adm_id
    left join public.ras r on r.id = a.ra_id
    left join public.cargos ca on ca.id = m.cargo_id
    left join public.instrumentos i on i.id = m.instrumento_id
    left join public.familias f on f.id = i.familia_id
    where m.excluido_em is null
      and public.casa_oracao_na_abrangencia(m.casa_oracao_id)
      and (p_regiao is null or r.id = p_regiao)
      and (p_setor is null or s.id = p_setor)
      and (p_casa_oracao is null or c.id = p_casa_oracao)
      and (p_cargo is null or m.cargo_id = p_cargo)
      and (p_instrumento is null or m.instrumento_id = p_instrumento)
      and (nullif(p_status, '') is null or m.status = p_status)
      and (nullif(p_visitante, '') is null
           or (p_visitante = 'sim' and m.visitante)
           or (p_visitante = 'nao' and not m.visitante))
    order by m.nome
    limit v_lim;
end;
$$;

create or replace function public.relatorio_presencas(
  p_inicio timestamptz, p_fim timestamptz, p_evento uuid, p_regiao uuid, p_setor uuid, p_casa_oracao uuid,
  p_status text, p_limite integer)
returns table (evento_tipo text, evento_data timestamptz, evento_local text, evento_finalidade text, regiao text,
               setor text, casa_oracao text, membro_nome text, membro_casa_oracao text, cargo text, instrumento text,
               familia text, cidade text, bairro text, visitante boolean, status text, hora_entrada timestamptz,
               hora_saida timestamptz, origem text, registrado_por text, total bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_lim int := least(greatest(coalesce(p_limite, 5000), 1), 20000);
begin
  perform public.exigir_permissao('portaria.visualizar');

  return query
    select ev.tipo, ev.data_evento, ev.local, fi.nome,
           r.nome, s.nome, c.nome,
           m.nome, m.congregacao, ca.nome, i.nome, f.nome,
           m.cidade, m.bairro, m.visitante,
           pr.status, pr.hora_entrada, pr.hora_saida,
           case when pr.portaria_id is null then 'ANTIGO' else pr.origem end,
           u.nome,
           count(*) over ()
    from public.presencas pr
    join public.eventos ev on ev.id = pr.evento_id and ev.excluido_em is null
    join public.membros m on m.id = pr.membro_id
    left join public.finalidades_evento fi on fi.id = ev.finalidade_id
    left join public.casas_oracao c on c.id = ev.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.adms a on a.id = c.adm_id
    left join public.ras r on r.id = a.ra_id
    left join public.cargos ca on ca.id = m.cargo_id
    left join public.instrumentos i on i.id = m.instrumento_id
    left join public.familias f on f.id = i.familia_id
    left join public.usuarios u on u.id = pr.registrado_por
    where pr.excluido_em is null
      and public.casa_oracao_na_abrangencia(ev.casa_oracao_id)
      and (p_inicio is null or ev.data_evento >= p_inicio)
      and (p_fim is null or ev.data_evento < p_fim)
      and (p_evento is null or pr.evento_id = p_evento)
      and (p_regiao is null or r.id = p_regiao)
      and (p_setor is null or s.id = p_setor)
      and (p_casa_oracao is null or c.id = p_casa_oracao)
      and (nullif(p_status, '') is null or pr.status = p_status)
    order by ev.data_evento desc, ev.id, m.nome
    limit v_lim;
end;
$$;

create or replace function public.relatorio_presenca_portaria(p_portaria uuid)
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $$
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
    left join public.adms a on a.id = c.adm_id
    left join public.ras r on r.id = a.ra_id
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
$$;

-- ---------------------------------------------------------------------------
-- 12. Auditoria e Backup conhecem as tabelas novas
-- ---------------------------------------------------------------------------
create or replace function public.auditar_tabela()
returns trigger
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_sens   text[] := array['cpf', 'qr_secret', 'cpf_mascarado', 'token_hash'];
  v_ruido  text[] := array['atualizado_em'];
  v_ref    jsonb;
  v_mud    jsonb;
  v_det    jsonb;
  v_acao   text;
  v_id     uuid;
  v_ent    text;
  v_rotulo text;
begin
  -- Restauração de backup em andamento: não registra linha a linha
  if current_setting('sysmusica.restaurando', true) = 'sim' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  -- Nome da entidade no singular (igual ao das ações já registradas por funções do sistema)
  v_ent := case tg_table_name
    when 'membros' then 'membro'
    when 'eventos' then 'evento'
    when 'presencas' then 'presenca'
    when 'instrumentos' then 'instrumento'
    when 'cargos' then 'cargo'
    when 'familias' then 'familia'
    when 'finalidades_evento' then 'finalidade'
    when 'usuarios' then 'usuario'
    when 'grupos' then 'grupo'
    when 'grupo_permissoes' then 'grupo_permissao'
    when 'usuario_vinculos' then 'vinculo'
    when 'estados' then 'estado'
    when 'rrms' then 'rrm'
    when 'ras' then 'ra'
    when 'adms' then 'adm'
    when 'setores' then 'setor'
    when 'casas_oracao' then 'casa_oracao'
    else tg_table_name
  end;

  v_ref := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  begin
    v_id := (v_ref ->> 'id')::uuid;
  exception when others then
    v_id := null;
  end;

  if tg_op = 'INSERT' then
    v_acao := 'registro_criado';
    v_det := jsonb_build_object('depois', public.auditoria_limpar(to_jsonb(new)));
  elsif tg_op = 'DELETE' then
    v_acao := 'registro_excluido';
    v_det := jsonb_build_object('antes', public.auditoria_limpar(to_jsonb(old)));
  else
    select coalesce(jsonb_object_agg(n.key,
             case when n.key = any (v_sens) then to_jsonb('(alterado)'::text)
                  else jsonb_build_object('de', o.value, 'para', n.value) end), '{}'::jsonb)
      into v_mud
    from jsonb_each(to_jsonb(new)) as n
    left join jsonb_each(to_jsonb(old)) as o on o.key = n.key
    where n.value is distinct from o.value and n.key <> all (v_ruido);

    if v_mud = '{}'::jsonb then
      return new;   -- nada relevante mudou (por exemplo, só a data de atualização)
    end if;

    -- Exclusão lógica: a linha ganhou a data de exclusão
    v_acao := case when (to_jsonb(old) ->> 'excluido_em') is null and (to_jsonb(new) ->> 'excluido_em') is not null
                   then 'registro_excluido' else 'registro_alterado' end;
    v_det := jsonb_build_object('mudancas', v_mud)
             || case when v_acao = 'registro_excluido' then jsonb_build_object('logica', true) else '{}'::jsonb end;
  end if;

  -- Rótulo legível: nome, tipo, e-mail ou local; presenças e vínculos usam o nome do membro/usuário
  v_rotulo := coalesce(v_ref ->> 'nome', v_ref ->> 'tipo', v_ref ->> 'email', v_ref ->> 'local');
  if v_rotulo is null then
    begin
      if v_ref ? 'membro_id' then
        select m.nome into v_rotulo from public.membros m where m.id = (v_ref ->> 'membro_id')::uuid;
      elsif v_ref ? 'usuario_id' then
        select u.nome into v_rotulo from public.usuarios u where u.id = (v_ref ->> 'usuario_id')::uuid;
      end if;
    exception when others then
      v_rotulo := null;
    end;
  end if;
  if v_rotulo is not null then
    v_det := v_det || jsonb_build_object('rotulo', v_rotulo);
  end if;

  insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
  values ((select auth.uid()), v_acao, v_ent, v_id, v_det);

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.backup_aplicar(p_usuario uuid, p_operacoes jsonb, p_resumo jsonb)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_op        jsonb;
  v_tabela    text;
  v_acao      text;
  v_linhas    jsonb;
  v_colunas   text[];
  v_def       record;
  v_cols      text;
  v_bcols     text;
  v_set       text;
  v_pk_cond   text;
  v_extra     text;
  v_n         bigint;
  v_ignorados bigint;
  v_resultado jsonb := '[]'::jsonb;
begin
  if p_operacoes is null or jsonb_typeof(p_operacoes) <> 'array' then
    raise exception 'Operações inválidas.';
  end if;

  perform set_config('sysmusica.restaurando', 'sim', true);

  for v_op in select * from jsonb_array_elements(p_operacoes) loop
    v_tabela := v_op ->> 'tabela';
    v_acao   := v_op ->> 'acao';
    v_linhas := coalesce(v_op -> 'linhas', '[]'::jsonb);

    select t.* into v_def
    from (values
      ('estados',             array['id'],                              false, false, ''),
      ('rrms',                array['id'],                              false, false, ''),
      ('ras',                 array['id'],                              false, false, ''),
      ('adms',                array['id'],                              false, false, ''),
      ('setores',             array['id'],                              false, false, ''),
      ('casas_oracao',        array['id'],                              false, false, ''),
      ('familias',            array['id'],                              false, false, ''),
      ('cargos',              array['id'],                              false, false, ''),
      ('finalidades_evento',  array['id'],                              false, false, ''),
      ('instrumentos',        array['id'],                              false, false, ''),
      ('grupos',              array['id'],                              false, false, ''),
      ('grupo_permissoes',    array['grupo_id', 'permissao_codigo'],    false, false, ''),
      ('usuarios',            array['id'],                              false, false, 'login'),
      ('usuario_grupos',      array['usuario_id', 'grupo_id'],          false, false, ''),
      ('usuario_vinculos',    array['usuario_id', 'nivel', 'alvo_id'],  false, false, ''),
      ('membros',             array['id'],                              true,  false, ''),
      ('eventos',             array['id'],                              true,  false, ''),
      ('portarias',           array['id'],                              true,  false, ''),
      ('portarias_historico', array['id'],                              false, true,  ''),
      ('presencas',           array['id'],                              true,  false, ''),
      ('presencas_avulsas',   array['id'],                              true,  false, '')
    ) as t(tabela, pk, soft, so_inserir, extra)
    where t.tabela = v_tabela;
    if not found then
      raise exception 'Tabela não permitida na restauração: %', coalesce(v_tabela, '(vazia)');
    end if;

    if v_acao is null or v_acao not in ('inserir', 'atualizar', 'excluir_logico', 'excluir') then
      raise exception 'Ação inválida na restauração: %', coalesce(v_acao, '(vazia)');
    end if;
    if v_def.so_inserir and v_acao <> 'inserir' then
      raise exception 'A tabela % só aceita devolver registros apagados.', v_tabela;
    end if;
    if v_acao = 'excluir_logico' and not v_def.soft then
      raise exception 'A tabela % não usa exclusão lógica.', v_tabela;
    end if;
    if v_acao = 'excluir' and v_def.soft then
      raise exception 'Os itens da tabela % são excluídos logicamente.', v_tabela;
    end if;
    if jsonb_typeof(v_linhas) <> 'array' then
      raise exception 'Linhas inválidas em %.', v_tabela;
    end if;
    if jsonb_array_length(v_linhas) = 0 then
      continue;
    end if;

    select coalesce(array_agg(x), '{}'::text[]) into v_colunas
    from jsonb_array_elements_text(coalesce(v_op -> 'colunas', '[]'::jsonb)) as x;

    if not (v_def.pk <@ v_colunas) then
      raise exception 'Faltam as colunas de identificação em %.', v_tabela;
    end if;

    -- Só colunas que existem e podem ser gravadas (as geradas ficam de fora)
    select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('b.%I', c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('%1$I = b.%1$I', c.column_name), ', ' order by c.ordinal_position)
             filter (where c.column_name <> all (v_def.pk))
      into v_cols, v_bcols, v_set
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = v_tabela
      and c.is_generated = 'NEVER' and c.column_name = any (v_colunas);

    select string_agg(format('c.%1$I = b.%1$I', k), ' and ') into v_pk_cond from unnest(v_def.pk) as k;

    v_ignorados := 0;

    if v_acao = 'inserir' then
      -- Usuários só voltam se a conta de login ainda existir (a senha não é guardada no backup)
      v_extra := case when v_def.extra = 'login' then 'where exists (select 1 from auth.users a where a.id = b.id)' else '' end;
      execute format(
        'insert into public.%1$I (%2$s) select %3$s from jsonb_populate_recordset(null::public.%1$I, $1) b %4$s',
        v_tabela, v_cols, v_bcols, v_extra) using v_linhas;
      get diagnostics v_n = row_count;
      v_ignorados := jsonb_array_length(v_linhas) - v_n;

    elsif v_acao = 'atualizar' then
      if v_set is null then
        v_n := 0;
      else
        execute format(
          'update public.%1$I c set %2$s from jsonb_populate_recordset(null::public.%1$I, $1) b where %3$s',
          v_tabela, v_set, v_pk_cond) using v_linhas;
        get diagnostics v_n = row_count;
      end if;

    elsif v_acao = 'excluir_logico' then
      execute format(
        'update public.%1$I c set excluido_em = now() from jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s and c.excluido_em is null',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;

    else
      execute format(
        'delete from public.%1$I c using jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;
    end if;

    v_resultado := v_resultado || jsonb_build_object(
      'tabela', v_tabela, 'acao', v_acao, 'afetados', v_n, 'ignorados', v_ignorados);
  end loop;

  perform set_config('sysmusica.restaurando', '', true);

  -- Uma única entrada resumida na auditoria (a auditoria linha a linha ficou pausada)
  insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
  values (p_usuario, 'backup_restaurado', 'backup', null,
          coalesce(p_resumo, '{}'::jsonb) || jsonb_build_object('operacoes', v_resultado));

  return v_resultado;
end;
$$;

-- ---------------------------------------------------------------------------
-- 13. Prova de que NINGUÉM ganhou nem perdeu acesso: compara antes e depois, usuário por usuário
-- ---------------------------------------------------------------------------
do $$
declare
  v_a record;
  v_dif bigint;
  v_extra bigint;
begin
  select * into v_a from _qtd_antes;

  if (select count(*) from public.estados) <> v_a.estados
     or (select count(*) from public.ras) <> v_a.regioes
     or (select count(*) from public.setores) <> v_a.setores
     or (select count(*) from public.casas_oracao) <> v_a.casas
     or (select count(*) from public.usuario_vinculos) <> v_a.vinculos then
    raise exception 'Migração abortada: a quantidade de itens mudou. Nada foi alterado.';
  end if;

  create temp table _vis_depois on commit drop as
  select v.usuario_id, c.id as casa_id
  from public.usuario_vinculos v
  cross join public.casas_oracao c
  join public.adms a on a.id = c.adm_id
  join public.ras ra on ra.id = a.ra_id
  join public.rrms rr on rr.id = ra.rrm_id
  join public.estados e on e.id = rr.estado_id
  left join public.setores s on s.id = c.setor_id
  where c.ativo and a.ativo and ra.ativo and rr.ativo and e.ativo and (c.setor_id is null or s.ativo)
    and ((v.nivel = 'CASA_ORACAO' and v.alvo_id = c.id)
      or (v.nivel = 'SETOR'       and v.alvo_id = s.id)
      or (v.nivel = 'ADM'         and v.alvo_id = a.id)
      or (v.nivel = 'RA'          and v.alvo_id = ra.id)
      or (v.nivel = 'RRM'         and v.alvo_id = rr.id)
      or (v.nivel = 'ESTADO'      and v.alvo_id = e.id));

  select count(*) into v_dif from (select * from _vis_antes except select * from _vis_depois) x;
  select count(*) into v_extra from (select * from _vis_depois except select * from _vis_antes) x;
  if v_dif > 0 or v_extra > 0 then
    raise exception 'Migração abortada: o acesso de usuários mudaria (% perderiam, % ganhariam acesso a casas). Nada foi alterado.', v_dif, v_extra;
  end if;
end $$;

select set_config('sysmusica.restaurando', '', true);

commit;
''',
}


# Arquivos a REMOVER: só são apagados se o conteúdo for idêntico ao esperado (cópia fica no backup)
REMOVER = {
}


# Arquivos SUBSTITUÍDOS por inteiro: só troca se o original tiver o hash (sha256, fim de linha normalizado) esperado
SUBST = {
    "src/modules/organizacao/tipos.ts": {'sha': "6fab2aabc2c3c6c7140009fb03ef40eb4a927923289c218b1aabe7098eae5a3e", 'novo': r'''/**
 * SysMúsica — Tipos da organização: Estado › RRM › RA › ADM › Setor (opcional) › Casa de Oração.
 * Campos = colunas das funções do banco (migração 0039).
 *   RRM = Reunião Regional Ministerial · RA = Regional Administrativa · ADM = Administração
 */

export type NivelOrganizacao = "ESTADO" | "RRM" | "RA" | "ADM" | "SETOR" | "CASA_ORACAO";

/** Um item da árvore. Os campos opcionais só vêm na consulta completa (tela de Organização). */
export interface NoOrganizacao {
  nivel: NivelOrganizacao;
  id: string;
  /**
   * estado -> nulo; RRM -> estado; RA -> RRM; ADM -> RA; setor -> ADM;
   * casa de oração -> o setor dela OU, quando não tem setor, a própria ADM.
   */
  parent_id: string | null;
  nome: string;
  descricao?: string | null;
  ativo?: boolean;
  cidade?: string | null; // só casas de oração
  bairro?: string | null; // só casas de oração
  qtd_filhos?: number; // itens diretos abaixo (na ADM: setores + casas de oração sem setor)
  qtd_membros?: number; // só casas de oração
}

/** Vínculo de um usuário com um nível da organização (sem o rótulo). */
export interface VinculoUsuario {
  nivel: NivelOrganizacao;
  alvo_id: string;
}

/** Vínculo com o texto para exibir (ex.: "Jequié › Ipiaú › Setor 1"). */
export interface VinculoRotulado extends VinculoUsuario {
  rotulo: string;
}
'''},
    "src/modules/organizacao/regras.ts": {'sha': "ad4cc8029e19b592be2176fde068cf79cfda7b9b05c61d3ef02dcab7d1ee6fe0", 'novo': r'''/**
 * SysMúsica — Regras puras da organização (sem banco). Testadas em regras.test.ts.
 * Árvore: Estado › RRM › RA › ADM › Setor (opcional) › Casa de Oração.
 * As regras de verdade (permissão, nomes repetidos, abrangência) ficam no banco; aqui há
 * montagem de listas para a tela e conferências rápidas.
 */
import type { NivelOrganizacao, NoOrganizacao, VinculoRotulado, VinculoUsuario } from "./tipos";

/** Nome curto de cada nível (aparece nas telas). */
export const ROTULO_NIVEL: Record<NivelOrganizacao, string> = {
  ESTADO: "Estado",
  RRM: "RRM",
  RA: "RA",
  ADM: "ADM",
  SETOR: "Setor",
  CASA_ORACAO: "Casa de Oração",
};

/** Significado de cada sigla (dica nas telas). */
export const NOME_COMPLETO_NIVEL: Record<NivelOrganizacao, string> = {
  ESTADO: "Estado",
  RRM: "Reunião Regional Ministerial",
  RA: "Regional Administrativa",
  ADM: "Administração",
  SETOR: "Setor (opcional)",
  CASA_ORACAO: "Casa de Oração",
};

/**
 * Níveis que ficam logo abaixo de cada nível. A ADM tem DOIS tipos de filho: setores e casas de oração
 * ligadas direto a ela (o setor é opcional).
 */
export const FILHOS_DE: Record<NivelOrganizacao, NivelOrganizacao[]> = {
  ESTADO: ["RRM"],
  RRM: ["RA"],
  RA: ["ADM"],
  ADM: ["SETOR", "CASA_ORACAO"],
  SETOR: ["CASA_ORACAO"],
  CASA_ORACAO: [],
};

const NIVEIS: NivelOrganizacao[] = ["ESTADO", "RRM", "RA", "ADM", "SETOR", "CASA_ORACAO"];

// Ordem natural em português ("Setor 2" antes de "Setor 10")
const porNome = (a: NoOrganizacao, b: NoOrganizacao) => a.nome.localeCompare(b.nome, "pt-BR", { numeric: true });

/** Itens de um nível que pertencem a um pai (pai nulo = os do topo / sem pai), em ordem de nome. */
export function filhosDe(nos: NoOrganizacao[], pai: string | null, nivel: NivelOrganizacao): NoOrganizacao[] {
  return nos.filter((no) => no.nivel === nivel && no.parent_id === pai).sort(porNome);
}

/** Todos os filhos diretos de um item, na ordem dos níveis (na ADM: primeiro os setores, depois as casas sem setor). */
export function filhosDoNo(nos: NoOrganizacao[], no: NoOrganizacao): NoOrganizacao[] {
  return FILHOS_DE[no.nivel].flatMap((nivel) => filhosDe(nos, no.id, nivel));
}

/** Os itens acima de um item (do mais alto ao mais próximo). Para quando o pai não existe na lista. */
export function ancestraisDe(nos: NoOrganizacao[], no: NoOrganizacao): NoOrganizacao[] {
  const porId = new Map(nos.map((item) => [item.id, item] as const));
  const caminho: NoOrganizacao[] = [];
  let atual = no.parent_id ? porId.get(no.parent_id) : undefined;
  while (atual && caminho.length < NIVEIS.length) {
    caminho.unshift(atual);
    atual = atual.parent_id ? porId.get(atual.parent_id) : undefined;
  }
  return caminho;
}

const plural = (n: number, singular: string, plurais: string) => `${n} ${n === 1 ? singular : plurais}`;

/**
 * Se o item ainda tem algo dentro (itens filhos ou membros), explica por que não pode ser excluído;
 * senão devolve null. É só uma resposta rápida da tela: o banco confere tudo de novo, inclusive eventos,
 * portarias e usuários vinculados.
 */
export function motivoBloqueioExclusao(no: NoOrganizacao): string | null {
  const filhos = no.qtd_filhos ?? 0;
  const membros = no.qtd_membros ?? 0;

  if (no.nivel === "ESTADO" && filhos > 0) {
    return `"${no.nome}" ainda tem ${plural(filhos, "RRM", "RRMs")}. Exclua as RRMs antes.`;
  }
  if (no.nivel === "RRM" && filhos > 0) {
    return `"${no.nome}" ainda tem ${plural(filhos, "RA", "RAs")}. Exclua as RAs antes.`;
  }
  if (no.nivel === "RA" && filhos > 0) {
    return `"${no.nome}" ainda tem ${plural(filhos, "ADM", "ADMs")}. Exclua as ADMs antes.`;
  }
  if (no.nivel === "ADM" && filhos > 0) {
    return `"${no.nome}" ainda tem ${plural(filhos, "item", "itens")} (setores e casas de oração). Transfira ou exclua esses itens antes.`;
  }
  if (no.nivel === "SETOR" && filhos > 0) {
    return `"${no.nome}" ainda tem ${plural(filhos, "casa de oração", "casas de oração")}. Transfira as casas de oração para outro local antes.`;
  }
  if (no.nivel === "CASA_ORACAO" && membros > 0) {
    return `"${no.nome}" ainda tem ${plural(membros, "membro", "membros")}. Mude os membros para outra casa de oração (ou exclua-os) antes.`;
  }
  return null;
}

/** Valida o nome de um item da organização; devolve a mensagem de erro ou null. */
export function validarNomeNo(nome: string): string | null {
  const tamanho = nome.trim().replace(/\s+/g, " ").length;
  return tamanho < 2 || tamanho > 80 ? "O nome deve ter entre 2 e 80 caracteres." : null;
}

export interface GrupoCasasOracao {
  rotulo: string; // ex.: "Jequié › Ipiaú › Setor 1" (ou "Jequié › Ipiaú" para casas sem setor)
  casasOracao: NoOrganizacao[];
}

/**
 * Agrupa as casas de oração por "RA › ADM › Setor" (com o estado na frente se houver mais de um; o setor
 * só aparece quando a casa tem setor). Casas cujo caminho não está na lista vão para o fim.
 */
export function agruparCasasOracaoParaSelecao(nos: NoOrganizacao[]): GrupoCasasOracao[] {
  const porId = new Map(nos.map((no) => [no.id, no] as const));
  const estados = nos.filter((no) => no.nivel === "ESTADO");
  const grupos = new Map<string, NoOrganizacao[]>();
  const semLocal: NoOrganizacao[] = [];

  for (const casaOracao of nos.filter((no) => no.nivel === "CASA_ORACAO")) {
    const pai = casaOracao.parent_id ? porId.get(casaOracao.parent_id) : undefined;
    const setor = pai?.nivel === "SETOR" ? pai : undefined;
    const adm = setor ? (setor.parent_id ? porId.get(setor.parent_id) : undefined) : pai?.nivel === "ADM" ? pai : undefined;
    const ra = adm?.parent_id ? porId.get(adm.parent_id) : undefined;
    if (!adm || !ra) {
      semLocal.push(casaOracao);
      continue;
    }
    const rrm = ra.parent_id ? porId.get(ra.parent_id) : undefined;
    const estado = rrm?.parent_id ? porId.get(rrm.parent_id) : undefined;
    const prefixo = estados.length > 1 && estado ? `${estado.nome} › ` : "";
    const rotulo = `${prefixo}${ra.nome} › ${adm.nome}${setor ? ` › ${setor.nome}` : ""}`;
    grupos.set(rotulo, [...(grupos.get(rotulo) ?? []), casaOracao]);
  }

  const lista: GrupoCasasOracao[] = [...grupos.entries()]
    .sort(([a], [b]) => a.localeCompare(b, "pt-BR", { numeric: true }))
    .map(([rotulo, casasOracao]) => ({ rotulo, casasOracao: [...casasOracao].sort(porNome) }));
  if (semLocal.length > 0) lista.push({ rotulo: "Sem local definido", casasOracao: [...semLocal].sort(porNome) });
  return lista;
}

export interface OpcaoDestino {
  id: string; // id do setor OU da ADM (o banco reconhece qual é)
  nome: string;
  nivel: "ADM" | "SETOR";
}

export interface GrupoDestinos {
  rotulo: string; // ex.: "Jequié › Ipiaú"
  opcoes: OpcaoDestino[];
}

/**
 * Destinos possíveis de uma transferência, agrupados por ADM ativa: a própria ADM (casa sem setor) e cada
 * setor ativo dela. Itens com algum pai inativo ficam de fora.
 */
export function agruparDestinosTransferencia(nos: NoOrganizacao[]): GrupoDestinos[] {
  const porId = new Map(nos.map((no) => [no.id, no] as const));
  const estados = nos.filter((no) => no.nivel === "ESTADO");
  const grupos: GrupoDestinos[] = [];

  for (const adm of nos.filter((no) => no.nivel === "ADM" && no.ativo !== false)) {
    const ra = adm.parent_id ? porId.get(adm.parent_id) : undefined;
    const rrm = ra?.parent_id ? porId.get(ra.parent_id) : undefined;
    const estado = rrm?.parent_id ? porId.get(rrm.parent_id) : undefined;
    if (!ra || ra.ativo === false || !rrm || rrm.ativo === false) continue;
    const prefixo = estados.length > 1 && estado ? `${estado.nome} › ` : "";
    const setores = filhosDe(nos, adm.id, "SETOR").filter((setor) => setor.ativo !== false);
    grupos.push({
      rotulo: `${prefixo}${ra.nome} › ${adm.nome}`,
      opcoes: [
        { id: adm.id, nome: "Sem setor (direto na ADM)", nivel: "ADM" },
        ...setores.map((setor) => ({ id: setor.id, nome: setor.nome, nivel: "SETOR" as const })),
      ],
    });
  }
  return grupos.sort((a, b) => a.rotulo.localeCompare(b.rotulo, "pt-BR", { numeric: true }));
}

/** Chave única de um vínculo, para guardar em conjuntos (ex.: "SETOR:abc"). */
export function chaveVinculo(nivel: NivelOrganizacao, id: string): string {
  return `${nivel}:${id}`;
}

/** Desfaz a chave de um vínculo; devolve nulo se estiver malformada. */
export function lerChaveVinculo(chave: string): VinculoUsuario | null {
  const posicao = chave.indexOf(":");
  if (posicao < 0) return null;
  const nivel = chave.slice(0, posicao);
  const alvo = chave.slice(posicao + 1);
  if (!NIVEIS.includes(nivel as NivelOrganizacao) || alvo === "") return null;
  return { nivel: nivel as NivelOrganizacao, alvo_id: alvo };
}

/** De { usuario: [vínculos com rótulo] } para { usuario: ["rótulo", ...] } (coluna da tabela de usuários). */
export function rotulosPorUsuario(mapa: Record<string, VinculoRotulado[]>): Record<string, string[]> {
  const resultado: Record<string, string[]> = {};
  for (const [usuarioId, vinculos] of Object.entries(mapa)) {
    resultado[usuarioId] = vinculos.map((vinculo) => vinculo.rotulo);
  }
  return resultado;
}
'''},
    "src/modules/organizacao/regras.test.ts": {'sha': "c99db65d808cc2a1ba6cb43f67a538e5e550f620989e19a653e5feea61c46c47", 'novo': r'''import { describe, expect, it } from "vitest";
import {
  agruparCasasOracaoParaSelecao,
  agruparDestinosTransferencia,
  ancestraisDe,
  chaveVinculo,
  filhosDe,
  filhosDoNo,
  lerChaveVinculo,
  motivoBloqueioExclusao,
  rotulosPorUsuario,
  validarNomeNo,
} from "@/modules/organizacao/regras";
import type { NoOrganizacao } from "@/modules/organizacao/tipos";

// Bahia
//  ├─ RRM Vitória da Conquista › RA Jequié › ADM Ipiaú ─ Setor 1 (Central) · casa "Solta" direto na ADM
//  └─ RRM Salvador › RA Salvador › ADM Centro ─ Setor 1 (Itinga, Caique) · Setor 2 · Setor 10 (inativo) · ADM Norte (inativa)
const nos: NoOrganizacao[] = [
  { nivel: "ESTADO", id: "e1", parent_id: null, nome: "Bahia", ativo: true },
  { nivel: "RRM", id: "m1", parent_id: "e1", nome: "Vitória da Conquista", ativo: true },
  { nivel: "RRM", id: "m2", parent_id: "e1", nome: "Salvador", ativo: true },
  { nivel: "RA", id: "r1", parent_id: "m1", nome: "Jequié", ativo: true },
  { nivel: "RA", id: "r2", parent_id: "m2", nome: "Salvador", ativo: true },
  { nivel: "ADM", id: "a1", parent_id: "r1", nome: "Ipiaú", ativo: true },
  { nivel: "ADM", id: "a2", parent_id: "r2", nome: "Centro", ativo: true },
  { nivel: "ADM", id: "a3", parent_id: "r2", nome: "Norte", ativo: false },
  { nivel: "SETOR", id: "s1", parent_id: "a1", nome: "Setor 1", ativo: true },
  { nivel: "SETOR", id: "s2", parent_id: "a2", nome: "Setor 1", ativo: true },
  { nivel: "SETOR", id: "s3", parent_id: "a2", nome: "Setor 10", ativo: false },
  { nivel: "SETOR", id: "s4", parent_id: "a2", nome: "Setor 2", ativo: true },
  { nivel: "CASA_ORACAO", id: "c1", parent_id: "s2", nome: "Itinga" },
  { nivel: "CASA_ORACAO", id: "c2", parent_id: "s2", nome: "Caique" },
  { nivel: "CASA_ORACAO", id: "c3", parent_id: "s1", nome: "Central" },
  { nivel: "CASA_ORACAO", id: "c4", parent_id: "a1", nome: "Solta" }, // direto na ADM, sem setor
];

describe("filhosDe e filhosDoNo", () => {
  it("traz só os itens do pai informado, em ordem natural", () => {
    expect(filhosDe(nos, "a2", "SETOR").map((n) => n.nome)).toEqual(["Setor 1", "Setor 2", "Setor 10"]);
  });

  it("separa 'Setor 1' de ADMs diferentes", () => {
    expect(filhosDe(nos, "a1", "SETOR").map((n) => n.id)).toEqual(["s1"]);
    expect(filhosDe(nos, "a2", "SETOR").map((n) => n.id)).not.toContain("s1");
  });

  it("a ADM tem setores E casas de oração diretas (setores primeiro)", () => {
    expect(filhosDoNo(nos, nos.find((n) => n.id === "a1")!).map((n) => `${n.nivel}:${n.nome}`)).toEqual([
      "SETOR:Setor 1",
      "CASA_ORACAO:Solta",
    ]);
  });

  it("cada nível desce para o seguinte", () => {
    expect(filhosDoNo(nos, nos[0]).map((n) => n.nome)).toEqual(["Salvador", "Vitória da Conquista"]);
    expect(filhosDoNo(nos, nos.find((n) => n.id === "m1")!).map((n) => n.nome)).toEqual(["Jequié"]);
    expect(filhosDoNo(nos, nos.find((n) => n.id === "c1")!)).toEqual([]);
  });
});

describe("ancestraisDe", () => {
  it("devolve o caminho do estado até o pai", () => {
    const casa = nos.find((n) => n.id === "c3")!;
    expect(ancestraisDe(nos, casa).map((n) => n.nome)).toEqual(["Bahia", "Vitória da Conquista", "Jequié", "Ipiaú", "Setor 1"]);
  });

  it("para uma casa sem setor o último é a ADM", () => {
    const casa = nos.find((n) => n.id === "c4")!;
    expect(ancestraisDe(nos, casa).at(-1)?.nome).toBe("Ipiaú");
  });

  it("não quebra quando o pai não está na lista", () => {
    expect(ancestraisDe(nos, { nivel: "CASA_ORACAO", id: "x", parent_id: "inexistente", nome: "Órfã" })).toEqual([]);
  });
});

describe("agruparCasasOracaoParaSelecao", () => {
  const grupos = agruparCasasOracaoParaSelecao(nos);

  it("agrupa por RA › ADM › Setor e mostra a ADM sozinha para casas sem setor", () => {
    expect(grupos.map((g) => g.rotulo)).toEqual([
      "Jequié › Ipiaú",
      "Jequié › Ipiaú › Setor 1",
      "Salvador › Centro › Setor 1",
    ]);
    expect(grupos[0].casasOracao.map((c) => c.nome)).toEqual(["Solta"]);
  });

  it("ordena as casas de oração de cada grupo pelo nome", () => {
    expect(grupos[2].casasOracao.map((c) => c.nome)).toEqual(["Caique", "Itinga"]);
  });

  it("casa cujo caminho não está na lista vai para 'Sem local definido', no fim", () => {
    const comOrfa = agruparCasasOracaoParaSelecao([...nos, { nivel: "CASA_ORACAO", id: "c9", parent_id: null, nome: "Órfã" }]);
    expect(comOrfa.at(-1)).toMatchObject({ rotulo: "Sem local definido" });
    expect(comOrfa.at(-1)?.casasOracao.map((c) => c.nome)).toEqual(["Órfã"]);
  });

  it("coloca o estado na frente quando há mais de um estado", () => {
    const maisUm = agruparCasasOracaoParaSelecao([...nos, { nivel: "ESTADO", id: "e2", parent_id: null, nome: "Sergipe" }]);
    expect(maisUm[0].rotulo).toBe("Bahia › Jequié › Ipiaú");
  });
});

describe("agruparDestinosTransferencia", () => {
  const grupos = agruparDestinosTransferencia(nos);

  it("lista cada ADM ativa com 'sem setor' e os setores ativos, ignorando ADM e setor inativos", () => {
    expect(grupos.map((g) => g.rotulo)).toEqual(["Jequié › Ipiaú", "Salvador › Centro"]);
    expect(grupos[1].opcoes.map((o) => `${o.nivel}:${o.nome}`)).toEqual([
      "ADM:Sem setor (direto na ADM)",
      "SETOR:Setor 1",
      "SETOR:Setor 2",
    ]);
  });

  it("a opção 'sem setor' leva o id da ADM e as demais o id do setor", () => {
    expect(grupos[0].opcoes.map((o) => o.id)).toEqual(["a1", "s1"]);
  });

  it("ADM de uma RA inativa não é oferecida", () => {
    const semRa = nos.map((n) => (n.id === "r1" ? { ...n, ativo: false } : n));
    expect(agruparDestinosTransferencia(semRa).map((g) => g.rotulo)).toEqual(["Salvador › Centro"]);
  });
});

describe("vínculos", () => {
  it("monta e desfaz a chave de um vínculo (todos os níveis)", () => {
    for (const nivel of ["ESTADO", "RRM", "RA", "ADM", "SETOR", "CASA_ORACAO"] as const) {
      const chave = chaveVinculo(nivel, "abc-123");
      expect(chave).toBe(`${nivel}:abc-123`);
      expect(lerChaveVinculo(chave)).toEqual({ nivel, alvo_id: "abc-123" });
    }
  });

  it("recusa chaves malformadas e o nível antigo REGIAO", () => {
    expect(lerChaveVinculo("sem-separador")).toBeNull();
    expect(lerChaveVinculo("OUTRO:abc")).toBeNull();
    expect(lerChaveVinculo("REGIAO:abc")).toBeNull();
    expect(lerChaveVinculo("SETOR:")).toBeNull();
  });

  it("lista só os rótulos por usuário", () => {
    expect(
      rotulosPorUsuario({ u1: [{ nivel: "ADM", alvo_id: "a1", rotulo: "Jequié › Ipiaú" }], u2: [] })
    ).toEqual({ u1: ["Jequié › Ipiaú"], u2: [] });
  });
});

describe("motivoBloqueioExclusao", () => {
  const base = { parent_id: null, ativo: true };

  it("bloqueia o item que ainda tem itens dentro e explica o motivo, em cada nível", () => {
    expect(motivoBloqueioExclusao({ ...base, nivel: "ESTADO", id: "e", nome: "Bahia", qtd_filhos: 2 })).toMatch(/2 RRMs/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "RRM", id: "m", nome: "Salvador", qtd_filhos: 1 })).toMatch(/1 RA\b/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "RA", id: "r", nome: "Jequié", qtd_filhos: 3 })).toMatch(/3 ADMs/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "ADM", id: "a", nome: "Ipiaú", qtd_filhos: 4 })).toMatch(/4 itens/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "SETOR", id: "s", nome: "Setor 1", qtd_filhos: 3 })).toMatch(/3 casas de oração/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "CASA_ORACAO", id: "c", nome: "Itinga", qtd_membros: 4 })).toMatch(/4 membros/);
  });

  it("libera o item vazio", () => {
    expect(motivoBloqueioExclusao({ ...base, nivel: "ADM", id: "a", nome: "Vazia", qtd_filhos: 0 })).toBeNull();
    expect(motivoBloqueioExclusao({ ...base, nivel: "SETOR", id: "s", nome: "Setor 9", qtd_filhos: 0 })).toBeNull();
    expect(motivoBloqueioExclusao({ ...base, nivel: "CASA_ORACAO", id: "c", nome: "Vazia", qtd_membros: 0 })).toBeNull();
  });
});

describe("validarNomeNo", () => {
  it("exige de 2 a 80 caracteres", () => {
    expect(validarNomeNo("A")).toMatch(/entre 2 e 80/);
    expect(validarNomeNo("  Setor 1  ")).toBeNull();
    expect(validarNomeNo("x".repeat(81))).toMatch(/entre 2 e 80/);
  });
});
'''},
    "src/modules/organizacao/components/ArvoreOrganizacao.tsx": {'sha': "861ab2acbcfa6206835511c6ebc5697d618a2c75f205cf87adc02a1239101348", 'novo': r'''"use client";

/**
 * SysMúsica — Árvore da organização: Estado › RRM › RA › ADM › Setor (opcional) › Casa de Oração,
 * com abrir/fechar e as ações de cada item.
 * RRM = Reunião Regional Ministerial · RA = Regional Administrativa · ADM = Administração.
 * Uma casa de oração pode ficar dentro de um setor OU ligada direto à ADM (o setor é opcional).
 * Os botões só aparecem para quem tem a permissão (a tela repassa); o banco confere de novo em cada operação.
 */
import { useState, type ReactNode } from "react";
import { ArrowRightLeft, ChevronDown, ChevronRight, Pencil, Plus, Power, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { FILHOS_DE, NOME_COMPLETO_NIVEL, ROTULO_NIVEL, filhosDe, filhosDoNo } from "../regras";
import type { NivelOrganizacao, NoOrganizacao } from "../tipos";

interface ArvoreOrganizacaoProps {
  nos: NoOrganizacao[];
  podeCriar: boolean;
  podeEditar: boolean;
  podeTransferir: boolean;
  podeExcluir: boolean;
  onNovo: (nivel: NivelOrganizacao, pai: NoOrganizacao | null) => void;
  onEditar: (no: NoOrganizacao) => void;
  onAlternar: (no: NoOrganizacao) => void;
  onTransferir: (no: NoOrganizacao) => void;
  onExcluir: (no: NoOrganizacao) => void;
}

const plural = (n: number, singular: string, plurais: string) => `${n} ${n === 1 ? singular : plurais}`;

// Níveis que começam abertos (da raiz até a RA); ADM e setor começam fechados
const ABERTOS_NO_INICIO: NivelOrganizacao[] = ["ESTADO", "RRM", "RA"];

export default function ArvoreOrganizacao({
  nos,
  podeCriar,
  podeEditar,
  podeTransferir,
  podeExcluir,
  onNovo,
  onEditar,
  onAlternar,
  onTransferir,
  onExcluir,
}: ArvoreOrganizacaoProps) {
  const [abertos, setAbertos] = useState<Set<string>>(
    () => new Set(nos.filter((no) => ABERTOS_NO_INICIO.includes(no.nivel)).map((no) => no.id))
  );

  function alternarAberto(id: string) {
    setAbertos((anterior) => {
      const novos = new Set(anterior);
      if (novos.has(id)) novos.delete(id);
      else novos.add(id);
      return novos;
    });
  }

  // Texto de contagem de cada item (ex.: "2 setores · 3 casas de oração")
  function contagem(no: NoOrganizacao): string {
    if (no.nivel === "ESTADO") return plural(no.qtd_filhos ?? 0, "RRM", "RRMs");
    if (no.nivel === "RRM") return plural(no.qtd_filhos ?? 0, "RA", "RAs");
    if (no.nivel === "RA") return plural(no.qtd_filhos ?? 0, "ADM", "ADMs");
    if (no.nivel === "ADM") {
      const setores = filhosDe(nos, no.id, "SETOR").length;
      const casas = filhosDe(nos, no.id, "CASA_ORACAO").length;
      return `${plural(setores, "setor", "setores")} · ${plural(casas, "casa de oração sem setor", "casas de oração sem setor")}`;
    }
    if (no.nivel === "SETOR") return plural(no.qtd_filhos ?? 0, "casa de oração", "casas de oração");
    return plural(no.qtd_membros ?? 0, "membro", "membros");
  }

  // Linha de um item e, se estiver aberto, os filhos dele (função comum e não componente: é recursiva)
  function renderLinha(no: NoOrganizacao, profundidade: number): ReactNode {
    const filhos = filhosDoNo(nos, no);
    const aberto = abertos.has(no.id);
    const inativo = no.ativo === false;

    return (
      <li key={`${no.nivel}:${no.id}`}>
        <div
          className="flex items-center gap-2 rounded-lg py-1.5 pr-2 hover:bg-slate-50"
          style={{ paddingLeft: `${profundidade * 1.25 + 0.25}rem` }}
        >
          {filhos.length > 0 ? (
            <button
              type="button"
              onClick={() => alternarAberto(no.id)}
              aria-expanded={aberto}
              aria-label={`${aberto ? "Fechar" : "Abrir"} ${no.nome}`}
              className="rounded p-0.5 text-slate-500 hover:bg-slate-100"
            >
              {aberto ? <ChevronDown className="h-4 w-4" aria-hidden="true" /> : <ChevronRight className="h-4 w-4" aria-hidden="true" />}
            </button>
          ) : (
            <span className="inline-block w-5" aria-hidden="true" />
          )}

          <span className="min-w-0 flex-1">
            <span
              className="mr-2 text-xs font-semibold uppercase tracking-wide text-slate-400"
              title={NOME_COMPLETO_NIVEL[no.nivel]}
            >
              {ROTULO_NIVEL[no.nivel]}
            </span>
            <span className={inativo ? "font-medium text-slate-400" : "font-medium text-slate-900"}>{no.nome}</span>
            <span className="ml-2 text-xs text-slate-500">
              {contagem(no)}
              {no.nivel === "CASA_ORACAO" && (no.bairro || no.cidade)
                ? ` · ${[no.bairro, no.cidade].filter(Boolean).join(", ")}`
                : ""}
            </span>
          </span>

          <Badge variante={inativo ? "perigo" : "sucesso"}>{inativo ? "Inativo" : "Ativo"}</Badge>

          <div className="flex shrink-0 gap-1">
            {/* Um botão + para cada tipo de filho (a ADM tem dois: setor e casa de oração) */}
            {podeCriar &&
              FILHOS_DE[no.nivel].map((nivelFilho) => (
                <BotaoIcone
                  key={nivelFilho}
                  icone={Plus}
                  rotulo={`Adicionar ${ROTULO_NIVEL[nivelFilho]} em ${no.nome}`}
                  onClick={() => onNovo(nivelFilho, no)}
                />
              ))}
            {podeTransferir && no.nivel === "CASA_ORACAO" && (
              <BotaoIcone icone={ArrowRightLeft} rotulo={`Transferir ${no.nome} para outra ADM ou setor`} onClick={() => onTransferir(no)} />
            )}
            {podeEditar && (
              <>
                <BotaoIcone icone={Pencil} rotulo={`Editar ${no.nome}`} onClick={() => onEditar(no)} />
                <BotaoIcone
                  icone={Power}
                  rotulo={`${inativo ? "Ativar" : "Inativar"} ${no.nome}`}
                  onClick={() => onAlternar(no)}
                />
              </>
            )}
            {podeExcluir && (
              <BotaoIcone icone={Trash2} variante="perigo" rotulo={`Excluir ${no.nome}`} onClick={() => onExcluir(no)} />
            )}
          </div>
        </div>

        {aberto && filhos.length > 0 && <ul>{filhos.map((filho) => renderLinha(filho, profundidade + 1))}</ul>}
      </li>
    );
  }

  const estados = filhosDe(nos, null, "ESTADO");

  return (
    <div className="space-y-6">
      <div className="rounded-2xl border border-slate-200 bg-white p-3 shadow-sm">
        {estados.length === 0 ? (
          <p className="px-2 py-6 text-center text-sm text-slate-500">Nenhum estado cadastrado.</p>
        ) : (
          <ul>{estados.map((estado) => renderLinha(estado, 0))}</ul>
        )}
      </div>
      <p className="px-1 text-xs text-slate-500">
        RRM = Reunião Regional Ministerial · RA = Regional Administrativa · ADM = Administração. O setor é opcional: uma
        casa de oração pode ficar ligada direto à ADM.
      </p>
    </div>
  );
}
'''},
    "src/modules/organizacao/components/FormularioTransferencia.tsx": {'sha': "5378fbd943e20ee19df27bdf5e1e905493f7eabf8bf2aefc3b22ed284d2eeff9", 'novo': r'''"use client";

/**
 * SysMúsica — Transferência de uma casa de oração para outro local (painel lateral).
 * O destino é uma ADM (a casa fica sem setor) ou um setor de uma ADM. Exige a permissão de transferir; fica no
 * histórico da casa de oração e na auditoria. As portarias da casa de oração passam a valer para o destino novo
 * (elas seguem a casa de oração do evento).
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { agruparDestinosTransferencia, ancestraisDe } from "../regras";
import { transferirCasaOracao } from "../services/organizacao";
import type { NoOrganizacao } from "../tipos";

interface FormularioTransferenciaProps {
  casaOracao: NoOrganizacao;
  nos: NoOrganizacao[];
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 " +
  "shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60";

export default function FormularioTransferencia({ casaOracao, nos, onSalvo }: FormularioTransferenciaProps) {
  const [destinoId, setDestinoId] = useState("");
  const [justificativa, setJustificativa] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const grupos = agruparDestinosTransferencia(nos);
  // Onde a casa está agora (ADM e, se tiver, setor): "Ipiaú › Setor 1" ou só "Ipiaú"
  const localAtual = ancestraisDe(nos, casaOracao)
    .filter((no) => no.nivel === "ADM" || no.nivel === "SETOR")
    .map((no) => no.nome)
    .join(" › ");

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);
    if (!destinoId) return setErro("Escolha o destino (ADM ou setor).");

    setSalvando(true);
    try {
      await transferirCasaOracao(casaOracao.id, destinoId, justificativa);
      await onSalvo(`Casa de Oração "${casaOracao.nome}" transferida.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível transferir a casa de oração.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
        <strong className="text-slate-900">{casaOracao.nome}</strong>
        {localAtual ? <> está em {localAtual}.</> : <> ainda não tem local definido.</>}
      </p>

      <div className="space-y-1.5">
        <label htmlFor="destino-transferencia" className="text-sm font-medium text-slate-700">
          Destino
        </label>
        <select
          id="destino-transferencia"
          value={destinoId}
          onChange={(e) => setDestinoId(e.target.value)}
          disabled={salvando}
          className={classeInput}
        >
          <option value="">Selecione a ADM ou o setor</option>
          {grupos.map((grupo) => (
            <optgroup key={grupo.rotulo} label={grupo.rotulo}>
              {grupo.opcoes.map((opcao) => (
                <option key={opcao.id} value={opcao.id}>
                  {opcao.nome}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
        <p className="text-xs text-slate-500">
          “Sem setor” deixa a casa ligada direto à ADM. O setor é opcional.
        </p>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="justificativa-transferencia" className="text-sm font-medium text-slate-700">
          Justificativa <span className="font-normal text-slate-400">(opcional)</span>
        </label>
        <textarea
          id="justificativa-transferencia"
          rows={3}
          maxLength={300}
          value={justificativa}
          onChange={(e) => setJustificativa(e.target.value)}
          disabled={salvando}
          className={classeInput}
        />
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Transferindo..." : "Transferir casa de oração"}
      </Button>
    </form>
  );
}
'''},
}


def ler(caminho):
    with open(caminho, "r", encoding="utf-8", newline="") as f:
        return f.read()

def eol_de(txt):
    return "\r\n" if "\r\n" in txt else "\n"

def adaptar(trecho, eol):
    return trecho.replace("\n", eol) if eol != "\n" else trecho

def norm(t):
    return t.replace("\r\n", "\n").rstrip("\n")

conteudo, problemas = {}, []
for arq, antigo, novo in EDITS:
    if arq in conteudo:
        continue
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"ARQUIVO NÃO ENCONTRADO: {arq}")
        conteudo[arq] = None
    else:
        conteudo[arq] = ler(caminho)

for arq, antigo, novo in EDITS:
    txt = conteudo.get(arq)
    if txt is None:
        continue
    n = txt.count(adaptar(antigo, eol_de(txt)))
    if n != 1:
        resumo = antigo.strip().split("\n")[0][:80]
        problemas.append(f"{arq}: trecho «{resumo}…» aparece {n} vez(es) (esperado 1)")

for arq in list(NOVOS):
    p = os.path.join(RAIZ, arq)
    if os.path.exists(p):
        if norm(ler(p)) == norm(NOVOS[arq]):
            print(f"já existe, idêntico (mantido): {arq}")
            del NOVOS[arq]
        else:
            problemas.append(f"JÁ EXISTE E É DIFERENTE (não vou sobrescrever): {arq}")

for arq, esperado in REMOVER.items():
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"PARA REMOVER, NÃO ENCONTRADO: {arq}")
    elif ler(caminho).replace("\r\n", "\n").strip() != esperado.replace("\r\n", "\n").strip():
        problemas.append(f"PARA REMOVER, CONTEÚDO DIFERENTE DO ESPERADO (não vou apagar): {arq}")

for arq, info in SUBST.items():
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"PARA SUBSTITUIR, NÃO ENCONTRADO: {arq}")
    elif hashlib.sha256(norm(ler(caminho)).encode("utf-8")).hexdigest() != info["sha"]:
        problemas.append(f"PARA SUBSTITUIR, O ARQUIVO É DIFERENTE DO ESPERADO (não vou sobrescrever): {arq}")

if problemas:
    print("NADA FOI ALTERADO. Divergências encontradas:")
    for p in problemas:
        print("  -", p)
    print("Se TODOS dizem 0 vez(es) / JÁ EXISTE, esta parte provavelmente já foi aplicada.")
    sys.exit(2)

alterados, criados = [], []
for arq in dict.fromkeys(a for a, _, _ in EDITS):
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    txt = conteudo[arq]
    eol = eol_de(txt)
    for a, antigo, novo in EDITS:
        if a != arq:
            continue
        ant = adaptar(antigo, eol)
        if txt.count(ant) != 1:
            print(f"ERRO: {arq}: trecho mudou durante a aplicação. Nada foi gravado.")
            sys.exit(2)
        txt = txt.replace(ant, adaptar(novo, eol), 1)
    with open(origem, "w", encoding="utf-8", newline="") as f:
        f.write(txt)
    alterados.append(arq)

substituidos = []
for arq, info in SUBST.items():
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    eol = eol_de(ler(origem))
    with open(origem, "w", encoding="utf-8", newline="") as f:
        f.write(adaptar(info["novo"].rstrip("\n") + "\n", eol))
    substituidos.append(arq)

removidos = []
for arq in REMOVER:
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    os.remove(origem)
    removidos.append(arq)

for arq, cont in NOVOS.items():
    destino = os.path.join(RAIZ, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    with open(destino, "w", encoding="utf-8", newline="") as f:
        f.write(cont)
    criados.append(arq)

with open(os.path.join(BKP, ".arquivos"), "w", encoding="utf-8") as f:
    f.write("\n".join(a for a in alterados + substituidos + criados if a.endswith((".ts", ".tsx"))) + "\n")
with open(os.path.join(BKP, ".novos"), "w", encoding="utf-8") as f:
    f.write("\n".join(criados) + "\n")
print(f"OK: {len(EDITS)} trocas em {len(alterados)} arquivos + {len(substituidos)} substituídos + {len(criados)} arquivos novos + {len(removidos)} removidos. Backup em {BKP}")
PYSCRIPT
rc=$?
[ $rc -eq 0 ] || { echo "Nada foi alterado (veja acima)."; exit 1; }

reverter() {
  echo "↩ Desfazendo as alterações a partir de $BKP ..."
  ( cd "$BKP" && find . -type f ! -name .arquivos ! -name .novos -print0 | while IFS= read -r -d '' f; do cp "$f" "$RAIZ/$f"; done )
  while IFS= read -r n; do [ -n "$n" ] && { rm -f "$RAIZ/$n"; rmdir -p "$(dirname "$RAIZ/$n")" 2>/dev/null; }; done < "$BKP/.novos"
  true
}

passo() {
  nome="$1"; shift
  echo "▶ $nome"
  if "$@" > /tmp/p7-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p7-passo.out
    reverter; echo "Alterações desfeitas. Me envie o log: $LOG"
    exit 1
  fi
}

echo; echo "== 2/3  Verificações =="
mapfile -t ARQ < <(grep -v '^$' "$BKP/.arquivos")
passo "tipos (tsc)"      npx tsc --noEmit
passo "testes (vitest)"  npx vitest run
passo "lint (eslint)"    npx eslint "${ARQ[@]}"
passo "build"            npm run build

echo; echo "== 3/3  PRONTO =="
echo "Backup: $BKP"
echo "Lembrete: o SQL 0039 precisa ter sido rodado no Supabase ANTES de testar as telas."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
