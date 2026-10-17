"use client";

/**
 * SysMúsica — Página /eventos: listagem em tabela (largura total), do evento mais recente para o
 * mais antigo, com novo, editar e excluir. Cada botão só aparece para quem tem a permissão
 * (grupo do usuário); o banco confere de novo em toda operação.
 * Excluir é exclusão lógica: o evento some das telas e as presenças registradas são mantidas.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import {
  buscarEventosEFinalidades,
  excluirEvento,
} from "@/modules/eventos/services/eventos";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import FormularioEvento from "@/components/FormularioEvento";
import ListaEventos from "@/components/ListaEventos";
import { formatarDataHora } from "@/lib/datas";
import type { Evento, FinalidadeEvento } from "@/types/database";

// Qual painel lateral está aberto: novo evento, ou edição de um evento
type PainelEvento = { tipo: "novo" } | { tipo: "editar"; evento: Evento };

export default function EventosPage() {
  const { pode } = useSessao();
  const [eventos, setEventos] = useState<Evento[]>([]);
  const [finalidades, setFinalidades] = useState<FinalidadeEvento[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<PainelEvento | null>(null);
  const [alvoExclusao, setAlvoExclusao] = useState<Evento | null>(null);
  const [excluindo, setExcluindo] = useState(false);
  const [erroExclusao, setErroExclusao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  // Busca eventos e finalidades
  const carregar = useCallback(async () => {
    try {
      const dados = await buscarEventosEFinalidades();
      setEventos(dados.eventos);
      setFinalidades(dados.finalidades);
      setErro(null);
    } catch (e) {
      // O detalhe técnico vai só para o console; a tela mostra uma mensagem simples
      console.error("Falha ao carregar eventos:", e);
      setErro("Não foi possível carregar os eventos. Verifique a conexão e tente novamente.");
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

  // Confirma a exclusão (lógica) do evento escolhido
  async function confirmarExclusao() {
    if (!alvoExclusao) return;
    setExcluindo(true);
    setErroExclusao(null);
    try {
      await excluirEvento(alvoExclusao.id);
      await carregar();
      setAviso("Evento excluído.");
      setAlvoExclusao(null);
    } catch (e) {
      setErroExclusao(e instanceof Error ? e.message : "Não foi possível excluir o evento.");
    } finally {
      setExcluindo(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Eventos"
          descricao={`Cadastre e acompanhe os ensaios, cultos e reuniões do SysMúsica.${
            !carregando && !erro ? ` ${eventos.length} cadastrado(s).` : ""
          }`}
          acoes={
            pode("eventos.criar") ? (
              <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                Novo evento
              </Button>
            ) : undefined
          }
        />

        <ListaEventos
          eventos={eventos}
          finalidades={finalidades}
          carregando={carregando}
          erro={erro}
          onTentarNovamente={tentarNovamente}
          podeEditar={pode("eventos.editar")}
          podeExcluir={pode("eventos.excluir")}
          onEditar={(evento) => setPainel({ tipo: "editar", evento })}
          onExcluir={(evento) => {
            setErroExclusao(null);
            setAlvoExclusao(evento);
          }}
        />
      </div>

      {/* Painel lateral: novo evento ou edição */}
      <Drawer
        aberto={painel !== null}
        onFechar={() => setPainel(null)}
        titulo={painel?.tipo === "editar" ? "Editar evento" : "Novo evento"}
        descricao="Preencha os dados do evento."
      >
        {painel && (
          <FormularioEvento
            evento={painel.tipo === "editar" ? painel.evento : null}
            finalidades={finalidades}
            onSalvo={aoSalvar}
          />
        )}
      </Drawer>

      {/* Confirmação de exclusão */}
      <ConfirmDialog
        aberto={alvoExclusao !== null}
        titulo="Excluir evento?"
        mensagem={
          <>
            <p>
              O evento de{" "}
              <strong>{alvoExclusao ? formatarDataHora(alvoExclusao.data_evento) : ""}</strong> em{" "}
              <strong>{alvoExclusao?.local}</strong> deixará de aparecer nas telas. As presenças já
              registradas nele são mantidas no histórico.
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
