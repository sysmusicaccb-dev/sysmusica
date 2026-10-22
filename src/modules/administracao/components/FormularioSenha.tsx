"use client";

/**
 * Sysmusica — Formulário para redefinir a senha de um usuário (feito pelo administrador).
 * A troca passa pelo servidor (precisa da chave secreta). Depois, informe a nova senha
 * ao usuário por um canal seguro.
 */
import { useState, type FormEvent } from "react";
import { Eye, EyeOff } from "lucide-react";
import Button from "@/components/ui/Button";
import { SENHA_MINIMA, validarSenha } from "../regras";
import { redefinirSenha } from "../services/acesso";
import type { UsuarioSistema } from "../tipos";

interface FormularioSenhaProps {
  usuario: UsuarioSistema;
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 " +
  "disabled:cursor-not-allowed disabled:opacity-70";

export default function FormularioSenha({ usuario, onSalvo }: FormularioSenhaProps) {
  const [senha, setSenha] = useState("");
  const [confirmacao, setConfirmacao] = useState("");
  const [mostrarSenha, setMostrarSenha] = useState(false);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    const erroSenha = validarSenha(senha);
    if (erroSenha) return setErro(erroSenha);
    if (senha !== confirmacao) return setErro("A confirmação da senha não confere.");

    setSalvando(true);
    try {
      await redefinirSenha(usuario.id, senha);
      await onSalvo(`Senha de "${usuario.nome}" redefinida. Informe a nova senha a ele por um canal seguro.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível redefinir a senha.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      <p className="text-sm text-slate-600">
        Nova senha para <span className="font-medium text-slate-900">{usuario.nome}</span> ({usuario.email}).
      </p>

      <div className="space-y-1.5">
        <label htmlFor="nova-senha" className="text-sm font-medium text-slate-700">
          Nova senha
        </label>
        <div className="relative">
          <input
            id="nova-senha"
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
        <label htmlFor="confirmar-nova-senha" className="text-sm font-medium text-slate-700">
          Confirmar a nova senha
        </label>
        <input
          id="confirmar-nova-senha"
          type={mostrarSenha ? "text" : "password"}
          required
          autoComplete="new-password"
          value={confirmacao}
          onChange={(e) => setConfirmacao(e.target.value)}
          disabled={salvando}
          className={classeInput}
        />
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : "Redefinir senha"}
      </Button>
    </form>
  );
}
