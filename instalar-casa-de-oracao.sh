cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-casa-de-oracao-$(date +%H%M%S)"; mkdir -p "$BKP"
MIG="supabase/migrations/0031_casa_de_oracao.sql"
cp -a src "$BKP/src"

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  rm -rf src && cp -a "$BKP/src" src
  rm -f "$MIG"
  echo ">>> REVERTIDO. Me mande o log: /tmp/casa-de-oracao-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
[ -f src/modules/organizacao/components/SeletorComum.tsx ] || { echo "ERRO: SeletorComum.tsx não existe (renomeação já feita?)."; exit 1; }
[ -e "$MIG" ] && { echo "ERRO: a migração 0031 já existe."; exit 1; }
[ -f supabase/migrations/0030_portaria_encerrada.sql ] || echo "AVISO: 0030 não encontrada (a Portaria encerrada ainda não foi instalada?). Segue assim mesmo."

echo; echo "=== 1) Trocando 'Comum' por 'Casa de Oração' no código (linha por linha, conferindo o texto exato) ==="
python3 - <<'PYSCRIPT'
import os, sys, json
EDICOES = json.loads(r'''{"src/app/(painel)/administracao/organizacao/layout.tsx": [["/** Protege a tela de Organização: só entra quem pode visualizar estados, regiões, setores e comuns. */", "/** Protege a tela de Organização: só entra quem pode visualizar estados, regiões, setores e casas de oração. */", 1]], "src/app/(painel)/administracao/organizacao/page.tsx": [[" * SysMúsica — Página /administracao/organizacao: estados, regiões, setores e comuns.", " * SysMúsica — Página /administracao/organizacao: estados, regiões, setores e casas de oração.", 1], [" * Cadastro pelo sistema (sem código fixo), com ativar/inativar e transferência de comum entre setores.", " * Cadastro pelo sistema (sem código fixo), com ativar/inativar e transferência de casa de oração entre setores.", 1], ["type Painel = { tipo: \"no\"; modo: ModoNo } | { tipo: \"transferir\"; comum: NoOrganizacao };", "type Painel = { tipo: \"no\"; modo: ModoNo } | { tipo: \"transferir\"; casaOracao: NoOrganizacao };", 1], ["  if (painel.tipo === \"transferir\") return \"Transferir comum\";", "  if (painel.tipo === \"transferir\") return \"Transferir casa de oração\";", 1], ["          descricao=\"Estados, regiões, setores e comuns. O acesso dos usuários aos dados segue esta estrutura.\"", "          descricao=\"Estados, regiões, setores e casas de oração. O acesso dos usuários aos dados segue esta estrutura.\"", 1], ["            onTransferir={(comum) => setPainel({ tipo: \"transferir\", comum })}", "            onTransferir={(casaOracao) => setPainel({ tipo: \"transferir\", casaOracao })}", 1], ["            ? \"A comum e as portarias dela passam a valer para o setor escolhido.\"", "            ? \"A casa de oração e as portarias dela passam a valer para o setor escolhido.\"", 1], ["          <FormularioTransferencia comum={painel.comum} nos={nos} onSalvo={aoSalvar} />", "          <FormularioTransferencia casaOracao={painel.casaOracao} nos={nos} onSalvo={aoSalvar} />", 1]], "src/app/(painel)/administracao/usuarios/page.tsx": [["      descricao: \"Estado, região, setor ou comum que o usuário pode ver e usar.\",", "      descricao: \"Estado, região, setor ou casa de oração que o usuário pode ver e usar.\",", 1]], "src/components/FormularioEvento.tsx": [["import SeletorComum from \"@/modules/organizacao/components/SeletorComum\";", "import SeletorCasaOracao from \"@/modules/organizacao/components/SeletorCasaOracao\";", 1], ["  ROTULO_COMUM,", "  ROTULO_CASA_ORACAO,", 1], ["  const [comumId, setComumId] = useState(evento?.comum_id ?? \"\");", "  const [casaOracaoId, setCasaOracaoId] = useState(evento?.casa_oracao_id ?? \"\");", 1], ["    const vazios = camposFaltando({ tipo, finalidade: finalidadeTexto, dataEvento, local, cidade, comumId });", "    const vazios = camposFaltando({ tipo, finalidade: finalidadeTexto, dataEvento, local, cidade, casaOracaoId });", 1], ["        comum_id: comumId || null,", "        casa_oracao_id: casaOracaoId || null,", 1], ["        <label htmlFor=\"comum-evento\" className=\"text-sm font-medium text-slate-700\">", "        <label htmlFor=\"casa-oracao-evento\" className=\"text-sm font-medium text-slate-700\">", 1], ["          Comum <span className=\"text-red-600\"> *</span> <span className=\"font-normal text-slate-400\">(define o setor da portaria)</span>", "          Casa de Oração <span className=\"text-red-600\"> *</span> <span className=\"font-normal text-slate-400\">(define o setor da portaria)</span>", 1], ["        <SeletorComum", "        <SeletorCasaOracao", 1], ["          id=\"comum-evento\"", "          id=\"casa-oracao-evento\"", 1], ["          valor={comumId}", "          valor={casaOracaoId}", 1], ["          onChange={setComumId}", "          onChange={setCasaOracaoId}", 1], ["          className={classeCampo(ROTULO_COMUM)}", "          className={classeCampo(ROTULO_CASA_ORACAO)}", 1]], "src/components/FormularioMembro.tsx": [[" * Comum: lista agrupada por Região › Setor (cadastrada em Organização). O nome da congregação sai da comum.", " * Casa de Oração: lista agrupada por Região › Setor (cadastrada em Organização). O nome da congregação sai da casa de oração.", 1], ["import SeletorComum from \"@/modules/organizacao/components/SeletorComum\";", "import SeletorCasaOracao from \"@/modules/organizacao/components/SeletorCasaOracao\";", 1], ["  const [comumId, setComumId] = useState(membro?.comum_id ?? \"\"); // a comum define o nome da congregação", "  const [casaOracaoId, setCasaOracaoId] = useState(membro?.casa_oracao_id ?? \"\"); // a casa de oração define o nome da congregação", 1], ["    if (!nome.trim() || !comumId || !cargoId) {", "    if (!nome.trim() || !casaOracaoId || !cargoId) {", 1], ["      return setErroForm(\"Preencha nome, cargo e comum.\");", "      return setErroForm(\"Preencha nome, cargo e casa de oração.\");", 1], ["        comum_id: comumId,", "        casa_oracao_id: casaOracaoId,", 1], ["      {/* Localidade: comum (lista do banco), cidade e bairro (com sugestões dos já cadastrados) */}", "      {/* Localidade: casa de oração (lista do banco), cidade e bairro (com sugestões dos já cadastrados) */}", 1], ["        <label htmlFor=\"comum-membro\" className=\"text-sm font-medium text-slate-700\">", "        <label htmlFor=\"casa-oracao-membro\" className=\"text-sm font-medium text-slate-700\">", 1], ["          Comum", "          Casa de Oração", 1], ["        <SeletorComum", "        <SeletorCasaOracao", 1], ["          id=\"comum-membro\"", "          id=\"casa-oracao-membro\"", 1], ["          valor={comumId}", "          valor={casaOracaoId}", 1], ["          onChange={setComumId}", "          onChange={setCasaOracaoId}", 1], ["          A comum define o setor e quem enxerga o cadastro. Se a comum não aparecer, peça a um administrador para", "          A casa de oração define o setor e quem enxerga o cadastro. Se a casa de oração não aparecer, peça a um administrador para", 1]], "src/modules/administracao/components/FormularioVinculos.tsx": [[" * O usuário pode ser ligado a um estado, região, setor ou comum: o acesso desce em cascata (um setor", " * O usuário pode ser ligado a um estado, região, setor ou casa de oração: o acesso desce em cascata (um setor", 1], [" * inclui todas as comuns dele). Sem nenhum vínculo, ele não vê nenhum dado (membros, eventos,", " * inclui todas as casas de oração dele). Sem nenhum vínculo, ele não vê nenhum dado (membros, eventos,", 1], ["  const semSetor = filhosDe(arvore, null, \"COMUM\");", "  const semSetor = filhosDe(arvore, null, \"CASA_ORACAO\");", 1], ["        Marcar um setor inclui todas as comuns dele; marcar uma região inclui todos os setores. Sem nenhuma", "        Marcar um setor inclui todas as casas de oração dele; marcar uma região inclui todos os setores. Sem nenhuma", 1], ["              <p className=\"mb-1 text-xs font-semibold text-slate-500\">Comuns sem setor</p>", "              <p className=\"mb-1 text-xs font-semibold text-slate-500\">Casas de Oração sem setor</p>", 1], ["              <ul>{semSetor.map((comum) => renderNo(comum, 0))}</ul>", "              <ul>{semSetor.map((casaOracao) => renderNo(casaOracao, 0))}</ul>", 1]], "src/modules/atendimento/components/BuscaLocalidade.tsx": [["                  <li key={item.comum_id}>", "                  <li key={item.casa_oracao_id}>", 1]], "src/modules/atendimento/components/EntradaSemCadastro.tsx": [["        origemComumId: localidade?.comum_id ?? null,", "        origemCasaOracaoId: localidade?.casa_oracao_id ?? null,", 1]], "src/modules/atendimento/components/FormularioVisitante.tsx": [[" * (Estado > Região > Setor > Comum, cadastrados em Organização): nada de origem digitada à mão.", " * (Estado > Região > Setor > Casa de Oração, cadastrados em Organização): nada de origem digitada à mão.", 1], [" * O visitante é cadastrado na COMUM da portaria em atendimento e só a região dela o enxerga.", " * O visitante é cadastrado na CASA DE ORAÇÃO da portaria em atendimento e só a região dela o enxerga.", 1], [" * O banco confere permissão, portaria aprovada, abrangência, instrumento, origem e nome repetido na comum.", " * O banco confere permissão, portaria aprovada, abrangência, instrumento, origem e nome repetido na casa de oração.", 1], ["  const [comumId, setComumId] = useState(\"\");", "  const [casaOracaoId, setCasaOracaoId] = useState(\"\");", 1], ["  const comuns = setorId ? filhosDe(origens, setorId, \"COMUM\") : [];", "  const casasOracao = setorId ? filhosDe(origens, setorId, \"CASA_ORACAO\") : [];", 1], ["    setComumId(\"\");", "    setCasaOracaoId(\"\");", 3], ["    const erroDados = validarDadosVisitante({ nome, cargoId, origemComumId: comumId });", "    const erroDados = validarDadosVisitante({ nome, cargoId, origemCasaOracaoId: casaOracaoId });", 1], ["          origemComumId: comumId,", "          origemCasaOracaoId: casaOracaoId,", 1], ["        O visitante é cadastrado na comum desta portaria e só aparece para esta região. Depois de salvar, você", "        O visitante é cadastrado na casa de oração desta portaria e só aparece para esta região. Depois de salvar, você", 1], ["          <label htmlFor=\"comum-visitante\" className=\"text-xs font-medium text-slate-600\">", "          <label htmlFor=\"casa-oracao-visitante\" className=\"text-xs font-medium text-slate-600\">", 1], ["            Comum", "            Casa de Oração", 1], ["            id=\"comum-visitante\"", "            id=\"casa-oracao-visitante\"", 1], ["            value={comumId}", "            value={casaOracaoId}", 1], ["            onChange={(e) => setComumId(e.target.value)}", "            onChange={(e) => setCasaOracaoId(e.target.value)}", 1], ["            <option value=\"\">Selecione a comum</option>", "            <option value=\"\">Selecione a casa de oração</option>", 1], ["            {comuns.map((item) => (", "            {casasOracao.map((item) => (", 1]], "src/modules/atendimento/regras.test.ts": [["  const completo = { nome: \"Maria da Silva\", cargoId: \"c1\", origemComumId: \"o1\" };", "  const completo = { nome: \"Maria da Silva\", cargoId: \"c1\", origemCasaOracaoId: \"o1\" };", 1], ["    expect(validarDadosVisitante({ ...completo, origemComumId: \"\" })).toMatch(/igreja de origem/);", "    expect(validarDadosVisitante({ ...completo, origemCasaOracaoId: \"\" })).toMatch(/igreja de origem/);", 1]], "src/modules/atendimento/regras.ts": [[" * A origem (igreja) é uma comum escolhida na lista, cadastrada em Organização: nunca texto livre.", " * A origem (igreja) é uma casa de oração escolhida na lista, cadastrada em Organização: nunca texto livre.", 1], [" * É só uma resposta rápida da tela: o banco confere tudo de novo (inclusive nome repetido na comum).", " * É só uma resposta rápida da tela: o banco confere tudo de novo (inclusive nome repetido na casa de oração).", 1], ["  origemComumId: string;", "  origemCasaOracaoId: string;", 1], ["  if (!dados.origemComumId) return \"Escolha a igreja de origem na lista (estado, região, setor e comum).\";", "  if (!dados.origemCasaOracaoId) return \"Escolha a igreja de origem na lista (estado, região, setor e casa de oração).\";", 1]], "src/modules/atendimento/services/atendimento.ts": [["/** Estrutura ativa (estados, regiões, setores e comuns) para escolher a origem do visitante. */", "/** Estrutura ativa (estados, regiões, setores e casas de oração) para escolher a origem do visitante. */", 1], [" * Cadastra o visitante na comum da portaria e devolve o cartão para a conferência.", " * Cadastra o visitante na casa de oração da portaria e devolve o cartão para a conferência.", 1], [" * O banco confere permissão, portaria aprovada, abrangência, nome completo e nome repetido na comum.", " * O banco confere permissão, portaria aprovada, abrangência, nome completo e nome repetido na casa de oração.", 1], ["    origemComumId: string;", "    origemCasaOracaoId: string;", 1], ["    p_origem_comum_id: dados.origemComumId,", "    p_origem_casa_oracao_id: dados.origemCasaOracaoId,", 1]], "src/modules/atendimento/services/entrada.ts": [["    origemComumId: string | null;", "    origemCasaOracaoId: string | null;", 1], ["    p_origem_comum_id: dados.origemComumId,", "    p_origem_casa_oracao_id: dados.origemCasaOracaoId,", 1]], "src/modules/atendimento/tiposEntrada.ts": [["  comum_id: string;", "  casa_oracao_id: string;", 1]], "src/modules/auditoria/regras.ts": [["  comum_transferida: \"Transferiu comum de setor\",", "  casa_oracao_transferida: \"Transferiu casa de oração de setor\",\n  comum_transferida: \"Transferiu casa de oração de setor\",", 1], ["  evento_comum_alterada: \"Mudou a comum do evento\",", "  evento_casa_oracao_alterada: \"Mudou a casa de oração do evento\",\n  evento_comum_alterada: \"Mudou a casa de oração do evento\",", 1], ["  comum: \"Comum\",", "  casa_oracao: \"Casa de Oração\",\n  comum: \"Casa de Oração\",", 1], ["  comum_id: \"Comum\",", "  casa_oracao_id: \"Casa de Oração\",\n  comum_id: \"Casa de Oração\",", 1], ["  origem_comum_id: \"Comum de origem\",", "  origem_casa_oracao_id: \"Casa de Oração de origem\",\n  origem_comum_id: \"Casa de Oração de origem\",", 1]], "src/modules/backup/tabelas.test.ts": [["    expect(ordenarParaGravar([\"presencas\", \"membros\", \"comuns\", \"membros\"])).toEqual([\"comuns\", \"membros\", \"presencas\"]);", "    expect(ordenarParaGravar([\"presencas\", \"membros\", \"casas_oracao\", \"membros\"])).toEqual([\"casas_oracao\", \"membros\", \"presencas\"]);", 1], ["    expect(ordenarParaApagar([\"presencas\", \"membros\", \"comuns\"])).toEqual([\"presencas\", \"membros\", \"comuns\"]);", "    expect(ordenarParaApagar([\"presencas\", \"membros\", \"casas_oracao\"])).toEqual([\"presencas\", \"membros\", \"casas_oracao\"]);", 1]], "src/modules/backup/tabelas.ts": [["  | \"comuns\"", "  | \"casas_oracao\"", 1], ["  tabela(\"comuns\", \"Comuns\", \"organizacao\", { referencias: [{ coluna: \"setor_id\", tabela: \"setores\" }] }),", "  tabela(\"casas_oracao\", \"Casas de Oração\", \"organizacao\", { referencias: [{ coluna: \"setor_id\", tabela: \"setores\" }] }),", 1], ["      { coluna: \"comum_id\", tabela: \"comuns\" },", "      { coluna: \"casa_oracao_id\", tabela: \"casas_oracao\" },", 3], ["      { coluna: \"origem_comum_id\", tabela: \"comuns\" },", "      { coluna: \"origem_casa_oracao_id\", tabela: \"casas_oracao\" },", 1], ["    descricao: \"Estados, regiões, setores e comuns\",", "    descricao: \"Estados, regiões, setores e casas de oração\",", 1], ["    tabelas: [\"estados\", \"regioes\", \"setores\", \"comuns\"],", "    tabelas: [\"estados\", \"regioes\", \"setores\", \"casas_oracao\"],", 1]], "src/modules/eventos/camposEvento.test.ts": [["  comumId: \"abc\",", "  casaOracaoId: \"abc\",", 1], ["    expect(camposFaltando({ tipo: \"\", finalidade: \"\", dataEvento: \"\", local: \"\", cidade: \"\", comumId: \"\" })).toEqual([", "    expect(camposFaltando({ tipo: \"\", finalidade: \"\", dataEvento: \"\", local: \"\", cidade: \"\", casaOracaoId: \"\" })).toEqual([", 1], ["      \"Comum\",", "      \"Casa de Oração\",", 1], ["  it(\"a comum escolhida é obrigatória ('Nenhuma' = vazio)\", () => {", "  it(\"a casa de oração escolhida é obrigatória ('Nenhuma' = vazio)\", () => {", 1], ["    expect(camposFaltando({ ...completo, comumId: \"\" })).toEqual([\"Comum\"]);", "    expect(camposFaltando({ ...completo, casaOracaoId: \"\" })).toEqual([\"Casa de Oração\"]);", 1]], "src/modules/eventos/camposEvento.ts": [["  comumId: string;", "  casaOracaoId: string;", 1], ["export const ROTULO_COMUM = \"Comum\";", "export const ROTULO_CASA_ORACAO = \"Casa de Oração\";", 1], ["  if (!campos.comumId.trim()) faltando.push(ROTULO_COMUM);", "  if (!campos.casaOracaoId.trim()) faltando.push(ROTULO_CASA_ORACAO);", 1]], "src/modules/eventos/services/eventos.ts": [["  comum_id?: string | null;", "  casa_oracao_id?: string | null;", 1]], "src/modules/instrumentos/components/SeletorInstrumento.tsx": [[" * demais seletores (Cargo, Comum). Só aparecem os instrumentos cadastrados no banco; instrumento novo", " * demais seletores (Cargo, Casa de Oração). Só aparecem os instrumentos cadastrados no banco; instrumento novo", 1]], "src/modules/membros/services/membros.ts": [["  comum_id?: string | null; // a comum escolhida (o banco ajusta o nome da congregação)", "  casa_oracao_id?: string | null; // a casa de oração escolhida (o banco ajusta o nome da congregação)", 1]], "src/modules/organizacao/components/ArvoreOrganizacao.tsx": [[" * SysMúsica — Árvore da organização: Estado > Região > Setor > Comum, com abrir/fechar e as ações de cada item.", " * SysMúsica — Árvore da organização: Estado > Região > Setor > Casa de Oração, com abrir/fechar e as ações de cada item.", 1], [" * Comuns que ainda não têm setor ficam numa seção própria, no fim, com o botão de transferir.", " * Casas de Oração que ainda não têm setor ficam numa seção própria, no fim, com o botão de transferir.", 1], ["  if (no.nivel === \"SETOR\") return `${n} ${n === 1 ? \"comum\" : \"comuns\"}`;", "  if (no.nivel === \"SETOR\") return `${n} ${n === 1 ? \"casa de oração\" : \"casas de oração\"}`;", 1], ["              {no.nivel === \"COMUM\" && (no.bairro || no.cidade)", "              {no.nivel === \"CASA_ORACAO\" && (no.bairro || no.cidade)", 1], ["            {podeTransferir && no.nivel === \"COMUM\" && (", "            {podeTransferir && no.nivel === \"CASA_ORACAO\" && (", 1], ["  const semSetor = filhosDe(nos, null, \"COMUM\");", "  const semSetor = filhosDe(nos, null, \"CASA_ORACAO\");", 1], ["          <h2 className=\"px-2 pt-1 text-sm font-semibold text-slate-900\">Comuns sem setor ({semSetor.length})</h2>", "          <h2 className=\"px-2 pt-1 text-sm font-semibold text-slate-900\">Casas de Oração sem setor ({semSetor.length})</h2>", 1], ["            Enquanto uma comum estiver sem setor, quem tem acesso restrito não vê nada dela (membros, eventos e", "            Enquanto uma casa de oração estiver sem setor, quem tem acesso restrito não vê nada dela (membros, eventos e", 1], ["          <ul>{semSetor.map((comum) => renderLinha(comum, 0))}</ul>", "          <ul>{semSetor.map((casaOracao) => renderLinha(casaOracao, 0))}</ul>", 1]], "src/modules/organizacao/components/FormularioNo.tsx": [[" * SysMúsica — Formulário de um item da organização (estado, região, setor ou comum), novo ou em edição.", " * SysMúsica — Formulário de um item da organização (estado, região, setor ou casa de oração), novo ou em edição.", 1], [" * comum de setor use a transferência (fica registrada). O banco confere permissão e nomes repetidos.", " * casa de oração de setor use a transferência (fica registrada). O banco confere permissão e nomes repetidos.", 1], ["          placeholder={nivel === \"SETOR\" ? \"Ex: Setor 6\" : nivel === \"COMUM\" ? \"Ex: Central Itinga\" : \"Nome\"}", "          placeholder={nivel === \"SETOR\" ? \"Ex: Setor 6\" : nivel === \"CASA_ORACAO\" ? \"Ex: Central Itinga\" : \"Nome\"}", 1], ["      {nivel !== \"COMUM\" && (", "      {nivel !== \"CASA_ORACAO\" && (", 1], ["      {nivel === \"COMUM\" && (", "      {nivel === \"CASA_ORACAO\" && (", 1]], "src/modules/organizacao/components/FormularioTransferencia.tsx": [[" * SysMúsica — Transferência de uma comum para outro setor (painel lateral).", " * SysMúsica — Transferência de uma casa de oração para outro setor (painel lateral).", 1], [" * Exige a permissão de transferir; fica no histórico da comum e na auditoria. As portarias da comum", " * Exige a permissão de transferir; fica no histórico da casa de oração e na auditoria. As portarias da casa de oração", 1], [" * passam a valer para o setor novo (elas seguem a comum do evento).", " * passam a valer para o setor novo (elas seguem a casa de oração do evento).", 1], ["import { transferirComum } from \"../services/organizacao\";", "import { transferirCasaOracao } from \"../services/organizacao\";", 1], ["  comum: NoOrganizacao;", "  casaOracao: NoOrganizacao;", 1], ["export default function FormularioTransferencia({ comum, nos, onSalvo }: FormularioTransferenciaProps) {", "export default function FormularioTransferencia({ casaOracao, nos, onSalvo }: FormularioTransferenciaProps) {", 1], ["  const setorAtual = comum.parent_id ? nos.find((no) => no.nivel === \"SETOR\" && no.id === comum.parent_id) : undefined;", "  const setorAtual = casaOracao.parent_id ? nos.find((no) => no.nivel === \"SETOR\" && no.id === casaOracao.parent_id) : undefined;", 1], ["      await transferirComum(comum.id, setorId, justificativa);", "      await transferirCasaOracao(casaOracao.id, setorId, justificativa);", 1], ["      await onSalvo(`Comum \"${comum.nome}\" transferida.`);", "      await onSalvo(`Casa de Oração \"${casaOracao.nome}\" transferida.`);", 1], ["      setErro(e instanceof Error ? e.message : \"Não foi possível transferir a comum.\");", "      setErro(e instanceof Error ? e.message : \"Não foi possível transferir a casa de oração.\");", 1], ["        <strong className=\"text-slate-900\">{comum.nome}</strong>", "        <strong className=\"text-slate-900\">{casaOracao.nome}</strong>", 1], ["                <option key={setor.id} value={setor.id} disabled={setor.id === comum.parent_id}>", "                <option key={setor.id} value={setor.id} disabled={setor.id === casaOracao.parent_id}>", 1], ["        {salvando ? \"Transferindo...\" : \"Transferir comum\"}", "        {salvando ? \"Transferindo...\" : \"Transferir casa de oração\"}", 1]], "src/modules/organizacao/components/SeletorComum.tsx": [[" * SysMúsica — Seletor de COMUM (igreja/salão), agrupado por \"Região › Setor\".", " * SysMúsica — Seletor de CASA DE ORAÇÃO (igreja/salão), agrupado por \"Região › Setor\".", 1], [" * Mostra só as comuns que o usuário pode usar (o banco filtra pela abrangência dele; quem tem", " * Mostra só as casas de oração que o usuário pode usar (o banco filtra pela abrangência dele; quem tem", 1], ["import { agruparComunsParaSelecao } from \"../regras\";", "import { agruparCasasOracaoParaSelecao } from \"../regras\";", 1], ["interface SeletorComumProps {", "interface SeletorCasaOracaoProps {", 1], ["  valor: string; // id da comum escolhida (\"\" = nenhuma)", "  valor: string; // id da casa de oração escolhida (\"\" = nenhuma)", 1], ["  onChange: (comumId: string) => void;", "  onChange: (casaOracaoId: string) => void;", 1], ["  /** Opcional: devolve também o nome da comum escolhida (vazio quando nenhuma). */", "  /** Opcional: devolve também o nome da casa de oração escolhida (vazio quando nenhuma). */", 1], ["export default function SeletorComum({", "export default function SeletorCasaOracao({", 1], ["}: SeletorComumProps) {", "}: SeletorCasaOracaoProps) {", 1], ["        setErro(e instanceof Error ? e.message : \"Não foi possível carregar as comuns.\");", "        setErro(e instanceof Error ? e.message : \"Não foi possível carregar as casas de oração.\");", 1], ["  const grupos = useMemo(() => agruparComunsParaSelecao(nos ?? []), [nos]);", "  const grupos = useMemo(() => agruparCasasOracaoParaSelecao(nos ?? []), [nos]);", 1], ["  const existe = grupos.some((grupo) => grupo.comuns.some((comum) => comum.id === valor));", "  const existe = grupos.some((grupo) => grupo.casasOracao.some((casaOracao) => casaOracao.id === valor));", 1], ["          onEscolherNome?.((nos ?? []).find((no) => no.nivel === \"COMUM\" && no.id === novoId)?.nome ?? \"\");", "          onEscolherNome?.((nos ?? []).find((no) => no.nivel === \"CASA_ORACAO\" && no.id === novoId)?.nome ?? \"\");", 1], ["        {/* A comum atual do registro pode estar fora da abrangência de quem edita: continua visível, sem trocar sozinha */}", "        {/* A casa de oração atual do registro pode estar fora da abrangência de quem edita: continua visível, sem trocar sozinha */}", 1], ["        {nos !== null && valor !== \"\" && !existe && <option value={valor}>Comum atual (fora da sua abrangência)</option>}", "        {nos !== null && valor !== \"\" && !existe && <option value={valor}>Casa de Oração atual (fora da sua abrangência)</option>}", 1], ["            {grupo.comuns.map((comum) => (", "            {grupo.casasOracao.map((casaOracao) => (", 1], ["              <option key={comum.id} value={comum.id}>", "              <option key={casaOracao.id} value={casaOracao.id}>", 1], ["                {comum.nome}", "                {casaOracao.nome}", 1]], "src/modules/organizacao/regras.test.ts": [["  agruparComunsParaSelecao,", "  agruparCasasOracaoParaSelecao,", 1], ["// Bahia > Salvador (Setor 1, Setor 2, Setor 10) e Jequié (Setor 1, Setor 9 inativo); duas comuns em", "// Bahia > Salvador (Setor 1, Setor 2, Setor 10) e Jequié (Setor 1, Setor 9 inativo); duas casas de oração em", 1], ["  { nivel: \"COMUM\", id: \"c1\", parent_id: \"s1\", nome: \"Itinga\" },", "  { nivel: \"CASA_ORACAO\", id: \"c1\", parent_id: \"s1\", nome: \"Itinga\" },", 1], ["  { nivel: \"COMUM\", id: \"c2\", parent_id: \"s1\", nome: \"Caique\" },", "  { nivel: \"CASA_ORACAO\", id: \"c2\", parent_id: \"s1\", nome: \"Caique\" },", 1], ["  { nivel: \"COMUM\", id: \"c3\", parent_id: \"s4\", nome: \"Central\" },", "  { nivel: \"CASA_ORACAO\", id: \"c3\", parent_id: \"s4\", nome: \"Central\" },", 1], ["  { nivel: \"COMUM\", id: \"c4\", parent_id: null, nome: \"Solta\" },", "  { nivel: \"CASA_ORACAO\", id: \"c4\", parent_id: null, nome: \"Solta\" },", 1], ["  it(\"devolve as comuns sem setor quando o pai é nulo\", () => {", "  it(\"devolve as casas de oração sem setor quando o pai é nulo\", () => {", 1], ["    expect(filhosDe(nos, null, \"COMUM\").map((n) => n.id)).toEqual([\"c4\"]);", "    expect(filhosDe(nos, null, \"CASA_ORACAO\").map((n) => n.id)).toEqual([\"c4\"]);", 1], ["describe(\"agruparComunsParaSelecao\", () => {", "describe(\"agruparCasasOracaoParaSelecao\", () => {", 1], ["  const grupos = agruparComunsParaSelecao(nos);", "  const grupos = agruparCasasOracaoParaSelecao(nos);", 1], ["  it(\"ordena as comuns de cada grupo pelo nome\", () => {", "  it(\"ordena as casas de oração de cada grupo pelo nome\", () => {", 1], ["    expect(grupos[1].comuns.map((c) => c.nome)).toEqual([\"Caique\", \"Itinga\"]);", "    expect(grupos[1].casasOracao.map((c) => c.nome)).toEqual([\"Caique\", \"Itinga\"]);", 1], ["    expect(motivoBloqueioExclusao({ ...base, nivel: \"SETOR\", id: \"s\", nome: \"Setor 1\", qtd_filhos: 3 })).toMatch(/3 comuns/);", "    expect(motivoBloqueioExclusao({ ...base, nivel: \"SETOR\", id: \"s\", nome: \"Setor 1\", qtd_filhos: 3 })).toMatch(/3 casas de oração/);", 1], ["    expect(motivoBloqueioExclusao({ ...base, nivel: \"COMUM\", id: \"c\", nome: \"Itinga\", qtd_membros: 4 })).toMatch(/4 membros/);", "    expect(motivoBloqueioExclusao({ ...base, nivel: \"CASA_ORACAO\", id: \"c\", nome: \"Itinga\", qtd_membros: 4 })).toMatch(/4 membros/);", 1], ["    expect(motivoBloqueioExclusao({ ...base, nivel: \"COMUM\", id: \"c\", nome: \"Vazia\", qtd_membros: 0 })).toBeNull();", "    expect(motivoBloqueioExclusao({ ...base, nivel: \"CASA_ORACAO\", id: \"c\", nome: \"Vazia\", qtd_membros: 0 })).toBeNull();", 1]], "src/modules/organizacao/regras.ts": [["  COMUM: \"Comum\",", "  CASA_ORACAO: \"Casa de Oração\",", 1], ["  SETOR: \"COMUM\",", "  SETOR: \"CASA_ORACAO\",", 1], ["  COMUM: null,", "  CASA_ORACAO: null,", 1], ["const NIVEIS: NivelOrganizacao[] = [\"ESTADO\", \"REGIAO\", \"SETOR\", \"COMUM\"];", "const NIVEIS: NivelOrganizacao[] = [\"ESTADO\", \"REGIAO\", \"SETOR\", \"CASA_ORACAO\"];", 1], ["    return `\"${no.nome}\" ainda tem ${filhos} ${filhos === 1 ? \"comum\" : \"comuns\"}. Transfira as comuns para outro setor antes.`;", "    return `\"${no.nome}\" ainda tem ${filhos} ${filhos === 1 ? \"casa de oração\" : \"casas de oração\"}. Transfira as casas de oração para outro setor antes.`;", 1], ["  if (no.nivel === \"COMUM\" && membros > 0) {", "  if (no.nivel === \"CASA_ORACAO\" && membros > 0) {", 1], ["    return `\"${no.nome}\" ainda tem ${membros} ${membros === 1 ? \"membro\" : \"membros\"}. Mude os membros para outra comum (ou exclua-os) antes.`;", "    return `\"${no.nome}\" ainda tem ${membros} ${membros === 1 ? \"membro\" : \"membros\"}. Mude os membros para outra casa de oração (ou exclua-os) antes.`;", 1], ["export interface GrupoComuns {", "export interface GrupoCasasOracao {", 1], ["  comuns: NoOrganizacao[];", "  casasOracao: NoOrganizacao[];", 1], ["/** Agrupa as comuns por \"Região › Setor\" (com o estado na frente se houver mais de um). Comuns sem setor vão para o fim. */", "/** Agrupa as casas de oração por \"Região › Setor\" (com o estado na frente se houver mais de um). Casas de Oração sem setor vão para o fim. */", 1], ["export function agruparComunsParaSelecao(nos: NoOrganizacao[]): GrupoComuns[] {", "export function agruparCasasOracaoParaSelecao(nos: NoOrganizacao[]): GrupoCasasOracao[] {", 1], ["  for (const comum of nos.filter((no) => no.nivel === \"COMUM\")) {", "  for (const casaOracao of nos.filter((no) => no.nivel === \"CASA_ORACAO\")) {", 1], ["    const setor = comum.parent_id ? porChave.get(`SETOR:${comum.parent_id}`) : undefined;", "    const setor = casaOracao.parent_id ? porChave.get(`SETOR:${casaOracao.parent_id}`) : undefined;", 1], ["      semSetor.push(comum);", "      semSetor.push(casaOracao);", 1], ["    grupos.set(rotulo, [...(grupos.get(rotulo) ?? []), comum]);", "    grupos.set(rotulo, [...(grupos.get(rotulo) ?? []), casaOracao]);", 1], ["  const lista: GrupoComuns[] = [...grupos.entries()]", "  const lista: GrupoCasasOracao[] = [...grupos.entries()]", 1], ["    .map(([rotulo, comuns]) => ({ rotulo, comuns: [...comuns].sort(porNome) }));", "    .map(([rotulo, casasOracao]) => ({ rotulo, casasOracao: [...casasOracao].sort(porNome) }));", 1], ["  if (semSetor.length > 0) lista.push({ rotulo: \"Sem setor definido\", comuns: [...semSetor].sort(porNome) });", "  if (semSetor.length > 0) lista.push({ rotulo: \"Sem setor definido\", casasOracao: [...semSetor].sort(porNome) });", 1]], "src/modules/organizacao/services/organizacao.ts": [[" * SysMúsica — Serviço de dados da organização (Estado > Região > Setor > Comum) e dos vínculos dos usuários.", " * SysMúsica — Serviço de dados da organização (Estado > Região > Setor > Casa de Oração) e dos vínculos dos usuários.", 1], ["/** Itens ativos que o usuário pode usar (seletor de comum nos formulários). */", "/** Itens ativos que o usuário pode usar (seletor de casa de oração nos formulários). */", 1], ["  if (error) throw new Error(mensagemDoErro(error, \"Não foi possível carregar as comuns.\"));", "  if (error) throw new Error(mensagemDoErro(error, \"Não foi possível carregar as casas de oração.\"));", 1], ["/** Muda uma comum de setor (fica no histórico e na auditoria). */", "/** Muda uma casa de oração de setor (fica no histórico e na auditoria). */", 1], ["export async function transferirComum(comumId: string, setorId: string, justificativa: string): Promise<void> {", "export async function transferirCasaOracao(casaOracaoId: string, setorId: string, justificativa: string): Promise<void> {", 1], ["  const { error } = await supabase.rpc(\"transferir_comum\", {", "  const { error } = await supabase.rpc(\"transferir_casa_oracao\", {", 1], ["    p_comum: comumId,", "    p_casa_oracao: casaOracaoId,", 1], ["  if (error) throw new Error(mensagemDoErro(error, \"Não foi possível transferir a comum.\"));", "  if (error) throw new Error(mensagemDoErro(error, \"Não foi possível transferir a casa de oração.\"));", 1]], "src/modules/organizacao/tipos.ts": [["/** SysMúsica — Tipos da organização (Estado > Região > Setor > Comum). Campos = colunas das funções do banco (0012). */", "/** SysMúsica — Tipos da organização (Estado > Região > Setor > Casa de Oração). Campos = colunas das funções do banco (0012). */", 1], ["export type NivelOrganizacao = \"ESTADO\" | \"REGIAO\" | \"SETOR\" | \"COMUM\";", "export type NivelOrganizacao = \"ESTADO\" | \"REGIAO\" | \"SETOR\" | \"CASA_ORACAO\";", 1], ["  parent_id: string | null; // estado -> nulo; região -> estado; setor -> região; comum -> setor (nulo = sem setor)", "  parent_id: string | null; // estado -> nulo; região -> estado; setor -> região; casa de oração -> setor (nulo = sem setor)", 1], ["  cidade?: string | null; // só comuns", "  cidade?: string | null; // só casas de oração", 1], ["  bairro?: string | null; // só comuns", "  bairro?: string | null; // só casas de oração", 1], ["  qtd_filhos?: number; // regiões do estado, setores da região, comuns do setor", "  qtd_filhos?: number; // regiões do estado, setores da região, casas de oração do setor", 1], ["  qtd_membros?: number; // só comuns", "  qtd_membros?: number; // só casas de oração", 1]], "src/modules/painel/components/PainelAoVivo.tsx": [["                    {[evento.local, evento.comum].filter(Boolean).join(\" · \")}", "                    {[evento.local, evento.casa_oracao].filter(Boolean).join(\" · \")}", 1]], "src/modules/painel/tipos.ts": [["  comum: string | null;", "  casa_oracao: string | null;", 1], ["  comum_nome: string | null;", "  casa_oracao_nome: string | null;", 1]], "src/modules/portarias/components/FormularioNovaPortaria.tsx": [["              {item.cidade ? ` (${item.cidade})` : \" — comum sem setor\"}", "              {item.cidade ? ` (${item.cidade})` : \" — casa de oração sem setor\"}", 1]], "src/modules/portarias/services/portarias.ts": [["  // O banco já devolve só os eventos das comuns da abrangência do usuário (\"cidade\" = Região › Setor)", "  // O banco já devolve só os eventos das casas de oração da abrangência do usuário (\"cidade\" = Região › Setor)", 1]], "src/modules/relatorios/catalogo.ts": [["    filtros: [\"periodo\", \"evento\", \"regiao\", \"setor\", \"comum\", \"statusPresenca\"],", "    filtros: [\"periodo\", \"evento\", \"regiao\", \"setor\", \"casa_oracao\", \"statusPresenca\"],", 1], ["      { id: \"membro_comum\", rotulo: \"Congregação do membro\", padrao: true },", "      { id: \"membro_casa_oracao\", rotulo: \"Congregação do membro\", padrao: true },", 1], ["      { id: \"comum\", rotulo: \"Comum do evento\", padrao: false },", "      { id: \"casa_oracao\", rotulo: \"Casa de Oração do evento\", padrao: false },", 1], ["    descricao: \"Lista de membros com cargo, instrumento, comum, setor e região.\",", "    descricao: \"Lista de membros com cargo, instrumento, casa de oração, setor e região.\",", 1], ["    filtros: [\"regiao\", \"setor\", \"comum\", \"cargo\", \"instrumento\", \"situacaoMembro\", \"visitante\"],", "    filtros: [\"regiao\", \"setor\", \"casa_oracao\", \"cargo\", \"instrumento\", \"situacaoMembro\", \"visitante\"],", 1], ["      { id: \"comum\", rotulo: \"Comum\", padrao: true },", "      { id: \"casa_oracao\", rotulo: \"Casa de Oração\", padrao: true },", 2], ["    descricao: \"Eventos com local, comum, quantidade de presenças e situação da portaria.\",", "    descricao: \"Eventos com local, casa de oração, quantidade de presenças e situação da portaria.\",", 1], ["    filtros: [\"periodo\", \"regiao\", \"setor\", \"comum\"],", "    filtros: [\"periodo\", \"regiao\", \"setor\", \"casa_oracao\"],", 1], ["      { id: \"comum\", rotulo: \"Comum\", padrao: false },", "      { id: \"casa_oracao\", rotulo: \"Casa de Oração\", padrao: false },", 1], ["    titulo: \"Regiões, setores e comuns\",", "    titulo: \"Regiões, setores e casas de oração\",", 1]], "src/modules/relatorios/components/FiltrosDoRelatorio.tsx": [[" * SysMúsica — Filtros do relatório. Mostra só os filtros do tipo escolhido. Região, setor e comum são", " * SysMúsica — Filtros do relatório. Mostra só os filtros do tipo escolhido. Região, setor e casa de oração são", 1], ["import { opcoesComum, opcoesRegiao, opcoesSetor } from \"../regras\";", "import { opcoesCasaOracao, opcoesRegiao, opcoesSetor } from \"../regras\";", 1], ["            onChange={(e) => mudar({ regiaoId: e.target.value, setorId: \"\", comumId: \"\" })}", "            onChange={(e) => mudar({ regiaoId: e.target.value, setorId: \"\", casaOracaoId: \"\" })}", 1], ["            onChange={(e) => mudar({ setorId: e.target.value, comumId: \"\" })}", "            onChange={(e) => mudar({ setorId: e.target.value, casaOracaoId: \"\" })}", 1], ["      {tem(\"comum\") && (", "      {tem(\"casa_oracao\") && (", 1], ["        <Campo id=\"rel-comum\" rotulo=\"Comum\">", "        <Campo id=\"rel-casa-oracao\" rotulo=\"Casa de Oração\">", 1], ["            id=\"rel-comum\"", "            id=\"rel-casa-oracao\"", 1], ["            value={valores.comumId}", "            value={valores.casaOracaoId}", 1], ["            onChange={(e) => mudar({ comumId: e.target.value })}", "            onChange={(e) => mudar({ casaOracaoId: e.target.value })}", 1], ["            <option value=\"\">{valores.setorId ? \"Todas as comuns\" : \"Escolha o setor primeiro\"}</option>", "            <option value=\"\">{valores.setorId ? \"Todas as casas de oração\" : \"Escolha o setor primeiro\"}</option>", 1], ["            {opcoesComum(organizacao, valores.setorId).map((opcao) => (", "            {opcoesCasaOracao(organizacao, valores.setorId).map((opcao) => (", 1]], "src/modules/relatorios/regras.test.ts": [["  opcoesComum,", "  opcoesCasaOracao,", 1], ["// Bahia > Salvador (Setor 1, Setor 2) e Jequié (Setor 1); comuns: Itinga e Caique em Salvador/Setor 1, Central em Jequié/Setor 1, Solta sem setor", "// Bahia > Salvador (Setor 1, Setor 2) e Jequié (Setor 1); casas de oração: Itinga e Caique em Salvador/Setor 1, Central em Jequié/Setor 1, Solta sem setor", 1], ["  { nivel: \"COMUM\", id: \"c1\", parent_id: \"s1\", nome: \"Itinga\", ativo: true, qtd_membros: 7, cidade: \"Lauro de Freitas\" },", "  { nivel: \"CASA_ORACAO\", id: \"c1\", parent_id: \"s1\", nome: \"Itinga\", ativo: true, qtd_membros: 7, cidade: \"Lauro de Freitas\" },", 1], ["  { nivel: \"COMUM\", id: \"c2\", parent_id: \"s1\", nome: \"Caique\", ativo: false, qtd_membros: 2 },", "  { nivel: \"CASA_ORACAO\", id: \"c2\", parent_id: \"s1\", nome: \"Caique\", ativo: false, qtd_membros: 2 },", 1], ["  { nivel: \"COMUM\", id: \"c3\", parent_id: \"s3\", nome: \"Central\", ativo: true, qtd_membros: 4 },", "  { nivel: \"CASA_ORACAO\", id: \"c3\", parent_id: \"s3\", nome: \"Central\", ativo: true, qtd_membros: 4 },", 1], ["  { nivel: \"COMUM\", id: \"c4\", parent_id: null, nome: \"Solta\", ativo: true, qtd_membros: 0 },", "  { nivel: \"CASA_ORACAO\", id: \"c4\", parent_id: null, nome: \"Solta\", ativo: true, qtd_membros: 0 },", 1], ["  it(\"lista regiões, setores da região e comuns do setor\", () => {", "  it(\"lista regiões, setores da região e casas de oração do setor\", () => {", 1], ["    expect(opcoesComum(nos, \"s1\").map((o) => o.rotulo)).toEqual([\"Caique\", \"Itinga\"]);", "    expect(opcoesCasaOracao(nos, \"s1\").map((o) => o.rotulo)).toEqual([\"Caique\", \"Itinga\"]);", 1], ["    expect(opcoesComum(nos, \"\")).toEqual([]);", "    expect(opcoesCasaOracao(nos, \"\")).toEqual([]);", 1], ["  it(\"traz a estrutura inteira, na ordem, com as comuns sem setor no fim\", () => {", "  it(\"traz a estrutura inteira, na ordem, com as casas de oração sem setor no fim\", () => {", 1], ["    expect(linhas.map((l) => `${l.nivel}:${l.comum || l.setor || l.regiao || l.estado}`)).toEqual([", "    expect(linhas.map((l) => `${l.nivel}:${l.casa_oracao || l.setor || l.regiao || l.estado}`)).toEqual([", 1], ["      \"Comum:Central\",", "      \"Casa de Oração:Central\",", 1], ["      \"Comum:Caique\",", "      \"Casa de Oração:Caique\",", 1], ["      \"Comum:Itinga\",", "      \"Casa de Oração:Itinga\",", 1], ["      \"Comum:Solta\",", "      \"Casa de Oração:Solta\",", 1], ["  it(\"preenche situação, membros e cidade da comum\", () => {", "  it(\"preenche situação, membros e cidade da casa de oração\", () => {", 1], ["    const itinga = linhas.find((l) => l.comum === \"Itinga\");", "    const itinga = linhas.find((l) => l.casa_oracao === \"Itinga\");", 1], ["    expect(linhas.find((l) => l.comum === \"Caique\")?.situacao).toBe(\"Inativo\");", "    expect(linhas.find((l) => l.casa_oracao === \"Caique\")?.situacao).toBe(\"Inativo\");", 1], ["    expect(doSetor.map((l) => l.nivel)).toEqual([\"Setor\", \"Comum\"]);", "    expect(doSetor.map((l) => l.nivel)).toEqual([\"Setor\", \"Casa de Oração\"]);", 1], ["    expect(doSetor[1].comum).toBe(\"Central\");", "    expect(doSetor[1].casa_oracao).toBe(\"Central\");", 1]], "src/modules/relatorios/regras.ts": [["  comumId: \"\",", "  casaOracaoId: \"\",", 1], ["  Record<\"evento\" | \"regiao\" | \"setor\" | \"comum\" | \"cargo\" | \"instrumento\", string>", "  Record<\"evento\" | \"regiao\" | \"setor\" | \"casa_oracao\" | \"cargo\" | \"instrumento\", string>", 1], ["    comum: nomeDe(\"COMUM\", filtros.comumId),", "    casa_oracao: nomeDe(\"CASA_ORACAO\", filtros.casaOracaoId),", 1], ["  if (tem(\"comum\") && filtros.comumId && rotulos.comum) partes.push(`Comum: ${rotulos.comum}`);", "  if (tem(\"casa_oracao\") && filtros.casaOracaoId && rotulos.casa_oracao) partes.push(`Casa de Oração: ${rotulos.casa_oracao}`);", 1], ["/** Comuns do setor escolhido (vazio sem setor). */", "/** Casas de Oração do setor escolhido (vazio sem setor). */", 1], ["export function opcoesComum(nos: NoOrganizacao[], setorId: string): OpcaoSelecao[] {", "export function opcoesCasaOracao(nos: NoOrganizacao[], setorId: string): OpcaoSelecao[] {", 1], ["  return setorId ? filhosDe(nos, setorId, \"COMUM\").map((no) => ({ id: no.id, rotulo: no.nome })) : [];", "  return setorId ? filhosDe(nos, setorId, \"CASA_ORACAO\").map((no) => ({ id: no.id, rotulo: no.nome })) : [];", 1], ["  { id: \"localizacao\", rotulo: \"Região, setor e comum\" },", "  { id: \"localizacao\", rotulo: \"Região, setor e casa de oração\" },", 1], ["    const partes = [rotulos.regiao, rotulos.setor, rotulos.comum].filter((parte): parte is string => Boolean(parte));", "    const partes = [rotulos.regiao, rotulos.setor, rotulos.casa_oracao].filter((parte): parte is string => Boolean(parte));", 1], ["/** A estrutura Estado > Região > Setor > Comum em linhas (com os filtros de região e setor). */", "/** A estrutura Estado > Região > Setor > Casa de Oração em linhas (com os filtros de região e setor). */", 1], ["    caminho: { estado?: string; regiao?: string; setor?: string; comum?: string }", "    caminho: { estado?: string; regiao?: string; setor?: string; casa_oracao?: string }", 1], ["    comum: caminho.comum ?? \"\",", "    casa_oracao: caminho.casa_oracao ?? \"\",", 1], ["    membros: no.nivel === \"COMUM\" ? String(no.qtd_membros ?? 0) : \"\",", "    membros: no.nivel === \"CASA_ORACAO\" ? String(no.qtd_membros ?? 0) : \"\",", 1], ["    itens: no.nivel === \"COMUM\" ? \"\" : String(no.qtd_filhos ?? 0),", "    itens: no.nivel === \"CASA_ORACAO\" ? \"\" : String(no.qtd_filhos ?? 0),", 1], ["        for (const comum of filhosDe(nos, setor.id, \"COMUM\")) {", "        for (const casaOracao of filhosDe(nos, setor.id, \"CASA_ORACAO\")) {", 1], ["          linhas.push(montar(comum, { ...caminho, comum: comum.nome }));", "          linhas.push(montar(casaOracao, { ...caminho, casa_oracao: casaOracao.nome }));", 1], ["  // Comuns que ainda não têm setor", "  // Casas de Oração que ainda não têm setor", 1], ["    for (const comum of filhosDe(nos, null, \"COMUM\")) {", "    for (const casaOracao of filhosDe(nos, null, \"CASA_ORACAO\")) {", 1], ["      linhas.push(montar(comum, { comum: comum.nome }));", "      linhas.push(montar(casaOracao, { casa_oracao: casaOracao.nome }));", 1]], "src/modules/relatorios/services/relatorios.ts": [["  comum: string | null;", "  casa_oracao: string | null;", 3], ["  membro_comum: string | null;", "  membro_casa_oracao: string | null;", 1], ["    p_comum: filtros.comumId || null,", "    p_casa_oracao: filtros.casaOracaoId || null,", 3], ["      comum: texto(linha.comum),", "      casa_oracao: texto(linha.casa_oracao),", 3], ["      membro_comum: texto(linha.membro_comum),", "      membro_casa_oracao: texto(linha.membro_casa_oracao),", 1]], "src/modules/relatorios/tipos.ts": [["  | \"comum\"", "  | \"casa_oracao\"", 1], ["  comumId: string;", "  casaOracaoId: string;", 1]], "src/types/database.ts": [["  comum_id?: string | null; // FK -> comuns.id: a comum do membro (define quem enxerga o cadastro)", "  casa_oracao_id?: string | null; // FK -> casas_oracao.id: a casa de oração do membro (define quem enxerga o cadastro)", 1], ["  \"id, nome, congregacao, cargo_id, data_nascimento, instrumento_id, status, data_cadastro, cidade, bairro, atualizado_em, cpf_mascarado, comum_id, foto_path, categoria\" as const;", "  \"id, nome, congregacao, cargo_id, data_nascimento, instrumento_id, status, data_cadastro, cidade, bairro, atualizado_em, cpf_mascarado, casa_oracao_id, foto_path, categoria\" as const;", 1], ["      \"id\" | \"data_nascimento\" | \"instrumento_id\" | \"status\" | \"data_cadastro\" | \"cidade\" | \"bairro\" | \"cpf\" | \"comum_id\" | \"foto_path\" | \"categoria\"", "      \"id\" | \"data_nascimento\" | \"instrumento_id\" | \"status\" | \"data_cadastro\" | \"cidade\" | \"bairro\" | \"cpf\" | \"casa_oracao_id\" | \"foto_path\" | \"categoria\"", 1], ["  cidade?: string | null; // município do evento (informativo; o setor vem da comum)", "  cidade?: string | null; // município do evento (informativo; o setor vem da casa de oração)", 1], ["  comum_id?: string | null; // comum do evento: define o setor da portaria e quem enxerga o evento", "  casa_oracao_id?: string | null; // casa de oração do evento: define o setor da portaria e quem enxerga o evento", 1], ["  Partial<Pick<Evento, \"id\" | \"finalidade_id\" | \"cidade\" | \"comum_id\">>;", "  Partial<Pick<Evento, \"id\" | \"finalidade_id\" | \"cidade\" | \"casa_oracao_id\">>;", 1]]}''')
NOVOS = {
    "supabase/migrations/0031_casa_de_oracao.sql": r"""-- 0031 — Renomeia "Comum" para "Casa de Oração" em todo o banco
-- Tabela comuns -> casas_oracao; coluna comum_id -> casa_oracao_id; nível COMUM -> CASA_ORACAO;
-- funções, gatilhos, políticas, mensagens e descrições de permissões. Roda tudo ou nada.
-- Backups gerados ANTES desta migração não restauram depois dela (os nomes das tabelas mudaram).
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.comuns') is null then
    raise exception 'A tabela comuns não existe (migração já aplicada?). Nada foi alterado.';
  end if;
end $$;

-- 1) Guarda quem pode executar cada função que será recriada
create temp table _acl_fn on commit drop as
select p.proname::text as velho,
       case when a.grantee = 0 then 'public' else a.grantee::regrole::text end as quem
from pg_proc p
cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
where p.pronamespace = 'public'::regnamespace
  and a.privilege_type = 'EXECUTE'
  and p.proname in ('cadastrar_visitante', 'comum_na_abrangencia', 'comum_na_minha_abrangencia', 'comuns_propaga_nome', 'eventos_do_painel', 'eventos_valida_comum', 'listar_eventos_para_portaria', 'membros_sincroniza_comum', 'registrar_entrada_avulsa', 'relatorio_eventos', 'relatorio_membros', 'relatorio_presencas', 'rotulo_setor', 'transferir_comum');

-- 2) Guarda e remove os gatilhos que usam essas funções; remove políticas e funções que mudam
create temp table _trg_fn on commit drop as
select pg_get_triggerdef(t.oid) as def, t.tgname::text as nome, c.relname::text as tabela
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_proc p on p.oid = t.tgfoid
where not t.tgisinternal and p.pronamespace = 'public'::regnamespace
  and p.proname in ('cadastrar_visitante', 'comum_na_abrangencia', 'comum_na_minha_abrangencia', 'comuns_propaga_nome', 'eventos_do_painel', 'eventos_valida_comum', 'listar_eventos_para_portaria', 'membros_sincroniza_comum', 'registrar_entrada_avulsa', 'relatorio_eventos', 'relatorio_membros', 'relatorio_presencas', 'rotulo_setor', 'transferir_comum');
do $$
declare r record;
begin
  for r in select * from _trg_fn loop
    execute format('drop trigger %I on public.%I', r.nome, r.tabela);
  end loop;
end $$;
drop policy if exists regiao_eventos on public.eventos;
drop policy if exists regiao_membros on public.membros;

drop function if exists public.cadastrar_visitante(p_portaria_id uuid, p_nome text, p_cargo_id uuid, p_instrumento_id uuid, p_origem_comum_id uuid, p_membro_id uuid, p_foto_path text);
drop function if exists public.comum_na_abrangencia(p_comum uuid);
drop function if exists public.comum_na_minha_abrangencia(p_comum uuid);
drop function if exists public.comuns_propaga_nome();
drop function if exists public.eventos_do_painel();
drop function if exists public.eventos_valida_comum();
drop function if exists public.listar_eventos_para_portaria();
drop function if exists public.membros_sincroniza_comum();
drop function if exists public.registrar_entrada_avulsa(p_portaria_id uuid, p_linha_codigo text, p_toca boolean, p_instrumento_id uuid, p_origem_comum_id uuid, p_origem_texto text);
drop function if exists public.relatorio_eventos(p_inicio timestamp with time zone, p_fim timestamp with time zone, p_regiao uuid, p_setor uuid, p_comum uuid, p_limite integer);
drop function if exists public.relatorio_membros(p_regiao uuid, p_setor uuid, p_comum uuid, p_cargo uuid, p_instrumento uuid, p_status text, p_visitante text, p_limite integer);
drop function if exists public.relatorio_presencas(p_inicio timestamp with time zone, p_fim timestamp with time zone, p_evento uuid, p_regiao uuid, p_setor uuid, p_comum uuid, p_status text, p_limite integer);
drop function if exists public.rotulo_setor(p_comum uuid);
drop function if exists public.transferir_comum(p_comum uuid, p_setor uuid, p_justificativa text);

-- 3) Tabelas, colunas, restrições e índices
alter table public.comuns rename to casas_oracao;
alter table public.comuns_historico rename to casas_oracao_historico;
alter table public.casas_oracao_historico rename column comum_id to casa_oracao_id;
alter table public.eventos rename column comum_id to casa_oracao_id;
alter table public.membros rename column comum_id to casa_oracao_id;
alter table public.membros rename column origem_comum_id to origem_casa_oracao_id;
alter table public.portarias rename column comum_id to casa_oracao_id;
alter table public.presencas_avulsas rename column origem_comum_id to origem_casa_oracao_id;

alter table public.casas_oracao rename constraint comuns_pkey to casas_oracao_pkey;
alter table public.casas_oracao rename constraint comuns_setor_id_fkey to casas_oracao_setor_id_fkey;
alter table public.casas_oracao_historico rename constraint comuns_historico_pkey to casas_oracao_historico_pkey;
alter table public.eventos rename constraint eventos_comum_id_fkey to eventos_casa_oracao_id_fkey;
alter table public.membros rename constraint membros_comum_id_fkey to membros_casa_oracao_id_fkey;
alter table public.membros rename constraint membros_origem_comum_id_fkey to membros_origem_casa_oracao_id_fkey;
alter table public.portarias rename constraint portarias_comum_id_fkey to portarias_casa_oracao_id_fkey;
alter table public.presencas_avulsas rename constraint presencas_avulsas_origem_comum_id_fkey to presencas_avulsas_origem_casa_oracao_id_fkey;
alter index public.comuns_nome_unico rename to casas_oracao_nome_unico;
alter index public.idx_comuns_setor rename to idx_casas_oracao_setor;
alter index public.idx_eventos_comum rename to idx_eventos_casa_oracao;
alter index public.idx_membros_comum rename to idx_membros_casa_oracao;
alter index public.idx_portarias_comum rename to idx_portarias_casa_oracao;

-- 4) Nível dos vínculos de usuário: COMUM -> CASA_ORACAO
alter table public.usuario_vinculos drop constraint usuario_vinculos_nivel_check;
update public.usuario_vinculos set nivel = 'CASA_ORACAO' where nivel = 'COMUM';
alter table public.usuario_vinculos add constraint usuario_vinculos_nivel_check
  check (nivel = any (array['ESTADO'::text, 'REGIAO'::text, 'SETOR'::text, 'CASA_ORACAO'::text]));

-- 5) Funções com os nomes e mensagens novos

CREATE OR REPLACE FUNCTION public.auditar_tabela()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    when 'regioes' then 'regiao'
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
$function$;

CREATE OR REPLACE FUNCTION public.cadastrar_visitante(p_portaria_id uuid, p_nome text, p_cargo_id uuid, p_instrumento_id uuid, p_origem_casa_oracao_id uuid, p_membro_id uuid, p_foto_path text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- A origem precisa ser uma casa de oração cadastrada, ativa e com setor, região e estado ativos
  select c.nome as casa_oracao, c.cidade as cidade, r.nome as regiao into v_origem
  from public.casas_oracao c
  join public.setores s on s.id = c.setor_id
  join public.regioes r on r.id = s.regiao_id
  join public.estados e on e.id = r.estado_id
  where c.id = p_origem_casa_oracao_id and c.ativo and s.ativo and r.ativo and e.ativo;
  if not found then
    raise exception 'Escolha a igreja de origem na lista (estado, região, setor e casa de oração). Se ela não aparecer, peça a um administrador para cadastrá-la em Organização.';
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
$function$;

CREATE OR REPLACE FUNCTION public.cartao_membro(p_portaria_id uuid, p_membro_id uuid)
 RETURNS TABLE(membro_id uuid, nome text, congregacao text, cargo text, instrumento text, cidade text, bairro text, status text, foto_path text, ja_registrado_em timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select m.id, m.nome, m.congregacao, c.nome, i.nome, m.cidade, m.bairro, m.status, m.foto_path,
         (select min(pr.hora_entrada)
            from public.presencas pr
            join public.portarias po on po.id = p_portaria_id
           where pr.membro_id = m.id
             and pr.excluido_em is null
             and (pr.portaria_id = po.id or pr.evento_id = po.evento_id))
  from public.membros m
  left join public.cargos c on c.id = m.cargo_id
  left join public.instrumentos i on i.id = m.instrumento_id
  where m.id = p_membro_id and m.excluido_em is null
    and public.casa_oracao_na_abrangencia(m.casa_oracao_id)
$function$;

CREATE OR REPLACE FUNCTION public.casa_oracao_na_abrangencia(p_casa_oracao uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.tem_acesso_total_organizacao() or public.casa_oracao_na_minha_abrangencia(p_casa_oracao)
$function$;

CREATE OR REPLACE FUNCTION public.casa_oracao_na_minha_abrangencia(p_casa_oracao uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p_casa_oracao is not null and exists (
    select 1
    from public.casas_oracao c
    join public.setores s on s.id = c.setor_id
    join public.regioes r on r.id = s.regiao_id
    join public.estados e on e.id = r.estado_id
    join public.usuario_vinculos v
      on v.usuario_id = (select auth.uid())
     and ((v.nivel = 'CASA_ORACAO'  and v.alvo_id = c.id)
       or (v.nivel = 'SETOR'  and v.alvo_id = s.id)
       or (v.nivel = 'REGIAO' and v.alvo_id = r.id)
       or (v.nivel = 'ESTADO' and v.alvo_id = e.id))
    where c.id = p_casa_oracao and c.ativo and s.ativo and r.ativo and e.ativo
  )
$function$;

CREATE OR REPLACE FUNCTION public.casas_oracao_propaga_nome()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.nome is distinct from old.nome then
    update public.membros set congregacao = new.nome where casa_oracao_id = new.id;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.contagem_membros_por()
 RETURNS TABLE(tipo text, id uuid, qtd bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('membros.visualizar');

  return query
    select 'INSTRUMENTO'::text, m.instrumento_id, count(*)
      from public.membros m
     where m.excluido_em is null and m.instrumento_id is not null
       and public.casa_oracao_na_abrangencia(m.casa_oracao_id)
     group by m.instrumento_id
    union all
    select 'CARGO'::text, m.cargo_id, count(*)
      from public.membros m
     where m.excluido_em is null and public.casa_oracao_na_abrangencia(m.casa_oracao_id)
     group by m.cargo_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.criar_portaria(p_evento_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid    uuid := (select auth.uid());
  v_dia    date := (now() at time zone 'America/Sao_Paulo')::date;
  v_evento public.eventos;
  v_usadas int;
  v_total  boolean;
  v_setor  uuid;
  v_id     uuid;
begin
  perform public.exigir_permissao('portarias.criar');
  v_total := public.tem_permissao('portarias.controle_total');

  -- Serializa as criações do MESMO usuário no MESMO dia (a 2ª requisição espera e recota)
  perform pg_advisory_xact_lock(hashtextextended('portarias:' || v_uid::text || ':' || v_dia::text, 0));

  select count(*)::int into v_usadas
  from public.portarias p
  where p.criada_por = v_uid and p.dia_criacao = v_dia;   -- inclui rejeitadas e excluídas

  if not v_total and v_usadas >= public.limite_diario_portarias() then
    raise exception 'Você atingiu o limite máximo de % portarias criadas hoje. Novas criações estarão disponíveis no próximo dia.',
      public.limite_diario_portarias();
  end if;

  select * into v_evento from public.eventos e where e.id = p_evento_id and e.excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if v_evento.casa_oracao_id is null then
    raise exception 'Escolha a casa de oração do evento (Eventos > Editar) antes de criar a portaria.';
  end if;

  select c.setor_id into v_setor from public.casas_oracao c where c.id = v_evento.casa_oracao_id;
  if v_setor is null then
    raise exception 'A casa de oração deste evento ainda não tem setor. Peça a um administrador para vinculá-la a um setor (Administração > Organização).';
  end if;
  if not public.casa_oracao_na_abrangencia(v_evento.casa_oracao_id) then
    raise exception 'Este evento está fora da sua abrangência (casa de oração de outro setor).' using errcode = '42501';
  end if;

  if exists (select 1 from public.portarias p
             where p.evento_id = p_evento_id and p.excluido_em is null
               and p.status in ('PENDENTE_APROVACAO', 'APROVADA')) then
    raise exception 'Já existe uma portaria pendente ou aprovada para este evento.';
  end if;

  insert into public.portarias (evento_id, casa_oracao_id, cidade, criada_por, dia_criacao)
  values (p_evento_id, v_evento.casa_oracao_id, public.rotulo_setor(v_evento.casa_oracao_id), v_uid, v_dia)
  returning id into v_id;

  insert into public.portarias_historico (portaria_id, acao, status_novo, usuario_id)
  values (v_id, 'CRIADA', 'PENDENTE_APROVACAO', v_uid);

  perform public.registrar_auditoria('portaria_criada', 'portaria', v_id,
            jsonb_build_object('evento_id', p_evento_id,
                               'acima_do_limite', v_usadas >= public.limite_diario_portarias()));
  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.decidir_portaria(p_id uuid, p_aprovar boolean, p_motivo text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid     uuid := (select auth.uid());
  v_p       public.portarias;
  v_motivo  text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_novo    text;
  v_propria boolean;
  v_fora    boolean;
begin
  perform public.exigir_permissao('portarias.aprovar');

  select * into v_p from public.portarias p where p.id = p_id and p.excluido_em is null for update;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;
  if v_p.status <> 'PENDENTE_APROVACAO' then
    raise exception 'Esta portaria já foi decidida e não pode mais ser alterada.';
  end if;

  v_propria := v_p.criada_por = v_uid;
  v_fora    := not public.casa_oracao_na_minha_abrangencia(v_p.casa_oracao_id);

  if v_propria and not public.tem_permissao('portarias.controle_total') then
    raise exception 'Você não pode aprovar ou rejeitar uma portaria criada por você.' using errcode = '42501';
  end if;
  if v_fora and not public.tem_acesso_total_organizacao() then
    raise exception 'Esta portaria está fora da sua abrangência de atuação (setor).' using errcode = '42501';
  end if;

  if not p_aprovar and (v_motivo is null or char_length(v_motivo) < 5) then
    raise exception 'Informe o motivo da rejeição (mínimo de 5 caracteres).';
  end if;
  if v_motivo is not null and char_length(v_motivo) > 300 then
    raise exception 'O motivo pode ter no máximo 300 caracteres.';
  end if;

  v_novo := case when p_aprovar then 'APROVADA' else 'REJEITADA' end;

  update public.portarias
     set status = v_novo, decidida_por = v_uid, decidida_em = now(),
         motivo_rejeicao = case when p_aprovar then null else v_motivo end,
         decisao_controle_total = (v_propria or v_fora)
   where id = p_id;

  insert into public.portarias_historico (portaria_id, acao, status_anterior, status_novo, usuario_id, motivo)
  values (p_id, v_novo, v_p.status, v_novo, v_uid,
          case when v_propria or v_fora then concat_ws(' · ', 'Decisão por controle total', v_motivo) else v_motivo end);

  perform public.registrar_auditoria('portaria_' || lower(v_novo), 'portaria', p_id,
            jsonb_build_object('status_anterior', v_p.status, 'motivo', v_motivo,
                               'controle_total', (v_propria or v_fora)));
end;
$function$;

CREATE OR REPLACE FUNCTION public.definir_foto_membro(p_membro_id uuid, p_path text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_antigo text;
  v_casa_oracao  uuid;
begin
  perform public.exigir_permissao('membros.foto');
  perform public.validar_foto_membro(p_membro_id, p_path);

  select m.foto_path, m.casa_oracao_id into v_antigo, v_casa_oracao
  from public.membros m where m.id = p_membro_id and m.excluido_em is null for update;
  if not found or not public.casa_oracao_na_abrangencia(v_casa_oracao) then
    raise exception 'Membro não encontrado.';
  end if;

  update public.membros set foto_path = p_path where id = p_membro_id;

  perform public.registrar_auditoria('foto_definida', 'membro', p_membro_id,
            jsonb_build_object('caminho', p_path));
  return v_antigo;
end;
$function$;

CREATE OR REPLACE FUNCTION public.definir_vinculos(p_usuario uuid, p_vinculos jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      when 'REGIAO' then exists (select 1 from public.regioes x where x.id = v_alvo)
      when 'SETOR'  then exists (select 1 from public.setores x where x.id = v_alvo)
      when 'CASA_ORACAO'  then exists (select 1 from public.casas_oracao x where x.id = v_alvo)
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
$function$;

CREATE OR REPLACE FUNCTION public.entradas_avulsas_da_portaria(p_portaria_id uuid)
 RETURNS TABLE(id uuid, linha_rotulo text, bloco text, toca boolean, instrumento text, origem text, hora_entrada timestamp with time zone, total bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_acesso_atendimento(p_portaria_id);
  return query
    select a.id, l.rotulo, l.bloco, a.toca, i.nome,
           coalesce(c.nome, a.origem_texto), a.hora_entrada, count(*) over ()
      from public.presencas_avulsas a
      join public.linhas_painel l on l.codigo = a.linha_codigo
      left join public.instrumentos i on i.id = a.instrumento_id
      left join public.casas_oracao c on c.id = a.origem_casa_oracao_id
     where a.portaria_id = p_portaria_id and a.excluido_em is null
     order by a.hora_entrada desc
     limit 20;
end;
$function$;

CREATE OR REPLACE FUNCTION public.evento_na_abrangencia(p_evento uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.eventos e
    where e.id = p_evento and public.casa_oracao_na_abrangencia(e.casa_oracao_id)
  )
$function$;

CREATE OR REPLACE FUNCTION public.eventos_do_painel()
 RETURNS TABLE(id uuid, tipo text, local_evento text, data_evento timestamp with time zone, cidade text, casa_oracao_nome text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('painel.visualizar');
  return query
    select e.id, e.tipo, e.local, e.data_evento, e.cidade, c.nome
      from public.eventos e
      left join public.casas_oracao c on c.id = e.casa_oracao_id
     where e.excluido_em is null
       and public.evento_na_abrangencia(e.id)
       and e.data_evento between now() - interval '30 days' and now() + interval '30 days'
     order by abs(extract(epoch from (e.data_evento - now())))
     limit 40;
end;
$function$;

CREATE OR REPLACE FUNCTION public.eventos_valida_casa_oracao()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if current_setting('sysmusica.org_excluindo', true) = 'sim' then
    return new;
  end if;

  if (select auth.uid()) is null then
    return new;   -- SQL Editor / rotinas internas: sem restrição
  end if;

  -- Quem tem acesso por região precisa escolher a casa de oração (senão o evento sumiria da própria lista)
  if new.casa_oracao_id is null and not public.tem_acesso_total_organizacao()
     and (tg_op = 'INSERT' or old.casa_oracao_id is not null) then
    raise exception 'Escolha a casa de oração do evento.';
  end if;

  if tg_op = 'INSERT' then
    if new.casa_oracao_id is not null and not public.casa_oracao_na_abrangencia(new.casa_oracao_id) then
      raise exception 'Esta casa de oração está fora da sua abrangência.' using errcode = '42501';
    end if;
  elsif new.casa_oracao_id is distinct from old.casa_oracao_id then
    if (new.casa_oracao_id is not null and not public.casa_oracao_na_abrangencia(new.casa_oracao_id))
       or (old.casa_oracao_id is not null and not public.casa_oracao_na_abrangencia(old.casa_oracao_id)) then
      raise exception 'Você não pode mudar a casa de oração deste evento: ela está fora da sua abrangência.'
        using errcode = '42501';
    end if;
    update public.portarias
       set casa_oracao_id = new.casa_oracao_id, cidade = public.rotulo_setor(new.casa_oracao_id)
     where evento_id = new.id and excluido_em is null;
    perform public.registrar_auditoria('evento_casa_oracao_alterada', 'evento', new.id,
              jsonb_build_object('de', old.casa_oracao_id, 'para', new.casa_oracao_id));
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.excluir_organizacao(p_nivel text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_nome text;
  v_qtd  bigint;
begin
  perform public.exigir_permissao('organizacao.excluir');

  if p_nivel is null or p_nivel not in ('ESTADO', 'REGIAO', 'SETOR', 'CASA_ORACAO') then
    raise exception 'Nível inválido.';
  end if;

  -- Trava o item e lê o nome (para as mensagens e a auditoria)
  if p_nivel = 'ESTADO' then
    select e.nome into v_nome from public.estados e where e.id = p_id for update;
  elsif p_nivel = 'REGIAO' then
    select r.nome into v_nome from public.regioes r where r.id = p_id for update;
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
    select count(*) into v_qtd from public.regioes x where x.estado_id = p_id;
    if v_qtd > 0 then
      raise exception 'O estado "%" ainda tem % região(ões). Exclua as regiões antes.', v_nome, v_qtd;
    end if;
    delete from public.estados where id = p_id;

  elsif p_nivel = 'REGIAO' then
    select count(*) into v_qtd from public.setores x where x.regiao_id = p_id;
    if v_qtd > 0 then
      raise exception 'A região "%" ainda tem % setor(es). Exclua os setores antes.', v_nome, v_qtd;
    end if;
    delete from public.regioes where id = p_id;

  elsif p_nivel = 'SETOR' then
    select count(*) into v_qtd from public.casas_oracao x where x.setor_id = p_id;
    if v_qtd > 0 then
      raise exception 'O setor "%" ainda tem % casa(s) de oração. Transfira as casas de oração para outro setor antes de excluir.', v_nome, v_qtd;
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
$function$;

CREATE OR REPLACE FUNCTION public.exigir_acesso_atendimento(p_portaria_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_p    public.portarias;
  v_data timestamptz;
begin
  perform public.exigir_permissao('portaria.registrar');
  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found or v_p.status <> 'APROVADA' or not public.casa_oracao_na_abrangencia(v_p.casa_oracao_id) then
    raise exception 'Portaria indisponível para você.' using errcode = '42501';
  end if;
  select e.data_evento into v_data from public.eventos e where e.id = v_p.evento_id;
  if public.portaria_encerrada(v_data) then
    raise exception 'Esta portaria foi encerrada e não aceita mais nada. Só o Administrador pode corrigir registros.'
      using errcode = '42501';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.exigir_acesso_portaria_sem_prazo(p_portaria_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_p public.portarias;
begin
  perform public.exigir_permissao('portaria.registrar');
  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found or v_p.status <> 'APROVADA' or not public.casa_oracao_na_abrangencia(v_p.casa_oracao_id) then
    raise exception 'Portaria indisponível para você.' using errcode = '42501';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_eventos_para_portaria()
 RETURNS TABLE(id uuid, tipo text, data_evento timestamp with time zone, local text, cidade text, casa_oracao_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('portarias.criar');
  return query
    select e.id, e.tipo, e.data_evento, e.local,
           case when c.setor_id is not null then public.rotulo_setor(e.casa_oracao_id) end,
           e.casa_oracao_id
    from public.eventos e
    join public.casas_oracao c on c.id = e.casa_oracao_id
    where e.excluido_em is null
      and public.casa_oracao_na_abrangencia(e.casa_oracao_id)
    order by e.data_evento desc
    limit 300;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_membros_para_foto()
 RETURNS TABLE(id uuid, nome text, congregacao text, foto_path text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('membros.foto');
  return query
    select m.id, m.nome, m.congregacao, m.foto_path
    from public.membros m
    where m.excluido_em is null and public.casa_oracao_na_abrangencia(m.casa_oracao_id)
    order by m.nome;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_organizacao()
 RETURNS TABLE(nivel text, id uuid, parent_id uuid, nome text, descricao text, ativo boolean, cidade text, bairro text, qtd_filhos bigint, qtd_membros bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_alguma_permissao(array['organizacao.visualizar', 'usuarios.vinculos', 'usuarios.editar']);
  return query
    select 'ESTADO'::text, e.id, null::uuid, e.nome, null::text, e.ativo, null::text, null::text,
           (select count(*) from public.regioes r where r.estado_id = e.id), 0::bigint
    from public.estados e
    union all
    select 'REGIAO'::text, r.id, r.estado_id, r.nome, r.descricao, r.ativo, null::text, null::text,
           (select count(*) from public.setores s where s.regiao_id = r.id), 0::bigint
    from public.regioes r
    union all
    select 'SETOR'::text, s.id, s.regiao_id, s.nome, s.descricao, s.ativo, null::text, null::text,
           (select count(*) from public.casas_oracao c where c.setor_id = s.id), 0::bigint
    from public.setores s
    union all
    select 'CASA_ORACAO'::text, c.id, c.setor_id, c.nome, null::text, c.ativo, c.cidade, c.bairro, 0::bigint,
           (select count(*) from public.membros m where m.casa_oracao_id = c.id and m.excluido_em is null)
    from public.casas_oracao c;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_organizacao_para_selecao()
 RETURNS TABLE(nivel text, id uuid, parent_id uuid, nome text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_total boolean;
begin
  if not public.tem_acesso() then
    raise exception 'Sem acesso.' using errcode = '42501';
  end if;
  v_total := public.tem_acesso_total_organizacao();

  return query
    with ok as (
      select c.id as casa_oracao_id, c.nome as casa_oracao_nome, c.setor_id as setor_id
      from public.casas_oracao c
      where c.ativo and (v_total or public.casa_oracao_na_minha_abrangencia(c.id))
    ),
    sset as (
      select s.id as setor_id, s.regiao_id as regiao_id, s.nome as setor_nome
      from public.setores s
      where s.ativo and (v_total or s.id in (select ok.setor_id from ok))
    ),
    rset as (
      select r.id as regiao_id, r.estado_id as estado_id, r.nome as regiao_nome
      from public.regioes r
      where r.ativo and (v_total or r.id in (select sset.regiao_id from sset))
    ),
    eset as (
      select e.id as estado_id, e.nome as estado_nome
      from public.estados e
      where e.ativo and (v_total or e.id in (select rset.estado_id from rset))
    )
    select 'ESTADO'::text, eset.estado_id, null::uuid, eset.estado_nome from eset
    union all
    select 'REGIAO'::text, rset.regiao_id, rset.estado_id, rset.regiao_nome from rset
    union all
    select 'SETOR'::text, sset.setor_id, sset.regiao_id, sset.setor_nome from sset
    union all
    select 'CASA_ORACAO'::text, ok.casa_oracao_id, ok.setor_id, ok.casa_oracao_nome from ok;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_origens_visitante()
 RETURNS TABLE(nivel text, id uuid, parent_id uuid, nome text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('portaria.cadastrar_visitante');
  return query
    select 'ESTADO'::text, e.id, null::uuid, e.nome
      from public.estados e where e.ativo
    union all
    select 'REGIAO'::text, r.id, r.estado_id, r.nome
      from public.regioes r join public.estados e on e.id = r.estado_id
     where r.ativo and e.ativo
    union all
    select 'SETOR'::text, s.id, s.regiao_id, s.nome
      from public.setores s
      join public.regioes r on r.id = s.regiao_id
      join public.estados e on e.id = r.estado_id
     where s.ativo and r.ativo and e.ativo
    union all
    select 'CASA_ORACAO'::text, c.id, c.setor_id, c.nome
      from public.casas_oracao c
      join public.setores s on s.id = c.setor_id
      join public.regioes r on r.id = s.regiao_id
      join public.estados e on e.id = r.estado_id
     where c.ativo and s.ativo and r.ativo and e.ativo;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_portarias()
 RETURNS TABLE(id uuid, evento_id uuid, status text, cidade text, criada_em timestamp with time zone, criada_por uuid, criador_nome text, decidida_em timestamp with time zone, decisor_nome text, motivo_rejeicao text, evento_tipo text, evento_data timestamp with time zone, evento_local text, evento_finalidade text, pode_decidir boolean, pode_excluir boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid    uuid := (select auth.uid());
  v_aprova boolean;
  v_exclui boolean;
  v_ctotal boolean;
begin
  perform public.exigir_alguma_permissao(array[
    'portarias.visualizar', 'portarias.criar', 'portarias.aprovar', 'portaria.registrar'
  ]);
  v_aprova := public.tem_permissao('portarias.aprovar');
  v_exclui := public.tem_permissao('portarias.excluir');
  v_ctotal := public.tem_permissao('portarias.controle_total');

  return query
    select p.id, p.evento_id, p.status, coalesce(public.rotulo_setor(p.casa_oracao_id), p.cidade),
           p.criada_em, p.criada_por, cr.nome,
           p.decidida_em, de.nome, p.motivo_rejeicao,
           ev.tipo, ev.data_evento, ev.local, fi.nome,
           (v_aprova and p.status = 'PENDENTE_APROVACAO'
              and (p.criada_por <> v_uid or v_ctotal)
              and public.casa_oracao_na_abrangencia(p.casa_oracao_id)),
           ((v_exclui or (p.criada_por = v_uid and p.status = 'PENDENTE_APROVACAO'))
              and not exists (select 1 from public.presencas pr
                              where pr.portaria_id = p.id and pr.excluido_em is null))
    from public.portarias p
    left join public.usuarios cr on cr.id = p.criada_por
    left join public.usuarios de on de.id = p.decidida_por
    left join public.eventos ev on ev.id = p.evento_id
    left join public.finalidades_evento fi on fi.id = ev.finalidade_id
    where public.pode_ver_portaria(p.id)
    order by p.criada_em desc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.membros_sincroniza_casa_oracao()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id  uuid;
  v_qtd int;
begin
  if current_setting('sysmusica.org_excluindo', true) = 'sim' then
    return new;
  end if;

  if new.casa_oracao_id is not null and (tg_op = 'INSERT' or new.casa_oracao_id is distinct from old.casa_oracao_id) then
    select c.nome into new.congregacao from public.casas_oracao c where c.id = new.casa_oracao_id;
    if not found then
      raise exception 'Casa de Oração não encontrada.';
    end if;
  elsif tg_op = 'INSERT' or new.congregacao is distinct from old.congregacao then
    select (array_agg(c.id))[1], count(*) into v_id, v_qtd
    from public.casas_oracao c
    where public.normalizar_texto(c.nome) = public.normalizar_texto(btrim(coalesce(new.congregacao, '')));
    new.casa_oracao_id := case when v_qtd = 1 then v_id else null end;
  end if;

  -- Quem tem acesso por região precisa ligar o membro a uma casa de oração (senão ele sumiria da própria lista)
  if new.casa_oracao_id is null and (select auth.uid()) is not null and not public.tem_acesso_total_organizacao() then
    raise exception 'Não encontrei a casa de oração "%". Use o nome exato de uma casa de oração cadastrada em Administração > Organização.',
      coalesce(new.congregacao, '');
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.painel_ao_vivo(p_evento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_evento jsonb;
  v_dados  jsonb;
begin
  perform public.exigir_permissao('painel.visualizar');
  if not public.evento_na_abrangencia(p_evento_id) then
    raise exception 'Evento indisponível para você.' using errcode = '42501';
  end if;

  select jsonb_build_object('id', e.id, 'tipo', e.tipo, 'local', e.local, 'data_evento', e.data_evento,
                            'cidade', e.cidade, 'casa_oracao', c.nome)
    into v_evento
    from public.eventos e
    left join public.casas_oracao c on c.id = e.casa_oracao_id
   where e.id = p_evento_id and e.excluido_em is null;
  if v_evento is null then
    raise exception 'Evento não encontrado.';
  end if;

  with base as (
    -- presenças de membros cadastrados
    select pr.toca, pr.linha_codigo, m.categoria, cg.nome as cargo,
           coalesce(pr.instrumento_id, m.instrumento_id) as instrumento_efetivo
      from public.presencas pr
      join public.membros m on m.id = pr.membro_id
      left join public.cargos cg on cg.id = m.cargo_id
     where pr.evento_id = p_evento_id and pr.excluido_em is null and pr.status = 'Presente'
    union all
    -- entradas SEM cadastro (a linha e o instrumento já vêm escolhidos na Portaria)
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
  ), por_familia as (
    select coalesce(f.nome, 'Sem família') as familia, count(*) as qtd
      from calc c
      join public.linhas_painel l on l.codigo = c.linha
      left join public.familias f on f.id = c.familia_id
     where c.instrumento_efetivo is not null
       and not public.instrumento_e_orgao(c.instrumento_nome)
       and (c.toca is true or (c.toca is null and l.toca_sempre))
     group by 1
  )
  select jsonb_build_object(
           'total', (select count(*) from calc),
           'linhas', coalesce((select jsonb_agg(jsonb_build_object('codigo', p.codigo, 'bloco', p.bloco,
                                    'rotulo', p.rotulo, 'ordem', p.ordem, 'qtd', p.qtd, 'selecionavel', p.selecionavel)
                                    order by p.ordem)
                                 from por_linha p where p.selecionavel or p.qtd > 0), '[]'::jsonb),
           'instrumentos', coalesce((select jsonb_agg(jsonb_build_object('familia', f.familia, 'qtd', f.qtd)
                                    order by f.familia) from por_familia f), '[]'::jsonb))
    into v_dados;

  return v_dados || jsonb_build_object('evento', v_evento, 'atualizado_em', now());
end;
$function$;

CREATE OR REPLACE FUNCTION public.pode_ver_portaria(p_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.portarias p
    where p.id = p_id and p.excluido_em is null
      and (
        p.criada_por = (select auth.uid())
        or public.tem_permissao('portarias.visualizar')
        or (public.tem_permissao('portarias.aprovar') and public.casa_oracao_na_abrangencia(p.casa_oracao_id))
        or (public.tem_permissao('portaria.registrar') and p.status = 'APROVADA'
            and public.casa_oracao_na_abrangencia(p.casa_oracao_id))
      )
  )
$function$;

CREATE OR REPLACE FUNCTION public.registrar_entrada_avulsa(p_portaria_id uuid, p_linha_codigo text, p_toca boolean DEFAULT NULL::boolean, p_instrumento_id uuid DEFAULT NULL::uuid, p_origem_casa_oracao_id uuid DEFAULT NULL::uuid, p_origem_texto text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_p     public.portarias;
  v_data  timestamptz;
  l       public.linhas_painel;
  v_toca  boolean;
  v_inst  uuid;
  v_texto text := nullif(btrim(regexp_replace(coalesce(p_origem_texto, ''), '\s+', ' ', 'g')), '');
  v_id    uuid;
begin
  perform public.exigir_acesso_atendimento(p_portaria_id);   -- permissão, portaria aprovada e abrangência
  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;

  -- Janela da portaria (a mesma regra da entrada de membros)
  select e.data_evento into v_data from public.eventos e where e.id = v_p.evento_id and e.excluido_em is null;
  if v_data is null then
    raise exception 'O evento desta portaria não foi encontrado.';
  end if;
  if not public.portaria_janela_aberta(v_data) then
    if public.tem_permissao('portarias.controle_total') then
      perform public.registrar_auditoria('presenca_fora_da_janela', 'portaria', p_portaria_id,
        jsonb_build_object('evento_id', v_p.evento_id, 'inicio_do_evento', v_data, 'registrado_em', now(),
          'sem_cadastro', true,
          'situacao', case when now() < v_data then 'antes da abertura' else 'depois do encerramento' end));
    else
      raise exception 'Fora do horário da portaria. Ela abre em % e encerra em % (2 horas antes e 3 horas depois do início do evento, horário de Salvador).',
        to_char((v_data - interval '2 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI'),
        to_char((v_data + interval '3 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI');
    end if;
  end if;

  select * into l from public.linhas_painel x where x.codigo = p_linha_codigo and x.selecionavel;
  if not found then
    raise exception 'Escolha o cargo ou a categoria da pessoa.';
  end if;

  if l.pergunta_toca then
    if p_toca is null then
      raise exception 'Informe se a pessoa vai tocar.';
    end if;
    v_toca := p_toca;
  elsif l.toca_sempre then
    v_toca := true;
  else
    v_toca := null;
  end if;

  if l.instrumento = 'LIVRE' and v_toca is true then
    if p_instrumento_id is null then
      raise exception 'Informe o instrumento que a pessoa vai tocar.';
    end if;
    if not exists (select 1 from public.instrumentos i where i.id = p_instrumento_id) then
      raise exception 'Instrumento inválido.';
    end if;
    if public.instrumento_e_orgao((select i.nome from public.instrumentos i where i.id = p_instrumento_id)) then
      raise exception 'O órgão é contado em Organistas: escolha a categoria de organista.';
    end if;
    v_inst := p_instrumento_id;
  else
    v_inst := null;
  end if;

  -- Localidade de origem (opcional): uma casa de oração da lista OU um texto livre
  if p_origem_casa_oracao_id is not null then
    if not exists (select 1 from public.casas_oracao c where c.id = p_origem_casa_oracao_id and c.ativo) then
      raise exception 'Localidade de origem inválida.';
    end if;
    v_texto := null;
  elsif v_texto is not null and (char_length(v_texto) < 2 or char_length(v_texto) > 120) then
    raise exception 'A localidade deve ter de 2 a 120 caracteres.';
  end if;

  insert into public.presencas_avulsas
    (portaria_id, evento_id, linha_codigo, toca, instrumento_id, origem_casa_oracao_id, origem_texto, registrado_por)
  values (p_portaria_id, v_p.evento_id, l.codigo, v_toca, v_inst, p_origem_casa_oracao_id, v_texto, (select auth.uid()))
  returning id into v_id;

  perform public.registrar_auditoria('entrada_avulsa_registrada', 'portaria', p_portaria_id,
    jsonb_build_object('linha', l.rotulo, 'toca', v_toca, 'localidade',
      coalesce((select c.nome from public.casas_oracao c where c.id = p_origem_casa_oracao_id), v_texto)));
  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.relatorio_eventos(p_inicio timestamp with time zone, p_fim timestamp with time zone, p_regiao uuid, p_setor uuid, p_casa_oracao uuid, p_limite integer)
 RETURNS TABLE(tipo text, data_evento timestamp with time zone, local_evento text, finalidade text, cidade text, regiao text, setor text, casa_oracao text, registros bigint, presentes bigint, portaria text, total bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    left join public.regioes r on r.id = s.regiao_id
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
$function$;

CREATE OR REPLACE FUNCTION public.relatorio_membros(p_regiao uuid, p_setor uuid, p_casa_oracao uuid, p_cargo uuid, p_instrumento uuid, p_status text, p_visitante text, p_limite integer)
 RETURNS TABLE(nome text, cargo text, instrumento text, familia text, regiao text, setor text, casa_oracao text, cidade text, bairro text, status text, visitante boolean, data_nascimento date, cadastrado_em timestamp with time zone, cpf_parcial text, total bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    left join public.regioes r on r.id = s.regiao_id
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
$function$;

CREATE OR REPLACE FUNCTION public.relatorio_presencas(p_inicio timestamp with time zone, p_fim timestamp with time zone, p_evento uuid, p_regiao uuid, p_setor uuid, p_casa_oracao uuid, p_status text, p_limite integer)
 RETURNS TABLE(evento_tipo text, evento_data timestamp with time zone, evento_local text, evento_finalidade text, regiao text, setor text, casa_oracao text, membro_nome text, membro_casa_oracao text, cargo text, instrumento text, familia text, cidade text, bairro text, visitante boolean, status text, hora_entrada timestamp with time zone, hora_saida timestamp with time zone, origem text, registrado_por text, total bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    left join public.regioes r on r.id = s.regiao_id
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
$function$;

CREATE OR REPLACE FUNCTION public.remover_foto_membro(p_membro_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_antigo text;
  v_casa_oracao  uuid;
begin
  perform public.exigir_permissao('membros.foto');

  select m.foto_path, m.casa_oracao_id into v_antigo, v_casa_oracao
  from public.membros m where m.id = p_membro_id and m.excluido_em is null for update;
  if not found or not public.casa_oracao_na_abrangencia(v_casa_oracao) then
    raise exception 'Membro não encontrado.';
  end if;

  update public.membros set foto_path = null where id = p_membro_id;

  perform public.registrar_auditoria('foto_removida', 'membro', p_membro_id, '{}'::jsonb);
  return v_antigo;
end;
$function$;

CREATE OR REPLACE FUNCTION public.rotulo_setor(p_casa_oracao uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select r.nome || ' › ' || s.nome
  from public.casas_oracao c
  join public.setores s on s.id = c.setor_id
  join public.regioes r on r.id = s.regiao_id
  where c.id = p_casa_oracao
$function$;

CREATE OR REPLACE FUNCTION public.rotulo_vinculo(p_nivel text, p_alvo uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case p_nivel
    when 'ESTADO' then (select e.nome from public.estados e where e.id = p_alvo)
    when 'REGIAO' then (select e.nome || ' › ' || r.nome
                          from public.regioes r join public.estados e on e.id = r.estado_id where r.id = p_alvo)
    when 'SETOR'  then (select r.nome || ' › ' || s.nome
                          from public.setores s join public.regioes r on r.id = s.regiao_id where s.id = p_alvo)
    when 'CASA_ORACAO'  then (select coalesce(r.nome || ' › ' || s.nome || ' › ', '') || c.nome
                          from public.casas_oracao c
                          left join public.setores s on s.id = c.setor_id
                          left join public.regioes r on r.id = s.regiao_id
                         where c.id = p_alvo)
  end
$function$;

CREATE OR REPLACE FUNCTION public.salvar_organizacao(p_nivel text, p_id uuid, p_parent uuid, p_nome text, p_descricao text, p_ativo boolean, p_cidade text, p_bairro text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_novo   boolean := p_id is null;
  v_nome   text    := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  v_desc   text    := nullif(btrim(coalesce(p_descricao, '')), '');
  v_cidade text    := nullif(btrim(coalesce(p_cidade, '')), '');
  v_bairro text    := nullif(btrim(coalesce(p_bairro, '')), '');
  v_id     uuid;
  v_pai    uuid;
begin
  if p_nivel is null or p_nivel not in ('ESTADO', 'REGIAO', 'SETOR', 'CASA_ORACAO') then
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

  elsif p_nivel = 'REGIAO' then
    v_pai := case when v_novo then p_parent else (select x.estado_id from public.regioes x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.estados e where e.id = v_pai) then
      raise exception 'Escolha o estado da região.';
    end if;
    if exists (select 1 from public.regioes x
                where x.estado_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma região com este nome neste estado.';
    end if;
    if v_novo then
      insert into public.regioes (estado_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.regioes set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  elsif p_nivel = 'SETOR' then
    v_pai := case when v_novo then p_parent else (select x.regiao_id from public.setores x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.regioes r where r.id = v_pai) then
      raise exception 'Escolha a região do setor.';
    end if;
    if exists (select 1 from public.setores x
                where x.regiao_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe um setor com este nome nesta região.';
    end if;
    if v_novo then
      insert into public.setores (regiao_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.setores set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  else  -- CASA_ORACAO
    v_pai := case when v_novo then p_parent else (select x.setor_id from public.casas_oracao x where x.id = p_id) end;
    if v_novo and (v_pai is null or not exists (select 1 from public.setores s where s.id = v_pai)) then
      raise exception 'Escolha o setor da casa de oração.';
    end if;
    if exists (select 1 from public.casas_oracao x
                where x.setor_id is not distinct from v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma casa de oração com este nome neste setor.';
    end if;
    if v_novo then
      insert into public.casas_oracao (setor_id, nome, cidade, bairro) values (v_pai, v_nome, v_cidade, v_bairro)
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
$function$;

CREATE OR REPLACE FUNCTION public.transferir_casa_oracao(p_casa_oracao uuid, p_setor uuid, p_justificativa text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_c    public.casas_oracao;
  v_just text := nullif(btrim(coalesce(p_justificativa, '')), '');
begin
  perform public.exigir_permissao('organizacao.transferir');

  select * into v_c from public.casas_oracao c where c.id = p_casa_oracao for update;
  if not found then
    raise exception 'Casa de Oração não encontrada.';
  end if;
  if not exists (select 1 from public.setores s where s.id = p_setor and s.ativo) then
    raise exception 'Escolha um setor ativo de destino.';
  end if;
  if v_c.setor_id is not distinct from p_setor then
    raise exception 'A casa de oração já pertence a este setor.';
  end if;
  if v_just is not null and char_length(v_just) > 300 then
    raise exception 'A justificativa pode ter no máximo 300 caracteres.';
  end if;
  if exists (select 1 from public.casas_oracao x
              where x.setor_id = p_setor and x.id <> p_casa_oracao
                and public.normalizar_texto(x.nome) = public.normalizar_texto(v_c.nome)) then
    raise exception 'O setor de destino já tem uma casa de oração com este nome.';
  end if;

  update public.casas_oracao set setor_id = p_setor where id = p_casa_oracao;
  -- As portarias seguem a casa de oração do evento: só o rótulo precisa ser atualizado
  update public.portarias p set cidade = public.rotulo_setor(p.casa_oracao_id)
   where p.casa_oracao_id = p_casa_oracao and p.excluido_em is null;

  insert into public.casas_oracao_historico (casa_oracao_id, setor_anterior, setor_novo, usuario_id, justificativa)
  values (p_casa_oracao, v_c.setor_id, p_setor, (select auth.uid()), v_just);

  perform public.registrar_auditoria('casa_oracao_transferida', 'casa_oracao', p_casa_oracao,
            jsonb_build_object('setor_anterior', v_c.setor_id, 'setor_novo', p_setor, 'justificativa', v_just));
end;
$function$;

CREATE OR REPLACE FUNCTION public.validar_registro_presenca(p_portaria_id uuid, p_evento_id uuid, p_membro_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_p         public.portarias;
  v_m         record;
  v_existente record;
  v_data      timestamptz;
begin
  perform public.exigir_permissao('portaria.registrar');

  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;
  if v_p.status <> 'APROVADA' then
    raise exception 'Esta portaria não está aprovada (situação: %). Só portarias aprovadas registram presenças.',
      case v_p.status when 'PENDENTE_APROVACAO' then 'pendente de aprovação'
                      when 'REJEITADA' then 'rejeitada' else v_p.status end;
  end if;
  if v_p.evento_id <> p_evento_id then
    raise exception 'A portaria não corresponde ao evento informado.';
  end if;
  if not public.casa_oracao_na_abrangencia(v_p.casa_oracao_id) then
    raise exception 'Você não tem acesso a esta portaria (fora da sua abrangência).' using errcode = '42501';
  end if;

  -- JANELA: de 2 horas antes a 3 horas depois do início do evento (horário de Salvador); depois disso, encerrada
  select e.data_evento into v_data from public.eventos e where e.id = v_p.evento_id;
  if v_data is null then
    raise exception 'O evento desta portaria não foi encontrado.';
  end if;
  -- Portaria ENCERRADA (passou de 3 horas depois do início): ninguém registra, nem o Administrador.
  -- O Administrador só corrige registros já existentes (editar/excluir), nunca cria entrada nova por aqui.
  if public.portaria_encerrada(v_data) then
    raise exception 'Esta portaria foi encerrada em % e não aceita mais entradas. Só o Administrador pode corrigir registros.',
      to_char((v_data + interval '3 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI');
  end if;
  -- Antes da abertura: só o controle total (Administrador), com registro na Auditoria
  if not public.portaria_janela_aberta(v_data) then
    if public.tem_permissao('portarias.controle_total') then
      -- Administrador: permitido, mas fica registrado na Auditoria
      perform public.registrar_auditoria('presenca_fora_da_janela', 'portaria', p_portaria_id,
        jsonb_build_object(
          'evento_id', p_evento_id,
          'membro_id', p_membro_id,
          'inicio_do_evento', v_data,
          'registrado_em', now(),
          'situacao', case when now() < v_data then 'antes da abertura' else 'depois do encerramento' end));
    else
      raise exception 'Fora do horário da portaria. Ela abre em % e encerra em % (2 horas antes e 3 horas depois do início do evento, horário de Salvador).',
        to_char((v_data - interval '2 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI'),
        to_char((v_data + interval '3 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI');
    end if;
  end if;

  select m.status, m.excluido_em into v_m from public.membros m where m.id = p_membro_id;
  if not found then
    raise exception 'Cadastro do membro não encontrado.';
  end if;
  if v_m.excluido_em is not null then
    raise exception 'Cadastro do membro não encontrado.';
  end if;
  if v_m.status <> 'Ativo' then
    raise exception 'O cadastro do membro está inativo.';
  end if;

  -- Duplicidade por EVENTO (inclui registros antigos, sem portaria)
  select pr.hora_entrada, pr.status, pr.portaria_id into v_existente
  from public.presencas pr
  where pr.membro_id = p_membro_id
    and pr.evento_id = p_evento_id
    and pr.excluido_em is null
    and (pr.hora_saida is null or pr.portaria_id = p_portaria_id)
  order by pr.hora_entrada
  limit 1;
  if found then
    raise exception 'Este músico já possui uma entrada registrada neste evento às % (situação: %)%.',
      to_char(v_existente.hora_entrada at time zone 'America/Sao_Paulo', 'HH24"h"MI'),
      v_existente.status,
      case when v_existente.portaria_id is null then ', registro antigo feito antes das portarias' else '' end;
  end if;
end;
$function$;


-- 6) Devolve a permissão de execução das funções recriadas
do $$
declare r record; q record; v_oid regprocedure;
begin
  for r in select * from (values ('cadastrar_visitante','cadastrar_visitante'), ('comum_na_abrangencia','casa_oracao_na_abrangencia'), ('comum_na_minha_abrangencia','casa_oracao_na_minha_abrangencia'), ('comuns_propaga_nome','casas_oracao_propaga_nome'), ('eventos_do_painel','eventos_do_painel'), ('eventos_valida_comum','eventos_valida_casa_oracao'), ('listar_eventos_para_portaria','listar_eventos_para_portaria'), ('membros_sincroniza_comum','membros_sincroniza_casa_oracao'), ('registrar_entrada_avulsa','registrar_entrada_avulsa'), ('relatorio_eventos','relatorio_eventos'), ('relatorio_membros','relatorio_membros'), ('relatorio_presencas','relatorio_presencas'), ('rotulo_setor','rotulo_setor'), ('transferir_comum','transferir_casa_oracao')) as t(velho, novo) loop
    for v_oid in select p.oid::regprocedure from pg_proc p
                 where p.pronamespace = 'public'::regnamespace and p.proname = r.novo loop
      execute format('revoke all on function %s from public, anon, authenticated, service_role', v_oid);
      for q in select distinct quem from _acl_fn where velho = r.velho loop
        execute format('grant execute on function %s to %s', v_oid, case when q.quem = 'public' then 'public' else q.quem end);
      end loop;
    end loop;
  end loop;
end $$;

-- 7) Gatilhos e políticas
do $$
declare r record; v text;
begin
  for r in select * from _trg_fn loop
    v := r.def;
    v := replace(v, 'listar_eventos_para_portaria', 'listar_eventos_para_portaria');
    v := replace(v, 'comum_na_minha_abrangencia', 'casa_oracao_na_minha_abrangencia');
    v := replace(v, 'membros_sincroniza_comum', 'membros_sincroniza_casa_oracao');
    v := replace(v, 'registrar_entrada_avulsa', 'registrar_entrada_avulsa');
    v := replace(v, 'comum_na_abrangencia', 'casa_oracao_na_abrangencia');
    v := replace(v, 'eventos_valida_comum', 'eventos_valida_casa_oracao');
    v := replace(v, 'cadastrar_visitante', 'cadastrar_visitante');
    v := replace(v, 'comuns_propaga_nome', 'casas_oracao_propaga_nome');
    v := replace(v, 'relatorio_presencas', 'relatorio_presencas');
    v := replace(v, 'eventos_do_painel', 'eventos_do_painel');
    v := replace(v, 'relatorio_eventos', 'relatorio_eventos');
    v := replace(v, 'relatorio_membros', 'relatorio_membros');
    v := replace(v, 'transferir_comum', 'transferir_casa_oracao');
    v := replace(v, 'rotulo_setor', 'rotulo_setor');
    v := replace(replace(replace(v, 'comuns', 'casas_oracao'), 'comum_id', 'casa_oracao_id'), 'Comum', 'Casa de Oração');
    execute v;
  end loop;
end $$;
create policy regiao_eventos on public.eventos for all
  using (public.casa_oracao_na_abrangencia(casa_oracao_id)) with check (public.casa_oracao_na_abrangencia(casa_oracao_id));
create policy regiao_membros on public.membros for all
  using (public.casa_oracao_na_abrangencia(casa_oracao_id)) with check (public.casa_oracao_na_abrangencia(casa_oracao_id));

-- 8) Demais funções que citam a tabela antiga pelo nome (ex.: backup_aplicar): trocam comuns -> casas_oracao
do $$
declare r record; v_def text; v_lista text := '';
begin
  for r in select p.oid, p.proname from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.prosrc ~* '\mcomuns\M' loop
    v_def := pg_get_functiondef(r.oid);
    v_def := replace(replace(v_def, 'comuns_historico', 'casas_oracao_historico'), 'comuns', 'casas_oracao');
    execute v_def;
    v_lista := v_lista || r.proname || ' ';
  end loop;
  if v_lista <> '' then raise notice 'Funções ajustadas automaticamente (nome da tabela): %', v_lista; end if;
end $$;

-- 9) Descrições das permissões
update public.permissoes set descricao = regexp_replace(regexp_replace(regexp_replace(descricao,
    'comum\(ns\)', 'casa(s) de oração', 'g'), 'comuns', 'casas de oração', 'g'), 'comum', 'casa de oração', 'g')
 where descricao ilike '%comum%';

-- 10) Conferência final: nada pode ter ficado com o nome antigo
do $$
declare v_sobra text;
begin
  select string_agg(p.proname, ', ') into v_sobra from pg_proc p
   where p.pronamespace = 'public'::regnamespace and (p.proname ilike '%comum%' or p.prosrc ~* 'comum|\mcomuns\M');
  if v_sobra is not null then
    raise exception 'Ainda há funções com o nome antigo: %. Nada foi alterado.', v_sobra;
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and column_name ilike '%comum%') then
    raise exception 'Ainda há colunas com o nome antigo. Nada foi alterado.';
  end if;
  if exists (select 1 from usuario_vinculos where nivel = 'COMUM') then
    raise exception 'Ainda há vínculos com o nível antigo. Nada foi alterado.';
  end if;
  raise notice 'OK: Comum renomeada para Casa de Oração em todo o banco.';
end $$;
""",
}

# Linhas de texto longas que o diagnóstico cortou: troca só as palavras (comuns/comum) na linha inteira
import re
PROSA_PREFIXO = [("src/modules/portarias/components/FormularioNovaPortaria.tsx", "Aparecem só os eventos que têm uma comum")]
def prosa(t):
    t = t.replace("comuns", "casas de oração").replace("Comuns", "Casas de Oração")
    return re.sub(r"\bComum\b", "Casa de Oração", re.sub(r"\bcomum\b", "casa de oração", t))

# 1a) confere tudo ANTES de gravar qualquer coisa (ignora espaços no fim da linha e o formato de quebra de linha)
planos = {}
erros = []
for caminho, trocas in EDICOES.items():
    if not os.path.exists(caminho):
        erros.append("arquivo não encontrado: " + caminho); continue
    bruto = open(caminho, encoding="utf-8", newline="").read()
    linhas = bruto.split("\n")
    mapa = {antigo.rstrip(): [novo, qtd, 0] for antigo, novo, qtd in trocas}
    for i, linha in enumerate(linhas):
        cr = "\r" if linha.endswith("\r") else ""
        chave = linha.rstrip()
        if chave in mapa:
            linhas[i] = mapa[chave][0].replace("\n", cr + "\n") + cr
            mapa[chave][2] += 1
    for arq, prefixo in PROSA_PREFIXO:
        if arq == caminho:
            achou = 0
            for i, linha in enumerate(linhas):
                if linha.strip().startswith(prefixo):
                    linhas[i] = prosa(linha); achou += 1
            if achou != 1:
                erros.append("em " + caminho + ": linha de texto longa não encontrada (" + str(achou) + ")")
    for antigo, (novo, qtd, achou) in mapa.items():
        if achou != qtd:
            erros.append("em " + caminho + ": esperava " + str(qtd) + " linha(s) e achei " + str(achou))
            erros.append("    esperado: " + antigo.strip()[:160])
            pedaco = antigo.strip()[:25]
            for i, linha in enumerate(bruto.split("\n")):
                if pedaco and pedaco in linha:
                    erros.append("    no arquivo (linha " + str(i + 1) + "): " + repr(linha.strip()[:200]))
    planos[caminho] = "\n".join(linhas)
if erros:
    print("ERRO: o código do projeto está diferente do que eu li. Nada foi gravado.")
    for e in erros: print(e)
    sys.exit(1)

# 1b) grava
total = 0
for caminho, texto in planos.items():
    open(caminho, "w", encoding="utf-8", newline="").write(texto)
    total += len(EDICOES[caminho])
antigo = "src/modules/organizacao/components/SeletorComum.tsx"
novo = "src/modules/organizacao/components/SeletorCasaOracao.tsx"
os.rename(antigo, novo)
for caminho, conteudo in NOVOS.items():
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    open(caminho, "w", encoding="utf-8").write(conteudo)
print("Arquivos alterados:", len(planos), "| trocas:", total, "| arquivo renomeado: SeletorComum -> SeletorCasaOracao | migração nova: 1")
PYSCRIPT
[ $? -eq 0 ] || { reverter; exit 1; }

echo; echo "=== 2) Parando o servidor de teste e limpando o cache ==="
pkill -f "next dev" 2>/dev/null; pkill -f next-server 2>/dev/null; pkill -f "next/dist" 2>/dev/null; sleep 2
for i in 1 2 3 4 5; do rm -rf .next 2>/dev/null; [ -d .next ] || break; sleep 1; done

echo; echo "=== 3) Conferência de tipos ==="
npx tsc --noEmit || { reverter; exit 1; }
echo; echo "=== 4) Testes automáticos ==="
npx vitest run || { reverter; exit 1; }
echo; echo "=== 5) Lint ==="
npx eslint src || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== 7) O que ainda cita 'comum' no código (deve sobrar só o adjetivo 'comum') ==="
grep -rniE "comum|comuns" src || echo "(nada)"

echo; echo "=== TUDO CERTO: código conferido ==="
git status --short | grep -v "instalar-"
echo
echo "PRÓXIMO PASSO: rodar a migração 0031 no Supabase ANTES de publicar (git push)."
) 2>&1 | tee /tmp/casa-de-oracao-instalar.log
