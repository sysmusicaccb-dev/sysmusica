"use client";

/**
 * SysMúsica — Página /portarias (Gestão de portarias): criar, aprovar, rejeitar, histórico, excluir.
 * Quem pode criar escolhe um evento e cria a portaria (PENDENTE); um aprovador autorizado, de outro
 * usuário e dentro da abrangência, aprova ou rejeita (com motivo). Só portaria APROVADA registra
 * presenças. Cada botão só aparece quando o banco diz que o usuário pode; o banco confere de novo.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import CotaPortariasIndicador from "@/modules/portarias/components/CotaPortarias";
import FormularioNovaPortaria from "@/modules/portarias/components/FormularioNovaPortaria";
import FormularioRejeicao from "@/modules/portarias/components/FormularioRejeicao";
import HistoricoPortaria from "@/modules/portarias/components/HistoricoPortaria";
import TabelaPortarias from "@/modules/portarias/components/TabelaPortarias";
import {
  buscarEventosParaPortaria,
  decidirPortaria,
  excluirPortaria,
  historicoDaPortaria,
  listarPortarias,
  minhaCota,
  minhasCidades,
} from "@/modules/portarias/services/portarias";
import type {
  CotaPortarias,
  EventoParaPortaria,
  HistoricoPortaria as ItemHistorico,
  PortariaDetalhada,
} from "@/modules/portarias/tipos";
import AbasDeLista from "@/components/AbasDeLista";
import { janelaDaPortaria } from "@/modules/portarias/janela";
import { abrirJanelaImpressao, escreverImpressao } from "@/lib/exportacao";
import { MARCA } from "@/lib/marca";
import { registrarUso } from "@/modules/auditoria/services/auditoria";
import FormularioRelatorioPresenca from "@/modules/relatorios/components/FormularioRelatorioPresenca";
import {
  lerOpcoesSalvas,
  montarImpressaoPresenca,
  salvarOpcoes,
  type OpcoesRelatorioPresenca,
} from "@/modules/relatorios/presencaPortaria";
import { agoraEmSalvador } from "@/modules/relatorios/regras";
import { buscarRelatorioPresencaPortaria } from "@/modules/relatorios/services/presencaPortaria";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import { formatarDataHora } from "@/lib/datas";

// Endereço da logomarca para a janela de impressão: completo (https) quando possível
function enderecoDaLogo(): string {
  return window.location.protocol === "https:" ? `${window.location.origin}${MARCA.logoCaminho}` : MARCA.logoCaminho;
}

// Qual painel lateral está aberto
type Painel =
  | { tipo: "nova" }
  | { tipo: "rejeitar"; portaria: PortariaDetalhada }
  | { tipo: "historico"; portaria: PortariaDetalhada; itens: ItemHistorico[] }
  | { tipo: "relatorio"; portaria: PortariaDetalhada };

export default function PortariasPage() {
  const { pode, conta } = useSessao();
  const podeCriar = pode("portarias.criar");
  const podeAprovar = pode("portarias.aprovar");
  const controleTotal = pode("portarias.controle_total"); // atua em qualquer cidade: não precisa de abrangência

  const [portarias, setPortarias] = useState<PortariaDetalhada[]>([]);
  const [eventos, setEventos] = useState<EventoParaPortaria[]>([]);
  const [cota, setCota] = useState<CotaPortarias | null>(null);
  const [cidades, setCidades] = useState<string[] | null>(null); // abrangência (só aprovadores)
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<Painel | null>(null);
  const [alvoAprovar, setAlvoAprovar] = useState<PortariaDetalhada | null>(null);
  const [alvoExcluir, setAlvoExcluir] = useState<PortariaDetalhada | null>(null);
  const [processando, setProcessando] = useState(false);
  const [erroConfirmacao, setErroConfirmacao] = useState<string | null>(null);
  const [erroAcao, setErroAcao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  const [aba, setAba] = useState<"ativas" | "historico">("ativas");
  const [gerandoRelatorio, setGerandoRelatorio] = useState(false);
  const [agora, setAgora] = useState(0); // instante atual (ms); 0 até a primeira carga

  // Busca as portarias e, conforme as permissões, os eventos, a cota e a abrangência
  const carregar = useCallback(async () => {
    try {
      const [lista, listaEventos, cotaAtual, cidadesAtuais] = await Promise.all([
        listarPortarias(),
        podeCriar ? buscarEventosParaPortaria() : Promise.resolve([] as EventoParaPortaria[]),
        podeCriar ? minhaCota() : Promise.resolve(null),
        podeAprovar ? minhasCidades() : Promise.resolve(null),
      ]);
      setPortarias(lista);
      setAgora(Date.now());
      setEventos(listaEventos);
      setCota(cotaAtual);
      setCidades(cidadesAtuais);
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar as portarias:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar as portarias.");
    } finally {
      setCarregando(false);
    }
  }, [podeCriar, podeAprovar]);

  // Primeira carga ao abrir a página
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga inicial. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  // Mantém a separação Ativas/Histórico em dia: a portaria cujo evento termina vai para o Histórico sozinha
  useEffect(() => {
    const id = setInterval(() => setAgora(Date.now()), 60_000);
    return () => clearInterval(id);
  }, []);

  function tentarNovamente() {
    setCarregando(true);
    void carregar();
  }

  // Depois de uma ação: recarrega, fecha o painel e mostra o aviso de sucesso
  async function aoSalvar(mensagem: string) {
    await carregar();
    setPainel(null);
    setAviso(mensagem);
  }

  // Relatório de presença da portaria. A janela abre já no clique (antes da espera) para o navegador não bloqueá-la.
  async function emitirRelatorioPresenca(portaria: PortariaDetalhada, opcoes: OpcoesRelatorioPresenca) {
    if (gerandoRelatorio) return;
    setErroAcao(null);
    const janela = abrirJanelaImpressao();
    if (!janela) {
      setErroAcao("O navegador bloqueou a janela. Libere os pop-ups deste site e tente de novo.");
      return;
    }
    setGerandoRelatorio(true);
    salvarOpcoes(opcoes); // guarda a escolha para os próximos relatórios
    try {
      const dados = await buscarRelatorioPresencaPortaria(portaria.id);
      // Imprimir fica registrado na Auditoria
      await registrarUso("relatorio_impresso", {
        tipo: "presenca_portaria",
        portaria_id: portaria.id,
        evento_id: portaria.evento_id,
        quantidade: Number(dados.total),
      });
      escreverImpressao(
        janela,
        montarImpressaoPresenca(dados, {
          emitidoPor: conta?.nome ?? "usuário",
          geradoEm: agoraEmSalvador(),
          logoUrl: enderecoDaLogo(),
          abrirImpressao: false, // mostra a folha para conferir; o botão Imprimir da janela imprime
        }, opcoes)
      );
      setPainel(null);
    } catch (e) {
      janela.close();
      setErroAcao(e instanceof Error ? e.message : "Não foi possível gerar o relatório de presença.");
    } finally {
      setGerandoRelatorio(false);
    }
  }

  async function abrirHistorico(portaria: PortariaDetalhada) {
    setErroAcao(null);
    try {
      setPainel({ tipo: "historico", portaria, itens: await historicoDaPortaria(portaria.id) });
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível abrir o histórico.");
    }
  }

  async function confirmarAprovacao() {
    if (!alvoAprovar) return;
    setProcessando(true);
    setErroConfirmacao(null);
    try {
      await decidirPortaria(alvoAprovar.id, true, null);
      await carregar();
      setAviso("Portaria aprovada. Ela já pode ser usada para registrar presenças.");
      setAlvoAprovar(null);
    } catch (e) {
      setErroConfirmacao(e instanceof Error ? e.message : "Não foi possível aprovar a portaria.");
    } finally {
      setProcessando(false);
    }
  }

  async function confirmarExclusao() {
    if (!alvoExcluir) return;
    setProcessando(true);
    setErroConfirmacao(null);
    try {
      await excluirPortaria(alvoExcluir.id);
      await carregar();
      setAviso("Portaria excluída. A cota do dia não é devolvida.");
      setAlvoExcluir(null);
    } catch (e) {
      setErroConfirmacao(e instanceof Error ? e.message : "Não foi possível excluir a portaria.");
    } finally {
      setProcessando(false);
    }
  }

  // Portaria cujo evento já encerrou (ou foi removido) vai para o Histórico
  const noHistorico = (portaria: PortariaDetalhada) => {
    const janela = janelaDaPortaria(portaria.evento_data, agora);
    return janela === null || janela.situacao === "encerrada";
  };
  const historico = portarias.filter(noHistorico);
  const ativas = portarias.filter((portaria) => !noHistorico(portaria));
  const visiveis = aba === "ativas" ? ativas : historico;

  // Eventos que ainda podem receber portaria (sem uma pendente ou aprovada)
  const eventosDisponiveis = eventos.filter(
    (evento) => !portarias.some((portaria) => portaria.evento_id === evento.id && portaria.status !== "REJEITADA")
  );

  const descricaoEvento = (portaria: PortariaDetalhada) =>
    `${portaria.evento_data ? formatarDataHora(portaria.evento_data) : "Evento removido"} · ${portaria.evento_local ?? ""}`;

  const tituloPainel =
    painel?.tipo === "rejeitar" ? "Rejeitar portaria" : painel?.tipo === "historico"
      ? "Histórico da portaria"
      : painel?.tipo === "relatorio"
        ? "Relatório de presença"
        : "Nova portaria";

  // Mensagem de erro reaproveitada pelos dois diálogos de confirmação
  const erroDialogo = erroConfirmacao && (
    <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">
      {erroConfirmacao}
    </p>
  );

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Portarias"
          descricao={`Criação e aprovação das portarias dos eventos.${
            !carregando && !erro ? ` ${portarias.length} portaria(s).` : ""
          }`}
          acoes={
            podeCriar ? (
              <>
                {cota && <CotaPortariasIndicador cota={cota} />}
                <Button icone={Plus} onClick={() => setPainel({ tipo: "nova" })} disabled={carregando || !!erro}>
                  Nova portaria
                </Button>
              </>
            ) : undefined
          }
        />

        {/* Aprovador sem cidade de abrangência: avisa o que fazer */}
        {podeAprovar && !controleTotal && cidades !== null && cidades.length === 0 && (
          <p className="mb-4 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
            Você ainda não tem vínculo com nenhum setor, então não consegue aprovar nem rejeitar portarias. Peça a
            um administrador para vinculá-lo a um setor em Administração &gt; Usuários.
          </p>
        )}

        {erroAcao && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroAcao}
          </p>
        )}

        {!carregando && !erro && (
          <AbasDeLista
            descricao="Situação das portarias"
            atual={aba}
            onTrocar={setAba}
            abas={[
              { id: "ativas", rotulo: "Ativas", total: ativas.length },
              { id: "historico", rotulo: "Histórico", total: historico.length },
            ]}
          />
        )}

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando portarias...</span>
            <Skeleton className="h-14 rounded-2xl" />
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar as portarias." mensagem={erro} onTentarNovamente={tentarNovamente} />
        ) : visiveis.length === 0 ? (
          <EmptyState
            titulo={
              portarias.length === 0
                ? "Nenhuma portaria por aqui ainda."
                : aba === "ativas"
                  ? "Nenhuma portaria ativa no momento."
                  : "O histórico está vazio."
            }
            descricao={
              aba === "historico"
                ? "As portarias de eventos já encerrados ficam guardadas aqui."
                : podeCriar
                ? "Clique em “Nova portaria” para solicitar a portaria de um evento."
                : "Quando houver portarias na sua abrangência, elas aparecem aqui."
            }
          />
        ) : (
          <TabelaPortarias
            portarias={visiveis}
            onAprovar={(portaria) => {
              setErroConfirmacao(null);
              setAlvoAprovar(portaria);
            }}
            onRejeitar={(portaria) => setPainel({ tipo: "rejeitar", portaria })}
            onHistorico={(portaria) => void abrirHistorico(portaria)}
            onRelatorio={(portaria) => {
              setErroAcao(null);
              setPainel({ tipo: "relatorio", portaria });
            }}
            podeRelatorio={(portaria) => {
              // Portaria aprovada cujo evento já começou (em andamento ou encerrado)
              const janela = janelaDaPortaria(portaria.evento_data, agora);
              return portaria.status === "APROVADA" && janela !== null && janela.situacao !== "antes";
            }}
            onExcluir={(portaria) => {
              setErroConfirmacao(null);
              setAlvoExcluir(portaria);
            }}
          />
        )}
      </div>

      {/* Painel lateral: nova portaria, rejeição ou histórico */}
      <Drawer
        aberto={painel !== null}
        onFechar={() => setPainel(null)}
        titulo={tituloPainel}
        descricao={
          painel?.tipo === "nova"
            ? "A portaria só poderá ser usada depois de aprovada por outro usuário."
            : painel?.tipo === "rejeitar"
              ? "Informe o motivo: ele fica no histórico."
              : painel?.tipo === "historico" || painel?.tipo === "relatorio"
                ? descricaoEvento(painel.portaria)
                : undefined
        }
      >
        {painel?.tipo === "nova" && <FormularioNovaPortaria eventos={eventosDisponiveis} cota={cota} onSalvo={aoSalvar} />}
        {painel?.tipo === "rejeitar" && <FormularioRejeicao portaria={painel.portaria} onSalvo={aoSalvar} />}
        {painel?.tipo === "historico" && <HistoricoPortaria itens={painel.itens} />}
        {painel?.tipo === "relatorio" && (
          <FormularioRelatorioPresenca
            opcoesIniciais={lerOpcoesSalvas()}
            gerando={gerandoRelatorio}
            erro={erroAcao}
            onGerar={(opcoes) => void emitirRelatorioPresenca(painel.portaria, opcoes)}
          />
        )}
      </Drawer>

      <ConfirmDialog
        aberto={alvoAprovar !== null}
        titulo="Aprovar portaria?"
        mensagem={
          <>
            <p>
              A portaria de <strong>{alvoAprovar ? descricaoEvento(alvoAprovar) : ""}</strong> poderá ser usada para
              registrar presenças pelos atendentes autorizados. A decisão não pode ser desfeita.
            </p>
            {erroDialogo}
          </>
        }
        textoConfirmar="Aprovar" variante="primario"
        processando={processando}
        onConfirmar={() => void confirmarAprovacao()}
        onCancelar={() => setAlvoAprovar(null)}
      />

      <ConfirmDialog
        aberto={alvoExcluir !== null}
        titulo="Excluir portaria?"
        mensagem={
          <>
            <p>
              A portaria de <strong>{alvoExcluir ? descricaoEvento(alvoExcluir) : ""}</strong> deixará de aparecer.
              Atenção: a cota diária de criação <strong>não é devolvida</strong>.
            </p>
            {erroDialogo}
          </>
        }
        textoConfirmar="Excluir"
        processando={processando}
        onConfirmar={() => void confirmarExclusao()}
        onCancelar={() => setAlvoExcluir(null)}
      />

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
