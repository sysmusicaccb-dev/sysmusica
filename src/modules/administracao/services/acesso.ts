/**
 * SysMúsica — Serviços da tela de Administração.
 *
 * Consultas e alterações de grupos/usuários usam as funções protegidas do banco (migração 0003).
 * Criar usuário e redefinir senha usam as rotas de servidor (/api/admin/...), pois dependem da
 * chave secreta, que nunca fica no navegador.
 */
import { supabase } from "@/lib/supabase";
import type {
  DadosNovoUsuario,
  GrupoAcesso,
  PermissaoCatalogo,
  UsuarioSistema,
} from "../tipos";

interface ErroDoBanco {
  code?: string;
  message: string;
}

/**
 * Converte um erro do banco em mensagem para o usuário.
 * Regras de negócio (P0001), permissão (42501) e nome repetido (23505) têm mensagem própria;
 * qualquer outro erro vira a mensagem padrão e o detalhe vai só para o console.
 */
function mensagemDoErro(erro: ErroDoBanco, padrao: string): string {
  if (erro.code === "23505") return "Já existe um registro com este nome.";
  if (erro.code === "P0001" || erro.code === "42501") return erro.message;
  console.error("Erro do banco:", erro);
  return padrao;
}

// ---------- Consultas ----------

export async function listarPermissoes(): Promise<PermissaoCatalogo[]> {
  const { data, error } = await supabase.rpc("listar_permissoes");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as permissões."));
  return (data ?? []) as PermissaoCatalogo[];
}

export async function listarGrupos(): Promise<GrupoAcesso[]> {
  const { data, error } = await supabase.rpc("listar_grupos");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os grupos."));
  return ((data ?? []) as GrupoAcesso[]).map((grupo) => ({
    ...grupo,
    qtd_usuarios: Number(grupo.qtd_usuarios), // o banco devolve bigint
  }));
}

export async function listarUsuarios(): Promise<UsuarioSistema[]> {
  const { data, error } = await supabase.rpc("listar_usuarios");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os usuários."));
  return (data ?? []) as UsuarioSistema[];
}

// ---------- Grupos ----------

export async function criarGrupo(dados: {
  nome: string;
  descricao: string;
  permissoes: string[];
}): Promise<void> {
  const { error } = await supabase.rpc("criar_grupo", {
    p_nome: dados.nome,
    p_descricao: dados.descricao,
    p_permissoes: dados.permissoes,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível criar o grupo."));
}

export async function atualizarGrupo(dados: {
  id: string;
  nome: string;
  descricao: string;
  ativo: boolean;
  permissoes: string[];
}): Promise<void> {
  const { error } = await supabase.rpc("atualizar_grupo", {
    p_id: dados.id,
    p_nome: dados.nome,
    p_descricao: dados.descricao,
    p_ativo: dados.ativo,
    p_permissoes: dados.permissoes,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar o grupo."));
}

export async function excluirGrupo(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_grupo", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir o grupo."));
}

// ---------- Usuários ----------

export async function atualizarUsuario(dados: {
  id: string;
  nome: string;
  grupoId: string | null;
  ativo: boolean;
}): Promise<void> {
  const { error } = await supabase.rpc("atualizar_usuario", {
    p_id: dados.id,
    p_nome: dados.nome,
    p_grupo_id: dados.grupoId,
    p_ativo: dados.ativo,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar o usuário."));
}

/** Chama uma rota de servidor da Administração enviando o token de login do usuário. */
async function chamarRotaAdmin(caminho: string, corpo: unknown): Promise<void> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error("Sua sessão expirou. Entre novamente.");

  let resposta: Response;
  try {
    resposta = await fetch(caminho, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify(corpo),
    });
  } catch {
    throw new Error("Não foi possível conectar ao servidor. Verifique a internet.");
  }

  if (!resposta.ok) {
    const json = (await resposta.json().catch(() => null)) as { erro?: string } | null;
    throw new Error(json?.erro ?? "Não foi possível concluir a operação.");
  }
}

export async function criarUsuario(dados: DadosNovoUsuario): Promise<void> {
  await chamarRotaAdmin("/api/admin/usuarios", dados);
}

export async function redefinirSenha(usuarioId: string, senha: string): Promise<void> {
  await chamarRotaAdmin(`/api/admin/usuarios/${usuarioId}/senha`, { senha });
}
