"use client";

/**
 * Sysmusica — Registrar Presença (visual do protótipo): passo a passo de 3 etapas para contar quem entra SEM
 * cadastro (candidato, visitante, irmão de outra casa): 1) tipo de participante, 2) categoria, 3) instrumento.
 * Ao lado, o "Resumo em tempo real" do evento (para quem pode ver o Painel ao vivo).
 *
 * Usa as mesmas funções da "Entrada sem cadastro" da Portaria (registrar_entrada_avulsa): o banco confere a
 * portaria (aprovada, dentro da janela de atendimento e da abrangência do usuário), a permissão e as regras.
 * A leitura do QR Code e a busca pelo nome continuam na tela Portaria.
 */
import { useCallback, useEffect, useMemo, useState } from "react";
import { Check, ChevronRight, Info, Keyboard, Music, Plus, QrCode, RefreshCw, Users, type LucideIcon } from "lucide-react";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import Skeleton from "@/components/ui/Skeleton";
import { cn } from "@/lib/cn";
import { formatarDataHora } from "@/lib/datas";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import ResumoTempoReal from "@/modules/painel/components/ResumoTempoReal";
import { buscarPainel } from "@/modules/painel/services/painel";
import type { DadosPainel } from "@/modules/painel/tipos";
import { descreverJanela, janelaDaPortaria } from "@/modules/portarias/janela";
import { listarPortarias } from "@/modules/portarias/services/portarias";
import type { PortariaDetalhada } from "@/modules/portarias/tipos";
import { horaCurta, ordenarPorProximidade } from "../regras";
import { descreverAvulsa, precisaInstrumento, precisaPerguntar, validarEntradaAvulsa } from "../regrasEntrada";
import {
  BLOCOS_ENTRADA,
  SINGULAR_BLOCO,
  familiasDosInstrumentos,
  instrumentosDaFamilia,
  linhasDoBloco,
  passoAtual,
  resumoCategorias,
} from "../regrasPresenca";
import { desfazerEntradaAvulsa, entradasAvulsasDaPortaria, opcoesEntrada, registrarEntradaAvulsa } from "../services/entrada";
import type { BlocoEntrada, EntradaAvulsa, LinhaEntrada, LocalidadeBusca, OpcoesEntrada } from "../tiposEntrada";
import BuscaLocalidade from "./BuscaLocalidade";
import RegistrarComQr from "./RegistrarComQr";
import SelecaoPortaria from "./SelecaoPortaria";

// Mesma chave da tela Portaria: a portaria escolhida vale nas duas telas
const CHAVE_PORTARIA = "sysmusica.atendimento.portaria";

function lerPortariaGuardada(): string | null {
  try {
    return window.sessionStorage.getItem(CHAVE_PORTARIA);
  } catch {
    return null;
  }
}

function guardarPortaria(id: string | null) {
  try {
    if (id) window.sessionStorage.setItem(CHAVE_PORTARIA, id);
    else window.sessionStorage.removeItem(CHAVE_PORTARIA);
  } catch {
    // sem armazenamento disponível: apenas não lembra a escolha
  }
}

// Portaria encerrada não atende ninguém; antes da abertura só o controle total atende (mesma regra da Portaria)
function janelaLiberada(portaria: PortariaDetalhada, agora: number, controleTotal: boolean): boolean {
  const situacao = janelaDaPortaria(portaria.evento_data, agora)?.situacao;
  if (situacao === "encerrada") return false;
  if (controleTotal) return true;
  return situacao === "aberta";
}

const INTERVALO_RESUMO_MS = 10_000;

// Visual de cada tipo de participante (cores do protótipo)
const VISUAL_BLOCO: Record<
  BlocoEntrada,
  { icone: LucideIcon; titulo: string; cartao: string; marcado: string; iconeCor: string; faixa: string }
> = {
  MINISTERIO: {
    icone: Users,
    titulo: "Ministério",
    cartao: "border-brand-200 bg-brand-50",
    marcado: "border-brand-600 ring-2 ring-brand-200",
    iconeCor: "text-brand-600",
    faixa: "bg-brand-50",
  },
  MUSICOS: {
    icone: Music,
    titulo: "Músicos",
    cartao: "border-emerald-200 bg-emerald-50",
    marcado: "border-emerald-600 ring-2 ring-emerald-200",
    iconeCor: "text-emerald-600",
    faixa: "bg-emerald-50",
  },
  ORGANISTAS: {
    icone: Keyboard,
    titulo: "Organistas",
    cartao: "border-amber-200 bg-amber-50",
    marcado: "border-amber-600 ring-2 ring-amber-200",
    iconeCor: "text-amber-600",
    faixa: "bg-amber-50",
  },
};

const classeSelect =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function RegistrarPresenca() {
  const { pode } = useSessao();
  const controleTotal = pode("portarias.controle_total");
  const verResumo = pode("painel.visualizar");
  const podeRegistrar = pode("portaria.registrar");

  // ---------- Portaria ----------
  const [portarias, setPortarias] = useState<PortariaDetalhada[]>([]);
  const [portariaId, setPortariaId] = useState<string | null>(null);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [agora, setAgora] = useState(0); // relógio da tela (30 s): abre e fecha a janela sozinho
  const [opcoes, setOpcoes] = useState<OpcoesEntrada | null>(null);
  const [avulsas, setAvulsas] = useState<EntradaAvulsa[]>([]);
  const [dados, setDados] = useState<DadosPainel | null>(null); // resumo em tempo real

  // ---------- Passo a passo ----------
  const [bloco, setBloco] = useState<BlocoEntrada | null>(null);
  const [linhaCodigo, setLinhaCodigo] = useState("");
  const [toca, setToca] = useState<boolean | null>(null);
  const [familia, setFamilia] = useState("");
  const [instrumentoId, setInstrumentoId] = useState("");
  const [localidade, setLocalidade] = useState<LocalidadeBusca | null>(null);
  const [outra, setOutra] = useState(false);
  const [texto, setTexto] = useState("");
  const [uf, setUf] = useState("");
  const [cidade, setCidade] = useState("");
  const [versaoOrigem, setVersaoOrigem] = useState(0); // recria o campo de origem ao limpar
  const [salvando, setSalvando] = useState(false);
  const [erroForm, setErroForm] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  const [qrAberto, setQrAberto] = useState(false); // popup "Registrar Presença com QR Code"

  const disponiveis = useMemo(
    () => portarias.filter((portaria) => janelaDaPortaria(portaria.evento_data, agora)?.situacao !== "encerrada"),
    [portarias, agora]
  );
  const portaria = disponiveis.find((item) => item.id === portariaId) ?? null;
  const janela = portaria ? janelaDaPortaria(portaria.evento_data, agora) : null;
  const eventoId = portaria?.evento_id ?? null;

  const carregar = useCallback(async () => {
    try {
      const aprovadas = (await listarPortarias()).filter((item) => item.status === "APROVADA");
      const agoraMs = Date.now();
      const ordenadas = ordenarPorProximidade(aprovadas, agoraMs);
      setPortarias(ordenadas);
      setAgora(agoraMs);
      const liberadas = ordenadas.filter((item) => janelaLiberada(item, agoraMs, controleTotal));
      // Mantém a atual, ou a lembrada, ou escolhe sozinho quando só há uma
      setPortariaId((atual) => {
        if (atual && liberadas.some((item) => item.id === atual)) return atual;
        const guardada = lerPortariaGuardada();
        if (guardada && liberadas.some((item) => item.id === guardada)) return guardada;
        return liberadas.length === 1 ? liberadas[0].id : null;
      });
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar as portarias:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar as portarias.");
    } finally {
      setCarregando(false);
    }
  }, [controleTotal]);

  const carregarAvulsas = useCallback(async (id: string) => {
    try {
      setAvulsas(await entradasAvulsasDaPortaria(id));
    } catch (e) {
      // A lista é apenas informativa: se falhar, o registro continua funcionando
      console.error("Falha ao carregar as entradas sem cadastro:", e);
    }
  }, []);

  const atualizarResumo = useCallback(async (id: string) => {
    try {
      setDados(await buscarPainel(id));
    } catch {
      // mantém os últimos números; a próxima rodada tenta de novo
    }
  }, []);

  /* eslint-disable react-hooks/set-state-in-effect */
  useEffect(() => {
    void carregar();
  }, [carregar]);

  // Linhas (categorias) e instrumentos: uma vez só
  useEffect(() => {
    opcoesEntrada()
      .then(setOpcoes)
      .catch((e: unknown) => console.error("Falha ao carregar as opções da entrada:", e));
  }, []);

  // Últimas entradas da portaria escolhida
  useEffect(() => {
    if (portariaId) void carregarAvulsas(portariaId);
  }, [portariaId, carregarAvulsas]);

  // Resumo em tempo real: atualiza a cada 10 s (com a aba em segundo plano não consulta)
  useEffect(() => {
    if (!eventoId || !verResumo) return;
    let ativo = true;
    const buscar = async () => {
      if (document.hidden) return;
      try {
        const resposta = await buscarPainel(eventoId);
        if (ativo) setDados(resposta);
      } catch {
        // mantém os últimos números
      }
    };
    void buscar();
    const temporizador = setInterval(() => void buscar(), INTERVALO_RESUMO_MS);
    return () => {
      ativo = false;
      clearInterval(temporizador);
    };
  }, [eventoId, verResumo]);

  // Se a portaria em atendimento encerrar, sai da tela na hora
  useEffect(() => {
    if (portariaId && portarias.length > 0 && !disponiveis.some((item) => item.id === portariaId)) {
      setPortariaId(null);
      guardarPortaria(null);
      setAviso("Esta portaria foi encerrada e saiu da tela.");
    }
  }, [portariaId, portarias, disponiveis]);
  /* eslint-enable react-hooks/set-state-in-effect */

  // Relógio da tela
  useEffect(() => {
    const temporizador = setInterval(() => setAgora(Date.now()), 30_000);
    return () => clearInterval(temporizador);
  }, []);

  function escolherPortaria(id: string | null) {
    setAvulsas([]);
    setDados(null);
    limpar(true);
    setPortariaId(id);
    guardarPortaria(id);
  }

  // ---------- Escolhas do passo a passo ----------
  const linhas: LinhaEntrada[] = opcoes?.linhas ?? [];
  const instrumentos = opcoes?.instrumentos ?? [];
  const linha = linhas.find((item) => item.codigo === linhaCodigo) ?? null;
  const perguntar = precisaPerguntar(linha);
  const pedirInstrumento = precisaInstrumento(linha, toca);
  const passo = passoAtual(bloco, linhaCodigo);

  function escolherBloco(novo: BlocoEntrada) {
    setBloco(novo);
    setLinhaCodigo("");
    setToca(null);
    setFamilia("");
    setInstrumentoId("");
    setErroForm(null);
  }

  // Trocar a categoria limpa as respostas que dependem dela
  function escolherLinha(codigo: string) {
    setLinhaCodigo(codigo);
    setToca(null);
    setFamilia("");
    setInstrumentoId("");
    setErroForm(null);
  }

  // "Limpar": volta ao começo (mantendo o tipo de participante, para o próximo registro, quando manterBloco = true)
  function limpar(zerarBloco = false) {
    if (zerarBloco) setBloco(null);
    setLinhaCodigo("");
    setToca(null);
    setFamilia("");
    setInstrumentoId("");
    setLocalidade(null);
    setOutra(false);
    setTexto("");
    setUf("");
    setCidade("");
    setVersaoOrigem((v) => v + 1);
    setErroForm(null);
  }

  async function registrar() {
    if (!portaria || salvando) return;

    const mensagem = validarEntradaAvulsa({ linha, toca, instrumentoId, outraLocalidade: false, localidadeTexto: "" });
    if (mensagem) return setErroForm(mensagem);
    // A Casa de Oração de origem é obrigatória (não existe mais a opção "não está na lista")
    if (!localidade) return setErroForm("Escolha a Casa de Oração de origem.");

    setSalvando(true);
    setErroForm(null);
    try {
      await registrarEntradaAvulsa(portaria.id, {
        linhaCodigo,
        toca: perguntar ? toca : null,
        instrumentoId: pedirInstrumento ? instrumentoId : null,
        origemCasaOracaoId: localidade?.casa_oracao_id ?? null,
        origemTexto: null,
      });
      setAviso(`Presença registrada: ${linha?.rotulo ?? "participante"}.`);
      limpar(); // mantém o tipo de participante: o próximo registro costuma ser do mesmo tipo
      await Promise.all([carregarAvulsas(portaria.id), verResumo ? atualizarResumo(portaria.evento_id) : Promise.resolve()]);
    } catch (e) {
      setErroForm(e instanceof Error ? e.message : "Não foi possível registrar a presença.");
    } finally {
      setSalvando(false);
    }
  }

  async function desfazer(id: string) {
    if (!portaria || !window.confirm("Desfazer esta entrada?")) return;
    try {
      await desfazerEntradaAvulsa(id);
      setAviso("Entrada desfeita.");
      await Promise.all([carregarAvulsas(portaria.id), verResumo ? atualizarResumo(portaria.evento_id) : Promise.resolve()]);
    } catch (e) {
      setErroForm(e instanceof Error ? e.message : "Não foi possível desfazer a entrada.");
    }
  }

  // ---------- Estados da tela ----------
  if (carregando) {
    return (
      <div role="status" aria-live="polite" className="space-y-3">
        <span className="sr-only">Carregando...</span>
        <Skeleton className="h-16 rounded-xl" />
        <Skeleton className="h-64 rounded-2xl" />
      </div>
    );
  }
  if (erro) {
    return (
      <ErrorState
        titulo="Não foi possível carregar as portarias."
        mensagem={erro}
        onTentarNovamente={() => {
          setCarregando(true);
          void carregar();
        }}
      />
    );
  }
  if (disponiveis.length === 0) {
    return (
      <EmptyState
        titulo="Nenhuma portaria aprovada disponível para você."
        descricao="Só é possível registrar presença em portarias aprovadas, dentro da sua abrangência. Peça a criação e a aprovação da portaria do evento."
      />
    );
  }
  if (!portaria) {
    return (
      <SelecaoPortaria portarias={disponiveis} agora={agora} controleTotal={controleTotal} onEscolher={(id) => escolherPortaria(id)} />
    );
  }

  const visual = bloco ? VISUAL_BLOCO[bloco] : null;
  const linhasBloco = bloco ? linhasDoBloco(linhas, bloco) : [];
  const familias = familiasDosInstrumentos(instrumentos);
  const instrumentosFamilia = instrumentosDaFamilia(instrumentos, familia);
  const passos = [
    { n: 1, titulo: "Tipo de participante", sub: "Escolha a aba correta" },
    { n: 2, titulo: "Categoria", sub: "Selecione a categoria" },
    { n: 3, titulo: "Instrumento", sub: "Quando aplicável" },
  ] as const;

  return (
    <div className="space-y-5">
      <div className={cn("grid items-start gap-5", verResumo && "lg:grid-cols-[minmax(0,1fr)_22rem]")}>
        <div className="min-w-0 space-y-5">
          {/* Portaria em atendimento */}
          <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 shadow-sm">
            <div className="min-w-0">
              <p className="text-xs font-semibold uppercase tracking-wide text-emerald-700">Portaria em atendimento</p>
              <p className="text-sm font-semibold text-slate-900">
                {portaria.evento_data ? formatarDataHora(portaria.evento_data) : "Evento removido"} ·{" "}
                {[portaria.evento_tipo, portaria.evento_local, portaria.cidade].filter(Boolean).join(" · ")}
              </p>
              {janela && agora > 0 && (
                <p className={"text-xs font-medium " + (janela.situacao === "aberta" ? "text-emerald-700" : "text-amber-700")}>
                  {descreverJanela(janela, agora)}
                  {janela.situacao !== "aberta" && " — fora do horário: o controle total permite o registro e ele fica na Auditoria."}
                </p>
              )}
            </div>
            {disponiveis.length > 1 && (
              <button
                type="button"
                onClick={() => escolherPortaria(null)}
                className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-50"
              >
                Trocar portaria
              </button>
            )}
          </div>

          {/* Passos */}
          <ol className="flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-3 shadow-sm" aria-label="Passos do registro">
            {passos.map((item, i) => (
              <li key={item.n} className="flex min-w-0 flex-1 items-center gap-3" aria-current={passo === item.n ? "step" : undefined}>
                <span
                  className={cn(
                    "flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-sm font-bold",
                    passo >= item.n ? "bg-brand-700 text-white" : "bg-slate-200 text-slate-600"
                  )}
                >
                  {item.n}
                </span>
                <span className="hidden min-w-0 sm:block">
                  <span className="block truncate text-sm font-semibold text-slate-900">{item.titulo}</span>
                  <span className="block truncate text-xs text-slate-500">{item.sub}</span>
                </span>
                {i < passos.length - 1 && <ChevronRight className="ml-auto h-5 w-5 shrink-0 text-slate-400" aria-hidden="true" />}
              </li>
            ))}
          </ol>

          {/* 1. Tipo de participante */}
          <div className="grid gap-3 sm:grid-cols-3" role="radiogroup" aria-label="Tipo de participante">
            {BLOCOS_ENTRADA.map((item) => {
              const v = VISUAL_BLOCO[item];
              const Icone = v.icone;
              const ativo = bloco === item;
              return (
                <button
                  key={item}
                  type="button"
                  role="radio"
                  aria-checked={ativo}
                  onClick={() => escolherBloco(item)}
                  disabled={opcoes === null}
                  className={cn(
                    "relative flex flex-col items-center gap-1 rounded-xl border px-3 py-4 text-center transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:opacity-60",
                    v.cartao,
                    ativo && v.marcado
                  )}
                >
                  {ativo && (
                    <span className="absolute right-2 top-2 flex h-6 w-6 items-center justify-center rounded-full bg-emerald-600 text-white">
                      <Check className="h-4 w-4" aria-hidden="true" />
                    </span>
                  )}
                  <Icone className={cn("h-9 w-9", v.iconeCor)} aria-hidden="true" />
                  <span className="text-lg font-bold text-slate-900">{v.titulo}</span>
                  <span className="text-xs text-slate-600">{resumoCategorias(linhas, item)}</span>
                </button>
              );
            })}
          </div>

          {/* 2 e 3. Categoria e instrumento (só depois de escolher o tipo) */}
          {bloco && visual ? (
            <section className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
              <header className={cn("flex items-center gap-3 border-b border-slate-200 px-5 py-4", visual.faixa)}>
                {(() => {
                  const Icone = visual.icone;
                  return <Icone className={cn("h-9 w-9 shrink-0", visual.iconeCor)} aria-hidden="true" />;
                })()}
                <div>
                  <h2 className="text-xl font-bold text-slate-900">Aba {visual.titulo}</h2>
                  <p className="text-sm text-slate-600">
                    Selecione a categoria e, quando aplicável, a família e o instrumento.
                  </p>
                </div>
              </header>

              <div className="space-y-6 p-5">
                <div className="grid gap-4 md:grid-cols-[minmax(0,1fr)_14rem]">
                  <fieldset>
                    <legend className="mb-2 text-lg font-bold text-slate-900">1. Categoria do {SINGULAR_BLOCO[bloco]}</legend>
                    <div className="divide-y divide-slate-100 rounded-lg border border-slate-200">
                      {linhasBloco.map((item) => {
                        const marcado = linhaCodigo === item.codigo;
                        return (
                          <label
                            key={item.codigo}
                            className={cn(
                              "flex cursor-pointer items-center gap-3 px-4 py-2.5 text-sm transition hover:bg-slate-50",
                              marcado ? "bg-brand-50 font-semibold text-slate-900" : "text-slate-700"
                            )}
                          >
                            <input
                              type="radio"
                              name="categoria-presenca"
                              checked={marcado}
                              onChange={() => escolherLinha(item.codigo)}
                              disabled={salvando}
                              className="h-5 w-5 border-slate-300 text-brand-600 focus:ring-brand-300"
                            />
                            {item.rotulo}
                          </label>
                        );
                      })}
                    </div>
                  </fieldset>

                  <aside className="rounded-lg bg-brand-50 p-4 text-sm text-slate-700">
                    <p className="flex items-start gap-2">
                      <Info className="mt-0.5 h-4 w-4 shrink-0 text-brand-600" aria-hidden="true" />
                      Nesta aba são registrados:
                    </p>
                    <ul className="mt-2 list-disc space-y-1 pl-9 font-medium">
                      {linhasBloco.map((item) => (
                        <li key={item.codigo}>{item.rotulo}</li>
                      ))}
                    </ul>
                  </aside>
                </div>

                {/* Instrumento: só quando a categoria pede */}
                {linha && (perguntar || pedirInstrumento) ? (
                  <div className="space-y-3">
                    <h3 className="text-lg font-bold text-slate-900">2. Selecionar família e instrumento</h3>

                    {perguntar && (
                      <fieldset disabled={salvando} className="space-y-2">
                        <legend className="text-sm font-semibold text-slate-800">Vai tocar?</legend>
                        <div className="grid max-w-md grid-cols-2 gap-2">
                          {[
                            { valor: true, rotulo: "Sim, vai tocar" },
                            { valor: false, rotulo: "Não vai tocar" },
                          ].map((opcao) => (
                            <label
                              key={String(opcao.valor)}
                              className={cn(
                                "flex cursor-pointer items-center justify-center rounded-lg border px-3 py-3 text-sm font-medium transition",
                                toca === opcao.valor
                                  ? "border-brand-600 bg-brand-50 text-brand-700"
                                  : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50"
                              )}
                            >
                              <input
                                type="radio"
                                name="toca-presenca"
                                checked={toca === opcao.valor}
                                onChange={() => {
                                  setToca(opcao.valor);
                                  if (!opcao.valor) {
                                    setFamilia("");
                                    setInstrumentoId("");
                                  }
                                }}
                                className="sr-only"
                              />
                              {opcao.rotulo}
                            </label>
                          ))}
                        </div>
                      </fieldset>
                    )}

                    {pedirInstrumento && (
                      <div className="grid gap-4 sm:grid-cols-2">
                        <div className="space-y-1.5">
                          <label htmlFor="presenca-familia" className="text-sm font-semibold text-slate-800">
                            Família musical
                          </label>
                          <select
                            id="presenca-familia"
                            value={familia}
                            onChange={(e) => {
                              setFamilia(e.target.value);
                              setInstrumentoId("");
                            }}
                            disabled={salvando}
                            className={classeSelect}
                          >
                            <option value="">Selecione a família</option>
                            {familias.map((nome) => (
                              <option key={nome} value={nome}>
                                {nome}
                              </option>
                            ))}
                          </select>
                        </div>
                        <div className="space-y-1.5">
                          <label htmlFor="presenca-instrumento" className="text-sm font-semibold text-slate-800">
                            Instrumento
                          </label>
                          <select
                            id="presenca-instrumento"
                            value={instrumentoId}
                            onChange={(e) => setInstrumentoId(e.target.value)}
                            disabled={salvando || familia === ""}
                            className={classeSelect}
                          >
                            <option value="">{familia === "" ? "Escolha primeiro a família" : "Selecione o instrumento"}</option>
                            {instrumentosFamilia.map((item) => (
                              <option key={item.id} value={item.id}>
                                {item.nome}
                              </option>
                            ))}
                          </select>
                        </div>
                      </div>
                    )}
                  </div>
                ) : linha ? (
                  <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
                    Esta categoria não precisa de instrumento.
                  </p>
                ) : null}

                {/* Origem (obrigatória, sempre aberta): o título "Casa de Oração (obrigatória)" vem do próprio campo */}
                <section className="rounded-lg border border-slate-200 px-4 py-3">
                  <div key={versaoOrigem}>
                    <BuscaLocalidade
                      escolhida={localidade}
                      onEscolher={setLocalidade}
                      outra={outra}
                      onOutra={setOutra}
                      texto={texto}
                      onTexto={setTexto}
                      uf={uf}
                      onUf={setUf}
                      cidade={cidade}
                      onCidade={setCidade}
                      desabilitado={salvando}
                      obrigatoria
                    />
                  </div>
                </section>

                {erroForm && (
                  <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
                    {erroForm}
                  </p>
                )}
                {!podeRegistrar && (
                  <p role="status" className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900">
                    Você pode ver esta tela, mas não tem permissão para registrar presenças.
                  </p>
                )}

                <div className="grid gap-3 sm:grid-cols-[1fr_2fr]">
                  <button
                    type="button"
                    onClick={() => limpar()}
                    disabled={salvando}
                    className="inline-flex items-center justify-center gap-2 rounded-lg bg-slate-100 px-4 py-3 text-base font-semibold text-slate-800 transition hover:bg-slate-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:opacity-50"
                  >
                    <RefreshCw className="h-5 w-5" aria-hidden="true" />
                    Limpar
                  </button>
                  <button
                    type="button"
                    onClick={() => void registrar()}
                    disabled={salvando || !podeRegistrar}
                    className="inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-600 px-4 py-3 text-base font-semibold text-white shadow-sm transition hover:bg-emerald-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-emerald-300 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    <span className="flex h-6 w-6 items-center justify-center rounded-full bg-[rgb(255_255_255/0.25)]" aria-hidden="true">
                      <Plus className="h-4 w-4" />
                    </span>
                    {salvando ? "Registrando..." : "Registrar Presença sem Cadastro"}
                  </button>
                </div>
              </div>
            </section>
          ) : (
            <p className="rounded-xl border border-dashed border-slate-300 bg-white px-4 py-8 text-center text-sm text-slate-500">
              Escolha acima o tipo de participante para continuar.
            </p>
          )}

          {/* Últimas entradas registradas aqui (dá para desfazer) */}
          {avulsas.length > 0 && (
            <section className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
              <h2 className="text-sm font-semibold text-slate-900">Últimas entradas sem cadastro</h2>
              <p className="mt-1 text-xs text-slate-500">{avulsas[0]?.total ?? avulsas.length} registro(s) nesta portaria</p>
              <ul className="mt-3 divide-y divide-slate-100">
                {avulsas.map((entrada) => (
                  <li key={entrada.id} className="flex items-center justify-between gap-3 py-2">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium text-slate-900">{descreverAvulsa(entrada)}</p>
                      <p className="truncate text-xs text-slate-500">{entrada.origem ?? "Localidade não informada"}</p>
                    </div>
                    <div className="flex shrink-0 items-center gap-3">
                      <span className="text-sm tabular-nums text-slate-600">{horaCurta(entrada.hora_entrada)}</span>
                      <button
                        type="button"
                        onClick={() => void desfazer(entrada.id)}
                        className="text-xs font-semibold text-red-700 hover:underline"
                      >
                        Desfazer
                      </button>
                    </div>
                  </li>
                ))}
              </ul>
            </section>
          )}

          {/* Membro cadastrado: lê o QR Code (ou busca pelo nome) em um popup e volta para esta tela */}
          <button
            type="button"
            onClick={() => setQrAberto(true)}
            disabled={!podeRegistrar || opcoes === null}
            className="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-brand-600 bg-white px-4 py-3 text-base font-semibold text-brand-700 shadow-sm transition hover:bg-brand-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:cursor-not-allowed disabled:opacity-60"
          >
            <QrCode className="h-5 w-5" aria-hidden="true" />
            Registrar Presença com QR Code
          </button>
        </div>

        {verResumo && (
          <aside className="min-w-0 lg:sticky lg:top-20">
            {dados ? (
              <ResumoTempoReal dados={dados} />
            ) : (
              <div role="status" aria-live="polite" className="space-y-3">
                <span className="sr-only">Carregando o resumo...</span>
                <Skeleton className="h-20 rounded-xl" />
                <Skeleton className="h-64 rounded-xl" />
              </div>
            )}
          </aside>
        )}
      </div>

      <Drawer
        aberto={qrAberto}
        onFechar={() => setQrAberto(false)}
        titulo="Registrar Presença com QR Code"
        descricao="Aponte a câmera para o QR Code do membro (ou busque pelo nome), confira a foto e confirme."
      >
        {qrAberto && portaria && (
          <RegistrarComQr
            portariaId={portaria.id}
            opcoes={opcoes}
            onRegistrado={async (mensagem) => {
              setQrAberto(false); // registrou: fecha o popup e volta para esta tela
              setAviso(mensagem);
              if (verResumo) await atualizarResumo(portaria.evento_id);
            }}
          />
        )}
      </Drawer>

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </div>
  );
}
