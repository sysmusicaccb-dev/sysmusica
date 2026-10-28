"use client";

/**
 * Sysmusica — Eventos > Perfil do Evento: cadastro dos perfis que definem o comportamento da tela
 * "Dados do Ensaio" (Ensaio Local, Ensaio Regional, Ensaio Técnico...). Lista com Editar, Duplicar e Excluir (lixeira);
 * "+ Adicionar" abre o painel lateral. Só o administrador global altera perfis: o banco confere.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus, SlidersHorizontal } from "lucide-react";
import Button from "@/components/ui/Button";
import CabecalhoDeAba from "@/components/ui/CabecalhoDeAba";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import Skeleton from "@/components/ui/Skeleton";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import FormularioPerfil from "@/modules/perfisEvento/components/FormularioPerfil";
import TabelaPerfis from "@/modules/perfisEvento/components/TabelaPerfis";
import type { PerfilEvento } from "@/modules/perfisEvento/regras";
import { duplicarPerfil, excluirPerfil, listarPerfis } from "@/modules/perfisEvento/services/perfisEvento";

type Painel = { tipo: "novo" } | { tipo: "editar"; perfil: PerfilEvento } | null;

export default function PerfilEventoPage() {
  const { pode } = useSessao();
  const [perfis, setPerfis] = useState<PerfilEvento[]>([]);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<Painel>(null);
  const [alvoExclusao, setAlvoExclusao] = useState<PerfilEvento | null>(null);
  const [excluindo, setExcluindo] = useState(false);
  const [erroExclusao, setErroExclusao] = useState<string | null>(null);
  const [ocupadoId, setOcupadoId] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    try {
      setPerfis(await listarPerfis());
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar perfis de evento:", e);
      setErro("Não foi possível carregar os perfis de evento. Verifique a conexão e tente novamente.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await, então o aviso da regra set-state-in-effect não se aplica aqui.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  async function aoSalvar(mensagem: string) {
    await carregar();
    setPainel(null);
    setAviso(mensagem);
  }

  // Duplicar: cria "Nome (cópia)" e recarrega a lista
  async function duplicar(perfil: PerfilEvento) {
    setOcupadoId(perfil.id);
    try {
      await duplicarPerfil(perfil.id);
      await carregar();
      setAviso(`Cópia de "${perfil.nome}" criada.`);
    } catch (e) {
      setAviso(e instanceof Error ? e.message : "Não foi possível duplicar o perfil.");
    } finally {
      setOcupadoId(null);
    }
  }

  async function confirmarExclusao() {
    if (!alvoExclusao) return;
    setExcluindo(true);
    setErroExclusao(null);
    try {
      await excluirPerfil(alvoExclusao.id);
      await carregar();
      setAviso(`Perfil "${alvoExclusao.nome}" excluído.`);
      setAlvoExclusao(null);
    } catch (e) {
      setErroExclusao(e instanceof Error ? e.message : "Não foi possível excluir o perfil.");
    } finally {
      setExcluindo(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl space-y-5 px-4 py-6 sm:px-6 lg:px-8">
        <CabecalhoDeAba
          icone={SlidersHorizontal}
          titulo="Perfil do Evento"
          descricao="Perfis que definem como a tela Dados do Ensaio funciona em cada tipo de evento."
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
            <span className="sr-only">Carregando perfis de evento...</span>
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState
            titulo="Não foi possível carregar os perfis de evento."
            mensagem={erro}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar();
            }}
          />
        ) : (
          <TabelaPerfis
            perfis={perfis}
            podeCriar={pode("tipoevento.criar")}
            podeEditar={pode("tipoevento.editar")}
            podeExcluir={pode("tipoevento.excluir")}
            ocupadoId={ocupadoId}
            onEditar={(perfil) => setPainel({ tipo: "editar", perfil })}
            onDuplicar={(perfil) => void duplicar(perfil)}
            onExcluir={(perfil) => {
              setErroExclusao(null);
              setAlvoExclusao(perfil);
            }}
          />
        )}
      </div>

      <Drawer
        aberto={painel !== null}
        titulo={painel?.tipo === "editar" ? "Editar Perfil" : "Novo Perfil"}
        descricao="Defina o nome e escolha os campos da tela Dados do Ensaio."
        larguraMaxima="max-w-3xl"
        onFechar={() => setPainel(null)}
      >
        {painel !== null && (
          <FormularioPerfil
            perfil={painel.tipo === "editar" ? painel.perfil : null}
            perfis={perfis}
            onSalvo={aoSalvar}
            onCancelar={() => setPainel(null)}
          />
        )}
      </Drawer>

      <ConfirmDialog
        aberto={alvoExclusao !== null}
        titulo="Excluir perfil?"
        mensagem={
          <>
            <p>
              O perfil <strong>{alvoExclusao?.nome}</strong> será excluído. Esta ação não pode ser desfeita. Perfis
              usados por algum tipo de evento não podem ser excluídos.
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
