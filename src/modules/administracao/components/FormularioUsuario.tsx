"use client";

/**
 * SysMúsica — Formulário de usuário (novo ou edição).
 * usuario = null -> criar conta (nome, e-mail, senha e grupo); preenchido -> editar nome e grupo.
 * O e-mail não muda depois de criado. Senha de conta existente: use "Redefinir senha".
 * A criação passa pelo servidor (precisa da chave secreta); a edição usa uma função do banco.
 */
import { useState, type FormEvent } from "react";
import { Eye, EyeOff } from "lucide-react";
import Button from "@/components/ui/Button";
import { SENHA_MINIMA, validarNome, validarSenha } from "../regras";
import { atualizarUsuario, criarUsuario } from "../services/acesso";
import type { GrupoAcesso, UsuarioSistema } from "../tipos";

interface FormularioUsuarioProps {
  usuario: UsuarioSistema | null;
  grupos: GrupoAcesso[];
  meuId: string | null;
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:opacity-70";

export default function FormularioUsuario({ usuario, grupos, meuId, onSalvo }: FormularioUsuarioProps) {
  const editando = usuario !== null;

  const [nome, setNome] = useState(usuario?.nome ?? "");
  const [email, setEmail] = useState(usuario?.email ?? "");
  const [senha, setSenha] = useState("");
  const [confirmacao, setConfirmacao] = useState("");
  const [mostrarSenha, setMostrarSenha] = useState(false);
  const [grupoId, setGrupoId] = useState(usuario?.grupo_id ?? "");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  // Só grupos ativos podem ser escolhidos (na edição, mantém o grupo atual mesmo se inativo)
  const gruposDisponiveis = grupos.filter((grupo) => grupo.ativo || grupo.id === usuario?.grupo_id);

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    const erroNome = validarNome(nome);
    if (erroNome) return setErro(erroNome);
    if (!grupoId) return setErro("Escolha o grupo do usuário.");

    if (!editando) {
      const erroSenha = validarSenha(senha);
      if (erroSenha) return setErro(erroSenha);
      if (senha !== confirmacao) return setErro("A confirmação da senha não confere.");
    }

    setSalvando(true);
    try {
      if (usuario) {
        await atualizarUsuario({ id: usuario.id, nome: nome.trim(), grupoId, ativo: usuario.ativo });
        await onSalvo(`Usuário "${nome.trim()}" atualizado.`);
      } else {
        await criarUsuario({ nome: nome.trim(), email, senha, grupoId });
        await onSalvo(`Usuário "${nome.trim()}" criado. Informe a senha a ele por um canal seguro.`);
      }
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar o usuário.");
    } finally {
      setSalvando(false);
    }
  }

  if (gruposDisponiveis.length === 0) {
    return (
      <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
        Não há grupos ativos. Crie um grupo em Administração &gt; Grupos e permissões antes de
        cadastrar usuários.
      </p>
    );
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      {editando && usuario.id === meuId && (
        <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
          Você está editando a sua própria conta. Mudar o seu grupo pode remover o seu acesso a
          algumas telas.
        </p>
      )}

      <div className="space-y-1.5">
        <label htmlFor="nome-usuario" className="text-sm font-medium text-slate-700">
          Nome
        </label>
        <input
          id="nome-usuario"
          type="text"
          required
          maxLength={80}
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Maria da Silva"
          className={classeInput}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="email-usuario" className="text-sm font-medium text-slate-700">
          E-mail (usado no login)
        </label>
        <input
          id="email-usuario"
          type="email"
          required
          maxLength={254}
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          disabled={salvando || editando}
          placeholder="maria@exemplo.com"
          className={classeInput}
        />
      </div>

      {!editando && (
        <>
          <div className="space-y-1.5">
            <label htmlFor="senha-usuario" className="text-sm font-medium text-slate-700">
              Senha inicial
            </label>
            <div className="relative">
              <input
                id="senha-usuario"
                type={mostrarSenha ? "text" : "password"}
                required
                autoComplete="new-password"
                value={senha}
                onChange={(e) => setSenha(e.target.value)}
                disabled={salvando}
                className={`${classeInput} pr-10`}
              />
              <button
                type="button"
                onClick={() => setMostrarSenha((atual) => !atual)}
                aria-label={mostrarSenha ? "Ocultar senha" : "Mostrar senha"}
                className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-slate-500 transition hover:text-slate-900"
              >
                {mostrarSenha ? (
                  <EyeOff className="h-4 w-4" aria-hidden="true" />
                ) : (
                  <Eye className="h-4 w-4" aria-hidden="true" />
                )}
              </button>
            </div>
            <p className="text-xs text-slate-500">
              Mínimo de {SENHA_MINIMA} caracteres, misturando letras e números.
            </p>
          </div>

          <div className="space-y-1.5">
            <label htmlFor="confirmacao-usuario" className="text-sm font-medium text-slate-700">
              Confirmar a senha
            </label>
            <input
              id="confirmacao-usuario"
              type={mostrarSenha ? "text" : "password"}
              required
              autoComplete="new-password"
              value={confirmacao}
              onChange={(e) => setConfirmacao(e.target.value)}
              disabled={salvando}
              className={classeInput}
            />
          </div>
        </>
      )}

      <div className="space-y-1.5">
        <label htmlFor="grupo-usuario" className="text-sm font-medium text-slate-700">
          Grupo de acesso
        </label>
        <select
          id="grupo-usuario"
          required
          value={grupoId}
          onChange={(e) => setGrupoId(e.target.value)}
          disabled={salvando}
          className={classeInput}
        >
          <option value="">Selecione um grupo</option>
          {gruposDisponiveis.map((grupo) => (
            <option key={grupo.id} value={grupo.id}>
              {grupo.nome}
              {grupo.ativo ? "" : " (inativo)"}
            </option>
          ))}
        </select>
        <p className="text-xs text-slate-500">O grupo define o que o usuário pode ver e fazer.</p>
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Criar usuário"}
      </Button>
    </form>
  );
}
