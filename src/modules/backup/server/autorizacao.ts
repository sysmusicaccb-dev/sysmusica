/**
 * SysMúsica — Confere QUEM está chamando a rota e se tem a permissão pedida.
 * 1) Valida a sessão (token do login) no Supabase. 2) Confere que a conta está ativa. 3) Junta o grupo
 * principal e os grupos extras e confere se algum deles tem a permissão. As permissões de backup só
 * podem pertencer ao grupo Administrador (trava no banco, migração 0020).
 */
import type { CodigoPermissao } from "@/lib/permissoes";
import { extrairToken, gruposEfetivos } from "../regras";
import { clienteAdmin } from "./clienteAdmin";
import { ErroBackup } from "./erros";

export interface UsuarioAutenticado {
  id: string;
  nome: string;
}

export async function autenticar(request: Request, permissao: CodigoPermissao): Promise<UsuarioAutenticado> {
  const token = extrairToken(request.headers.get("authorization"));
  if (!token) throw new ErroBackup(401, "Sua sessão não foi encontrada. Entre de novo.");

  const admin = clienteAdmin();
  const { data: sessao, error } = await admin.auth.getUser(token);
  if (error || !sessao.user) throw new ErroBackup(401, "Sua sessão expirou. Entre de novo.");
  const id = sessao.user.id;

  const { data: usuario } = await admin
    .from("usuarios")
    .select("id, nome, ativo, grupo_id")
    .eq("id", id)
    .maybeSingle();
  if (!usuario || usuario.ativo !== true) throw new ErroBackup(403, "Esta conta não tem acesso ao sistema.");

  const { data: extras } = await admin.from("usuario_grupos").select("grupo_id").eq("usuario_id", id);
  const grupos = gruposEfetivos(
    usuario.grupo_id ?? null,
    ((extras ?? []) as { grupo_id: string }[]).map((linha) => linha.grupo_id)
  );
  if (grupos.length === 0) throw new ErroBackup(403, "Somente o Administrador pode usar o módulo de backup.");

  const { data: concedidas } = await admin
    .from("grupo_permissoes")
    .select("permissao_codigo")
    .in("grupo_id", grupos)
    .eq("permissao_codigo", permissao);
  if (!concedidas || concedidas.length === 0) {
    throw new ErroBackup(403, "Somente o Administrador pode usar o módulo de backup.");
  }

  return { id, nome: typeof usuario.nome === "string" ? usuario.nome : "" };
}
