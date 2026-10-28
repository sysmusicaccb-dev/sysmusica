"use client";

/**
 * Sysmusica — Página /eventos: listagem em tabela (largura total), do evento mais recente para o
 * mais antigo, com novo, editar e excluir. Cada botão só aparece para quem tem a permissão
 * (grupo do usuário); o banco confere de novo em toda operação.
 * Excluir é exclusão lógica: o evento some das telas e as presenças registradas são mantidas.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import {
  buscarEventosEFinalidades,
  encerrarEvento,
  excluirEvento,
  reabrirEvento,
} from "@/modules/eventos/services/eventos";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import FormularioEvento from "@/components/FormularioEvento";
import ListaEventos from "@/components/ListaEventos";
import AbasDeLista from "@/components/AbasDeLista";
import FormularioCancelamento from "@/modules/eventos/components/FormularioCancelamento";
import { abaDoEvento, type AbaEvento } from "@/modules/eventos/ciclo";
import { formatarDataHora } from "@/lib/datas";
import { chaveDoTipo, listarModelosDosTipos } from "@/modules/eventos/services/configEventos";
import { valoresDistintos } from "@/lib/listas";
import type { Evento, FinalidadeEvento } from "@/types/database";

// Qual painel lateral está aberto: novo evento, ou edição de um evento
type PainelEvento = { tipo: "novo" } | { tipo: "editar"; evento: Evento } | { tipo: "cancelar"; evento: Evento };

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
  const [alvoEncerrar, setAlvoEncerrar] = useState<Evento | null>(null); // evento que quem aprova portarias vai encerrar
  const [encerrando, setEncerrando] = useState(false);
  const [erroEncerrar, setErroEncerrar] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  const [aba, setAba] = useState<AbaEvento>("proximos");
  const [agora, setAgora] = useState(0); // instante atual (ms); 0 até a primeira carga
  // Tipo do evento -> Local/Regional: decide quem vê o botão Encerrar (o banco confere de novo ao encerrar)
  const [modelos, setModelos] = useState<Map<string, string | null>>(new Map());
  useEffect(() => {
    let ativo = true;
    listarModelosDosTipos()
      .then((mapa) => {
        if (ativo) setModelos(mapa);
      })
      .catch((e: unknown) => console.error("Falha ao carregar os tipos de evento:", e));
    return () => {
      ativo = false;
    };
  }, []);
  // Administrador/Administrador Regional: qualquer evento. Instrutor: ensaio Local. Secretário da Música: Regional e demais.
  const podeEncerrarEste = (evento: Evento): boolean => {
    if (pode("eventos.encerrar_qualquer")) return true;
    const modelo = modelos.get(chaveDoTipo(evento.tipo)) ?? null;
    return modelo === "LOCAL" ? pode("eventos.encerrar_local") : pode("eventos.encerrar_regional");
  };

  // Busca eventos e finalidades
  const carregar = useCallback(async () => {
    try {
      const dados = await buscarEventosEFinalidades();
      setEventos(dados.eventos);
      setAgora(Date.now());
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

  // Mantém a situação dos eventos em dia: um evento que termina sai de "Próximos" sozinho
  useEffect(() => {
    const id = setInterval(() => setAgora(Date.now()), 60_000);
    return () => clearInterval(id);
  }, []);

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

  // Encerra o evento antes do horário (o banco confere a permissão, a abrangência e se ele está em andamento)
  async function confirmarEncerramento() {
    if (!alvoEncerrar) return;
    setEncerrando(true);
    setErroEncerrar(null);
    try {
      await encerrarEvento(alvoEncerrar.id);
      await carregar();
      setAviso("Evento encerrado.");
      setAlvoEncerrar(null);
    } catch (e) {
      setErroEncerrar(e instanceof Error ? e.message : "Não foi possível encerrar o evento.");
    } finally {
      setEncerrando(false);
    }
  }

  // Reabre um evento encerrado à mão (só o Administrador; vale enquanto o horário do evento ainda vale)
  async function reabrir(evento: Evento) {
    try {
      await reabrirEvento(evento.id);
      await carregar();
      setAviso("Evento reaberto.");
    } catch (e) {
      setAviso(e instanceof Error ? e.message : "Não foi possível reabrir o evento.");
    }
  }

  // Cada evento aparece em UMA aba. Próximos: do mais perto para o mais longe; as demais: do mais recente.
  const eventosDaAba = (alvo: AbaEvento) =>
    eventos.filter((evento) => abaDoEvento(evento.data_evento, Boolean(evento.cancelado_em), agora, evento.encerrado_em) === alvo);
  const proximos = eventosDaAba("proximos").reverse(); // a busca vem do mais recente para o mais antigo
  const encerrados = eventosDaAba("encerrados");
  const arquivo = eventosDaAba("arquivo");
  const visiveis = aba === "proximos" ? proximos : aba === "encerrados" ? encerrados : arquivo;
  const textosVazios: Record<AbaEvento, { titulo: string; descricao: string }> = {
    proximos: {
      titulo: "Nenhum evento em andamento ou agendado.",
      descricao: "Clique em “Adicionar” para cadastrar o próximo. Os eventos já encerrados estão na aba Encerrados.",
    },
    encerrados: {
      titulo: "Nenhum evento encerrado recentemente.",
      descricao: "Quando um evento terminar (ou for cancelado), ele passa a aparecer aqui.",
    },
    arquivo: {
      titulo: "O arquivo está vazio.",
      descricao: "Eventos encerrados há mais de 30 dias ficam guardados aqui para consulta.",
    },
  };

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Eventos"
          descricao={`Cadastre e acompanhe os ensaios, cultos e reuniões do Sysmusica.${
            !carregando && !erro ? ` ${eventos.length} cadastrado(s).` : ""
          }`}
          acoes={
            pode("eventos.criar") ? (
              <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                Adicionar
              </Button>
            ) : undefined
          }
        />

        {!carregando && !erro && (
          <AbasDeLista
            descricao="Situação dos eventos"
            atual={aba}
            onTrocar={setAba}
            abas={[
              { id: "proximos", rotulo: "Próximos", total: proximos.length },
              { id: "encerrados", rotulo: "Encerrados", total: encerrados.length },
              { id: "arquivo", rotulo: "Arquivo", total: arquivo.length },
            ]}
          />
        )}

        <ListaEventos
          eventos={eventos.length === 0 ? eventos : visiveis}
          agora={agora}
          tituloVazio={eventos.length === 0 ? undefined : textosVazios[aba].titulo}
          descricaoVazia={eventos.length === 0 ? undefined : textosVazios[aba].descricao}
          finalidades={finalidades}
          carregando={carregando}
          erro={erro}
          onTentarNovamente={tentarNovamente}
          podeEditar={pode("eventos.editar")}
          podeExcluir={pode("eventos.excluir")}
          podeCancelar={pode("eventos.cancelar")}
          podeEncerrar={pode("eventos.encerrar_qualquer") || pode("eventos.encerrar_regional") || pode("eventos.encerrar_local")}
          podeEncerrarEvento={podeEncerrarEste}
          onEncerrar={(evento) => {
            setErroEncerrar(null);
            setAlvoEncerrar(evento);
          }}
          onReabrir={(evento) => void reabrir(evento)}
          onCancelar={(evento) => setPainel({ tipo: "cancelar", evento })}
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
        titulo={
          painel?.tipo === "editar" ? "Editar evento" : painel?.tipo === "cancelar" ? "Cancelar evento" : "Novo evento"
        }
        descricao={
          painel?.tipo === "cancelar"
            ? "Informe o motivo: ele fica guardado no histórico."
            : "Preencha os dados do evento."
        }
      >
        {painel?.tipo === "cancelar" && <FormularioCancelamento evento={painel.evento} onSalvo={aoSalvar} />}
        {painel && painel.tipo !== "cancelar" && (
          <FormularioEvento
            evento={painel.tipo === "editar" ? painel.evento : null}
            sugestoesCidade={valoresDistintos(eventos.flatMap((item) => (item.cidade ? [item.cidade] : [])))}
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
              <strong>{alvoExclusao?.local}</strong> deixará de aparecer nas telas. Eventos que já têm
              presenças registradas não podem ser excluídos: nesse caso o Administrador deve cancelá-lo (o histórico
              fica guardado).
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

      {/* Confirmação de encerramento (antes do horário) */}
      <ConfirmDialog
        aberto={alvoEncerrar !== null}
        titulo="Encerrar evento?"
        mensagem={
          <>
            <p>
              O evento de <strong>{alvoEncerrar ? formatarDataHora(alvoEncerrar.data_evento) : ""}</strong> em{" "}
              <strong>{alvoEncerrar?.local}</strong> deixará de aparecer no Painel ao Vivo, a Portaria não registrará mais
              entradas e ele passará para a aba Encerrados. Só o Administrador pode reabri-lo.
            </p>
            {erroEncerrar && (
              <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">
                {erroEncerrar}
              </p>
            )}
          </>
        }
        textoConfirmar="Encerrar"
        processando={encerrando}
        onConfirmar={() => void confirmarEncerramento()}
        onCancelar={() => setAlvoEncerrar(null)}
      />

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
