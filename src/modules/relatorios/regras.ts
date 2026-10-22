/**
 * Sysmusica — Regras puras dos Relatórios (sem banco): escolha de colunas, montagem da tabela, ajuste da
 * página, resumo dos filtros e montagem das linhas dos relatórios que vêm de cadastros simples.
 * Testadas em regras.test.ts.
 */
import type { CodigoPermissao } from "@/lib/permissoes";
import type { ItemInformacao } from "@/lib/exportacao";
import { formatarDataHora } from "@/lib/datas";
import { intervaloDoFiltro } from "@/modules/auditoria/regras";
import { filhosDe, ROTULO_NIVEL } from "@/modules/organizacao/regras";
import type { NoOrganizacao } from "@/modules/organizacao/tipos";
import { ROTULO_STATUS } from "@/modules/portarias/regras";
import type { PortariaDetalhada } from "@/modules/portarias/tipos";
import type { Cargo, Familia, Instrumento } from "@/types/database";
import type {
  DefinicaoRelatorio,
  FiltrosRelatorio,
  LinhaRelatorio,
  OpcoesFiltros,
  CampoFiltro,
  ItemCabecalho,
  ItemRodape,
  MargemPagina,
  OpcoesPagina,
  TipoRelatorioId,
} from "./tipos";

export const FILTROS_VAZIOS: FiltrosRelatorio = {
  inicio: "",
  fim: "",
  eventoId: "",
  rrmId: "",
  regiaoId: "",
  admId: "",
  setorId: "",
  casaOracaoId: "",
  cargoId: "",
  instrumentoId: "",
  situacao: "",
  statusPresenca: "",
  visitante: "",
};

export const PAGINA_INICIAL: OpcoesPagina = {
  titulo: "",
  rodape: "",
  orientacao: "retrato", // padrão: retrato; a paisagem é a segunda opção
  subtitulo: "",
  margem: "normal",
  cabecalho: {
    marca: true,
    evento: true,
    periodo: true,
    localizacao: true,
    filtros: true,
    total: true,
    resumo: true,
    emissao: true,
    emitidoPor: true,
  },
  // Quem emitiu, quando e o total já ficam no quadro do cabeçalho: o rodapé padrão só leva o nome do sistema
  // (e a numeração das páginas). Quem quiser repetir esses itens no rodapé marca nas opções da página.
  rodapeMarcado: { paginacao: true, sistema: true, emitidoPor: false, emissao: false, total: false },
  assinaturas: false,
  nomesAssinaturas: "Responsável",
  ajuste: "automatico",
  escala: "100",
  fonte: "9",
};

// ---------- Tipos e colunas ----------

/** Tipos de relatório que o usuário pode ver (basta ter uma das permissões do tipo). */
export function tiposDisponiveis(
  definicoes: DefinicaoRelatorio[],
  pode: (permissao: CodigoPermissao) => boolean
): DefinicaoRelatorio[] {
  return definicoes.filter((definicao) => definicao.permissoes.some((permissao) => pode(permissao)));
}

/** Colunas que o usuário pode ver (algumas exigem uma permissão própria). */
export function colunasVisiveis(
  definicao: DefinicaoRelatorio,
  pode: (permissao: CodigoPermissao) => boolean
) {
  return definicao.colunas.filter((coluna) => !coluna.exigePermissao || pode(coluna.exigePermissao));
}

/** Marca de início: as colunas padrão do tipo. */
export function marcadasIniciais(colunas: { id: string; padrao: boolean }[]): Set<string> {
  return new Set(colunas.filter((coluna) => coluna.padrao).map((coluna) => coluna.id));
}

/** Move uma coluna uma posição para cima (-1) ou para baixo (1). Devolve uma lista nova. */
export function moverColuna(ordem: string[], id: string, direcao: -1 | 1): string[] {
  const indice = ordem.indexOf(id);
  const destino = indice + direcao;
  if (indice < 0 || destino < 0 || destino >= ordem.length) return ordem;
  const nova = [...ordem];
  [nova[indice], nova[destino]] = [nova[destino], nova[indice]];
  return nova;
}

/** Colunas marcadas, na ordem escolhida. */
export function colunasEscolhidas(ordem: string[], marcadas: Set<string>): string[] {
  return ordem.filter((id) => marcadas.has(id));
}

/**
 * Monta a tabela final: rótulos das colunas escolhidas e uma linha de textos para cada registro.
 * A coluna "numero" é preenchida sozinha (1, 2, 3...); valor ausente vira texto vazio.
 */
export function montarTabela(
  definicao: DefinicaoRelatorio,
  idsEscolhidos: string[],
  linhas: LinhaRelatorio[]
): { colunas: string[]; linhas: string[][] } {
  const colunas = idsEscolhidos.map((id) => definicao.colunas.find((coluna) => coluna.id === id)?.rotulo ?? id);
  const dados = linhas.map((linha, indice) =>
    idsEscolhidos.map((id) => (id === "numero" ? String(indice + 1) : (linha[id] ?? "")))
  );
  return { colunas, linhas: dados };
}

// ---------- Filtros ----------

/** Confere os filtros antes de buscar; devolve a mensagem de erro ou null. */
export function validarFiltros(definicao: DefinicaoRelatorio, filtros: FiltrosRelatorio): string | null {
  if (definicao.filtros.includes("periodo") && filtros.inicio && filtros.fim && filtros.inicio > filtros.fim) {
    return "A data inicial não pode ser depois da data final.";
  }
  return null;
}

/** "2026-10-18" -> "18/10/2026". */
export function formatarDataFiltro(dia: string): string {
  const [ano, mes, dia2] = dia.split("-");
  return ano && mes && dia2 ? `${dia2}/${mes}/${ano}` : dia;
}

export type RotulosFiltros = Partial<
  Record<"evento" | "rrm" | "regiao" | "adm" | "setor" | "casa_oracao" | "cargo" | "instrumento", string>
>;

/** Nomes (e não identificadores) dos itens escolhidos nos filtros, para o resumo do relatório. */
export function rotulosDosFiltros(filtros: FiltrosRelatorio, opcoes: OpcoesFiltros | null): RotulosFiltros {
  const organizacao = opcoes?.organizacao ?? [];
  const nomeDe = (nivel: NoOrganizacao["nivel"], id: string) =>
    id ? organizacao.find((no) => no.nivel === nivel && no.id === id)?.nome : undefined;
  const evento = filtros.eventoId ? opcoes?.eventos.find((item) => item.id === filtros.eventoId) : undefined;

  return {
    evento: evento ? `${formatarDataHora(evento.data_evento)} · ${evento.tipo} · ${evento.local}` : undefined,
    rrm: nomeDe("RRM", filtros.rrmId ?? ""),
    regiao: nomeDe("RA", filtros.regiaoId), // o filtro "regiao" dos relatórios é a RA
    adm: nomeDe("ADM", filtros.admId ?? ""),
    setor: nomeDe("SETOR", filtros.setorId),
    casa_oracao: nomeDe("CASA_ORACAO", filtros.casaOracaoId),
    cargo: filtros.cargoId ? opcoes?.cargos.find((item) => item.id === filtros.cargoId)?.nome : undefined,
    instrumento: filtros.instrumentoId
      ? opcoes?.instrumentos.find((item) => item.id === filtros.instrumentoId)?.nome
      : undefined,
  };
}

/** Resumo dos filtros usados, em uma linha, para o cabeçalho do relatório. */
export function resumoFiltros(
  definicao: DefinicaoRelatorio,
  filtros: FiltrosRelatorio,
  rotulos: RotulosFiltros
): string {
  const tem = (campo: DefinicaoRelatorio["filtros"][number]) => definicao.filtros.includes(campo);
  const partes: string[] = [];

  if (tem("periodo") && (filtros.inicio || filtros.fim)) {
    partes.push(
      `Período: ${filtros.inicio ? formatarDataFiltro(filtros.inicio) : "início"} a ${
        filtros.fim ? formatarDataFiltro(filtros.fim) : "hoje"
      }`
    );
  }
  if (tem("evento") && filtros.eventoId && rotulos.evento) partes.push(`Evento: ${rotulos.evento}`);
  if (tem("rrm") && filtros.rrmId && rotulos.rrm) partes.push(`RRM: ${rotulos.rrm}`);
  if (tem("regiao") && filtros.regiaoId && rotulos.regiao) partes.push(`RA: ${rotulos.regiao}`);
  if (tem("adm") && filtros.admId && rotulos.adm) partes.push(`ADM: ${rotulos.adm}`);
  if (tem("setor") && filtros.setorId && rotulos.setor) partes.push(`Setor: ${rotulos.setor}`);
  if (tem("casa_oracao") && filtros.casaOracaoId && rotulos.casa_oracao) partes.push(`Casa de Oração: ${rotulos.casa_oracao}`);
  if (tem("cargo") && filtros.cargoId && rotulos.cargo) partes.push(`Cargo: ${rotulos.cargo}`);
  if (tem("instrumento") && filtros.instrumentoId && rotulos.instrumento) {
    partes.push(`Instrumento: ${rotulos.instrumento}`);
  }
  if (tem("situacaoMembro") && filtros.situacao) partes.push(`Situação: ${filtros.situacao}`);
  if (tem("statusPresenca") && filtros.statusPresenca) partes.push(`Presença: ${filtros.statusPresenca}`);
  if (tem("visitante") && filtros.visitante === "sim") partes.push("Somente visitantes");
  if (tem("visitante") && filtros.visitante === "nao") partes.push("Sem visitantes");
  if (tem("situacaoPortaria") && filtros.situacao) {
    partes.push(`Situação: ${(ROTULO_STATUS as Record<string, string>)[filtros.situacao] ?? filtros.situacao}`);
  }
  return partes.join(" · ");
}

// ---------- Listas dos filtros de organização ----------

export interface OpcaoSelecao {
  id: string;
  rotulo: string;
}

const porRotulo = (a: OpcaoSelecao, b: OpcaoSelecao) => a.rotulo.localeCompare(b.rotulo, "pt-BR", { numeric: true });

/** RAs para escolher (com o estado na frente se houver mais de um estado). */
/** RRMs para escolher (com o estado na frente se houver mais de um estado). */
export function opcoesRrm(nos: NoOrganizacao[]): OpcaoSelecao[] {
  const estados = nos.filter((no) => no.nivel === "ESTADO");
  const porId = new Map(nos.map((no) => [no.id, no] as const));
  return nos
    .filter((no) => no.nivel === "RRM")
    .map((rrm) => {
      const estado = rrm.parent_id ? porId.get(rrm.parent_id) : undefined;
      return { id: rrm.id, rotulo: estados.length > 1 && estado ? `${estado.nome} › ${rrm.nome}` : rrm.nome };
    })
    .sort(porRotulo);
}

/** RAs para escolher; com a RRM escolhida, só as dela. */
export function opcoesRegiao(nos: NoOrganizacao[], rrmId?: string): OpcaoSelecao[] {
  const estados = nos.filter((no) => no.nivel === "ESTADO");
  const porId = new Map(nos.map((no) => [no.id, no] as const));
  return nos
    .filter((no) => no.nivel === "RA" && (!rrmId || no.parent_id === rrmId))
    .map((ra) => {
      const rrm = ra.parent_id ? porId.get(ra.parent_id) : undefined;
      const estado = rrm?.parent_id ? porId.get(rrm.parent_id) : undefined;
      return { id: ra.id, rotulo: estados.length > 1 && estado ? `${estado.nome} › ${ra.nome}` : ra.nome };
    })
    .sort(porRotulo);
}

/** ADMs da RA escolhida. Vazio sem RA. */
export function opcoesAdm(nos: NoOrganizacao[], regiaoId: string): OpcaoSelecao[] {
  if (!regiaoId) return [];
  return filhosDe(nos, regiaoId, "ADM")
    .map((adm) => ({ id: adm.id, rotulo: adm.nome }))
    .sort(porRotulo);
}

/** Setores da RA escolhida (ou só da ADM escolhida), com o nome da ADM na frente ("Setor 1" existe em várias ADMs). Vazio sem RA. */
export function opcoesSetor(nos: NoOrganizacao[], regiaoId: string, admId?: string): OpcaoSelecao[] {
  if (!regiaoId) return [];
  return filhosDe(nos, regiaoId, "ADM")
    .filter((adm) => !admId || adm.id === admId)
    .flatMap((adm) => filhosDe(nos, adm.id, "SETOR").map((setor) => ({ id: setor.id, rotulo: `${adm.nome} › ${setor.nome}` })))
    .sort(porRotulo);
}

/**
 * Casas de Oração para escolher: as do setor escolhido; sem setor, todas as da RA (as ligadas direto à ADM
 * e as que estão dentro de setores). Vazio sem RA.
 */
export function opcoesCasaOracao(nos: NoOrganizacao[], regiaoId: string, setorId: string, admId?: string): OpcaoSelecao[] {
  const comoOpcao = (no: NoOrganizacao) => ({ id: no.id, rotulo: no.nome });
  if (setorId) return filhosDe(nos, setorId, "CASA_ORACAO").map(comoOpcao);
  if (!regiaoId) return [];
  return filhosDe(nos, regiaoId, "ADM")
    .filter((adm) => !admId || adm.id === admId)
    .flatMap((adm) => [
      ...filhosDe(nos, adm.id, "CASA_ORACAO"),
      ...filhosDe(nos, adm.id, "SETOR").flatMap((setor) => filhosDe(nos, setor.id, "CASA_ORACAO")),
    ])
    .map(comoOpcao)
    .sort(porRotulo);
}

// ---------- Cabeçalho, rodapé e margens do relatório impresso ----------

export const NOME_DO_SISTEMA = "Sysmusica";

/** Itens do quadro do cabeçalho, na ordem em que aparecem. */
export const ITENS_CABECALHO: { id: ItemCabecalho; rotulo: string }[] = [
  { id: "marca", rotulo: "Marca do sistema (logomarca ou nome)" },
  { id: "evento", rotulo: "Evento escolhido (nome, data, hora e local)" },
  { id: "periodo", rotulo: "Período" },
  { id: "localizacao", rotulo: "RA, setor e casa de oração" },
  { id: "filtros", rotulo: "Outros filtros usados" },
  { id: "total", rotulo: "Total de registros" },
  { id: "resumo", rotulo: "Resumo dos totais (presentes, ausentes...)" },
  { id: "emissao", rotulo: "Data e hora da emissão" },
  { id: "emitidoPor", rotulo: "Emitido por (nome do usuário)" },
];

/** Itens do rodapé, na ordem em que aparecem (o texto livre vem sempre primeiro). */
export const ITENS_RODAPE: { id: ItemRodape; rotulo: string }[] = [
  { id: "paginacao", rotulo: "Numeração das páginas (Página 1 de 3)" },
  { id: "sistema", rotulo: "Nome do sistema" },
  { id: "emitidoPor", rotulo: "Emitido por" },
  { id: "emissao", rotulo: "Data e hora da emissão" },
  { id: "total", rotulo: "Total de registros" },
];

/** Margens da página em milímetros. */
export const MARGENS: Record<MargemPagina, number> = { estreita: 8, normal: 12, larga: 18 };

export function margemEmMm(margem: MargemPagina): number {
  return MARGENS[margem] ?? MARGENS.normal;
}

// Filtros que entram no item "Outros filtros usados" (período, evento e localização têm item próprio)
const OUTROS_FILTROS: CampoFiltro[] = [
  "cargo",
  "instrumento",
  "situacaoMembro",
  "statusPresenca",
  "visitante",
  "situacaoPortaria",
];

/** Itens do cabeçalho que fazem sentido para o tipo escolhido (marca, total, emissão e emitido por valem sempre). */
export function itensCabecalhoDisponiveis(definicao: DefinicaoRelatorio): ItemCabecalho[] {
  const tem = (campo: CampoFiltro) => definicao.filtros.includes(campo);
  return ITENS_CABECALHO.map((item) => item.id).filter((id) => {
    switch (id) {
      case "evento":
        return tem("evento");
      case "periodo":
        return tem("periodo");
      case "localizacao":
        return tem("regiao");
      case "filtros":
        return OUTROS_FILTROS.some((campo) => tem(campo));
      case "resumo":
        return definicao.id === "presenca" || definicao.id === "eventos";
      default:
        return true;
    }
  });
}

/** Data e hora de agora no fuso de Salvador, no formato "18/10/2026 01:31". */
export function agoraEmSalvador(agora: Date = new Date()): string {
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: "America/Sao_Paulo",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  })
    .format(agora)
    .replace(", ", " ");
}

/** Resumo dos totais do relatório: presença (por situação) e eventos (presenças). Os demais tipos não têm. */
export function resumoDeTotais(tipo: TipoRelatorioId, linhas: LinhaRelatorio[]): string {
  if (tipo === "presenca") {
    const contar = (situacao: string) => linhas.filter((linha) => linha.status === situacao).length;
    return `Presentes: ${contar("Presente")} · Ausentes: ${contar("Ausente")} · Justificados: ${contar("Justificado")}`;
  }
  if (tipo === "eventos") {
    const somar = (campo: string) => linhas.reduce((total, linha) => total + (Number(linha[campo]) || 0), 0);
    return `Presenças registradas: ${somar("registros")} · Presentes: ${somar("presentes")}`;
  }
  return "";
}

// Filtros além de período, evento e localização, em uma linha ("Cargo: Músico · Presença: Presente")
function textoOutrosFiltros(
  definicao: DefinicaoRelatorio,
  filtros: FiltrosRelatorio,
  rotulos: RotulosFiltros
): string {
  const tem = (campo: CampoFiltro) => definicao.filtros.includes(campo);
  const partes: string[] = [];

  if (tem("cargo") && filtros.cargoId && rotulos.cargo) partes.push(`Cargo: ${rotulos.cargo}`);
  if (tem("instrumento") && filtros.instrumentoId && rotulos.instrumento) {
    partes.push(`Instrumento: ${rotulos.instrumento}`);
  }
  if (tem("situacaoMembro") && filtros.situacao) partes.push(`Situação: ${filtros.situacao}`);
  if (tem("statusPresenca") && filtros.statusPresenca) partes.push(`Presença: ${filtros.statusPresenca}`);
  if (tem("visitante") && filtros.visitante === "sim") partes.push("Somente visitantes");
  if (tem("visitante") && filtros.visitante === "nao") partes.push("Sem visitantes");
  if (tem("situacaoPortaria") && filtros.situacao) {
    partes.push(`Situação: ${(ROTULO_STATUS as Record<string, string>)[filtros.situacao] ?? filtros.situacao}`);
  }
  return partes.join(" · ");
}

export interface EntradaInformacoes {
  definicao: DefinicaoRelatorio;
  filtros: FiltrosRelatorio;
  rotulos: RotulosFiltros;
  itens: Record<ItemCabecalho, boolean>;
  emitidoPor: string;
  geradoEm: string;
  linhas: LinhaRelatorio[]; // para o resumo dos totais
  total: number; // linhas que vão para o papel
}

/** Monta o quadro de informações do cabeçalho, só com os itens marcados que fazem sentido para o tipo. */
export function montarInformacoes(entrada: EntradaInformacoes): ItemInformacao[] {
  const { definicao, filtros, rotulos, itens } = entrada;
  const tem = (campo: CampoFiltro) => definicao.filtros.includes(campo);
  const lista: ItemInformacao[] = [];

  if (itens.evento && tem("evento")) {
    lista.push({
      rotulo: "Evento",
      valor: filtros.eventoId ? (rotulos.evento ?? "Evento escolhido") : "Todos os eventos do período",
      largo: true,
    });
  }

  if (itens.periodo && tem("periodo")) {
    const de = filtros.inicio ? formatarDataFiltro(filtros.inicio) : "";
    const ate = filtros.fim ? formatarDataFiltro(filtros.fim) : "";
    if (de || ate) lista.push({ rotulo: "Período", valor: `${de || "início"} a ${ate || "hoje"}` });
  }

  if (itens.localizacao && tem("regiao")) {
    const partes = [rotulos.rrm, rotulos.regiao, rotulos.adm, rotulos.setor, rotulos.casa_oracao].filter((parte): parte is string => Boolean(parte));
    lista.push({ rotulo: "Localização", valor: partes.length > 0 ? partes.join(" › ") : "Toda a sua abrangência" });
  }

  if (itens.filtros && OUTROS_FILTROS.some((campo) => tem(campo))) {
    // Só mostra a linha quando há filtro de verdade; sem filtro, ela some do cabeçalho
    const outros = textoOutrosFiltros(definicao, filtros, rotulos);
    if (outros) lista.push({ rotulo: "Filtros", valor: outros, largo: true });
  }

  if (itens.total) lista.push({ rotulo: "Total de registros", valor: String(entrada.total) });

  if (itens.resumo) {
    const resumo = resumoDeTotais(definicao.id, entrada.linhas);
    if (resumo) lista.push({ rotulo: "Resumo", valor: resumo, largo: true });
  }

  if (itens.emissao) lista.push({ rotulo: "Emitido em", valor: entrada.geradoEm });
  if (itens.emitidoPor) lista.push({ rotulo: "Emitido por", valor: entrada.emitidoPor });
  return lista;
}

/** Itens de texto do rodapé: o texto livre primeiro e depois os marcados (a numeração é tratada à parte). */
export function montarItensRodape(entrada: {
  itens: Record<ItemRodape, boolean>;
  textoLivre: string;
  emitidoPor: string;
  geradoEm: string;
  total: number;
}): string[] {
  const lista: string[] = [];
  const livre = entrada.textoLivre.trim();
  if (livre) lista.push(livre);
  if (entrada.itens.sistema) lista.push(NOME_DO_SISTEMA);
  if (entrada.itens.emitidoPor) lista.push(`Emitido por ${entrada.emitidoPor}`);
  if (entrada.itens.emissao) lista.push(`Emitido em ${entrada.geradoEm}`);
  if (entrada.itens.total) lista.push(`${entrada.total} registro(s)`);
  return lista;
}

/** Nomes das linhas de assinatura: até 4, separados por vírgula (vazio = "Responsável"). Desligado = nenhuma. */
export function lerAssinaturas(ativo: boolean, texto: string): string[] {
  if (!ativo) return [];
  const nomes = texto
    .split(",")
    .map((nome) => nome.trim().slice(0, 60))
    .filter((nome) => nome !== "")
    .slice(0, 4);
  return nomes.length > 0 ? nomes : ["Responsável"];
}

// ---------- Ajuste da página ----------

export const ESCALA_MIN = 30;
export const ESCALA_MAX = 200;
export const FONTE_MIN = 5;
export const FONTE_MAX = 20;

function numero(texto: string): number {
  return Number(texto.trim().replace(",", "."));
}

/** Confere o zoom e o tamanho da letra do ajuste manual; devolve a mensagem de erro ou null. */
export function validarAjusteManual(escala: string, fonte: string): string | null {
  const zoom = numero(escala);
  const letra = numero(fonte);
  if (!Number.isFinite(zoom) || zoom < ESCALA_MIN || zoom > ESCALA_MAX) {
    return `O zoom deve estar entre ${ESCALA_MIN}% e ${ESCALA_MAX}%.`;
  }
  if (!Number.isFinite(letra) || letra < FONTE_MIN || letra > FONTE_MAX) {
    return `O tamanho da letra deve estar entre ${FONTE_MIN} e ${FONTE_MAX} pt.`;
  }
  return null;
}

/** Lê o zoom e o tamanho da letra (use depois de validarAjusteManual). */
export function lerAjusteManual(escala: string, fonte: string): { escala: number; tamanhoFonte: number } {
  return { escala: numero(escala), tamanhoFonte: numero(fonte) };
}

/** Nome do arquivo sem acentos nem símbolos: "Presença por evento" -> "presenca-por-evento-2026-10-18". */
export function nomeDoArquivo(titulo: string, dia: string): string {
  const base = titulo
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return `${base || "relatorio"}-${dia}`;
}

// ---------- Linhas dos relatórios que vêm de cadastros simples ----------

/** Conta quantas vezes cada identificador aparece (ignora vazios). */
export function contarPor(ids: (string | null | undefined)[]): Map<string, number> {
  const contagem = new Map<string, number>();
  for (const id of ids) {
    if (id) contagem.set(id, (contagem.get(id) ?? 0) + 1);
  }
  return contagem;
}

/** Instrumentos por família (os sem família no fim), com a quantidade de membros. */
export function linhasInstrumentos(
  instrumentos: Instrumento[],
  familias: Familia[],
  membrosPorInstrumento: Map<string, number>
): LinhaRelatorio[] {
  const nomeDaFamilia = new Map(familias.map((familia) => [familia.id, familia.nome] as const));
  const itens = instrumentos.map((instrumento) => ({
    nome: instrumento.nome,
    familia: instrumento.familia_id ? (nomeDaFamilia.get(instrumento.familia_id) ?? "") : "",
    quantidade: membrosPorInstrumento.get(instrumento.id) ?? 0,
  }));

  itens.sort((a, b) => {
    if (a.familia === "" && b.familia !== "") return 1;
    if (b.familia === "" && a.familia !== "") return -1;
    return (
      a.familia.localeCompare(b.familia, "pt-BR") || a.nome.localeCompare(b.nome, "pt-BR", { numeric: true })
    );
  });

  return itens.map((item) => ({
    instrumento: item.nome,
    familia: item.familia || "Sem família definida",
    membros: String(item.quantidade),
  }));
}

export type CargoRelatorio = Cargo & { exige_instrumento?: boolean };

/** Cargos em ordem de nome, com a quantidade de membros. */
export function linhasCargos(cargos: CargoRelatorio[], membrosPorCargo: Map<string, number>): LinhaRelatorio[] {
  return [...cargos]
    .sort((a, b) => a.nome.localeCompare(b.nome, "pt-BR"))
    .map((cargo) => ({
      cargo: cargo.nome,
      permite_instrumento: cargo.permite_instrumento ? "Sim" : "Não",
      exige_instrumento: cargo.exige_instrumento ? "Sim" : "Não",
      membros: String(membrosPorCargo.get(cargo.id) ?? 0),
    }));
}

/** Portarias filtradas por situação e por período (da data do evento). */
export function linhasPortarias(
  portarias: PortariaDetalhada[],
  filtros: Pick<FiltrosRelatorio, "inicio" | "fim" | "situacao">
): LinhaRelatorio[] {
  const periodo = intervaloDoFiltro(filtros.inicio, filtros.fim);
  const inicio = periodo.inicio ? Date.parse(periodo.inicio) : null;
  const fim = periodo.fim ? Date.parse(periodo.fim) : null;

  return portarias
    .filter((portaria) => {
      if (filtros.situacao && portaria.status !== filtros.situacao) return false;
      if (inicio !== null || fim !== null) {
        if (!portaria.evento_data) return false;
        const data = Date.parse(portaria.evento_data);
        if (inicio !== null && data < inicio) return false;
        if (fim !== null && data >= fim) return false;
      }
      return true;
    })
    .map((portaria) => ({
      data_evento: portaria.evento_data ? formatarDataHora(portaria.evento_data) : "Evento removido",
      tipo: portaria.evento_tipo ?? "",
      local: portaria.evento_local ?? "",
      finalidade: portaria.evento_finalidade ?? "",
      setor: portaria.cidade,
      situacao: ROTULO_STATUS[portaria.status],
      criada_por: portaria.criador_nome ?? "",
      criada_em: formatarDataHora(portaria.criada_em),
      decidida_por: portaria.decisor_nome ?? "",
      decidida_em: portaria.decidida_em ? formatarDataHora(portaria.decidida_em) : "",
      motivo: portaria.motivo_rejeicao ?? "",
    }));
}

/** A estrutura Estado › RRM › RA › ADM › Setor › Casa de Oração em linhas (com os filtros de RA e de setor). */
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
