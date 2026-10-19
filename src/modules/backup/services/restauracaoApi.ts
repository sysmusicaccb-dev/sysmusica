/** SysMúsica — Chamada do navegador à rota de comparação da restauração (leva o token do login). */
import { supabase } from "@/lib/supabase";
import type { ResultadoComparacao } from "../restauracao";
import type { GrupoDados } from "../tabelas";

export async function compararBackup(id: string, grupos: GrupoDados[]): Promise<ResultadoComparacao> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error("Sua sessão expirou. Entre de novo.");

  const resposta = await fetch("/api/backup/restauracao/comparar", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ id, grupos }),
    cache: "no-store",
  });
  const json = (await resposta.json().catch(() => null)) as (ResultadoComparacao & { erro?: string }) | null;
  if (!resposta.ok || !json) throw new Error(json?.erro ?? "Não foi possível comparar o backup.");
  return json;
}
