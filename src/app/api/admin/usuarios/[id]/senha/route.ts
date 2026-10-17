/**
 * SysMúsica — POST /api/admin/usuarios/[id]/senha: redefine a senha de um usuário.
 *
 * Exige a permissão usuarios.editar (conferida no banco). A nova senha segue a mesma regra
 * da criação de usuário e nunca é registrada em log.
 */
import { NextResponse } from "next/server";
import { validarSenha } from "@/modules/administracao/regras";
import { exigirPermissao } from "@/modules/administracao/server/autorizacao";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { ErroHttp } from "@/modules/administracao/server/erros";
import { respostaDeErro } from "@/modules/administracao/server/resposta";

const REGEX_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function POST(request: Request, contexto: { params: Promise<{ id: string }> }) {
  try {
    await exigirPermissao(request, "usuarios.editar");

    const { id } = await contexto.params;
    if (!REGEX_UUID.test(id)) throw new ErroHttp(400, "Usuário inválido.");

    const corpo = (await request.json().catch(() => null)) as { senha?: unknown } | null;
    if (typeof corpo?.senha !== "string") throw new ErroHttp(400, "Informe a nova senha.");
    const erroSenha = validarSenha(corpo.senha);
    if (erroSenha) throw new ErroHttp(400, erroSenha);

    const admin = clienteAdmin();
    const { error } = await admin.auth.admin.updateUserById(id, { password: corpo.senha });
    if (error) {
      if (error.status === 404) throw new ErroHttp(404, "Usuário não encontrado.");
      throw error;
    }

    return NextResponse.json({ ok: true });
  } catch (erro) {
    return respostaDeErro(erro);
  }
}
