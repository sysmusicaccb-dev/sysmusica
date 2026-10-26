"use client";

/**
 * Sysmusica — Atendimento da portaria: escolher a portaria, ler o QR Code (ou buscar pelo nome),
 * conferir a fotografia e os dados e registrar a entrada.
 *
 * Só aparecem portarias APROVADAS dentro da abrangência do usuário (o banco filtra). Toda consulta
 * e todo registro são conferidos de novo no banco, que também grava quem registrou e a origem.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import Skeleton from "@/components/ui/Skeleton";
import { formatarDataHora } from "@/lib/datas";
import { listarPortarias } from "@/modules/portarias/services/portarias";
import { descreverJanela, janelaDaPortaria } from "@/modules/portarias/janela";
import type { PortariaDetalhada } from "@/modules/portarias/tipos";
import { ordenarPorProximidade, pareceQrSysMusica } from "../regras";
import { buscarMembroPorQr, entradasDaPortaria, excluirEntrada, recarregarCartao, registrarEntrada } from "../services/atendimento";
import { valoresDaEntrada } from "../regrasEntrada";
import { desfazerEntradaAvulsa, entradasAvulsasDaPortaria, infoEntrada, opcoesEntrada } from "../services/entrada";
import type { CartaoMembro, EntradaRecente, OrigemEntrada } from "../tipos";
import type { EntradaAvulsa, EscolhaToca, InfoEntrada, OpcoesEntrada } from "../tiposEntrada";
import BuscaPorNome from "./BuscaPorNome";
import CartaoConferencia from "./CartaoConferencia";
import EntradasRecentes from "./EntradasRecentes";
import EntradaSemCadastro from "./EntradaSemCadastro";
import LeitorQr from "./LeitorQr";
import SelecaoPortaria from "./SelecaoPortaria";

// Lembra a portaria escolhida se a página for recarregada (só vale se ela ainda estiver disponível)
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

// Portaria encerrada (passou de 3h depois do início) não atende ninguém, nem o Administrador: ela sai da tela.
// Antes da abertura, só o controle total atende (com registro na Auditoria). Depois do encerramento, o Administrador
// só corrige registros em "Registros e correções".
function janelaLiberada(portaria: PortariaDetalhada, agora: number, controleTotal: boolean): boolean {
  const situacao = janelaDaPortaria(portaria.evento_data, agora)?.situacao;
  if (situacao === "encerrada") return false;
  if (controleTotal) return true;
  return situacao === "aberta";
}

export default function AtendimentoPortaria() {
  // O link para "Registros e correções" só aparece para quem pode editar ou excluir registros
  const { pode } = useSessao();
  const podeCorrigir = pode("portaria.editar") || pode("portaria.excluir");
  const controleTotal = pode("portarias.controle_total");

  const [portarias, setPortarias] = useState<PortariaDetalhada[]>([]);
  const [portariaId, setPortariaId] = useState<string | null>(null);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [entradas, setEntradas] = useState<EntradaRecente[]>([]);
  const [cartao, setCartao] = useState<{ membro: CartaoMembro; origem: OrigemEntrada } | null>(null);
  const [consultando, setConsultando] = useState(false);
  const [registrando, setRegistrando] = useState(false);
  const [erroCartao, setErroCartao] = useState<string | null>(null);
  const [erroLeitura, setErroLeitura] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  const [semCadastro, setSemCadastro] = useState(false); // janela da entrada sem cadastro
  const [avulsas, setAvulsas] = useState<EntradaAvulsa[]>([]); // entradas sem cadastro desta portaria
  const [opcoes, setOpcoes] = useState<OpcoesEntrada | null>(null); // linhas do painel e instrumentos
  const [info, setInfo] = useState<InfoEntrada | null>(null); // como o membro conferido será contado
  const [escolha, setEscolha] = useState<EscolhaToca>({ toca: null, instrumentoId: "" }); // resposta de "Vai tocar?"
  // Cada entrada registrada muda esta chave: a busca por nome é recriada vazia, pronta para o próximo membro
  const [chaveBusca, setChaveBusca] = useState(0);
  const refBusca = useRef<HTMLDivElement>(null);
  const [agora, setAgora] = useState(0); // relógio da tela (atualiza a cada 30 s) para abrir e fechar a janela sozinho

  // Portarias que ainda podem aparecer: as ENCERRADAS saem da lista sozinhas (o relógio recalcula a cada 30 s)
  const disponiveis = useMemo(
    () => portarias.filter((portaria) => janelaDaPortaria(portaria.evento_data, agora)?.situacao !== "encerrada"),
    [portarias, agora]
  );

  // Portarias aprovadas disponíveis, da mais próxima do horário atual para a mais distante
  const carregar = useCallback(async () => {
    try {
      const aprovadas = (await listarPortarias()).filter((portaria) => portaria.status === "APROVADA");
      const agoraMs = Date.now();
      const ordenadas = ordenarPorProximidade(aprovadas, agoraMs);
      setPortarias(ordenadas);
      setAgora(agoraMs);
      const liberadas = ordenadas.filter((portaria) => janelaLiberada(portaria, agoraMs, controleTotal));

      // Seleção: mantém a atual, ou a lembrada, ou escolhe sozinho quando só há uma
      setPortariaId((atual) => {
        if (atual && liberadas.some((portaria) => portaria.id === atual)) return atual;
        const guardada = lerPortariaGuardada();
        if (guardada && liberadas.some((portaria) => portaria.id === guardada)) return guardada;
        return liberadas.length === 1 ? liberadas[0].id : null;
      });
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar as portarias do atendimento:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar as portarias.");
    } finally {
      setCarregando(false);
    }
  }, [controleTotal]);

  const carregarEntradas = useCallback(async (id: string) => {
    try {
      const [lista, semCadastroLista] = await Promise.all([entradasDaPortaria(id), entradasAvulsasDaPortaria(id)]);
      setEntradas(lista);
      setAvulsas(semCadastroLista);
    } catch (e) {
      // A lista é apenas informativa: se falhar, o atendimento continua
      console.error("Falha ao carregar as entradas:", e);
    }
  }, []);

  /* eslint-disable react-hooks/set-state-in-effect */
  useEffect(() => {
    void carregar();
  }, [carregar]);

  // Ao ter uma portaria escolhida, busca as últimas entradas dela
  useEffect(() => {
    if (portariaId) void carregarEntradas(portariaId);
  }, [portariaId, carregarEntradas]);

  // Linhas do painel e instrumentos (uma vez só): usados na pergunta "Vai tocar?" e na entrada sem cadastro
  useEffect(() => {
    opcoesEntrada()
      .then(setOpcoes)
      .catch((e: unknown) => console.error("Falha ao carregar as opções da entrada:", e));
  }, []);

  // Se a portaria em atendimento encerrar, sai da tela na hora: fecha a conferência e a entrada sem cadastro
  useEffect(() => {
    if (portariaId && portarias.length > 0 && !disponiveis.some((portaria) => portaria.id === portariaId)) {
      setCartao(null);
      setSemCadastro(false);
      setPortariaId(null);
      guardarPortaria(null);
      setAviso("Esta portaria foi encerrada e saiu da tela. Só o Administrador pode corrigir registros.");
    }
  }, [portariaId, portarias, disponiveis]);
  /* eslint-enable react-hooks/set-state-in-effect */

  // O aviso de leitura some sozinho depois de alguns segundos
  useEffect(() => {
    if (!erroLeitura) return;
    const temporizador = setTimeout(() => setErroLeitura(null), 5000);
    return () => clearTimeout(temporizador);
  }, [erroLeitura]);

  // Relógio da tela: a cada 30 segundos recalcula quais portarias estão com a janela aberta
  useEffect(() => {
    const temporizador = setInterval(() => setAgora(Date.now()), 30_000);
    return () => clearInterval(temporizador);
  }, []);

  // Depois de registrar uma entrada: devolve o cursor ao campo de busca (que já está vazio)
  useEffect(() => {
    if (chaveBusca === 0) return;
    const temporizador = setTimeout(() => refBusca.current?.querySelector("input")?.focus(), 150);
    return () => clearTimeout(temporizador);
  }, [chaveBusca]);

  function tentarNovamente() {
    setCarregando(true);
    void carregar();
  }

  function escolherPortaria(id: string | null) {
    setEntradas([]);
    setAvulsas([]);
    setCartao(null);
    setErroLeitura(null);
    setPortariaId(id);
    guardarPortaria(id);
  }

  // QR Code lido: consulta o membro e abre a conferência
  async function aoLerQr(texto: string) {
    if (!portariaId || cartao || consultando) return;
    setErroLeitura(null);

    if (!pareceQrSysMusica(texto)) {
      setErroLeitura("Este QR Code não é do Sysmusica.");
      return;
    }

    setConsultando(true);
    try {
      const membro = await buscarMembroPorQr(portariaId, texto);
      await abrirCartao(membro, "QR");
    } catch (e) {
      setErroLeitura(e instanceof Error ? e.message : "Não foi possível ler o QR Code.");
    } finally {
      setConsultando(false);
    }
  }

  // Foto tirada na conferência: recarrega os dados do cartão (a foto já aparece)
  async function aoSalvarFotoNoCartao() {
    if (!portariaId || !cartao) return;
    const atualizado = await recarregarCartao(portariaId, cartao.membro.membro_id);
    setCartao({ membro: atualizado, origem: cartao.origem });
  }

  // Abre a conferência: antes, consulta se a pessoa precisa responder "Vai tocar?"
  async function abrirCartao(membro: CartaoMembro, origem: OrigemEntrada) {
    if (!portariaId) return;
    try {
      setInfo(await infoEntrada(portariaId, membro.membro_id));
      setEscolha({ toca: null, instrumentoId: "" });
      setErroCartao(null);
      setCartao({ membro, origem });
    } catch (e) {
      setErroLeitura(e instanceof Error ? e.message : "Não foi possível abrir a conferência.");
    }
  }

  // Membro localizado pelo nome: abre a conferência
  function aoEscolherPorNome(membro: CartaoMembro) {
    void abrirCartao(membro, "MANUAL");
  }

  // Entrada sem cadastro registrada: fecha a janela e atualiza as listas
  async function aoRegistrarSemCadastro(descricao: string) {
    setSemCadastro(false);
    setAviso(`Entrada sem cadastro registrada: ${descricao}`);
    if (portariaId) await carregarEntradas(portariaId);
  }

  // Exclui um registro de presença (pede confirmação; o banco confere a permissão e a região)
  async function excluirRegistro(entrada: EntradaRecente) {
    if (!portariaId) return;
    if (!window.confirm(`Excluir o registro de presença de ${entrada.membro_nome}? Ele some da portaria e dos relatórios.`)) return;
    try {
      await excluirEntrada(entrada.presenca_id);
      setAviso(`Registro excluído: ${entrada.membro_nome}`);
      await carregarEntradas(portariaId);
    } catch (e) {
      setErroLeitura(e instanceof Error ? e.message : "Não foi possível excluir o registro.");
    }
  }

  // Desfaz uma entrada sem cadastro (pede confirmação)
  async function desfazerSemCadastro(id: string) {
    if (!portariaId || !window.confirm("Desfazer esta entrada sem cadastro?")) return;
    try {
      await desfazerEntradaAvulsa(id);
      setAviso("Entrada desfeita.");
      await carregarEntradas(portariaId);
    } catch (e) {
      setErroLeitura(e instanceof Error ? e.message : "Não foi possível desfazer a entrada.");
    }
  }

  async function confirmar() {
    if (!portariaId || !cartao || registrando) return;
    setRegistrando(true);
    setErroCartao(null);
    try {
      const valores = valoresDaEntrada(info, escolha);
      await registrarEntrada(portariaId, cartao.membro.membro_id, cartao.origem, valores.toca, valores.instrumentoId);
      setAviso(`Entrada registrada: ${cartao.membro.nome}`);
      setCartao(null);
      setChaveBusca((n) => n + 1); // o nome sai do resultado e a busca fica limpa para o próximo
      await carregarEntradas(portariaId);
    } catch (e) {
      setErroCartao(e instanceof Error ? e.message : "Não foi possível registrar a entrada.");
    } finally {
      setRegistrando(false);
    }
  }

  const portaria = disponiveis.find((item) => item.id === portariaId) ?? null;
  const janela = portaria ? janelaDaPortaria(portaria.evento_data, agora) : null;

  return (
    <div className="space-y-6">
      {carregando ? (
        <div role="status" aria-live="polite" className="space-y-3">
          <span className="sr-only">Carregando portarias...</span>
          <Skeleton className="h-20 rounded-2xl" />
          <Skeleton className="h-64 rounded-2xl" />
        </div>
      ) : erro ? (
        <ErrorState titulo="Não foi possível carregar as portarias." mensagem={erro} onTentarNovamente={tentarNovamente} />
      ) : disponiveis.length === 0 ? (
        <EmptyState
          titulo="Nenhuma portaria aprovada disponível para você."
          descricao="Só é possível atender em portarias aprovadas, dentro da sua abrangência. Peça a criação e a aprovação da portaria do evento."
        />
      ) : !portaria ? (
        <SelecaoPortaria
          portarias={disponiveis}
          agora={agora}
          controleTotal={controleTotal}
          onEscolher={(id) => escolherPortaria(id)}
        />
      ) : (
        <>
          {/* Portaria em atendimento */}
          <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <div className="min-w-0">
              <p className="text-xs font-semibold uppercase tracking-wide text-emerald-700">Portaria em atendimento</p>
              <p className="text-base font-semibold text-slate-900">
                {portaria.evento_data ? formatarDataHora(portaria.evento_data) : "Evento removido"}
              </p>
              <p className="text-sm text-slate-600">
                {[portaria.evento_tipo, portaria.evento_local, portaria.cidade].filter(Boolean).join(" · ")}
              </p>
              {janela && agora > 0 && (
                <p className={"mt-1 text-xs font-medium " + (janela.situacao === "aberta" ? "text-emerald-700" : "text-amber-700")}>
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

          <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
            <div className="space-y-6">
              <LeitorQr ativo={!cartao && !consultando} onLeitura={(texto) => void aoLerQr(texto)} />

              {(erroLeitura || consultando) && (
                <p
                  role={erroLeitura ? "alert" : "status"}
                  className={
                    "rounded-lg px-3 py-2 text-sm " +
                    (erroLeitura ? "bg-red-50 text-red-700" : "bg-slate-50 text-slate-600")
                  }
                >
                  {erroLeitura ?? "Consultando o QR Code..."}
                </p>
              )}

              <div ref={refBusca}>
                <BuscaPorNome
                  key={chaveBusca}
                  portariaId={portaria.id}
                  desabilitado={cartao !== null}
                  onEscolher={aoEscolherPorNome}
                />
              </div>

              <section className="rounded-2xl border border-dashed border-slate-300 bg-white p-4 shadow-sm">
                <h2 className="text-sm font-semibold text-slate-900">Candidato, visitante ou irmão sem cadastro?</h2>
                <p className="mt-1 text-xs text-slate-500">
                  Registre a entrada sem criar cadastro: informe o cargo ou categoria, o instrumento e de onde a
                  pessoa vem. Ela entra na contagem do evento.
                </p>
                <button
                  type="button"
                  onClick={() => setSemCadastro(true)}
                  disabled={cartao !== null || opcoes === null}
                  className="mt-3 rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  Entrada sem cadastro
                </button>
              </section>
            </div>

            <aside>
              <EntradasRecentes
                entradas={entradas}
                avulsas={avulsas}
                onDesfazerAvulsa={(id) => void desfazerSemCadastro(id)}
                onExcluir={pode("portaria.excluir") ? (entrada) => void excluirRegistro(entrada) : undefined}
              />
            </aside>
          </div>
        </>
      )}

      <div className={podeCorrigir ? "text-sm" : "hidden"}>
        <Link href="/portaria/registros" className="font-semibold text-brand-700 hover:underline">
          Registros e correções
        </Link>
      </div>

      {cartao && (
        <CartaoConferencia
          // A chave reinicia a caixa "conferi a identidade" a cada membro
          key={cartao.membro.membro_id}
          membro={cartao.membro}
          origem={cartao.origem}
          registrando={registrando}
          erro={erroCartao}
          onConfirmar={() => void confirmar()}
          onCancelar={() => setCartao(null)}
          podeFoto={pode("membros.foto")}
          onFotoSalva={aoSalvarFotoNoCartao}
          info={info}
          instrumentos={opcoes?.instrumentos ?? []}
          escolha={escolha}
          onEscolha={setEscolha}
        />
      )}

      <Drawer
        aberto={semCadastro}
        onFechar={() => setSemCadastro(false)}
        titulo="Entrada sem cadastro"
        descricao="Candidato, visitante ou irmão sem cadastro: não cria cadastro, só conta na presença do evento."
      >
        {semCadastro && portaria && opcoes && (
          <EntradaSemCadastro portariaId={portaria.id} opcoes={opcoes} onRegistrada={(d) => void aoRegistrarSemCadastro(d)} />
        )}
      </Drawer>

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </div>
  );
}
