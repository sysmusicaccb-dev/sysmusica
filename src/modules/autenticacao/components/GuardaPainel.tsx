"use client";

/**
 * SysMúsica — Guarda do painel: só mostra as telas internas para quem está logado e com acesso.
 *  - sem login: manda para /login;
 *  - conta sem grupo, inativa ou sem nenhuma permissão: mostra a tela "Sem acesso";
 *  - erro ao carregar as permissões: oferece tentar novamente.
 * Esta guarda melhora a experiência; a proteção dos dados é feita pelo banco (RLS).
 */
import { useEffect, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { LogOut, ShieldAlert } from "lucide-react";
import Button from "@/components/ui/Button";
import { useSessao } from "../SessaoProvider";

function TelaCarregando() {
  return (
    <div
      role="status"
      aria-live="polite"
      className="flex min-h-screen items-center justify-center bg-slate-50"
    >
      <span className="sr-only">Carregando...</span>
      <span
        className="h-8 w-8 animate-spin rounded-full border-4 border-brand-200 border-t-brand-600"
        aria-hidden="true"
      />
    </div>
  );
}

function TelaAvisoDeAcesso({
  titulo,
  mensagem,
  acoes,
}: {
  titulo: string;
  mensagem: string;
  acoes: ReactNode;
}) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-50 p-6">
      <div className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-8 text-center shadow-sm">
        <span className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-amber-100 text-amber-700">
          <ShieldAlert className="h-6 w-6" aria-hidden="true" />
        </span>
        <h1 className="mt-4 text-lg font-semibold text-slate-900">{titulo}</h1>
        <p className="mt-2 text-sm text-slate-600">{mensagem}</p>
        <div className="mt-6 flex flex-col gap-2">{acoes}</div>
      </div>
    </div>
  );
}

export default function GuardaPainel({ children }: { children: ReactNode }) {
  const { carregando, sessao, conta, erroConta, sair } = useSessao();
  const router = useRouter();

  // Sem login: vai para a tela de entrada
  useEffect(() => {
    if (!carregando && !sessao) router.replace("/login");
  }, [carregando, sessao, router]);

  if (carregando || !sessao) return <TelaCarregando />;

  const botaoSair = (
    <Button variante="secundario" icone={LogOut} onClick={() => void sair()}>
      Sair da conta
    </Button>
  );

  if (erroConta) {
    return (
      <TelaAvisoDeAcesso
        titulo="Não foi possível verificar seu acesso"
        mensagem={erroConta}
        acoes={
          <>
            <Button onClick={() => window.location.reload()}>Tentar novamente</Button>
            {botaoSair}
          </>
        }
      />
    );
  }

  if (!conta || !conta.ativo || conta.permissoes.length === 0) {
    return (
      <TelaAvisoDeAcesso
        titulo="Sua conta ainda não tem acesso"
        mensagem="Peça a um administrador para liberar o seu acesso, definindo o grupo ao qual você pertence."
        acoes={botaoSair}
      />
    );
  }

  return <>{children}</>;
}
