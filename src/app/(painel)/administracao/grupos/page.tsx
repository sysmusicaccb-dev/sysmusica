"use client";

/**
 * SysMúsica — Administração > Grupos e permissões: lista de grupos com criar, editar (inclusive a
 * grade de permissões) e excluir. Cada botão só aparece para quem tem a permissão; o banco
 * confere a permissão de novo em toda operação.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import FormularioGrupo from "@/modules/administracao/components/FormularioGrupo";
import TabelaGrupos from "@/modules/administracao/components/TabelaGrupos";
import {
  excluirGrupo,
  listarGrupos,
  listarPermissoes,
} from "@/modules/administracao/services/acesso";
import type { GrupoAcesso, PermissaoCatalogo } from "@/modules/administracao/tipos";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";

// Qual painel lateral está aberto: novo grupo, ou edição de um grupo
type PainelGrupo = { tipo: "novo" } | { tipo: "editar"; grupo: GrupoAcesso };

export default function GruposPage() {
  const { pode } = useSessao();

  const [grupos, setGrupos] = useState<GrupoAcesso[]>([]);
  const [catalogo, setCatalogo] = useState<PermissaoCatalogo[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<PainelGrupo | null>(null);
  const [alvoExclusao, setAlvoExclusao] = useState<GrupoAcesso | null>(null);
  const [excluindo, setExcluindo] = useState(false);
  const [erroExclusao, setErroExclusao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  // Busca grupos e catálogo de permissões em paralelo
  const carregar = useCallback(async () => {
    try {
      const [listaGrupos, listaPermissoes] = await Promise.all([listarGrupos(), listarPermissoes()]);
      setGrupos(listaGrupos);
      setCatalogo(listaPermissoes);
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar grupos:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar os grupos.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga ao abrir a página
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga inicial. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  // Botão "Tentar novamente": volta ao estado de loading e busca de novo
  function tentarNovamente() {
    setCarregando(true);
    void carregar();
  }

  // Depois de salvar: recarrega a lista, fecha o painel e mostra o aviso de sucesso
  async function aoSalvar(mensagem: string) {
    await carregar();
    setPainel(null);
    setAviso(mensagem);
  }

  // Confirma a exclusão do grupo escolhido
  async function confirmarExclusao() {
    if (!alvoExclusao) return;
    setExcluindo(true);
    setErroExclusao(null);
    try {
      await excluirGrupo(alvoExclusao.id);
      await carregar();
      setAviso(`Grupo "${alvoExclusao.nome}" excluído.`);
      setAlvoExclusao(null);
    } catch (e) {
      setErroExclusao(e instanceof Error ? e.message : "Não foi possível excluir o grupo.");
    } finally {
      setExcluindo(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Grupos e permissões"
          descricao={`Cada grupo define o que seus usuários podem ver e fazer.${
            !carregando && !erro ? ` ${grupos.length} grupo(s).` : ""
          }`}
          acoes={
            pode("grupos.criar") ? (
              <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                Adicionar
              </Button>
            ) : undefined
          }
        />

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando grupos...</span>
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar os grupos." mensagem={erro} onTentarNovamente={tentarNovamente} />
        ) : grupos.length === 0 ? (
          <EmptyState titulo="Nenhum grupo cadastrado." descricao="Clique em “Adicionar” para criar o primeiro." />
        ) : (
          <TabelaGrupos
            grupos={grupos}
            totalPermissoes={catalogo.length}
            podeEditar={pode("grupos.editar")}
            podeExcluir={pode("grupos.excluir")}
            onEditar={(grupo) => setPainel({ tipo: "editar", grupo })}
            onExcluir={(grupo) => {
              setErroExclusao(null);
              setAlvoExclusao(grupo);
            }}
          />
        )}
      </div>

      {/* Painel lateral: novo grupo ou edição (com a grade de permissões) */}
      <Drawer
        aberto={painel !== null}
        onFechar={() => setPainel(null)}
        titulo={painel?.tipo === "editar" ? "Editar grupo" : "Novo grupo"}
        descricao="Defina o nome e marque o que o grupo pode fazer em cada módulo."
      >
        {painel?.tipo === "novo" && (
          <FormularioGrupo grupo={null} catalogo={catalogo} onSalvo={aoSalvar} />
        )}
        {painel?.tipo === "editar" && (
          <FormularioGrupo grupo={painel.grupo} catalogo={catalogo} onSalvo={aoSalvar} />
        )}
      </Drawer>

      {/* Confirmação de exclusão */}
      <ConfirmDialog
        aberto={alvoExclusao !== null}
        titulo="Excluir grupo?"
        mensagem={
          <>
            <p>
              O grupo <strong>{alvoExclusao?.nome}</strong> e as suas permissões serão excluídos. Esta ação
              não pode ser desfeita.
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
