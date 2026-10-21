/**
 * SysMúsica — Layout das páginas PÚBLICAS (sem login, sem menu). Hoje: /cadastro.
 * Não usa o GuardaPainel: quem chega aqui não precisa estar logado. Nunca coloque dados internos nestas páginas.
 */
import type { ReactNode } from "react";

export const metadata = {
  title: "Cadastro Musical — SysMúsica",
  robots: { index: false, follow: false }, // o link é divulgado diretamente; não precisa aparecer em buscadores
};

export default function LayoutPublico({ children }: { children: ReactNode }) {
  return <div className="min-h-screen bg-slate-50 text-slate-900">{children}</div>;
}
