"use client";

/**
 * SysMúsica — Página /portaria: histórico de presenças agrupado por evento (largura total).
 * "Registrar presenças" abre o formulário de lançamento em um painel lateral; cada presença
 * tem editar e excluir. Cada botão só aparece para quem tem a permissão (grupo do usuário);
 * o banco confere de novo em toda operação.
 * Excluir é exclusão lógica: o registro some da portaria e dos relatórios e fica guardado no banco.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import { buscarDadosPortaria, excluirPresenca } from "@/modules/portaria/services/portaria";
import FormularioEdicaoPresenca from "@/modules/portaria/components/FormularioEdicaoPresenca";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import FormularioPresenca from "@/components/FormularioPresenca";
import ListaPresencas from "@/components/ListaPresencas";
import { formatarDataHora } from "@/lib/datas";
import type { Evento, Instrumento, MembroPublico, Presenca } from "@/types/database";

// Qual painel lateral está aberto: lançar presenças, ou editar uma presença
type PainelPortaria = { tipo: "registrar" } | { tipo: "editar"; presenca: Presenca };

export default function PortariaPage() {
  const { pode } = useSessao();
  const [eventos, setEventos] = useState<Evento[]>([]);
  const [membros, setMembros] = useState<MembroPublico[]>([]);
  const [instrumentos, setInstrumentos] = useState<Instrumento[]>([]);
  const [presencas, setPresencas] = useState<Presenca[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<PainelPortaria | null>(null);
  const [alvoExclusao, setAlvoExclusao] = useState<Presenca | null>(null);
  const [excluindo, setExcluindo] = useState(false);
  const [erroExclusao, setErroExclusao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  // Busca eventos, membros, presenças e instrumentos
  const carregar = useCallback(async () => {
    try {
      const dados = await buscarDadosPortaria();
      setEventos(dados.eventos);
      setMembros(dados.membros);
      setInstrumentos(dados.instrumentos);
      setPresencas(dados.presencas);
      setErro(null);
    } catch (e) {
      // O detalhe técnico vai só para o console; a tela mostra uma mensagem simples
      console.error("Falha ao carregar a portaria:", e);
      setErro("Não foi possível carregar os dados. Verifique a conexão e tente novamente.");
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

  // Depois de salvar: recarrega os dados, fecha o painel e mostra o aviso de sucesso
  async function aoSalvar(mensagem: string) {
    await carregar();
    setPainel(null);
    setAviso(mensagem);
  }

  // Textos de identificação usados na edição e na confirmação de exclusão
  const nomeDoMembro = (membroId: string) =>
    membros.find((membro) => membro.id === membroId)?.nome ?? "Membro excluído";
  const descricaoDoEvento = (eventoId: string) => {
    const evento = eventos.find((item) => item.id === eventoId);
    return evento
      ? `${evento.tipo} · ${formatarDataHora(evento.data_evento)} · ${evento.local}`
      : "Evento";
  };

  // Confirma a exclusão (lógica) da presença escolhida
  async function confirmarExclusao() {
    if (!alvoExclusao) return;
    setExcluindo(true);
    setErroExclusao(null);
    try {
      await excluirPresenca(alvoExclusao.id);
      await carregar();
      setAviso(`Presença de "${nomeDoMembro(alvoExclusao.membro_id)}" excluída.`);
      setAlvoExclusao(null);
    } catch (e) {
      setErroExclusao(e instanceof Error ? e.message : "Não foi possível excluir o registro.");
    } finally {
      setExcluindo(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Portaria"
          descricao={`Controle de entrada dos membros nos eventos.${
            !carregando && !erro ? ` ${presencas.length} registro(s).` : ""
          }`}
          acoes={
            pode("portaria.registrar") ? (
              <Button icone={Plus} onClick={() => setPainel({ tipo: "registrar" })} disabled={carregando || !!erro}>
                Registrar presenças
              </Button>
            ) : undefined
          }
        />

        <ListaPresencas
          presencas={presencas}
          membros={membros}
          instrumentos={instrumentos}
          eventos={eventos}
          carregando={carregando}
          erro={erro}
          onTentarNovamente={tentarNovamente}
          podeEditar={pode("portaria.editar")}
          podeExcluir={pode("portaria.excluir")}
          onEditar={(presenca) => setPainel({ tipo: "editar", presenca })}
          onExcluir={(presenca) => {
            setErroExclusao(null);
            setAlvoExclusao(presenca);
          }}
        />
      </div>

      {/* Painel lateral: lançar presenças ou editar uma presença */}
      <Drawer
        aberto={painel !== null}
        onFechar={() => setPainel(null)}
        titulo={painel?.tipo === "editar" ? "Editar presença" : "Registrar presenças"}
        descricao={
          painel?.tipo === "editar"
            ? "Corrija o status ou os horários deste registro."
            : "Escolha o evento e marque cada membro."
        }
      >
        {painel?.tipo === "registrar" && (
          <FormularioPresenca
            eventos={eventos}
            membros={membros}
            instrumentos={instrumentos}
            presencas={presencas}
            carregando={carregando}
            erro={erro}
            onPresencaAdicionada={aoSalvar}
          />
        )}
        {painel?.tipo === "editar" && (
          <FormularioEdicaoPresenca
            presenca={painel.presenca}
            nomeMembro={nomeDoMembro(painel.presenca.membro_id)}
            descricaoEvento={descricaoDoEvento(painel.presenca.evento_id)}
            onSalvo={aoSalvar}
          />
        )}
      </Drawer>

      {/* Confirmação de exclusão */}
      <ConfirmDialog
        aberto={alvoExclusao !== null}
        titulo="Excluir presença?"
        mensagem={
          <>
            <p>
              O registro de <strong>{alvoExclusao ? nomeDoMembro(alvoExclusao.membro_id) : ""}</strong> em{" "}
              {alvoExclusao ? descricaoDoEvento(alvoExclusao.evento_id) : ""} deixará de aparecer na
              portaria e nos relatórios. Para apenas corrigir o status ou os horários, use Editar.
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
