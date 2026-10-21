/**
 * SysMúsica — Regras puras dos Dados do Ensaio (sem banco). Testadas em regras.test.ts.
 *
 * Só ensaios Local e Regional. O que se registra:
 *   - quem atendeu (Regional: sempre um Ancião; Local: Ancião, Diácono, Cooperador do Ofício ou de RJM) e o nome;
 *   - a palavra exortada (só no Regional, obrigatória, até 500 caracteres; o Local não tem palavra);
 *   - de 1 a 3 encarregados, cada um com nome e Cidade-UF;
 *   - o hino de abertura (obrigatório e FORA da lista) e os hinos executados (sem repetir).
 * O banco aplica as mesmas regras (migração 0041); aqui ficam as conferências para a tela.
 */
import type { ModeloEnsaio } from "@/modules/tiposEvento/regras";
import type { CargaEnsaio, CargoAtende, DadosSalvos, EventoDoEnsaio } from "./tipos";

export const CARGOS_ATENDE: { codigo: CargoAtende; rotulo: string }[] = [
  { codigo: "ANCIAO", rotulo: "Ancião" },
  { codigo: "DIACONO", rotulo: "Diácono" },
  { codigo: "COOPERADOR_OFICIO", rotulo: "Cooperador do Ofício Ministerial" },
  { codigo: "COOPERADOR_RJM", rotulo: "Cooperador da Reunião de Jovens e Menores" },
];

export const PALAVRA_MAXIMA = 500;
export const MAXIMO_ENCARREGADOS = 3;
export const NOME_MINIMO = 3;
export const NOME_MAXIMO = 120;
export const MAXIMO_HINOS = 100;

/** Siglas dos 26 estados e do Distrito Federal. */
export const SIGLAS_UF = [
  "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA",
  "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO",
];

export function rotuloDoCargo(cargo: CargoAtende | ""): string {
  return CARGOS_ATENDE.find((item) => item.codigo === cargo)?.rotulo ?? "";
}

/** Cargos que podem atender: no Regional só o Ancião; no Local, os quatro. */
export function cargosDoModelo(modelo: ModeloEnsaio): CargoAtende[] {
  return modelo === "REGIONAL" ? ["ANCIAO"] : CARGOS_ATENDE.map((item) => item.codigo);
}

/** O ensaio tem o campo Palavra? (só o Regional) */
export function temPalavra(modelo: ModeloEnsaio): boolean {
  return modelo === "REGIONAL";
}

/** Rótulo do encarregado conforme o modelo: "Encarregado Regional" ou "Encarregado Local". */
export function rotuloEncarregado(modelo: ModeloEnsaio): string {
  return modelo === "REGIONAL" ? "Encarregado Regional" : "Encarregado Local";
}

const ESPACOS = /\s+/g;
export function limparEspacos(texto: string): string {
  return texto.trim().replace(ESPACOS, " ");
}

// ---------------------------------------------------------------------------
// Cidade-UF
// ---------------------------------------------------------------------------

/** Monta o texto gravado: "São Paulo-SP". */
export function montarCidadeUf(cidade: string, uf: string): string {
  return `${limparEspacos(cidade)}-${uf.trim().toUpperCase()}`;
}

/** Confere "Cidade-UF" (ex.: "São Paulo-SP"). Devolve a mensagem de erro ou null. */
export function validarCidadeUf(texto: string): string | null {
  const limpo = limparEspacos(texto);
  const achou = /^(.{2,})-([A-Z]{2})$/.exec(limpo);
  if (!achou || !SIGLAS_UF.includes(achou[2])) {
    return "Informe a cidade no formato Cidade-UF (ex.: São Paulo-SP). Escolha uma das sugestões.";
  }
  return null;
}

// ---------------------------------------------------------------------------
// Estado do formulário
// ---------------------------------------------------------------------------

export interface EncarregadoForm {
  nome: string;
  cidadeUf: string;
}

export interface EstadoEnsaio {
  atendeCargo: CargoAtende | "";
  atendeNome: string;
  palavra: string;
  hinoAberturaId: string;
  encarregados: EncarregadoForm[]; // de 1 a 3
  hinosIds: string[]; // hinos executados, na ordem em que foram cantados
}

const ENCARREGADO_VAZIO: EncarregadoForm = { nome: "", cidadeUf: "" };

/** Formulário em branco. No Regional o cargo já vem como Ancião (é o único possível). */
export function estadoVazio(modelo: ModeloEnsaio): EstadoEnsaio {
  return {
    atendeCargo: modelo === "REGIONAL" ? "ANCIAO" : "",
    atendeNome: "",
    palavra: "",
    hinoAberturaId: "",
    encarregados: [{ ...ENCARREGADO_VAZIO }],
    hinosIds: [],
  };
}

/** Formulário a partir do que já foi gravado (ou em branco, se ainda não há dados). */
export function estadoDosDados(dados: DadosSalvos | null, modelo: ModeloEnsaio): EstadoEnsaio {
  if (!dados) return estadoVazio(modelo);
  const encarregados = [...dados.encarregados]
    .sort((a, b) => a.ordem - b.ordem)
    .map((item) => ({ nome: item.nome, cidadeUf: item.cidade_uf }));
  return {
    atendeCargo: dados.atende_cargo,
    atendeNome: dados.atende_nome,
    palavra: dados.palavra ?? "",
    hinoAberturaId: dados.hino_abertura_id,
    encarregados: encarregados.length > 0 ? encarregados : [{ ...ENCARREGADO_VAZIO }],
    hinosIds: [...dados.hinos],
  };
}

/** Muda a quantidade de encarregados (1 a 3): mantém os já digitados e acrescenta linhas em branco. */
export function ajustarQuantidade(encarregados: EncarregadoForm[], quantidade: number): EncarregadoForm[] {
  const alvo = Math.min(MAXIMO_ENCARREGADOS, Math.max(1, Math.trunc(quantidade) || 1));
  const novos = encarregados.slice(0, alvo);
  while (novos.length < alvo) novos.push({ ...ENCARREGADO_VAZIO });
  return novos;
}

// ---------------------------------------------------------------------------
// Hinos executados
// ---------------------------------------------------------------------------

/** Acrescenta hinos ao fim da lista, sem repetir e sem o hino de abertura. */
export function adicionarHinos(selecionados: string[], novos: string[], abertura: string): string[] {
  const resultado = [...selecionados];
  for (const id of novos) {
    if (id === abertura || resultado.includes(id)) continue;
    if (resultado.length >= MAXIMO_HINOS) break;
    resultado.push(id);
  }
  return resultado;
}

export function removerHinos(selecionados: string[], remover: string[]): string[] {
  return selecionados.filter((id) => !remover.includes(id));
}

/** Sobe (-1) ou desce (+1) um hino na ordem de execução. */
export function moverHino(selecionados: string[], indice: number, passo: -1 | 1): string[] {
  const destino = indice + passo;
  if (indice < 0 || indice >= selecionados.length || destino < 0 || destino >= selecionados.length) return selecionados;
  const copia = [...selecionados];
  [copia[indice], copia[destino]] = [copia[destino], copia[indice]];
  return copia;
}

/** Hinos que ainda podem ser escolhidos: ativos, fora da lista e diferentes do hino de abertura. */
export function hinosDisponiveis<T extends { id: string; ativo: boolean }>(
  todos: T[],
  selecionados: string[],
  abertura: string
): T[] {
  return todos.filter((hino) => hino.ativo && hino.id !== abertura && !selecionados.includes(hino.id));
}

/**
 * Escolhe o hino de abertura. Se ele estava entre os hinos executados, sai de lá (a abertura não conta na lista);
 * `saiuDaLista` avisa a tela para mostrar a informação.
 */
export function escolherAbertura(
  estado: EstadoEnsaio,
  hinoId: string
): { estado: EstadoEnsaio; saiuDaLista: boolean } {
  const saiuDaLista = hinoId !== "" && estado.hinosIds.includes(hinoId);
  return {
    estado: { ...estado, hinoAberturaId: hinoId, hinosIds: removerHinos(estado.hinosIds, [hinoId]) },
    saiuDaLista,
  };
}

/** Acha o hino pelo texto do campo de busca do hino de abertura (o texto exato de uma das opções). */
export function acharPeloRotulo<T extends { id: string }>(
  opcoes: { rotulo: string; hino: T }[],
  texto: string
): T | null {
  const alvo = limparEspacos(texto).toLowerCase();
  if (alvo === "") return null;
  return opcoes.find((opcao) => limparEspacos(opcao.rotulo).toLowerCase() === alvo)?.hino ?? null;
}

// ---------------------------------------------------------------------------
// Validação e envio
// ---------------------------------------------------------------------------

export interface ErroCampo {
  campo: string; // "atende_cargo", "atende_nome", "palavra", "hino_abertura", "encarregado_0_nome", "encarregado_0_cidade"
  mensagem: string;
}

/** Confere o formulário na ordem em que aparece na tela. Lista vazia = pode salvar. */
export function validarEnsaio(estado: EstadoEnsaio, modelo: ModeloEnsaio): ErroCampo[] {
  const erros: ErroCampo[] = [];

  if (!estado.atendeCargo || !cargosDoModelo(modelo).includes(estado.atendeCargo)) {
    erros.push({
      campo: "atende_cargo",
      mensagem:
        modelo === "REGIONAL"
          ? "No ensaio Regional quem atende é sempre um Ancião."
          : "Escolha o cargo de quem atendeu o ensaio.",
    });
  }
  const nome = limparEspacos(estado.atendeNome);
  if (nome.length < NOME_MINIMO) {
    erros.push({ campo: "atende_nome", mensagem: "Informe o nome de quem atendeu o ensaio." });
  } else if (nome.length > NOME_MAXIMO) {
    erros.push({ campo: "atende_nome", mensagem: `O nome pode ter no máximo ${NOME_MAXIMO} caracteres.` });
  }

  if (temPalavra(modelo)) {
    const palavra = estado.palavra.trim();
    if (palavra === "") erros.push({ campo: "palavra", mensagem: "Informe a palavra que foi exortada." });
    else if (palavra.length > PALAVRA_MAXIMA) {
      erros.push({ campo: "palavra", mensagem: `A palavra pode ter no máximo ${PALAVRA_MAXIMA} caracteres.` });
    }
  }

  if (estado.encarregados.length < 1 || estado.encarregados.length > MAXIMO_ENCARREGADOS) {
    erros.push({ campo: "encarregados", mensagem: `Informe de 1 a ${MAXIMO_ENCARREGADOS} encarregados.` });
  }
  const nomesVistos = new Set<string>();
  estado.encarregados.forEach((item, indice) => {
    const nomeEnc = limparEspacos(item.nome);
    if (nomeEnc.length < NOME_MINIMO || nomeEnc.length > NOME_MAXIMO) {
      erros.push({
        campo: `encarregado_${indice}_nome`,
        mensagem: `Informe o nome do ${indice + 1}º encarregado.`,
      });
    } else {
      const chave = nomeEnc.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
      if (nomesVistos.has(chave)) {
        erros.push({ campo: `encarregado_${indice}_nome`, mensagem: "Este nome já foi informado em outro encarregado." });
      }
      nomesVistos.add(chave);
    }
    const erroCidade = validarCidadeUf(item.cidadeUf);
    if (erroCidade) erros.push({ campo: `encarregado_${indice}_cidade`, mensagem: erroCidade });
  });

  if (!estado.hinoAberturaId) {
    erros.push({ campo: "hino_abertura", mensagem: "Escolha o hino de abertura na lista." });
  } else if (estado.hinosIds.includes(estado.hinoAberturaId)) {
    erros.push({ campo: "hinos", mensagem: "O hino de abertura não conta entre os hinos executados." });
  }
  if (new Set(estado.hinosIds).size !== estado.hinosIds.length) {
    erros.push({ campo: "hinos", mensagem: "O mesmo hino não pode ser executado duas vezes." });
  }
  if (estado.hinosIds.length > MAXIMO_HINOS) {
    erros.push({ campo: "hinos", mensagem: `Informe no máximo ${MAXIMO_HINOS} hinos executados.` });
  }
  return erros;
}

/** Monta o que é enviado ao banco (já limpo). Só chame depois de validarEnsaio devolver lista vazia. */
export function montarCarga(estado: EstadoEnsaio, modelo: ModeloEnsaio): CargaEnsaio {
  return {
    atende_cargo: (estado.atendeCargo || "ANCIAO") as CargoAtende,
    atende_nome: limparEspacos(estado.atendeNome),
    palavra: temPalavra(modelo) ? estado.palavra.trim() : null,
    hino_abertura_id: estado.hinoAberturaId,
    encarregados: estado.encarregados.map((item) => ({
      nome: limparEspacos(item.nome),
      cidade_uf: limparEspacos(item.cidadeUf),
    })),
    hinos: [...estado.hinosIds],
  };
}

/** Nada foi digitado ainda? (o botão Limpar só faz sentido quando há algo) */
export function estaVazio(estado: EstadoEnsaio, modelo: ModeloEnsaio): boolean {
  const base = estadoVazio(modelo);
  return (
    estado.atendeCargo === base.atendeCargo &&
    estado.atendeNome.trim() === "" &&
    estado.palavra.trim() === "" &&
    estado.hinoAberturaId === "" &&
    estado.hinosIds.length === 0 &&
    estado.encarregados.every((item) => item.nome.trim() === "" && item.cidadeUf.trim() === "")
  );
}

// ---------------------------------------------------------------------------
// Quando dá para preencher
// ---------------------------------------------------------------------------

/**
 * Por que a tela está só para consulta (ou null, se dá para editar). O banco decide; aqui só se explica.
 * Ordem: cancelado, ainda não começou, encerrado, sem permissão.
 */
export function motivoSemEdicao(
  evento: Pick<EventoDoEnsaio, "cancelado" | "iniciado" | "encerrado">,
  podeEditar: boolean,
  temPermissaoPreencher: boolean
): string | null {
  if (podeEditar) return null;
  if (evento.cancelado) return "Este evento foi cancelado: os dados não podem ser alterados.";
  if (!temPermissaoPreencher) return "Você pode ver os dados do ensaio, mas não tem permissão para preenchê-los.";
  if (!evento.iniciado) {
    return "O ensaio ainda não começou. Os dados podem ser preenchidos a partir de 2 horas antes do horário.";
  }
  if (evento.encerrado) return "Este ensaio já foi encerrado. Só o Administrador pode alterar os dados.";
  return "Não é possível alterar os dados deste ensaio agora.";
}
