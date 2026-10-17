/**
 * SysMúsica — POST /api/admin/usuarios: cria uma conta de login e a coloca em um grupo.
 *
 * Exige a permissão usuarios.criar (conferida no banco). A senha só trafega nesta requisição
 * (HTTPS) e é guardada pelo Supabase com hash; ela nunca é registrada em log.
 * Fluxo: valida entrada -> confere o grupo -> cria a conta (já confirmada) -> o gatilho do banco
 * cria a linha em "usuarios" -> vincula o grupo. Se o vínculo falhar, a conta é removida.
 */
import { NextResponse } from "next/server";
import { validarNovoUsuario } from "@/modules/administracao/regras";
import { exigirPermissao } from "@/modules/administracao/server/autorizacao";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { ErroHttp } from "@/modules/administracao/server/erros";
import { respostaDeErro } from "@/modules/administracao/server/resposta";

export async function POST(request: Request) {
  try {
    await exigirPermissao(request, "usuarios.criar");

    const validacao = validarNovoUsuario(await request.json().catch(() => null));
    if (!validacao.ok) throw new ErroHttp(400, validacao.erro);
    const { nome, email, senha, grupoId } = validacao.dados;

    const admin = clienteAdmin();

    // O grupo precisa existir e estar ativo
    const { data: grupo, error: erroGrupo } = await admin
      .from("grupos")
      .select("id, ativo")
      .eq("id", grupoId)
      .maybeSingle();
    if (erroGrupo) throw erroGrupo;
    if (!grupo || !grupo.ativo) throw new ErroHttp(400, "Escolha um grupo ativo.");

    // Cria a conta de login (já confirmada: o administrador informa a senha ao usuário)
    const { data: criado, error: erroCriacao } = await admin.auth.admin.createUser({
      email,
      password: senha,
      email_confirm: true,
      user_metadata: { nome },
    });
    if (erroCriacao || !criado.user) {
      if (erroCriacao?.code === "email_exists") {
        throw new ErroHttp(409, "Já existe um usuário com este e-mail.");
      }
      throw erroCriacao ?? new Error("Conta não criada.");
    }

    // Vincula ao grupo (a linha em "usuarios" foi criada pelo gatilho do banco)
    const { error: erroVinculo } = await admin
      .from("usuarios")
      .update({ nome, grupo_id: grupoId, ativo: true })
      .eq("id", criado.user.id);
    if (erroVinculo) {
      // Desfaz: não deixa uma conta sem grupo para trás
      await admin.auth.admin.deleteUser(criado.user.id);
      throw erroVinculo;
    }

    return NextResponse.json({ id: criado.user.id }, { status: 201 });
  } catch (erro) {
    return respostaDeErro(erro);
  }
}
