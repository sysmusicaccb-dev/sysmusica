"use client";

/**
 * SysMúsica — Administração > Usuários: lista de usuários com criar, editar, redefinir senha e
 * ativar/desativar. Cada botão só aparece para quem tem a permissão; o banco e o servidor
 * conferem a permissão de novo em toda operação.
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
import FormularioVinculos from "@/modules/administracao/components/FormularioVinculos";
import { rotulosPorUsuario } from "@/modules/organizacao/regras";
import { listarOrganizacao, listarVinculosRotulados } from "@/modules/organizacao/services/organizacao";
import type { NoOrganizacao, VinculoRotulado } from "@/modules/organizacao/tipos";
import FormularioSenha from "@/modules/administracao/components/FormularioSenha";
import FormularioUsuario from "@/modules/administracao/components/FormularioUsuario";
import TabelaUsuarios from "@/modules/administracao/components/TabelaUsuarios";
import {
  atualizarUsuario,
  // (a abrangência por cidade foi substituída pelos vínculos organizacionais)
  listarGrupos,
  listarUsuarios,
} from "@/modules/administracao/services/acesso";
import type { GrupoAcesso, UsuarioSistema } from "@/modules/administracao/tipos";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";

// Qual painel lateral está aberto (e para qual usuário)
type PainelUsuario =
  | { tipo: "novo" }
  | { tipo: "editar"; usuario: UsuarioSistema }
  | { tipo: "senha"; usuario: UsuarioSistema }
  | { tipo: "abrangencia"; usuario: UsuarioSistema };

export default function UsuariosPage() {
  const { pode, sessao } = useSessao();
  const meuId = sessao?.user.id ?? null;

  const [usuarios, setUsuarios] = useState<UsuarioSistema[]>([]);
  const [grupos, setGrupos] = useState<GrupoAcesso[]>([]);
  const [abrangencias, setAbrangencias] = useState<Record<string, VinculoRotulado[]>>({});
  const [arvore, setArvore] = useState<NoOrganizacao[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<PainelUsuario | null>(null);
  const [alvoStatus, setAlvoStatus] = useState<UsuarioSistema | null>(null); // confirmação ativar/desativar
  const [alterandoStatus, setAlterandoStatus] = useState(false);
  const [erroStatus, setErroStatus] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  // Busca usuários e grupos em paralelo
  const carregar = useCallback(async () => {
    try {
      const [listaUsuarios, listaGrupos, mapaAbrangencias, listaCidades] = await Promise.all([
        listarUsuarios(),
        listarGrupos(),
        listarVinculosRotulados(),
        // só quem edita usuários lista as cidades; para os demais a lista fica vazia
        listarOrganizacao().catch(() => [] as NoOrganizacao[]),
      ]);
      setUsuarios(listaUsuarios);
      setGrupos(listaGrupos);
      setAbrangencias(mapaAbrangencias);
      setArvore(listaCidades);
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar usuários:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar os usuários.");
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

  // Confirma ativar/desativar o usuário escolhido
  async function confirmarStatus() {
    if (!alvoStatus) return;
    setAlterandoStatus(true);
    setErroStatus(null);
    try {
      await atualizarUsuario({
        id: alvoStatus.id,
        nome: alvoStatus.nome,
        grupoId: alvoStatus.grupo_id,
        ativo: !alvoStatus.ativo,
      });
      await carregar();
      setAviso(`Usuário "${alvoStatus.nome}" ${alvoStatus.ativo ? "desativado" : "ativado"}.`);
      setAlvoStatus(null);
    } catch (e) {
      setErroStatus(e instanceof Error ? e.message : "Não foi possível alterar o status.");
    } finally {
      setAlterandoStatus(false);
    }
  }

  const titulosPainel = {
    novo: { titulo: "Novo usuário", descricao: "Crie a conta de login e escolha o grupo de acesso." },
    editar: { titulo: "Editar usuário", descricao: "Altere o nome ou o grupo de acesso." },
    senha: { titulo: "Redefinir senha", descricao: "Defina uma nova senha para este usuário." },
    abrangencia: {
      titulo: "Vínculos organizacionais",
      descricao: "Estado, região, setor ou comum que o usuário pode ver e usar.",
    },
  } as const;

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Usuários"
          descricao={`Quem acessa o sistema e o grupo de cada um.${
            !carregando && !erro ? ` ${usuarios.length} usuário(s).` : ""
          }`}
          acoes={
            pode("usuarios.criar") ? (
              <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                Novo usuário
              </Button>
            ) : undefined
          }
        />

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando usuários...</span>
            <Skeleton className="h-14 rounded-2xl" />
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar os usuários." mensagem={erro} onTentarNovamente={tentarNovamente} />
        ) : usuarios.length === 0 ? (
          <EmptyState titulo="Nenhum usuário cadastrado." descricao="Clique em “Novo usuário” para criar o primeiro." />
        ) : (
          <>
            {erroStatus && !alvoStatus && (
              <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
                {erroStatus}
              </p>
            )}
            <TabelaUsuarios
              usuarios={usuarios}
              grupos={grupos}
              meuId={meuId}
              podeEditar={pode("usuarios.editar")}
              onEditar={(usuario) => setPainel({ tipo: "editar", usuario })}
              onRedefinirSenha={(usuario) => setPainel({ tipo: "senha", usuario })}
              cidadesPorUsuario={rotulosPorUsuario(abrangencias)}
              onAbrangencia={(usuario) => setPainel({ tipo: "abrangencia", usuario })}
              onAlterarStatus={(usuario) => {
                setErroStatus(null);
                setAlvoStatus(usuario);
              }}
            />
          </>
        )}
      </div>

      {/* Painel lateral: novo, editar ou redefinir senha */}
      <Drawer
        aberto={painel !== null}
        onFechar={() => setPainel(null)}
        titulo={painel ? titulosPainel[painel.tipo].titulo : ""}
        descricao={painel ? titulosPainel[painel.tipo].descricao : undefined}
      >
        {painel?.tipo === "novo" && (
          <FormularioUsuario usuario={null} grupos={grupos} meuId={meuId} onSalvo={aoSalvar} />
        )}
        {painel?.tipo === "editar" && (
          <FormularioUsuario usuario={painel.usuario} grupos={grupos} meuId={meuId} onSalvo={aoSalvar} />
        )}
        {painel?.tipo === "senha" && <FormularioSenha usuario={painel.usuario} onSalvo={aoSalvar} />}
        {painel?.tipo === "abrangencia" && (
          <FormularioVinculos
            usuario={painel.usuario}
            arvore={arvore}
            vinculosIniciais={abrangencias[painel.usuario.id] ?? []}
            onSalvo={aoSalvar}
          />
        )}
      </Drawer>

      {/* Confirmação de ativar/desativar */}
      <ConfirmDialog
        aberto={alvoStatus !== null}
        titulo={alvoStatus?.ativo ? "Desativar usuário?" : "Ativar usuário?"}
        mensagem={
          <>
            {alvoStatus?.ativo ? (
              <p>
                <strong>{alvoStatus?.nome}</strong> não conseguirá mais acessar o sistema. O cadastro e o
                histórico são mantidos, e você pode ativar a conta de novo quando quiser.
              </p>
            ) : (
              <p>
                <strong>{alvoStatus?.nome}</strong> voltará a acessar o sistema com as permissões do seu grupo.
              </p>
            )}
            {erroStatus && (
              <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">
                {erroStatus}
              </p>
            )}
          </>
        }
        textoConfirmar={alvoStatus?.ativo ? "Desativar" : "Ativar"}
        variante={alvoStatus?.ativo ? "perigo" : "primario"}
        processando={alterandoStatus}
        onConfirmar={() => void confirmarStatus()}
        onCancelar={() => setAlvoStatus(null)}
      />

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
