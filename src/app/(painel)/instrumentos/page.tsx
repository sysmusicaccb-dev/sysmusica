"use client";

/**
 * Sysmusica — Página /instrumentos: tabela de instrumentos e famílias com novo, editar e excluir.
 * Cada botão só aparece para quem tem a permissão (grupo do usuário); o banco confere de novo.
 * Os instrumentos também nascem no cadastro de membros (digitando um instrumento novo).
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import {
  buscarInstrumentosEFamilias,
  excluirInstrumento,
} from "@/modules/instrumentos/services/instrumentos";
import FormularioInstrumento from "@/modules/instrumentos/components/FormularioInstrumento";
import TabelaInstrumentos from "@/modules/instrumentos/components/TabelaInstrumentos";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import type { Familia, Instrumento } from "@/types/database";

// Qual painel lateral está aberto: novo instrumento, ou edição de um instrumento
type PainelInstrumento = { tipo: "novo" } | { tipo: "editar"; instrumento: Instrumento };

export default function InstrumentosPage() {
  const { pode } = useSessao();
  const [instrumentos, setInstrumentos] = useState<Instrumento[]>([]);
  const [familias, setFamilias] = useState<Familia[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<PainelInstrumento | null>(null);
  const [alvoExclusao, setAlvoExclusao] = useState<Instrumento | null>(null);
  const [excluindo, setExcluindo] = useState(false);
  const [erroExclusao, setErroExclusao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  // Busca instrumentos e famílias
  const carregar = useCallback(async () => {
    try {
      const dados = await buscarInstrumentosEFamilias();
      setInstrumentos(dados.instrumentos);
      setFamilias(dados.familias);
      setErro(null);
    } catch (e) {
      // O detalhe técnico vai só para o console; a tela mostra uma mensagem simples
      console.error("Falha ao carregar instrumentos:", e);
      setErro("Não foi possível carregar os instrumentos. Verifique a conexão e tente novamente.");
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

  // Confirma a exclusão do instrumento escolhido (o banco recusa se algum membro ainda usar)
  async function confirmarExclusao() {
    if (!alvoExclusao) return;
    setExcluindo(true);
    setErroExclusao(null);
    try {
      await excluirInstrumento(alvoExclusao.id);
      await carregar();
      setAviso(`Instrumento "${alvoExclusao.nome}" excluído.`);
      setAlvoExclusao(null);
    } catch (e) {
      setErroExclusao(e instanceof Error ? e.message : "Não foi possível excluir o instrumento.");
    } finally {
      setExcluindo(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Instrumentos e Famílias"
          descricao={`A família de cada instrumento é definida automaticamente pelo nome.${
            !carregando && !erro ? ` ${instrumentos.length} instrumento(s).` : ""
          }`}
          acoes={
            pode("instrumentos.criar") ? (
              <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                Adicionar
              </Button>
            ) : undefined
          }
        />

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando instrumentos...</span>
            <Skeleton className="h-14 rounded-2xl" />
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-10" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState
            titulo="Não foi possível carregar os instrumentos."
            mensagem={erro}
            onTentarNovamente={tentarNovamente}
          />
        ) : instrumentos.length === 0 ? (
          <EmptyState
            titulo="Nenhum instrumento cadastrado ainda."
            descricao="Clique em “Adicionar” ou cadastre um músico ou organista com instrumento."
          />
        ) : (
          <TabelaInstrumentos
            instrumentos={instrumentos}
            familias={familias}
            podeEditar={pode("instrumentos.editar")}
            podeExcluir={pode("instrumentos.excluir")}
            onEditar={(instrumento) => setPainel({ tipo: "editar", instrumento })}
            onExcluir={(instrumento) => {
              setErroExclusao(null);
              setAlvoExclusao(instrumento);
            }}
          />
        )}
      </div>

      {/* Painel lateral: novo instrumento ou edição */}
      <Drawer
        aberto={painel !== null}
        onFechar={() => setPainel(null)}
        titulo={painel?.tipo === "editar" ? "Editar instrumento" : "Novo instrumento"}
        descricao="A família é sugerida automaticamente pelo nome."
      >
        {painel && (
          <FormularioInstrumento
            instrumento={painel.tipo === "editar" ? painel.instrumento : null}
            instrumentos={instrumentos}
            familias={familias}
            podeEscolherFamilia={pode("instrumentos.editar")}
            onSalvo={aoSalvar}
          />
        )}
      </Drawer>

      {/* Confirmação de exclusão */}
      <ConfirmDialog
        aberto={alvoExclusao !== null}
        titulo="Excluir instrumento?"
        mensagem={
          <>
            <p>
              O instrumento <strong>{alvoExclusao?.nome}</strong> será excluído. Esta ação não pode ser
              desfeita. Se algum membro ainda usar este instrumento, a exclusão será recusada.
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
