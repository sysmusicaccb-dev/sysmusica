"use client";

/**
 * SysMúsica — Página /tipos-evento: cadastro dos tipos de evento (Ensaio Regional, Culto Oficial...).
 * Cada tipo diz se usa a tela Dados do Ensaio e em qual modelo. Os botões só aparecem para quem tem a
 * permissão; o banco confere de novo.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import { excluirTipoEvento, listarTiposEvento, salvarTipoEvento } from "@/modules/tiposEvento/services/tiposEvento";
import FormularioTipoEvento from "@/modules/tiposEvento/components/FormularioTipoEvento";
import TabelaTiposEvento from "@/modules/tiposEvento/components/TabelaTiposEvento";
import type { TipoEvento } from "@/modules/tiposEvento/regras";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";

type Painel = { tipo: "novo" } | { tipo: "editar"; item: TipoEvento };

export default function TiposEventoPage() {
  const { pode } = useSessao();
  const [tipos, setTipos] = useState<TipoEvento[]>([]);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<Painel | null>(null);
  const [alvoExclusao, setAlvoExclusao] = useState<TipoEvento | null>(null);
  const [excluindo, setExcluindo] = useState(false);
  const [erroExclusao, setErroExclusao] = useState<string | null>(null);
  const [alternandoId, setAlternandoId] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    try {
      setTipos(await listarTiposEvento());
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar tipos de evento:", e);
      setErro("Não foi possível carregar os tipos de evento. Verifique a conexão e tente novamente.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await, então o aviso da regra set-state-in-effect não se aplica aqui.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  function tentarNovamente() {
    setCarregando(true);
    void carregar();
  }

  async function aoSalvar(mensagem: string) {
    await carregar();
    setPainel(null);
    setAviso(mensagem);
  }

  // Liga/desliga o tipo sem abrir o formulário (mantém os demais campos como estão)
  async function alternar(tipo: TipoEvento) {
    setAlternandoId(tipo.id);
    try {
      await salvarTipoEvento(tipo.id, {
        nome: tipo.nome,
        descricao: tipo.descricao ?? "",
        modelo_ensaio: tipo.modelo_ensaio,
        ativo: !tipo.ativo,
      });
      await carregar();
      setAviso(`Tipo "${tipo.nome}" ${tipo.ativo ? "desativado" : "ativado"}.`);
    } catch (e) {
      setAviso(e instanceof Error ? e.message : "Não foi possível alterar o status.");
    } finally {
      setAlternandoId(null);
    }
  }

  async function confirmarExclusao() {
    if (!alvoExclusao) return;
    setExcluindo(true);
    setErroExclusao(null);
    try {
      await excluirTipoEvento(alvoExclusao.id);
      await carregar();
      setAviso(`Tipo "${alvoExclusao.nome}" excluído.`);
      setAlvoExclusao(null);
    } catch (e) {
      setErroExclusao(e instanceof Error ? e.message : "Não foi possível excluir o tipo de evento.");
    } finally {
      setExcluindo(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Tipo do Evento"
          descricao={`Os tipos aparecem na lista ao criar um evento.${
            !carregando && !erro ? ` ${tipos.length} tipo(s).` : ""
          }`}
          acoes={
            pode("tipoevento.criar") ? (
              <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                Adicionar
              </Button>
            ) : undefined
          }
        />

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando tipos de evento...</span>
            <Skeleton className="h-14 rounded-2xl" />
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-10" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar os tipos de evento." mensagem={erro} onTentarNovamente={tentarNovamente} />
        ) : tipos.length === 0 ? (
          <EmptyState titulo="Nenhum tipo de evento cadastrado." descricao="Clique em “Adicionar” para criar o primeiro." />
        ) : (
          <TabelaTiposEvento
            tipos={tipos}
            podeEditar={pode("tipoevento.editar")}
            podeExcluir={pode("tipoevento.excluir")}
            alternandoId={alternandoId}
            onEditar={(item) => setPainel({ tipo: "editar", item })}
            onExcluir={(item) => {
              setErroExclusao(null);
              setAlvoExclusao(item);
            }}
            onAlternar={(item) => void alternar(item)}
          />
        )}
      </div>

      <Drawer
        aberto={painel !== null}
        onFechar={() => setPainel(null)}
        titulo={painel?.tipo === "editar" ? "Editar tipo de evento" : "Novo tipo de evento"}
        descricao="Defina o nome e se este tipo usa a tela Dados do Ensaio."
      >
        {painel && (
          <FormularioTipoEvento tipo={painel.tipo === "editar" ? painel.item : null} tipos={tipos} onSalvo={aoSalvar} />
        )}
      </Drawer>

      <ConfirmDialog
        aberto={alvoExclusao !== null}
        titulo="Excluir tipo de evento?"
        mensagem={
          <>
            <p>
              O tipo <strong>{alvoExclusao?.nome}</strong> será excluído. Esta ação não pode ser desfeita. Tipos que já
              foram usados em eventos não podem ser excluídos: desative-os.
            </p>
            {erroExclusao && (
              <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">
                {erroExclusao}
              </p>
            )}
          </>
        }
        textoConfirmar="Excluir"
        processando={excluindo}
        onConfirmar={() => void confirmarExclusao()}
        onCancelar={() => setAlvoExclusao(null)}
      />

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
