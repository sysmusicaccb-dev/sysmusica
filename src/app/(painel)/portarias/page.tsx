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
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import { formatarDataHora } from "@/lib/datas";

// Qual painel lateral está aberto
type Painel =
  | { tipo: "nova" }
  | { tipo: "rejeitar"; portaria: PortariaDetalhada }
  | { tipo: "historico"; portaria: PortariaDetalhada; itens: ItemHistorico[] };

export default function PortariasPage() {
  const { pode } = useSessao();
  const podeCriar = pode("portarias.criar");
  const podeAprovar = pode("portarias.aprovar");

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

  // Eventos que ainda podem receber portaria (sem uma pendente ou aprovada)
  const eventosDisponiveis = eventos.filter(
    (evento) => !portarias.some((portaria) => portaria.evento_id === evento.id && portaria.status !== "REJEITADA")
  );

  const descricaoEvento = (portaria: PortariaDetalhada) =>
    `${portaria.evento_data ? formatarDataHora(portaria.evento_data) : "Evento removido"} · ${portaria.evento_local ?? ""}`;

  const tituloPainel =
    painel?.tipo === "rejeitar" ? "Rejeitar portaria" : painel?.tipo === "historico" ? "Histórico da portaria" : "Nova portaria";

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
        {podeAprovar && cidades !== null && cidades.length === 0 && (
          <p className="mb-4 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
            Você ainda não tem cidades de abrangência, então não consegue aprovar nem rejeitar portarias. Peça a
            um administrador para marcá-las em Administração &gt; Usuários.
          </p>
        )}

        {erroAcao && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroAcao}
          </p>
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
        ) : portarias.length === 0 ? (
          <EmptyState
            titulo="Nenhuma portaria por aqui ainda."
            descricao={
              podeCriar
                ? "Clique em “Nova portaria” para solicitar a portaria de um evento."
                : "Quando houver portarias na sua abrangência, elas aparecem aqui."
            }
          />
        ) : (
          <TabelaPortarias
            portarias={portarias}
            onAprovar={(portaria) => {
              setErroConfirmacao(null);
              setAlvoAprovar(portaria);
            }}
            onRejeitar={(portaria) => setPainel({ tipo: "rejeitar", portaria })}
            onHistorico={(portaria) => void abrirHistorico(portaria)}
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
              : painel?.tipo === "historico"
                ? descricaoEvento(painel.portaria)
                : undefined
        }
      >
        {painel?.tipo === "nova" && <FormularioNovaPortaria eventos={eventosDisponiveis} cota={cota} onSalvo={aoSalvar} />}
        {painel?.tipo === "rejeitar" && <FormularioRejeicao portaria={painel.portaria} onSalvo={aoSalvar} />}
        {painel?.tipo === "historico" && <HistoricoPortaria itens={painel.itens} />}
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
