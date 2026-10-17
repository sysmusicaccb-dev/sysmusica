"use client";

/**
 * SysMúsica — Página /instrumentos: tabela de instrumentos e famílias (largura total).
 *
 * Quem pode corrigir a família de um instrumento é definido pelo GRUPO do usuário
 * (permissão instrumentos.editar). A regra de verdade está no banco (RLS).
 * Os instrumentos NASCEM no cadastro de membros; botões de novo/editar/excluir
 * chegam na próxima etapa.
 */
import { useCallback, useEffect, useState } from "react";
import {
  atualizarFamiliaDoInstrumento,
  buscarInstrumentosEFamilias,
} from "@/modules/instrumentos/services/instrumentos";
import TabelaInstrumentos from "@/modules/instrumentos/components/TabelaInstrumentos";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import type { Familia, Instrumento } from "@/types/database";

export default function InstrumentosPage() {
  const { pode } = useSessao();
  const [instrumentos, setInstrumentos] = useState<Instrumento[]>([]);
  const [familias, setFamilias] = useState<Familia[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  const [salvandoId, setSalvandoId] = useState<string | null>(null);
  const [erroEdicao, setErroEdicao] = useState<string | null>(null);

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

  // Corrige a família de um instrumento (o banco confere a permissão)
  async function alterarFamilia(instrumento: Instrumento, novaFamiliaId: string) {
    setErroEdicao(null);
    setSalvandoId(instrumento.id);
    try {
      await atualizarFamiliaDoInstrumento(instrumento.id, novaFamiliaId || null);
      // Atualiza a tela sem recarregar tudo
      setInstrumentos((anterior) =>
        anterior.map((item) =>
          item.id === instrumento.id ? { ...item, familia_id: novaFamiliaId || null } : item
        )
      );
      setAviso(`Família de "${instrumento.nome}" atualizada.`);
    } catch (e) {
      setErroEdicao(e instanceof Error ? e.message : "Não foi possível salvar a alteração.");
    } finally {
      setSalvandoId(null);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Instrumentos e famílias"
          descricao={`A família de cada instrumento é definida automaticamente no cadastro de membros.${
            !carregando && !erro ? ` ${instrumentos.length} instrumento(s).` : ""
          }`}
        />

        {carregando ? (
          // Carregando: skeleton
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
            descricao="Os instrumentos são criados automaticamente quando você cadastra um membro com instrumento."
          />
        ) : (
          <TabelaInstrumentos
            instrumentos={instrumentos}
            familias={familias}
            podeEditar={pode("instrumentos.editar")}
            salvandoId={salvandoId}
            erroEdicao={erroEdicao}
            onAlterarFamilia={(instrumento, novaFamiliaId) =>
              void alterarFamilia(instrumento, novaFamiliaId)
            }
          />
        )}
      </div>

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
