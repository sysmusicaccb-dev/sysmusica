/**
 * SysMúsica — Regras puras do módulo Administração (sem acesso ao banco).
 * Usadas pela tela E pelo servidor (a validação do servidor é a que vale; a da tela só ajuda).
 * Testadas em regras.test.ts.
 */
import type { DadosNovoUsuario, PermissaoCatalogo } from "./tipos";

export const SENHA_MINIMA = 10;
export const SENHA_MAXIMA = 72; // limite do algoritmo de senha usado pelo Supabase (bcrypt)

const REGEX_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const REGEX_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Devolve a mensagem de erro da senha, ou null quando ela é aceitável. */
export function validarSenha(senha: string): string | null {
  if (senha.length < SENHA_MINIMA) return `A senha deve ter pelo menos ${SENHA_MINIMA} caracteres.`;
  if (senha.length > SENHA_MAXIMA) return `A senha pode ter no máximo ${SENHA_MAXIMA} caracteres.`;
  if (!/[A-Za-z]/.test(senha) || !/[0-9]/.test(senha)) return "A senha deve misturar letras e números.";
  return null;
}

/** Devolve a mensagem de erro do nome de pessoa, ou null quando ele é aceitável. */
export function validarNome(nome: string): string | null {
  const tamanho = nome.trim().length;
  if (tamanho < 2) return "Informe o nome (mínimo de 2 caracteres).";
  if (tamanho > 80) return "O nome pode ter no máximo 80 caracteres.";
  return null;
}

export type ResultadoValidacao =
  | { ok: true; dados: DadosNovoUsuario }
  | { ok: false; erro: string };

/** Valida o corpo recebido na criação de usuário (qualquer tipo de entrada, inclusive lixo). */
export function validarNovoUsuario(corpo: unknown): ResultadoValidacao {
  if (typeof corpo !== "object" || corpo === null) return { ok: false, erro: "Dados inválidos." };

  const { nome, email, senha, grupoId } = corpo as Record<string, unknown>;
  if (
    typeof nome !== "string" ||
    typeof email !== "string" ||
    typeof senha !== "string" ||
    typeof grupoId !== "string"
  ) {
    return { ok: false, erro: "Preencha todos os campos." };
  }

  const erroNome = validarNome(nome);
  if (erroNome) return { ok: false, erro: erroNome };

  const emailLimpo = email.trim().toLowerCase();
  if (emailLimpo.length > 254 || !REGEX_EMAIL.test(emailLimpo)) {
    return { ok: false, erro: "Informe um e-mail válido." };
  }

  const erroSenha = validarSenha(senha);
  if (erroSenha) return { ok: false, erro: erroSenha };

  if (!REGEX_UUID.test(grupoId)) return { ok: false, erro: "Escolha o grupo do usuário." };

  return { ok: true, dados: { nome: nome.trim(), email: emailLimpo, senha, grupoId } };
}

// ---------------------------------------------------------------------
// Grade de permissões do grupo
// ---------------------------------------------------------------------

export interface ModuloPermissoes {
  chave: string; // prefixo do código (ex: "membros")
  titulo: string; // nome de exibição (ex: "Membros")
  itens: PermissaoCatalogo[];
}

const ORDEM_ACOES = ["Visualizar", "Criar", "Registrar", "Editar", "Excluir"];

/** Agrupa o catálogo por módulo e ordena as ações (Visualizar, Criar, Registrar, Editar, Excluir). */
export function agruparPermissoesPorModulo(catalogo: PermissaoCatalogo[]): ModuloPermissoes[] {
  const mapa = new Map<string, ModuloPermissoes>();
  for (const permissao of catalogo) {
    const chave = permissao.codigo.split(".")[0];
    const modulo = mapa.get(chave) ?? { chave, titulo: permissao.modulo, itens: [] };
    modulo.itens.push(permissao);
    mapa.set(chave, modulo);
  }

  const posicao = (acao: string) => {
    const indice = ORDEM_ACOES.indexOf(acao);
    return indice === -1 ? ORDEM_ACOES.length : indice;
  };
  return [...mapa.values()].map((modulo) => ({
    ...modulo,
    itens: [...modulo.itens].sort((a, b) => posicao(a.acao) - posicao(b.acao)),
  }));
}

/**
 * Marca/desmarca uma permissão, mantendo a grade coerente:
 *  - marcar uma ação marca também "visualizar" do módulo (não dá para editar sem poder ver);
 *  - desmarcar "visualizar" desmarca todas as ações do módulo.
 */
export function alternarPermissao(
  selecionadas: ReadonlySet<string>,
  codigo: string,
  catalogo: PermissaoCatalogo[]
): Set<string> {
  const novas = new Set(selecionadas);
  const [modulo] = codigo.split(".");
  const visualizar = `${modulo}.visualizar`;

  if (novas.has(codigo)) {
    novas.delete(codigo);
    if (codigo === visualizar) {
      for (const outro of [...novas]) {
        if (outro.startsWith(`${modulo}.`)) novas.delete(outro);
      }
    }
  } else {
    novas.add(codigo);
    if (catalogo.some((permissao) => permissao.codigo === visualizar)) novas.add(visualizar);
  }
  return novas;
}

/** Marca todas as ações do módulo; se todas já estavam marcadas, desmarca todas. */
export function alternarModulo(
  selecionadas: ReadonlySet<string>,
  modulo: ModuloPermissoes
): Set<string> {
  const novas = new Set(selecionadas);
  const todasMarcadas = modulo.itens.every((item) => novas.has(item.codigo));
  for (const item of modulo.itens) {
    if (todasMarcadas) novas.delete(item.codigo);
    else novas.add(item.codigo);
  }
  return novas;
}
