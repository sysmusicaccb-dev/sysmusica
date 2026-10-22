"use client";

/**
 * Sysmusica — Página /administracao/organizacao: Estado › RRM › RA › ADM › Setor (opcional) › Casa de Oração.
 * Cadastro pelo sistema (sem código fixo), com ativar/inativar e transferência de casa de oração entre ADMs e setores.
 * Cada botão só aparece para quem tem a permissão; o banco confere de novo em toda operação.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import ArvoreOrganizacao from "@/modules/organizacao/components/ArvoreOrganizacao";
import FormularioNo, { type ModoNo } from "@/modules/organizacao/components/FormularioNo";
import FormularioTransferencia from "@/modules/organizacao/components/FormularioTransferencia";
import { motivoBloqueioExclusao, ROTULO_NIVEL } from "@/modules/organizacao/regras";
import { excluirNo, listarOrganizacao, salvarNo } from "@/modules/organizacao/services/organizacao";
import type { NivelOrganizacao, NoOrganizacao } from "@/modules/organizacao/tipos";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";

// Qual painel lateral está aberto
type Painel = { tipo: "no"; modo: ModoNo } | { tipo: "transferir"; casaOracao: NoOrganizacao };

// Título do painel lateral
function tituloDoPainel(painel: Painel | null): string {
  if (!painel) return "";
  if (painel.tipo === "transferir") return "Transferir casa de oração";
  const modo = painel.modo;
  return modo.tipo === "editar"
    ? `Editar ${ROTULO_NIVEL[modo.no.nivel].toLowerCase()}`
    : `Novo(a) ${ROTULO_NIVEL[modo.nivel].toLowerCase()}`;
}

export default function OrganizacaoPage() {
  const { pode } = useSessao();
  const podeCriar = pode("organizacao.criar");
  const podeEditar = pode("organizacao.editar");
  const podeTransferir = pode("organizacao.transferir");
  const podeExcluir = pode("organizacao.excluir");

  const [nos, setNos] = useState<NoOrganizacao[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<Painel | null>(null);
  const [alvoAlternar, setAlvoAlternar] = useState<NoOrganizacao | null>(null);
  const [alvoExcluir, setAlvoExcluir] = useState<NoOrganizacao | null>(null);
  const [erroAcao, setErroAcao] = useState<string | null>(null);
  const [processando, setProcessando] = useState(false);
  const [erroConfirmacao, setErroConfirmacao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    try {
      setNos(await listarOrganizacao());
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar a organização:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar a organização.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga ao abrir a página
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona). Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  function tentarNovamente() {
    setCarregando(true);
    void carregar();
  }

  // Depois de salvar: recarrega, fecha o painel e mostra o aviso
  async function aoSalvar(mensagem: string) {
    await carregar();
    setPainel(null);
    setAviso(mensagem);
  }

  // Ativa ou inativa o item (reenvia os dados atuais com a situação trocada)
  async function confirmarAlternar() {
    if (!alvoAlternar) return;
    setProcessando(true);
    setErroConfirmacao(null);
    try {
      await salvarNo({
        nivel: alvoAlternar.nivel,
        id: alvoAlternar.id,
        paiId: alvoAlternar.parent_id,
        nome: alvoAlternar.nome,
        descricao: alvoAlternar.descricao ?? "",
        ativo: alvoAlternar.ativo === false,
        cidade: alvoAlternar.cidade ?? "",
        bairro: alvoAlternar.bairro ?? "",
      });
      await carregar();
      setAviso(`"${alvoAlternar.nome}" ${alvoAlternar.ativo === false ? "ativado(a)" : "inativado(a)"}.`);
      setAlvoAlternar(null);
    } catch (e) {
      setErroConfirmacao(e instanceof Error ? e.message : "Não foi possível alterar a situação.");
    } finally {
      setProcessando(false);
    }
  }

  // Pede a exclusão: se o item ainda tiver algo dentro, explica o motivo; senão abre a confirmação
  function pedirExclusao(no: NoOrganizacao) {
    const motivo = motivoBloqueioExclusao(no);
    if (motivo) {
      setErroAcao(motivo);
      return;
    }
    setErroAcao(null);
    setErroConfirmacao(null);
    setAlvoExcluir(no);
  }

  // Exclui de vez o item (o banco confere de novo e informa se houver eventos, portarias ou usuários ligados)
  async function confirmarExclusao() {
    if (!alvoExcluir) return;
    setProcessando(true);
    setErroConfirmacao(null);
    try {
      await excluirNo(alvoExcluir.nivel, alvoExcluir.id);
      await carregar();
      setAviso(`"${alvoExcluir.nome}" excluído(a).`);
      setAlvoExcluir(null);
    } catch (e) {
      setErroConfirmacao(e instanceof Error ? e.message : "Não foi possível excluir.");
    } finally {
      setProcessando(false);
    }
  }

  function abrirNovo(nivel: NivelOrganizacao, pai: NoOrganizacao | null) {
    setPainel({ tipo: "no", modo: { tipo: "novo", nivel, pai } });
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Organização"
          descricao="Estado › RRM › RA › ADM › Setor (opcional) › Casa de Oração. O acesso dos usuários aos dados segue esta estrutura."
          acoes={
            podeCriar ? (
              <Button icone={Plus} onClick={() => abrirNovo("ESTADO", null)} disabled={carregando || !!erro}>
                Adicionar
              </Button>
            ) : undefined
          }
        />

        {erroAcao && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroAcao}
          </p>
        )}

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando a organização...</span>
            {[0, 1, 2, 3, 4].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar a organização." mensagem={erro} onTentarNovamente={tentarNovamente} />
        ) : nos.length === 0 ? (
          <EmptyState
            titulo="Nenhum item cadastrado."
            descricao={podeCriar ? "Clique em “Adicionar” para começar." : "A estrutura ainda não foi cadastrada."}
          />
        ) : (
          <ArvoreOrganizacao
            nos={nos}
            podeCriar={podeCriar}
            podeEditar={podeEditar}
            podeTransferir={podeTransferir}
            podeExcluir={podeExcluir}
            onExcluir={pedirExclusao}
            onNovo={abrirNovo}
            onEditar={(no) => setPainel({ tipo: "no", modo: { tipo: "editar", no } })}
            onAlternar={(no) => {
              setErroConfirmacao(null);
              setAlvoAlternar(no);
            }}
            onTransferir={(casaOracao) => setPainel({ tipo: "transferir", casaOracao })}
          />
        )}
      </div>

      <Drawer
        aberto={painel !== null}
        onFechar={() => setPainel(null)}
        titulo={tituloDoPainel(painel)}
        descricao={
          painel?.tipo === "transferir"
            ? "A casa de oração e as portarias dela passam a valer para o destino escolhido (ADM ou setor)."
            : "Os nomes não podem se repetir dentro do mesmo item pai."
        }
      >
        {painel?.tipo === "no" && <FormularioNo modo={painel.modo} onSalvo={aoSalvar} />}
        {painel?.tipo === "transferir" && (
          <FormularioTransferencia casaOracao={painel.casaOracao} nos={nos} onSalvo={aoSalvar} />
        )}
      </Drawer>

      <ConfirmDialog
        aberto={alvoAlternar !== null}
        titulo={alvoAlternar?.ativo === false ? "Ativar item?" : "Inativar item?"}
        mensagem={
          <>
            <p>
              {alvoAlternar?.ativo === false ? (
                <>
                  <strong>{alvoAlternar?.nome}</strong> volta a aparecer nas escolhas e a valer para o acesso.
                </>
              ) : (
                <>
                  <strong>{alvoAlternar?.nome}</strong> deixa de aparecer nas escolhas e quem tem acesso por esse
                  item (e pelos itens abaixo dele) perde o acesso aos dados dele. Quem tem acesso total não é
                  afetado.
                </>
              )}
            </p>
            {erroConfirmacao && (
              <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">
                {erroConfirmacao}
              </p>
            )}
          </>
        }
        textoConfirmar={alvoAlternar?.ativo === false ? "Ativar" : "Inativar"}
        processando={processando}
        onConfirmar={() => void confirmarAlternar()}
        onCancelar={() => setAlvoAlternar(null)}
      />

      <ConfirmDialog
        aberto={alvoExcluir !== null}
        titulo="Excluir item?"
        mensagem={
          <>
            <p>
              <strong>{alvoExcluir?.nome}</strong> será excluído(a) de vez. Esta ação não pode ser desfeita. Se
              preferir só esconder, use Inativar.
            </p>
            {erroConfirmacao && (
              <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">
                {erroConfirmacao}
              </p>
            )}
          </>
        }
        textoConfirmar="Excluir"
        processando={processando}
        onConfirmar={() => void confirmarExclusao()}
        onCancelar={() => setAlvoExcluir(null)}
      />

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
