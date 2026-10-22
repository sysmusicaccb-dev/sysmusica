"use client";

/**
 * Sysmusica — Página /membros: listagem em tabela (largura total) com busca e filtros, novo,
 * editar, excluir e QR Code. Cada botão só aparece para quem tem a permissão (grupo do usuário);
 * o banco confere de novo em toda operação.
 * Excluir é exclusão lógica: o membro some das telas e o histórico de presenças é mantido.
 * Editar abre o formulário já com o CPF completo (só para quem tem a permissão membros.cpf).
 */
import { useCallback, useEffect, useState } from "react";
import { Plus, Users } from "lucide-react";
import {
  buscarDadosMembros,
  excluirMembro,
  obterCpfMembro,
  obterQrMembro,
  regenerarQrMembro,
} from "@/modules/membros/services/membros";
import QrMembro from "@/modules/membros/components/QrMembro";
import type { CadastroMusical } from "@/modules/membros/cadastroMusical";
import { obterCadastroMusical } from "@/modules/membros/services/cadastroMusical";
import { urlsDasFotos } from "@/modules/membros/services/fotos";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import Notificacao from "@/components/ui/Notificacao";
import BotaoCopiarLinkCadastro from "@/modules/cadastroPublico/components/BotaoCopiarLink";
import FormularioMembro from "@/components/FormularioMembro";
import ListaMembros from "@/components/ListaMembros";
import { valoresDistintos } from "@/lib/listas";
import { montarConteudoQr } from "@/lib/qr";
import { gerarImagemQr } from "@/lib/qrImagem";
import type { Cargo, Familia, Instrumento, MembroPublico } from "@/types/database";

// Qual painel lateral está aberto: novo membro, edição ou QR Code de um membro
type PainelMembro =
  | { tipo: "novo" }
  | { tipo: "editar"; membro: MembroPublico; cpfInicial: string | null; cadastro: CadastroMusical | null }
  | { tipo: "qr"; membro: MembroPublico; imagem: string; conteudo: string };

export default function MembrosPage() {
  const { pode } = useSessao();
  const [cargos, setCargos] = useState<Cargo[]>([]);
  const [instrumentos, setInstrumentos] = useState<Instrumento[]>([]);
  const [familias, setFamilias] = useState<Familia[]>([]);
  const [membros, setMembros] = useState<MembroPublico[]>([]);
  const [urlsFotos, setUrlsFotos] = useState<Record<string, string>>({}); // miniaturas da lista
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<PainelMembro | null>(null);
  const [abrindo, setAbrindo] = useState(false); // buscando CPF/QR antes de abrir o painel
  const [erroAcao, setErroAcao] = useState<string | null>(null);
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
      // Miniaturas: um único pedido de URLs temporárias para todas as fotos (se falhar, a lista fica sem miniaturas)
      setUrlsFotos(await urlsDasFotos(dados.membros.flatMap((m) => (m.foto_path ? [m.foto_path] : []))));
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

  // Abre a edição já com o CPF completo (a consulta fica registrada na auditoria)
  async function abrirEdicao(membro: MembroPublico) {
    if (abrindo) return;
    setErroAcao(null);
    setAbrindo(true);
    try {
      const [cpfInicial, cadastro] = await Promise.all([
        pode("membros.cpf") ? obterCpfMembro(membro.id) : Promise.resolve(null),
        obterCadastroMusical(membro.id), // dados pessoais do Cadastro Musical (null = membro antigo, sem cadastro)
      ]);
      setPainel({ tipo: "editar", membro, cpfInicial, cadastro });
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível abrir a edição.");
    } finally {
      setAbrindo(false);
    }
  }

  // Busca o código do QR Code no servidor (fica registrado na auditoria) e gera a imagem
  async function montarPainelQr(membro: MembroPublico, codigo: string): Promise<PainelMembro> {
    const conteudo = montarConteudoQr(codigo);
    const imagem = await gerarImagemQr(conteudo);
    return { tipo: "qr", membro, imagem, conteudo };
  }

  async function abrirQr(membro: MembroPublico) {
    if (abrindo) return;
    setErroAcao(null);
    setAbrindo(true);
    try {
      setPainel(await montarPainelQr(membro, await obterQrMembro(membro.id)));
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível abrir o QR Code.");
    } finally {
      setAbrindo(false);
    }
  }

  // Substitui o QR Code (o código antigo deixa de funcionar) e mostra a nova imagem
  async function substituirQr(membro: MembroPublico, justificativa: string) {
    const novoCodigo = await regenerarQrMembro(membro.id, justificativa);
    setPainel(await montarPainelQr(membro, novoCodigo));
    setAviso(`QR Code de "${membro.nome}" substituído. O código anterior deixou de funcionar.`);
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

  // Sugestões dos campos de localidade (valores já cadastrados)
  const sugestoes = {
    congregacoes: valoresDistintos(membros.map((membro) => membro.congregacao)),
    cidades: valoresDistintos(membros.map((membro) => membro.cidade)),
    bairros: valoresDistintos(membros.map((membro) => membro.bairro)),
  };

  const tituloPainel =
    painel?.tipo === "editar"
      ? "Editar cadastro musical"
      : painel?.tipo === "qr"
        ? "QR Code do membro"
        : "Cadastro Musical";

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {/* Cabeçalho no padrão do protótipo: ícone, título, descrição, copiar link de cadastro e Adicionar */}
        <header className="mb-5 flex flex-wrap items-center justify-between gap-4 rounded-xl border border-slate-200 bg-brand-50 px-5 py-4 shadow-sm">
          <div className="flex min-w-0 items-center gap-4">
            <Users className="h-10 w-10 shrink-0 text-brand-700" aria-hidden="true" />
            <div className="min-w-0">
              <h1 className="text-2xl font-bold tracking-tight text-slate-900">Músicos e Organistas</h1>
              <p className="text-sm text-slate-600">
                {`Cadastre e acompanhe os membros do Sysmusica.${!carregando && !erro ? ` ${membros.length} cadastrado(s).` : ""}`}
              </p>
            </div>
          </div>
          {pode("membros.criar") ? (
            <div className="flex flex-wrap gap-2">
              {/* Copia o link público /cadastro para enviar aos membros (o "+ Adicionar" continua interno) */}
              <BotaoCopiarLinkCadastro />
              <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                Adicionar
              </Button>
            </div>
          ) : null}
        </header>

        {erroAcao && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroAcao}
          </p>
        )}

        <ListaMembros
          membros={membros}
          cargos={cargos}
          instrumentos={instrumentos}
          familias={familias}
          carregando={carregando}
          erro={erro}
          urlsFotos={urlsFotos}
          onTentarNovamente={tentarNovamente}
          podeEditar={pode("membros.editar")}
          podeExcluir={pode("membros.excluir")}
          podeQr={pode("membros.qr")}
          onEditar={(membro) => void abrirEdicao(membro)}
          onQr={(membro) => void abrirQr(membro)}
          onExcluir={(membro) => {
            setErroExclusao(null);
            setAlvoExclusao(membro);
          }}
        />
      </div>

      {/* Painel lateral: novo membro, edição ou QR Code */}
      <Drawer
        aberto={painel !== null}
        onFechar={() => setPainel(null)}
        titulo={tituloPainel}
        descricao={
          painel?.tipo === "qr"
            ? "Identificação individual e permanente do membro."
            : "Campos com * são obrigatórios. A fotografia identifica a pessoa na portaria."
        }
      >
        {(painel?.tipo === "novo" || painel?.tipo === "editar") && (
          <FormularioMembro
            membro={painel.tipo === "editar" ? painel.membro : null}
            cpfInicial={painel.tipo === "editar" ? painel.cpfInicial : null}
            cadastroInicial={painel.tipo === "editar" ? painel.cadastro : null}
            podeCpf={pode("membros.cpf")}
            podeFoto={pode("membros.foto")}
            podeDocumento={pode("membros.cpf")}
            cargos={cargos}
            instrumentos={instrumentos}
            familias={familias}
            sugestoes={sugestoes}
            carregando={carregando}
            erro={erro}
            onSalvo={aoSalvar}
          />
        )}
        {painel?.tipo === "qr" && (
          <QrMembro
            nome={painel.membro.nome}
            congregacao={painel.membro.congregacao}
            imagem={painel.imagem}
            conteudo={painel.conteudo}
            podeSubstituir={pode("membros.qr_revogar")}
            onSubstituir={(justificativa) => substituirQr(painel.membro, justificativa)}
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
              presenças dele é mantido. Para apenas impedir novos registros sem excluir, altere a situação
              cadastral para Inativo na edição.
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
