"use client";

/**
 * Sysmusica — Página /tipos-evento: cadastro dos tipos de evento (Ensaio Regional, Culto Oficial...).
 * Layout do protótipo: lista à esquerda (busca, status, editar, excluir, paginação) e, à direita, o formulário
 * "Novo Tipo de Evento" sempre visível (vira "Editar" ao clicar no lápis). Cada tipo diz se usa a tela
 * Dados do Ensaio e em qual modelo. Os botões só aparecem para quem tem a permissão; o banco confere de novo.
 */
import { useCallback, useEffect, useState } from "react";
import { CalendarDays, Info } from "lucide-react";
import { excluirTipoEvento, listarTiposEvento, salvarTipoEvento } from "@/modules/tiposEvento/services/tiposEvento";
import FormularioTipoEvento from "@/modules/tiposEvento/components/FormularioTipoEvento";
import TabelaTiposEvento from "@/modules/tiposEvento/components/TabelaTiposEvento";
import type { TipoEvento } from "@/modules/tiposEvento/regras";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import Skeleton from "@/components/ui/Skeleton";

export default function TiposEventoPage() {
  const { pode } = useSessao();
  const [tipos, setTipos] = useState<TipoEvento[]>([]);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [editando, setEditando] = useState<TipoEvento | null>(null); // tipo aberto no formulário (null = novo)
  const [versaoForm, setVersaoForm] = useState(0); // muda para recarregar os campos do formulário
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

  // Volta o formulário ao estado "Novo Tipo de Evento", em branco
  function limparFormulario() {
    setEditando(null);
    setVersaoForm((v) => v + 1);
  }

  function editar(item: TipoEvento) {
    setEditando(item);
    setVersaoForm((v) => v + 1);
  }

  async function aoSalvar(mensagem: string) {
    await carregar();
    limparFormulario();
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
      if (editando?.id === alvoExclusao.id) limparFormulario();
      setAviso(`Tipo "${alvoExclusao.nome}" excluído.`);
      setAlvoExclusao(null);
    } catch (e) {
      setErroExclusao(e instanceof Error ? e.message : "Não foi possível excluir o tipo de evento.");
    } finally {
      setExcluindo(false);
    }
  }

  // O formulário aparece para quem pode criar; quem só edita o vê ao clicar no lápis de um tipo
  const mostrarFormulario = pode("tipoevento.criar") || editando !== null;

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl space-y-5 px-4 py-6 sm:px-6 lg:px-8">
        <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_22rem]">
          <header className="flex items-center gap-4 rounded-xl border border-slate-200 bg-brand-50 px-5 py-4 shadow-sm">
            <CalendarDays className="h-10 w-10 shrink-0 text-brand-700" aria-hidden="true" />
            <div className="min-w-0">
              <h1 className="text-2xl font-bold tracking-tight text-slate-900">Tipo do Evento</h1>
              <p className="text-sm text-slate-600">
                Cadastre e gerencie os tipos de evento que serão utilizados no sistema.
              </p>
            </div>
          </header>
          <aside className="flex items-center gap-3 rounded-xl border border-brand-100 bg-brand-50 px-5 py-4 text-sm text-slate-700">
            <Info className="h-5 w-5 shrink-0 text-brand-600" aria-hidden="true" />
            <p>Estes tipos de evento aparecerão na tela de Dados do Ensaio e na Portaria.</p>
          </aside>
        </div>

        <div className={mostrarFormulario ? "grid items-start gap-5 lg:grid-cols-[minmax(0,1fr)_22rem]" : ""}>
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
          ) : (
            <TabelaTiposEvento
              tipos={tipos}
              podeEditar={pode("tipoevento.editar")}
              podeExcluir={pode("tipoevento.excluir")}
              alternandoId={alternandoId}
              editandoId={editando?.id ?? null}
              onEditar={editar}
              onExcluir={(item) => {
                setErroExclusao(null);
                setAlvoExclusao(item);
              }}
              onAlternar={(item) => void alternar(item)}
            />
          )}

          {mostrarFormulario && (
            <FormularioTipoEvento
              key={`${editando?.id ?? "novo"}-${versaoForm}`}
              tipo={editando}
              tipos={tipos}
              onSalvo={aoSalvar}
              onLimpar={limparFormulario}
            />
          )}
        </div>
      </div>

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
