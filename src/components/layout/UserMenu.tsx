"use client";

/**
 * SysMúsica — Menu do usuário (topo da tela): identificação, grupo de acesso e botão Sair.
 * Só tem ações que existem: por enquanto, encerrar a sessão.
 */
import { useEffect, useRef, useState } from "react";
import { ChevronDown, LogOut } from "lucide-react";
import Badge from "@/components/ui/Badge";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";

export default function UserMenu() {
  const { conta, sessao, sair } = useSessao();
  const [aberto, setAberto] = useState(false);
  const raizRef = useRef<HTMLDivElement>(null);

  const nome = conta?.nome ?? sessao?.user.email ?? "Usuário";
  const email = conta?.email ?? sessao?.user.email ?? "";

  // O menu fecha ao clicar fora ou apertar Esc (só enquanto está aberto)
  useEffect(() => {
    if (!aberto) return;

    function aoClicarFora(evento: MouseEvent) {
      if (raizRef.current && !raizRef.current.contains(evento.target as Node)) setAberto(false);
    }
    function aoPressionar(evento: KeyboardEvent) {
      if (evento.key === "Escape") setAberto(false);
    }

    document.addEventListener("mousedown", aoClicarFora);
    document.addEventListener("keydown", aoPressionar);
    return () => {
      document.removeEventListener("mousedown", aoClicarFora);
      document.removeEventListener("keydown", aoPressionar);
    };
  }, [aberto]);

  return (
    <div ref={raizRef} className="relative">
      <button
        type="button"
        onClick={() => setAberto((atual) => !atual)}
        aria-haspopup="menu"
        aria-expanded={aberto}
        className="flex items-center gap-2 rounded-lg px-2 py-1.5 text-left transition hover:bg-slate-100 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
      >
        <span
          aria-hidden="true"
          className="flex h-8 w-8 items-center justify-center rounded-full bg-brand-100 text-sm font-bold text-brand-700"
        >
          {nome.charAt(0).toUpperCase()}
        </span>
        <span className="hidden min-w-0 sm:block">
          <span className="block max-w-40 truncate text-sm font-medium text-slate-900">{nome}</span>
          {conta?.grupo && (
            <span className="block max-w-40 truncate text-xs text-slate-500">{conta.grupo}</span>
          )}
        </span>
        <ChevronDown className="h-4 w-4 text-slate-500" aria-hidden="true" />
      </button>

      {aberto && (
        <div
          role="menu"
          className="absolute right-0 z-50 mt-2 w-64 rounded-xl border border-slate-200 bg-white p-2 shadow-lg"
        >
          <div className="px-3 py-2">
            <p className="truncate text-sm font-medium text-slate-900">{nome}</p>
            <p className="truncate text-xs text-slate-500">{email}</p>
            {conta?.grupo && (
              <div className="mt-2">
                <Badge variante="marca">{conta.grupo}</Badge>
              </div>
            )}
          </div>
          <div className="my-1 border-t border-slate-100" />
          <button
            type="button"
            role="menuitem"
            onClick={() => {
              setAberto(false);
              void sair();
            }}
            className="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm text-slate-700 transition hover:bg-slate-100 hover:text-slate-900"
          >
            <LogOut className="h-4 w-4" aria-hidden="true" />
            Sair da conta
          </button>
        </div>
      )}
    </div>
  );
}
