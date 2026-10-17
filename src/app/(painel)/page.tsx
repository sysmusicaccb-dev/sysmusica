"use client";

/**
 * SysMúsica — Página inicial "/".
 * Quem tem permissão vê o dashboard. Quem não tem (ex: grupo Portaria) vai direto para o
 * primeiro módulo que pode acessar.
 */
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { primeiraRotaPermitida } from "@/components/layout/navegacao";
import EmptyState from "@/components/ui/EmptyState";
import DashboardConteudo from "@/modules/dashboard/components/DashboardConteudo";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";

export default function InicioPage() {
  const { pode } = useSessao();
  const router = useRouter();

  const podeVerDashboard = pode("dashboard.visualizar");
  const destino = podeVerDashboard ? null : primeiraRotaPermitida(pode);

  // Sem acesso ao dashboard: redireciona para o primeiro módulo permitido
  useEffect(() => {
    if (destino) router.replace(destino);
  }, [destino, router]);

  if (podeVerDashboard) return <DashboardConteudo />;
  if (destino) return null; // redirecionando

  return (
    <main className="mx-auto max-w-2xl px-4 py-16">
      <EmptyState
        titulo="Nenhum módulo disponível"
        descricao="Seu grupo ainda não tem acesso a nenhuma tela. Fale com um administrador."
      />
    </main>
  );
}
