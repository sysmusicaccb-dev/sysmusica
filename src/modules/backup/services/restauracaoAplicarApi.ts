/** SysMúsica — Chamada do navegador à rota que restaura o backup (leva o token do login e a senha digitada). */
import { supabase } from "@/lib/supabase";
import type { ModoRestauracao, RespostaRestauracao } from "../aplicacao";
import type { GrupoDados } from "../tabelas";

export async function restaurarBackup(dados: {
  id: string;
  grupos: GrupoDados[];
  modo: ModoRestauracao;
  confirmacao: string;
  senha: string;
}): Promise<RespostaRestauracao> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error("Sua sessão expirou. Entre de novo.");

  const resposta = await fetch("/api/backup/restauracao/aplicar", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(dados),
    cache: "no-store",
  });
  const json = (await resposta.json().catch(() => null)) as (RespostaRestauracao & { erro?: string }) | null;
  if (!resposta.ok || !json) throw new Error(json?.erro ?? "Não foi possível restaurar o backup.");
  return json;
}
