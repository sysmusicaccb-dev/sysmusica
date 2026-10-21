/**
 * SysMúsica — Página /fotografias (APOSENTADA).
 * A tela Fotografias saiu do menu: a fotografia agora é cadastrada, trocada e removida em
 * Músicos / Organistas (botão Editar), onde também existem o filtro "Sem fotografia" e as miniaturas.
 * Esta página só mantém funcionando links e favoritos antigos.
 */
import { redirect } from "next/navigation";

export default function FotografiasPage() {
  redirect("/membros");
}
