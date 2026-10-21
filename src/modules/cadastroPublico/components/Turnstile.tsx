"use client";

/**
 * SysMúsica — Verificação anti-robô (Cloudflare Turnstile).
 * Precisa da variável NEXT_PUBLIC_TURNSTILE_SITE_KEY (chave do site, pública). Sem ela, avisa que o formulário
 * está indisponível: o servidor também recusa o envio sem a verificação ("falha fechada").
 * Para testar localmente use a chave de teste da Cloudflare 1x00000000000000000000AA.
 */
import { useEffect, useRef, useState } from "react";

interface ApiTurnstile {
  render: (
    el: HTMLElement,
    opcoes: {
      sitekey: string;
      callback: (token: string) => void;
      "expired-callback": () => void;
      "error-callback": () => void;
      language?: string;
    }
  ) => string;
  remove: (id: string) => void;
  reset: (id: string) => void;
}

declare global {
  interface Window {
    turnstile?: ApiTurnstile;
  }
}

const SCRIPT = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";

interface TurnstileProps {
  /** Recebe o token (ou "" quando expira/erra). */
  onToken: (token: string) => void;
  /** Aumente este número para pedir uma NOVA verificação (o token vale uma só vez, mesmo se o envio falhar). */
  reiniciar?: number;
}

export default function Turnstile({ onToken, reiniciar = 0 }: TurnstileProps) {
  const caixa = useRef<HTMLDivElement>(null);
  const idWidgetRef = useRef<string | null>(null);
  const [indisponivel, setIndisponivel] = useState(false);
  const chave = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY;

  useEffect(() => {
    if (!chave || !caixa.current) return;
    const alvo = caixa.current;
    let idWidget: string | null = null;
    let cancelado = false;

    function desenhar() {
      if (cancelado || !window.turnstile) return;
      idWidget = window.turnstile.render(alvo, {
        sitekey: chave as string,
        language: "pt-br",
        callback: (token) => onToken(token),
        "expired-callback": () => onToken(""),
        "error-callback": () => onToken(""),
      });
      idWidgetRef.current = idWidget;
    }

    if (window.turnstile) {
      desenhar();
    } else {
      let script = document.querySelector<HTMLScriptElement>(`script[src="${SCRIPT}"]`);
      if (!script) {
        script = document.createElement("script");
        script.src = SCRIPT;
        script.async = true;
        document.head.appendChild(script);
      }
      script.addEventListener("load", desenhar);
      script.addEventListener("error", () => setIndisponivel(true));
    }
    return () => {
      cancelado = true;
      if (idWidget && window.turnstile) window.turnstile.remove(idWidget);
    };
  }, [chave, onToken]);

  // Nova verificação a pedido do formulário (depois de um envio que falhou)
  useEffect(() => {
    if (reiniciar > 0 && idWidgetRef.current && window.turnstile) window.turnstile.reset(idWidgetRef.current);
  }, [reiniciar]);

  if (!chave || indisponivel) {
    return (
      <p role="alert" className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">
        A verificação de segurança está indisponível no momento. Tente novamente mais tarde.
      </p>
    );
  }
  return <div ref={caixa} className="min-h-[65px]" />;
}
