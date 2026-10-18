/**
 * SysMúsica — Serviço das preferências de aparência na conta do usuário (migração 0019).
 * Se a migração ainda não foi aplicada (ou a conta não pode salvar), a leitura devolve nulo e o sistema
 * segue com a cópia do aparelho.
 */
import { mensagemDoErro } from "@/lib/erros";
import { supabase } from "@/lib/supabase";
import { lerPreferencias } from "../regras";
import type { Preferencias } from "../tipos";

/** Preferências salvas na conta, ou nulo se não houver (ou se não for possível consultar). */
export async function buscarPreferenciasDaConta(): Promise<Preferencias | null> {
  const { data, error } = await supabase.rpc("minhas_preferencias");
  if (error) return null;
  const linha = ((data ?? []) as unknown[])[0];
  return linha ? lerPreferencias(linha) : null;
}

/** Salva as preferências na conta (o banco confere os valores). */
export async function salvarPreferenciasNaConta(preferencias: Preferencias): Promise<void> {
  const { error } = await supabase.rpc("salvar_preferencias", {
    p_tema: preferencias.tema,
    p_cor: preferencias.cor,
    p_fonte: preferencias.fonte,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar na sua conta."));
}
