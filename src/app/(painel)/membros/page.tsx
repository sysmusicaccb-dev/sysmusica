"use client";

/**
 * SysMúsica — Página /membros: listagem em tabela (largura total) com busca e filtros, novo,
 * editar e excluir. Cada botão só aparece para quem tem a permissão (grupo do usuário); o banco
 * confere de novo em toda operação.
 * Excluir é exclusão lógica: o membro some das telas e o histórico de presenças é mantido.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import {
  buscarDadosMembros,
  excluirMembro,
} from "@/modules/membros/services/membros";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import FormularioMembro from "@/components/FormularioMembro";
import ListaMembros from "@/components/ListaMembros";
import type { Cargo, Familia, Instrumento, MembroPublico } from "@/types/database";

// Qual painel lateral está aberto: novo membro, ou edição de um membro
type PainelMembro = { tipo: "novo" } | { tipo: "editar"; membro: MembroPublico };

export default function MembrosPage() {
  const { pode } = useSessao();
  const [cargos, setCargos] = useState<Cargo[]>([]);
  const [instrumentos, setInstrumentos] = useState<Instrumento[]>([]);
  const [familias, setFamilias] = useState<Familia[]>([]);
  const [membros, setMembros] = useState<MembroPublico[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<PainelMembro | null>(null);
  const [alvoExclusao, setAlvoExclusao] = useState<MembroPublico | null>(null);
  const [excluindo, setExcluindo] = useState(false);
  const [erroExclusao, setErroExclusao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  // Busca cargos, instrumentos, famílias e membros
  const carregar = useCallback(async () => {
    try {
      const dados = await buscarDadosMembros();
      setCargos(dados.cargos);
      setInstrumentos(dados.instrumentos);
      setFamilias(dados.familias);
      setMembros(dados.membros);
      setErro(null);
    } catch (e) {
      // O detalhe técnico vai só para o console; a tela mostra uma mensagem simples
      console.error("Falha ao carregar membros:", e);
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

  // Depois de salvar: recarrega a lista, fecha o painel e mostra o aviso de sucesso
  async function aoSalvar(mensagem: string) {
    await carregar();
    setPainel(null);
    setAviso(mensagem);
  }

  // Confirma a exclusão (lógica) do membro escolhido
  async function confirmarExclusao() {
    if (!alvoExclusao) return;
    setExcluindo(true);
    setErroExclusao(null);
    try {
      await excluirMembro(alvoExclusao.id);
      await carregar();
      setAviso(`Membro "${alvoExclusao.nome}" excluído.`);
      setAlvoExclusao(null);
    } catch (e) {
      setErroExclusao(e instanceof Error ? e.message : "Não foi possível excluir o membro.");
    } finally {
      setExcluindo(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Membros"
          descricao={`Cadastre e acompanhe os membros do SysMúsica.${
            !carregando && !erro ? ` ${membros.length} cadastrado(s).` : ""
          }`}
          acoes={
            pode("membros.criar") ? (
              <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                Novo membro
              </Button>
            ) : undefined
          }
        />

        <ListaMembros
          membros={membros}
          cargos={cargos}
          instrumentos={instrumentos}
          familias={familias}
          carregando={carregando}
          erro={erro}
          onTentarNovamente={tentarNovamente}
          podeEditar={pode("membros.editar")}
          podeExcluir={pode("membros.excluir")}
          onEditar={(membro) => setPainel({ tipo: "editar", membro })}
          onExcluir={(membro) => {
            setErroExclusao(null);
            setAlvoExclusao(membro);
          }}
        />
      </div>

      {/* Painel lateral: novo membro ou edição */}
      <Drawer
        aberto={painel !== null}
        onFechar={() => setPainel(null)}
        titulo={painel?.tipo === "editar" ? "Editar membro" : "Novo membro"}
        descricao="Preencha os dados do membro."
      >
        {painel && (
          <FormularioMembro
            membro={painel.tipo === "editar" ? painel.membro : null}
            cargos={cargos}
            instrumentos={instrumentos}
            familias={familias}
            carregando={carregando}
            erro={erro}
            onSalvo={aoSalvar}
          />
        )}
      </Drawer>

      {/* Confirmação de exclusão */}
      <ConfirmDialog
        aberto={alvoExclusao !== null}
        titulo="Excluir membro?"
        mensagem={
          <>
            <p>
              <strong>{alvoExclusao?.nome}</strong> deixará de aparecer nas telas. O histórico de
              presenças dele é mantido. Para apenas impedir novos registros sem excluir, altere o status
              para Inativo na edição.
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
