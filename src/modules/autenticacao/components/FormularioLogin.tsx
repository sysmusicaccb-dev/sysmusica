"use client";

/**
 * SysMúsica — Formulário de login (e-mail e senha), integrado ao Supabase Auth.
 *
 * Estados visuais: carregando (botão com indicador, campos bloqueados), sucesso e erro.
 * Mensagens de erro são genéricas: não revelam se o e-mail existe nem detalhes técnicos.
 * O redirecionamento para o sistema acontece na página /login, assim que a sessão chega.
 */
import { useState, type FormEvent } from "react";
import { Eye, EyeOff, Lock, Mail } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { cn } from "@/lib/cn";

// Campo com ícone à esquerda (e, na senha, botão de mostrar/ocultar à direita)
const classeInput =
  "w-full rounded-lg border bg-white py-2.5 pl-10 pr-3 text-sm text-slate-900 shadow-sm " +
  "placeholder:text-slate-400 focus:outline-none focus:ring-2 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioLogin() {
  const [email, setEmail] = useState("");
  const [senha, setSenha] = useState("");
  const [mostrarSenha, setMostrarSenha] = useState(false);
  const [entrando, setEntrando] = useState(false);
  const [entrou, setEntrou] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function entrar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (entrando) return; // evita envio duplicado
    setErro(null);
    setEntrando(true);

    try {
      const { error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password: senha,
      });

      if (error) {
        // O detalhe técnico fica só no console
        console.error("Falha no login:", error.message);
        setErro(
          error.name === "AuthRetryableFetchError"
            ? "Não foi possível conectar ao servidor. Verifique a internet e tente novamente."
            : "E-mail ou senha inválidos."
        );
        setEntrando(false);
        return;
      }

      // Sucesso: a página /login redireciona quando a sessão for confirmada
      setEntrou(true);
    } catch (e) {
      console.error("Falha inesperada no login:", e);
      setErro("Não foi possível entrar agora. Tente novamente.");
      setEntrando(false);
    }
  }

  const classeBorda = erro
    ? "border-red-300 focus:border-red-500 focus:ring-red-200"
    : "border-slate-300 focus:border-brand-500 focus:ring-brand-200";

  return (
    <form onSubmit={entrar} className="space-y-5" noValidate={false}>
      <div className="space-y-1.5">
        <label htmlFor="email" className="text-sm font-medium text-slate-700">
          E-mail
        </label>
        <div className="relative">
          <Mail
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="email"
            type="email"
            required
            autoComplete="username"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            disabled={entrando}
            aria-invalid={erro ? true : undefined}
            placeholder="seu@email.com"
            className={cn(classeInput, classeBorda)}
          />
        </div>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="senha" className="text-sm font-medium text-slate-700">
          Senha
        </label>
        <div className="relative">
          <Lock
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="senha"
            type={mostrarSenha ? "text" : "password"}
            required
            autoComplete="current-password"
            value={senha}
            onChange={(e) => setSenha(e.target.value)}
            disabled={entrando}
            aria-invalid={erro ? true : undefined}
            aria-describedby={erro ? "erro-login" : undefined}
            placeholder="Sua senha"
            className={cn(classeInput, classeBorda, "pr-10")}
          />
          <button
            type="button"
            onClick={() => setMostrarSenha((atual) => !atual)}
            aria-label={mostrarSenha ? "Ocultar senha" : "Mostrar senha"}
            className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-slate-500 transition hover:text-slate-900 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
          >
            {mostrarSenha ? (
              <EyeOff className="h-4 w-4" aria-hidden="true" />
            ) : (
              <Eye className="h-4 w-4" aria-hidden="true" />
            )}
          </button>
        </div>
      </div>

      {erro && (
        <p
          id="erro-login"
          role="alert"
          className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700"
        >
          {erro}
        </p>
      )}
      {entrou && (
        <p role="status" className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
          Acesso confirmado. Entrando no sistema...
        </p>
      )}

      <button
        type="submit"
        disabled={entrando}
        className="flex w-full items-center justify-center gap-2 rounded-lg bg-brand-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-brand-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:cursor-not-allowed disabled:opacity-70"
      >
        {entrando && (
          <span
            className="h-4 w-4 animate-spin rounded-full border-2 border-white/40 border-t-white"
            aria-hidden="true"
          />
        )}
        {entrando ? "Entrando..." : "Entrar"}
      </button>
    </form>
  );
}
