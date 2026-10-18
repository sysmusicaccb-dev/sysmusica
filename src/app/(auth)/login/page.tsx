"use client";

/**
 * SysMúsica — Tela de login (rota pública /login).
 * Se a pessoa já estiver logada, vai direto para o sistema.
 * Layout em duas colunas no desktop (marca à esquerda, formulário à direita); só o formulário no celular.
 * A logomarca (emblema da CCB) aparece em uma plaquinha branca, para ficar nítida em qualquer fundo e em
 * qualquer modo (claro ou escuro).
 */
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import LogoMarca from "@/components/ui/LogoMarca";
import FormularioLogin from "@/modules/autenticacao/components/FormularioLogin";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";

export default function LoginPage() {
  const { carregando, sessao } = useSessao();
  const router = useRouter();

  // Já está logado: vai para o sistema
  useEffect(() => {
    if (!carregando && sessao) router.replace("/");
  }, [carregando, sessao, router]);

  return (
    <main className="grid min-h-screen bg-slate-50 text-slate-900 lg:grid-cols-2">
      {/* Painel da marca (some no celular) */}
      <aside className="hidden flex-col justify-between bg-sidebar p-12 text-sidebar-fg lg:flex">
        <div className="flex items-center gap-4">
          <LogoMarca altura={64} comFundoBranco />
          <span className="text-2xl font-bold tracking-tight text-white">SysMúsica</span>
        </div>
        <div>
          <h2 className="text-3xl font-bold leading-tight text-white">
            Gestão de membros, eventos e portaria em um só lugar.
          </h2>
          <p className="mt-4 max-w-md text-base">
            Acesse com a conta fornecida pelo administrador. O que você pode ver e fazer depende do
            grupo de acesso ao qual pertence.
          </p>
        </div>
        <div aria-hidden="true" />
      </aside>

      {/* Formulário */}
      <section className="flex items-center justify-center p-6 sm:p-12">
        <div className="w-full max-w-sm">
          {/* Marca no celular */}
          <div className="mb-8 flex items-center gap-3 lg:hidden">
            <LogoMarca altura={44} comFundoBranco />
            <span className="text-xl font-bold tracking-tight">SysMúsica</span>
          </div>

          <h1 className="text-2xl font-bold tracking-tight">Entrar</h1>
          <p className="mt-1 text-sm text-slate-600">
            Informe seu e-mail e senha para acessar o sistema.
          </p>
          <div className="mt-8">
            <FormularioLogin />
          </div>
        </div>
      </section>
    </main>
  );
}
