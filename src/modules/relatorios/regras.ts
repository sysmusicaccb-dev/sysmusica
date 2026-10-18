/**
 * SysMúsica — Regras puras dos Relatórios (sem banco): escolha de colunas, montagem da tabela, ajuste da
 * página, resumo dos filtros e montagem das linhas dos relatórios que vêm de cadastros simples.
 * Testadas em regras.test.ts.
 */
import type { CodigoPermissao } from "@/lib/permissoes";
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
  OpcoesPagina,
} from "./tipos";

export const FILTROS_VAZIOS: FiltrosRelatorio = {
  inicio: "",
  fim: "",
  eventoId: "",
  regiaoId: "",
  setorId: "",
  comumId: "",
  cargoId: "",
  instrumentoId: "",
  situacao: "",
  statusPresenca: "",
  visitante: "",
};

export const PAGINA_INICIAL: OpcoesPagina = {
  titulo: "",
  rodape: "",
  orientacao: "paisagem",
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
  Record<"evento" | "regiao" | "setor" | "comum" | "cargo" | "instrumento", string>
>;

/** Nomes (e não identificadores) dos itens escolhidos nos filtros, para o resumo do relatório. */
export function rotulosDosFiltros(filtros: FiltrosRelatorio, opcoes: OpcoesFiltros | null): RotulosFiltros {
  const organizacao = opcoes?.organizacao ?? [];
  const nomeDe = (nivel: NoOrganizacao["nivel"], id: string) =>
    id ? organizacao.find((no) => no.nivel === nivel && no.id === id)?.nome : undefined;
  const evento = filtros.eventoId ? opcoes?.eventos.find((item) => item.id === filtros.eventoId) : undefined;

  return {
    evento: evento ? `${formatarDataHora(evento.data_evento)} · ${evento.tipo} · ${evento.local}` : undefined,
    regiao: nomeDe("REGIAO", filtros.regiaoId),
    setor: nomeDe("SETOR", filtros.setorId),
    comum: nomeDe("COMUM", filtros.comumId),
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
  if (tem("regiao") && filtros.regiaoId && rotulos.regiao) partes.push(`Região: ${rotulos.regiao}`);
  if (tem("setor") && filtros.setorId && rotulos.setor) partes.push(`Setor: ${rotulos.setor}`);
  if (tem("comum") && filtros.comumId && rotulos.comum) partes.push(`Comum: ${rotulos.comum}`);
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

/** Regiões para escolher (com o estado na frente se houver mais de um estado). */
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

/** Comuns do setor escolhido (vazio sem setor). */
export function opcoesComum(nos: NoOrganizacao[], setorId: string): OpcaoSelecao[] {
  return setorId ? filhosDe(nos, setorId, "COMUM").map((no) => ({ id: no.id, rotulo: no.nome })) : [];
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

/** A estrutura Estado > Região > Setor > Comum em linhas (com os filtros de região e setor). */
export function linhasOrganizacao(
  nos: NoOrganizacao[],
  filtro: { regiaoId: string; setorId: string }
): LinhaRelatorio[] {
  const linhas: LinhaRelatorio[] = [];
  const filtrando = filtro.regiaoId !== "" || filtro.setorId !== "";
  const situacao = (no: NoOrganizacao) => (no.ativo === false ? "Inativo" : "Ativo");

  const montar = (
    no: NoOrganizacao,
    caminho: { estado?: string; regiao?: string; setor?: string; comum?: string }
  ): LinhaRelatorio => ({
    nivel: ROTULO_NIVEL[no.nivel],
    estado: caminho.estado ?? "",
    regiao: caminho.regiao ?? "",
    setor: caminho.setor ?? "",
    comum: caminho.comum ?? "",
    situacao: situacao(no),
    cidade: no.cidade ?? "",
    bairro: no.bairro ?? "",
    membros: no.nivel === "COMUM" ? String(no.qtd_membros ?? 0) : "",
    itens: no.nivel === "COMUM" ? "" : String(no.qtd_filhos ?? 0),
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

        for (const comum of filhosDe(nos, setor.id, "COMUM")) {
          linhas.push(montar(comum, { ...caminho, comum: comum.nome }));
        }
      }
    }
  }

  // Comuns que ainda não têm setor
  if (!filtrando) {
    for (const comum of filhosDe(nos, null, "COMUM")) {
      linhas.push(montar(comum, { comum: comum.nome }));
    }
  }
  return linhas;
}
