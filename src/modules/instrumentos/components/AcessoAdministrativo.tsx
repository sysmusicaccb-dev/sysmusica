"use client";

/**
 * SysMúsica — Acesso administrativo (conteúdo do painel lateral da tela de instrumentos).
 *
 * Sem login: formulário de e-mail e senha (com botão para mostrar/ocultar a senha).
 * Com login: mostra quem está conectado, se tem permissão de administrador, e o botão Sair.
 * Como criar um administrador: veja o cabeçalho do supabase/schema.sql.
 */
import { useState, type FormEvent } from "react";
import type { Session } from "@supabase/supabase-js";
import { Eye, EyeOff, LogOut } from "lucide-react";
import { supabase } from "@/lib/supabase";
import Button from "@/components/ui/Button";
import Skeleton from "@/components/ui/Skeleton";

interface AcessoAdministrativoProps {
  sessao: Session | null;
  carregando: boolean; // ainda verificando se há sessão salva
  ehAdmin: boolean;
  onEntrou: () => void;
  onSaiu: () => void;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function AcessoAdministrativo({
  sessao,
  carregando,
  ehAdmin,
  onEntrou,
  onSaiu,
}: AcessoAdministrativoProps) {
  const [email, setEmail] = useState("");
  const [senha, setSenha] = useState("");
  const [mostrarSenha, setMostrarSenha] = useState(false);
  const [entrando, setEntrando] = useState(false);
  const [erroLogin, setErroLogin] = useState<string | null>(null);

  async function entrar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    setErroLogin(null);
    setEntrando(true);
    try {
      const { error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password: senha,
      });
      if (error) {
        // Mensagem genérica: não revela se o e-mail existe nem detalhes técnicos
        throw new Error("E-mail ou senha inválidos.");
      }
      setSenha("");
      onEntrou(); // a sessão chega pelo onAuthStateChange da página
    } catch (e) {
      setErroLogin(e instanceof Error ? e.message : "Não foi possível entrar.");
    } finally {
      setEntrando(false);
    }
  }

  async function sair() {
    await supabase.auth.signOut();
    onSaiu();
  }

  // Verificando se já existe sessão salva
  if (carregando) {
    return (
      <div role="status" aria-live="polite" className="space-y-3">
        <span className="sr-only">Verificando acesso...</span>
        <Skeleton className="h-10" />
        <Skeleton className="h-10" />
      </div>
    );
  }

  // Sem login: formulário de entrada
  if (!sessao) {
    return (
      <form onSubmit={entrar} className="space-y-4">
        <div className="space-y-1.5">
          <label htmlFor="email" className="text-sm font-medium text-slate-700">
            E-mail
          </label>
          <input
            id="email"
            type="email"
            required
            autoComplete="username"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            disabled={entrando}
            className={classeInput}
          />
        </div>

        <div className="space-y-1.5">
          <label htmlFor="senha" className="text-sm font-medium text-slate-700">
            Senha
          </label>
          <div className="relative">
            <input
              id="senha"
              type={mostrarSenha ? "text" : "password"}
              required
              autoComplete="current-password"
              value={senha}
              onChange={(e) => setSenha(e.target.value)}
              disabled={entrando}
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
        </div>

        {erroLogin && (
          <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroLogin}
          </p>
        )}

        <Button type="submit" disabled={entrando} className="w-full">
          {entrando ? "Entrando..." : "Entrar"}
        </Button>
      </form>
    );
  }

  // Com login: identificação e permissão
  return (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">
        Conectado como <span className="font-medium text-slate-900">{sessao.user.email}</span>
      </p>
      {ehAdmin ? (
        <p className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
          Você é administrador: use a coluna Família da tabela para corrigir classificações.
        </p>
      ) : (
        <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
          Esta conta não tem permissão de administrador, então a tabela fica somente leitura.
        </p>
      )}
      <Button variante="secundario" icone={LogOut} onClick={() => void sair()} className="w-full">
        Sair
      </Button>
    </div>
  );
}
