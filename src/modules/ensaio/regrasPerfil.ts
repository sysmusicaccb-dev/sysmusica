/**
 * Sysmusica — Regras da tela Dados do Ensaio guiadas pela configuração do perfil (sem banco).
 * Versão "por perfil" do estado, da validação e do envio: o que não está ligado no perfil não aparece, não é
 * conferido e vai vazio. Testadas em regrasPerfil.test.ts. O banco refaz as mesmas conferências (migração 0080).
 */
import type { CampoExtra, CargoEncarregado, ConfigEnsaio } from "./perfilConfig";
import {
  limparEspacos,
  removerHinos,
  validarCidadeUf,
  MAXIMO_HINOS,
  NOME_MAXIMO,
  NOME_MINIMO,
  type EncarregadoForm,
  type ErroCampo,
  type EstadoEnsaio,
} from "./regras";
import type { CargoAtende, DadosSalvos } from "./tipos";

export interface EncarregadoCfg extends EncarregadoForm {
  cargo: CargoEncarregado | "";
}

export interface EstadoEnsaioCfg extends Omit<EstadoEnsaio, "encarregados"> {
  encarregados: EncarregadoCfg[];
  houveAbertura: "" | "SIM" | "NAO"; // resposta de "Houve hino de abertura?" (perfil com modo "pergunta")
  extras: Record<string, string>; // campos extras por id; sim/não guarda "SIM" ou "NAO"; vazio = sem resposta
}

/** O que a tela envia para salvar_dados_ensaio (campos desligados no perfil vão nulos ou vazios). */
export interface CargaEnsaioCfg {
  atende_cargo: CargoAtende | null;
  atende_nome: string | null;
  palavra: string | null;
  hino_abertura_id: string | null;
  encarregados: { nome: string; cidade_uf: string | null; cargo: CargoEncarregado | null }[];
  hinos: string[];
  extras: Record<string, string | number | boolean>; // só campos extras ativos e preenchidos
}

const EXTRA_CURTO_MAXIMO = 200;
const EXTRA_LONGO_MAXIMO = 1000;

/** "3,5" ou "3.5" viram 3.5; qualquer outra coisa vira null. */
export function numeroDoTexto(texto: string): number | null {
  const limpo = texto.trim();
  if (!/^-?\d+([.,]\d+)?$/.test(limpo)) return null;
  const n = Number(limpo.replace(",", "."));
  return Number.isFinite(n) ? n : null;
}

/** Valor guardado no banco -> texto do formulário. */
function extraParaEstado(campo: CampoExtra, valor: unknown): string {
  if (campo.tipo === "sim_nao") return valor === true ? "SIM" : valor === false ? "NAO" : "";
  if (typeof valor === "number") return String(valor).replace(".", ",");
  return typeof valor === "string" ? valor : "";
}

/** Cargo já escolhido quando o perfil só permite um. */
function cargoUnico(config: ConfigEnsaio): CargoEncarregado | "" {
  return config.encarregados.cargos.length === 1 ? config.encarregados.cargos[0] : "";
}

function linhaVazia(config: ConfigEnsaio): EncarregadoCfg {
  return { nome: "", cidadeUf: "", cargo: cargoUnico(config) };
}

/** Muda a quantidade de encarregados (dentro do mínimo e do máximo do perfil), mantendo os já digitados. */
export function ajustarQuantidadeCfg(lista: EncarregadoCfg[], quantidade: number, config: ConfigEnsaio): EncarregadoCfg[] {
  const { minimo, maximo } = config.encarregados;
  const alvo = Math.min(maximo, Math.max(minimo, Math.trunc(quantidade) || 0));
  const novos = lista.slice(0, alvo);
  while (novos.length < alvo) novos.push(linhaVazia(config));
  return novos;
}

export function estadoVazioCfg(config: ConfigEnsaio): EstadoEnsaioCfg {
  const unico = config.quem_atendeu.cargos.length === 1 ? config.quem_atendeu.cargos[0] : "";
  return {
    atendeCargo: unico,
    atendeNome: "",
    palavra: "",
    hinoAberturaId: "",
    houveAbertura: "",
    // Começa com 1 linha (ou o mínimo do perfil); com mínimo 0 a pessoa escolhe a quantidade
    encarregados: config.encarregados.ativo ? ajustarQuantidadeCfg([], Math.max(1, config.encarregados.minimo), config) : [],
    hinosIds: [],
    extras: {},
  };
}

/** Formulário a partir do que já foi gravado (ou em branco, se ainda não há dados). */
export function estadoDosDadosCfg(dados: DadosSalvos | null, config: ConfigEnsaio): EstadoEnsaioCfg {
  if (!dados) return estadoVazioCfg(config);
  const vazio = estadoVazioCfg(config);
  const salvos: EncarregadoCfg[] = [...dados.encarregados]
    .sort((a, b) => a.ordem - b.ordem)
    .map((item) => ({
      nome: item.nome,
      cidadeUf: item.cidade_uf ?? "",
      cargo: (item.cargo as CargoEncarregado | null | undefined) ?? cargoUnico(config),
    }));
  return {
    atendeCargo: dados.atende_cargo ?? vazio.atendeCargo,
    atendeNome: dados.atende_nome ?? "",
    palavra: dados.palavra ?? "",
    hinoAberturaId: dados.hino_abertura_id ?? "",
    houveAbertura: dados.hino_abertura_id ? "SIM" : "NAO",
    encarregados: config.encarregados.ativo
      ? ajustarQuantidadeCfg(salvos, Math.max(salvos.length, config.encarregados.minimo), config)
      : [],
    hinosIds: [...dados.hinos],
    extras: Object.fromEntries(
      config.campos_extras
        .filter((c) => c.ativo)
        .map((c) => [c.id, extraParaEstado(c, dados.extras?.[c.id])] as const)
        .filter(([, valor]) => valor !== "")
    ),
  };
}

/** O hino de abertura entra no ensaio? (obrigatório, ou "pergunta" respondida com Sim) */
export function usaAbertura(config: ConfigEnsaio, estado: Pick<EstadoEnsaioCfg, "houveAbertura">): boolean {
  const modo = config.hino_abertura.modo;
  return modo === "obrigatorio" || (modo === "pergunta" && estado.houveAbertura === "SIM");
}

/** Escolhe o hino de abertura. Se ele estava entre os executados, sai de lá (a abertura não conta na lista). */
export function escolherAberturaCfg(estado: EstadoEnsaioCfg, hinoId: string): { estado: EstadoEnsaioCfg; saiuDaLista: boolean } {
  const saiuDaLista = hinoId !== "" && estado.hinosIds.includes(hinoId);
  return {
    estado: { ...estado, hinoAberturaId: hinoId, hinosIds: removerHinos(estado.hinosIds, [hinoId]) },
    saiuDaLista,
  };
}

/** Confere o formulário na ordem em que aparece na tela. Lista vazia = pode salvar. */
export function validarEnsaioCfg(estado: EstadoEnsaioCfg, config: ConfigEnsaio): ErroCampo[] {
  const erros: ErroCampo[] = [];

  if (config.quem_atendeu.ativo) {
    if (!estado.atendeCargo || !config.quem_atendeu.cargos.includes(estado.atendeCargo)) {
      erros.push({ campo: "atende_cargo", mensagem: "Escolha o cargo de quem atendeu o ensaio." });
    }
    const nome = limparEspacos(estado.atendeNome);
    if (nome.length < NOME_MINIMO) {
      erros.push({ campo: "atende_nome", mensagem: "Informe o nome de quem atendeu o ensaio." });
    } else if (nome.length > NOME_MAXIMO) {
      erros.push({ campo: "atende_nome", mensagem: `O nome pode ter no máximo ${NOME_MAXIMO} caracteres.` });
    }
  }

  // Hino de abertura (fica no mesmo cartão de quem atendeu)
  if (config.hino_abertura.modo === "pergunta" && estado.houveAbertura === "") {
    erros.push({ campo: "hino_abertura", mensagem: "Informe se houve hino de abertura." });
  } else if (usaAbertura(config, estado) && !estado.hinoAberturaId) {
    erros.push({ campo: "hino_abertura", mensagem: "Escolha o hino de abertura na lista." });
  }

  if (config.palavra.ativo) {
    const palavra = estado.palavra.trim();
    if (palavra === "" && config.palavra.obrigatoria) {
      erros.push({ campo: "palavra", mensagem: "Informe a palavra que foi exortada." });
    } else if (palavra.length > config.palavra.limite) {
      erros.push({ campo: "palavra", mensagem: `A palavra pode ter no máximo ${config.palavra.limite} caracteres.` });
    }
  }

  if (config.encarregados.ativo) {
    const { minimo, maximo, cargos, cidade_uf: pedeCidade } = config.encarregados;
    if (estado.encarregados.length < minimo || estado.encarregados.length > maximo) {
      erros.push({
        campo: "encarregados",
        mensagem: minimo === maximo ? `Informe ${maximo} encarregado(s).` : `Informe de ${minimo} a ${maximo} encarregados.`,
      });
    }
    const nomesVistos = new Set<string>();
    estado.encarregados.forEach((item, indice) => {
      const nomeEnc = limparEspacos(item.nome);
      if (nomeEnc.length < NOME_MINIMO || nomeEnc.length > NOME_MAXIMO) {
        erros.push({ campo: `encarregado_${indice}_nome`, mensagem: `Informe o nome do ${indice + 1}º encarregado.` });
      } else {
        const chave = nomeEnc.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
        if (nomesVistos.has(chave)) {
          erros.push({ campo: `encarregado_${indice}_nome`, mensagem: "Este nome já foi informado em outro encarregado." });
        }
        nomesVistos.add(chave);
      }
      if (cargos.length > 1 && (item.cargo === "" || !cargos.includes(item.cargo))) {
        erros.push({ campo: `encarregado_${indice}_cargo`, mensagem: `Escolha o cargo do ${indice + 1}º encarregado.` });
      }
      if (pedeCidade) {
        const erroCidade = validarCidadeUf(item.cidadeUf);
        if (erroCidade) erros.push({ campo: `encarregado_${indice}_cidade`, mensagem: erroCidade });
      }
    });
  }

  if (config.hinos_executados.ativo) {
    if (estado.hinoAberturaId && usaAbertura(config, estado) && estado.hinosIds.includes(estado.hinoAberturaId)) {
      erros.push({ campo: "hinos", mensagem: "O hino de abertura não conta entre os hinos executados." });
    }
    if (new Set(estado.hinosIds).size !== estado.hinosIds.length) {
      erros.push({ campo: "hinos", mensagem: "O mesmo hino não pode ser executado duas vezes." });
    }
    if (estado.hinosIds.length > MAXIMO_HINOS) {
      erros.push({ campo: "hinos", mensagem: `Informe no máximo ${MAXIMO_HINOS} hinos executados.` });
    }
  }

  // Campos extras do perfil (na ordem da tela)
  for (const c of config.campos_extras) {
    if (!c.ativo) continue;
    const valor = (estado.extras[c.id] ?? "").trim();
    const campo = `extra_${c.id}`;
    if (valor === "") {
      if (c.obrigatorio) erros.push({ campo, mensagem: `Preencha o campo "${c.nome}".` });
    } else if (c.tipo === "texto_curto" && valor.length > EXTRA_CURTO_MAXIMO) {
      erros.push({ campo, mensagem: `O campo "${c.nome}" aceita até ${EXTRA_CURTO_MAXIMO} caracteres.` });
    } else if (c.tipo === "texto_longo" && valor.length > EXTRA_LONGO_MAXIMO) {
      erros.push({ campo, mensagem: `O campo "${c.nome}" aceita até ${EXTRA_LONGO_MAXIMO} caracteres.` });
    } else if (c.tipo === "numero" && numeroDoTexto(valor) === null) {
      erros.push({ campo, mensagem: `O campo "${c.nome}" aceita só número.` });
    } else if (c.tipo === "sim_nao" && valor !== "SIM" && valor !== "NAO") {
      erros.push({ campo, mensagem: `Responda Sim ou Não no campo "${c.nome}".` });
    } else if (c.tipo === "lista" && !c.opcoes.includes(valor)) {
      erros.push({ campo, mensagem: `Escolha uma das opções do campo "${c.nome}".` });
    }
  }
  return erros;
}

/** Valores dos campos extras ativos e preenchidos, já no tipo certo (número, sim/não como verdadeiro/falso). */
function montarExtras(estado: EstadoEnsaioCfg, config: ConfigEnsaio): CargaEnsaioCfg["extras"] {
  const saida: CargaEnsaioCfg["extras"] = {};
  for (const c of config.campos_extras) {
    if (!c.ativo) continue;
    const bruto = (estado.extras[c.id] ?? "").trim();
    if (bruto === "") continue;
    if (c.tipo === "numero") {
      const n = numeroDoTexto(bruto);
      if (n !== null) saida[c.id] = n;
    } else if (c.tipo === "sim_nao") {
      saida[c.id] = bruto === "SIM";
    } else if (c.tipo === "texto_curto") {
      saida[c.id] = limparEspacos(bruto);
    } else {
      saida[c.id] = bruto;
    }
  }
  return saida;
}

/** Monta o que é enviado ao banco (já limpo). Só chame depois de validarEnsaioCfg devolver lista vazia. */
export function montarCargaCfg(estado: EstadoEnsaioCfg, config: ConfigEnsaio): CargaEnsaioCfg {
  const qa = config.quem_atendeu;
  const enc = config.encarregados;
  return {
    atende_cargo: qa.ativo ? ((estado.atendeCargo || null) as CargoAtende | null) : null,
    atende_nome: qa.ativo ? limparEspacos(estado.atendeNome) : null,
    palavra: config.palavra.ativo ? estado.palavra.trim() : null,
    hino_abertura_id: usaAbertura(config, estado) ? estado.hinoAberturaId : null,
    encarregados: enc.ativo
      ? estado.encarregados.map((item) => ({
          nome: limparEspacos(item.nome),
          cidade_uf: enc.cidade_uf ? limparEspacos(item.cidadeUf) : null,
          cargo: item.cargo === "" ? null : item.cargo,
        }))
      : [],
    hinos: config.hinos_executados.ativo ? [...estado.hinosIds] : [],
    extras: montarExtras(estado, config),
  };
}
