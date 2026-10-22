"use client";

/**
 * Sysmusica — Página /hinos: lista de hinos do hinário e coros (corinhos), usada nos Dados do Ensaio.
 * Permite adicionar, editar, ativar/desativar, excluir (só se nunca foi usado) e importar uma lista colada.
 */
import { useCallback, useEffect, useState } from "react";
import { FileUp, Plus } from "lucide-react";
import { excluirHino, listarHinos, salvarHino } from "@/modules/hinos/services/hinos";
import FormularioHino from "@/modules/hinos/components/FormularioHino";
import ImportarHinos from "@/modules/hinos/components/ImportarHinos";
import TabelaHinos from "@/modules/hinos/components/TabelaHinos";
import { rotuloHino, type Hino } from "@/modules/hinos/regras";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";

type Painel = { tipo: "novo" } | { tipo: "editar"; item: Hino } | { tipo: "importar" };

export default function HinosPage() {
  const { pode } = useSessao();
  const [hinos, setHinos] = useState<Hino[]>([]);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<Painel | null>(null);
  const [alvoExclusao, setAlvoExclusao] = useState<Hino | null>(null);
  const [excluindo, setExcluindo] = useState(false);
  const [erroExclusao, setErroExclusao] = useState<string | null>(null);
  const [alternandoId, setAlternandoId] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    try {
      setHinos(await listarHinos());
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar hinos:", e);
      setErro("Não foi possível carregar os hinos. Verifique a conexão e tente novamente.");
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

  async function alternar(hino: Hino) {
    setAlternandoId(hino.id);
    try {
      await salvarHino(hino.id, { categoria: hino.categoria, numero: hino.numero, nome: hino.nome, ativo: !hino.ativo });
      await carregar();
      setAviso(`${rotuloHino(hino.categoria, hino.numero)} ${hino.ativo ? "desativado" : "ativado"}.`);
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
      await excluirHino(alvoExclusao.id);
      await carregar();
      setAviso(`${rotuloHino(alvoExclusao.categoria, alvoExclusao.numero)} excluído.`);
      setAlvoExclusao(null);
    } catch (e) {
      setErroExclusao(e instanceof Error ? e.message : "Não foi possível excluir o hino.");
    } finally {
      setExcluindo(false);
    }
  }

  const podeCriar = pode("hinos.criar");

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Hinos"
          descricao={`Hinário e coros usados nos Dados do Ensaio.${!carregando && !erro ? ` ${hinos.length} cadastrado(s).` : ""}`}
          acoes={
            podeCriar ? (
              <div className="flex flex-wrap gap-2">
                {/* Botão simples (não usamos uma variante do Button que pode não existir no projeto) */}
                <button
                  type="button"
                  onClick={() => setPainel({ tipo: "importar" })}
                  disabled={carregando || !!erro}
                  className="inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 shadow-sm transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <FileUp className="h-4 w-4" aria-hidden="true" />
                  Importar lista
                </button>
                <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                  Adicionar
                </Button>
              </div>
            ) : undefined
          }
        />

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando hinos...</span>
            <Skeleton className="h-14 rounded-2xl" />
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-10" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar os hinos." mensagem={erro} onTentarNovamente={tentarNovamente} />
        ) : hinos.length === 0 ? (
          <EmptyState
            titulo="Nenhum hino cadastrado ainda."
            descricao={podeCriar ? "Use “Importar lista” para colar o hinário de uma vez, ou “Adicionar” para um por um." : undefined}
          />
        ) : (
          <TabelaHinos
            hinos={hinos}
            podeEditar={pode("hinos.editar")}
            podeExcluir={pode("hinos.excluir")}
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
        titulo={painel?.tipo === "importar" ? "Importar lista de hinos" : painel?.tipo === "editar" ? "Editar hino" : "Novo hino"}
        descricao={
          painel?.tipo === "importar"
            ? "Só acrescenta: números que já existem são mantidos como estão."
            : "Hino do hinário aparece como “002”; coro aparece como “Coro 2”."
        }
      >
        {painel?.tipo === "importar" ? (
          <ImportarHinos existentes={hinos} onImportado={aoSalvar} />
        ) : painel ? (
          <FormularioHino
            hino={painel.tipo === "editar" ? painel.item : null}
            hinos={hinos}
            categoriaInicial="HINO"
            onSalvo={aoSalvar}
          />
        ) : null}
      </Drawer>

      <ConfirmDialog
        aberto={alvoExclusao !== null}
        titulo="Excluir hino?"
        mensagem={
          <>
            <p>
              <strong>{alvoExclusao && `${rotuloHino(alvoExclusao.categoria, alvoExclusao.numero)} – ${alvoExclusao.nome}`}</strong> será
              excluído. Esta ação não pode ser desfeita. Hinos já usados em ensaios não podem ser excluídos: desative-os.
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
