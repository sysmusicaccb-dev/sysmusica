/**
 * Sysmusica — Modelo do Relatório do Ensaio (regra pura, sem tela e sem banco). Testado em modelo.test.ts.
 * Transforma a resposta do banco no que a folha mostra. Todos os números e nomes vêm do sistema:
 * Ministério, Músicos e Organistas são as linhas do painel; "Orquestra" = Músicos + Organistas;
 * "Total geral" = Ministério + Orquestra; os instrumentos e as famílias são os de quem toca (o órgão conta em Organistas).
 */
import { escolherDesenho, type ChaveDesenho } from "@/modules/instrumentos/ilustracoes";
import { montarInstrumentos, type DadosPainelTotais } from "@/modules/painel/detalhe";
import { agruparBlocos, formatarDiaDoEvento, formatarHoraDoEvento } from "@/modules/painel/regras";
import { rotuloHino } from "@/modules/hinos/regras";
import { rotuloDoCargoEncarregado, tituloBlocoEncarregados, valorExtraTexto } from "../perfilConfig";
import { rotuloDoCargo } from "../regras";
import type { CargoAtende } from "../tipos";
import { cargosEmUso } from "../regrasPerfil";
import type { HinoRelatorio, RespostaRelatorioEnsaio } from "./tipos";

export interface LinhaFolha {
  rotulo: string;
  qtd: number;
}
export interface BlocoFolha {
  titulo: string;
  linhas: LinhaFolha[];
  total: number;
}
export interface FamiliaFolha {
  nome: string;
  qtd: number;
  percentual: string;
  cor: string;
}
export interface InstrumentoFolha {
  nome: string;
  familia: string;
  qtd: number;
  desenho: ChaveDesenho;
}

export interface ModeloRelatorio {
  titulo: string; // "ENSAIO REGIONAL"
  subtitulo: string; // "GANDÚ - CENTRAL" (cidade - casa de oração)
  dia: string; // "11/10/2026"
  diaSemana: string; // "domingo"
  hora: string; // "09h"
  atendimento: { titulo: string; texto: string } | null;
  palavra: string | null;
  regencia: { titulo: string; nomes: string[] } | null;
  hinos: { abertura: string | null; numeros: string[]; total: number } | null;
  extras: { rotulo: string; valor: string }[];
  familias: FamiliaFolha[];
  totalInstrumentos: number;
  instrumentos: InstrumentoFolha[];
  ministerio: BlocoFolha;
  musicos: BlocoFolha;
  organistas: BlocoFolha;
  orquestra: number;
  totalGeral: number;
  emitidoPor: string;
  geradoEm: string;
  marca: string;
}

/** Cores das famílias (as do modelo: Cordas azul, Madeiras vermelho, Metais amarelo); as outras seguem uma lista fixa. */
const CORES_FIXAS: Record<string, string> = { Cordas: "#2563eb", Madeiras: "#ef4444", Metais: "#f5b400" };
const CORES_OUTRAS = ["#10b981", "#8b5cf6", "#64748b", "#0ea5e9"];

export function corDaFamilia(nome: string, indiceEntreOutras: number): string {
  return CORES_FIXAS[nome] ?? CORES_OUTRAS[indiceEntreOutras % CORES_OUTRAS.length];
}

function numeroDoHino(h: HinoRelatorio): string {
  return rotuloHino(h.categoria, h.numero).replace(/^0+(?=\d)/, ""); // "076" vira "76"; "Coro 3" fica
}

function diaDaSemana(iso: string): string {
  const nome = new Intl.DateTimeFormat("pt-BR", { timeZone: "America/Sao_Paulo", weekday: "long" }).format(new Date(iso));
  return nome.charAt(0).toUpperCase() + nome.slice(1); // "Terça-feira"
}

export function montarModeloRelatorio(
  r: RespostaRelatorioEnsaio,
  extras: { emitidoPor: string; geradoEm: string; marca: string }
): ModeloRelatorio {
  const evento = r.evento;
  const config = r.config;
  const dados = r.dados;

  // ---- Números do painel ----
  const blocos = agruparBlocos(r.painel.linhas);
  const bloco = (codigo: "MINISTERIO" | "MUSICOS" | "ORGANISTAS", titulo: string): BlocoFolha => {
    const b = blocos.find((item) => item.bloco === codigo);
    return {
      titulo,
      total: b?.total ?? 0,
      linhas: (b?.linhas ?? []).map((l) => ({ rotulo: l.rotulo, qtd: l.qtd })),
    };
  };
  const ministerio = bloco("MINISTERIO", "Ministério");
  const musicos = bloco("MUSICOS", "Músicos");
  const organistas = bloco("ORGANISTAS", "Organistas");
  const orquestra = musicos.total + organistas.total;

  const { total: totalInstrumentos, familias, instrumentos } = montarInstrumentos(r.painel as DadosPainelTotais);
  let outras = 0;
  const familiasFolha: FamiliaFolha[] = familias.map((f) => ({
    nome: f.nome,
    qtd: f.qtd,
    percentual: f.percentual,
    cor: corDaFamilia(f.nome, CORES_FIXAS[f.nome] ? 0 : outras++),
  }));
  const instrumentosFolha: InstrumentoFolha[] = (instrumentos ?? []).map((i) => ({
    nome: i.nome,
    familia: i.familia,
    qtd: i.qtd,
    desenho: escolherDesenho(i.nome, i.familia),
  }));

  // ---- Dados do ensaio (só aparecem quando o tipo do evento tem perfil de ensaio) ----
  const temPerfil = config !== null && evento.modelo_ensaio !== null;
  const atendimento =
    temPerfil && config.quem_atendeu.ativo
      ? {
          titulo: config.quem_atendeu.titulo,
          texto:
            dados?.atende_nome
              ? [rotuloDoCargo((dados.atende_cargo ?? "") as CargoAtende | ""), dados.atende_nome].filter((p) => p !== "").join(" ")
              : "—",
        }
      : null;
  const palavra = temPerfil && config.palavra.ativo ? (dados?.palavra?.trim() || "—") : null;
  const cargosEnc = temPerfil && dados ? cargosEmUso(dados.encarregados, config) : (config?.encarregados.cargos ?? []);
  const regencia =
    temPerfil && config.encarregados.ativo
      ? {
          titulo: tituloBlocoEncarregados(cargosEnc),
          nomes: (dados?.encarregados ?? []).map((e) =>
            config.encarregados.cargos.length > 1 && e.cargo ? `${e.nome} – ${rotuloDoCargoEncarregado(e.cargo)}` : e.nome
          ),
        }
      : null;
  const hinos =
    temPerfil && config.hinos_executados.ativo
      ? {
          abertura: dados?.abertura ? numeroDoHino(dados.abertura) : null,
          numeros: (dados?.hinos ?? []).map(numeroDoHino),
          total: dados?.hinos.length ?? 0,
        }
      : null;
  const extrasFolha =
    temPerfil && dados
      ? config.campos_extras
          .filter((c) => c.ativo)
          .map((c) => ({ rotulo: c.nome, valor: valorExtraTexto(c, dados.extras?.[c.id]) }))
          .filter((x) => x.valor !== "")
      : [];

  const subtitulo = [evento.cidade, evento.casa_oracao ?? evento.local].filter((p): p is string => Boolean(p && p.trim())).join(" - ");

  return {
    titulo: evento.tipo.toUpperCase(),
    subtitulo: subtitulo.toUpperCase(),
    dia: formatarDiaDoEvento(evento.data_evento),
    diaSemana: diaDaSemana(evento.data_evento),
    hora: formatarHoraDoEvento(evento.data_evento),
    atendimento,
    palavra,
    regencia,
    hinos,
    extras: extrasFolha,
    familias: familiasFolha,
    totalInstrumentos,
    instrumentos: instrumentosFolha,
    ministerio,
    musicos,
    organistas,
    orquestra,
    totalGeral: ministerio.total + orquestra,
    emitidoPor: extras.emitidoPor,
    geradoEm: extras.geradoEm,
    marca: extras.marca,
  };
}
