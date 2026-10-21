"use client";

/**
 * SysMúsica — Página /cadastros-pendentes: cadastros enviados pelo link público (/cadastro), aguardando análise.
 * Aprovar cria o membro (ou atualiza o que já existe); Recusar exige um motivo. Nada entra no sistema sem aprovação.
 * Cada pessoa só enxerga os pedidos das Casas de Oração da sua abrangência.
 */
import { useCallback, useEffect, useState } from "react";
import {
  aprovarCadastro,
  avisarQueFilaMudou,
  listarCadastros,
  obterCadastro,
  recusarCadastro,
} from "@/modules/cadastrosPendentes/services/cadastrosPendentes";
import DetalheDoCadastro from "@/modules/cadastrosPendentes/components/DetalheCadastro";
import TabelaCadastros from "@/modules/cadastrosPendentes/components/TabelaCadastros";
import { validarMotivo } from "@/modules/cadastrosPendentes/regras";
import type { DetalheCadastro, FiltroStatus, ResumoCadastro } from "@/modules/cadastrosPendentes/tipos";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";

const FILTROS: { valor: FiltroStatus; rotulo: string }[] = [
  { valor: "PENDENTE", rotulo: "Pendentes" },
  { valor: "APROVADO", rotulo: "Aprovados" },
  { valor: "REJEITADO", rotulo: "Recusados" },
  { valor: "EXPIRADO", rotulo: "Vencidos" },
  { valor: "TODOS", rotulo: "Todos" },
];

export default function CadastrosPendentesPage() {
  const { pode } = useSessao();
  const [filtro, setFiltro] = useState<FiltroStatus>("PENDENTE");
  const [itens, setItens] = useState<ResumoCadastro[]>([]);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [aberto, setAberto] = useState<DetalheCadastro | null>(null);
  const [abrindoId, setAbrindoId] = useState<string | null>(null);
  const [confirmando, setConfirmando] = useState<"aprovar" | "recusar" | null>(null);
  const [motivo, setMotivo] = useState("");
  const [erroDecisao, setErroDecisao] = useState<string | null>(null);
  const [processando, setProcessando] = useState(false);
  const [aviso, setAviso] = useState<string | null>(null);
  const [casaEscolhida, setCasaEscolhida] = useState(""); // casa escolhida ao aprovar um pedido com casa digitada

  const carregar = useCallback(async (status: FiltroStatus) => {
    try {
      setItens(await listarCadastros(status));
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar cadastros pendentes:", e);
      setErro("Não foi possível carregar os cadastros. Verifique a conexão e tente novamente.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await, então o aviso da regra set-state-in-effect não se aplica aqui.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar(filtro);
  }, [carregar, filtro]);

  function trocarFiltro(novo: FiltroStatus) {
    setCarregando(true);
    setFiltro(novo);
  }

  async function abrir(item: ResumoCadastro) {
    if (abrindoId) return;
    setAbrindoId(item.id);
    setAviso(null);
    try {
      setAberto(await obterCadastro(item.id));
    } catch (e) {
      setAviso(e instanceof Error ? e.message : "Não foi possível abrir o cadastro.");
    } finally {
      setAbrindoId(null);
    }
  }

  function fecharDecisao() {
    setConfirmando(null);
    setCasaEscolhida("");
    setMotivo("");
    setErroDecisao(null);
  }

  async function decidir() {
    if (!aberto || !confirmando) return;
    if (confirmando === "recusar") {
      const problema = validarMotivo(motivo);
      if (problema) return setErroDecisao(problema);
    }
    setProcessando(true);
    setErroDecisao(null);
    try {
      if (confirmando === "aprovar") {
        await aprovarCadastro(aberto.id, casaEscolhida || undefined);
        setAviso(
          aberto.tipo === "NOVO"
            ? `Cadastro de "${aberto.nome}" aprovado: o membro foi criado.`
            : `Cadastro de "${aberto.nome}" aprovado: os dados do membro foram atualizados.`
        );
      } else {
        await recusarCadastro(aberto.id, motivo.trim());
        setAviso(`Cadastro de "${aberto.nome}" recusado.`);
      }
      fecharDecisao();
      setAberto(null);
      await carregar(filtro);
    } catch (e) {
      setErroDecisao(e instanceof Error ? e.message : "Não foi possível concluir.");
      avisarQueFilaMudou(); // se outro aprovador já decidiu, o contador do menu se acerta
    } finally {
      setProcessando(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Cadastros pendentes"
          descricao="Cadastros enviados pelo link público. Nada entra no sistema sem a sua aprovação."
        />

        <div role="group" aria-label="Filtrar por situação" className="mb-4 flex flex-wrap gap-1">
          {FILTROS.map((f) => (
            <button
              key={f.valor}
              type="button"
              aria-pressed={filtro === f.valor}
              onClick={() => trocarFiltro(f.valor)}
              className={
                "rounded-lg px-3 py-1.5 text-sm font-medium transition " +
                (filtro === f.valor ? "bg-brand-600 text-white" : "bg-slate-100 text-slate-700 hover:bg-slate-200")
              }
            >
              {f.rotulo}
            </button>
          ))}
        </div>

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando cadastros...</span>
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState
            titulo="Não foi possível carregar os cadastros."
            mensagem={erro}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar(filtro);
            }}
          />
        ) : itens.length === 0 ? (
          <EmptyState
            titulo={filtro === "PENDENTE" ? "Nenhum cadastro aguardando análise." : "Nenhum cadastro nesta situação."}
            descricao="O link para divulgar é o endereço do sistema seguido de /cadastro (há um botão para copiá-lo em Músicos / Organistas)."
          />
        ) : (
          <TabelaCadastros itens={itens} onAbrir={(item) => void abrir(item)} />
        )}
      </div>

      <Drawer
        aberto={aberto !== null}
        onFechar={() => setAberto(null)}
        titulo={aberto?.nome ?? "Cadastro"}
        descricao="Confira os dados e as imagens antes de decidir."
      >
        {aberto && (
          <DetalheDoCadastro
            key={aberto.id}
            detalhe={aberto}
            podeAprovar={pode("cadastros.aprovar")}
            ocupado={processando}
            onAprovar={(casaId) => {
              setErroDecisao(null);
              setCasaEscolhida(casaId ?? "");
              setConfirmando("aprovar");
            }}
            onRecusar={() => {
              setErroDecisao(null);
              setConfirmando("recusar");
            }}
          />
        )}
      </Drawer>

      <ConfirmDialog
        aberto={confirmando !== null}
        titulo={confirmando === "aprovar" ? "Aprovar este cadastro?" : "Recusar este cadastro?"}
        mensagem={
          <>
            {confirmando === "aprovar" ? (
              <p>
                {aberto?.tipo === "NOVO" ? (
                  <>
                    O membro <strong>{aberto?.nome}</strong> será criado com estes dados.
                  </>
                ) : (
                  <>
                    Os dados de <strong>{aberto?.nome}</strong> serão substituídos pelos do pedido.
                  </>
                )}
              </p>
            ) : (
              <div className="space-y-2">
                <p>Explique o motivo. Ele fica registrado para a secretaria; a pessoa não é avisada pelo sistema.</p>
                <label htmlFor="motivo-recusa" className="sr-only">
                  Motivo da recusa
                </label>
                <textarea
                  id="motivo-recusa"
                  rows={3}
                  maxLength={300}
                  value={motivo}
                  onChange={(e) => setMotivo(e.target.value)}
                  className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 [color-scheme:light]"
                  placeholder="Ex.: documento ilegível, envie novamente"
                />
              </div>
            )}
            {erroDecisao && (
              <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">
                {erroDecisao}
              </p>
            )}
          </>
        }
        textoConfirmar={confirmando === "aprovar" ? "Aprovar" : "Recusar"}
        processando={processando}
        onConfirmar={() => void decidir()}
        onCancelar={fecharDecisao}
      />

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
