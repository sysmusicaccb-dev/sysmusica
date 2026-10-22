/**
 * Sysmusica — Layout raiz (HTML, fontes e metadados).
 *
 * A estrutura visual do painel (menu lateral, topo, breadcrumbs) fica em
 * src/app/(painel)/layout.tsx. Assim, telas públicas (ex: login, Fase 2) podem ter
 * um layout próprio, sem o menu.
 *
 * O script do <head> aplica o modo (claro/escuro), a cor e o tamanho da letra ANTES da primeira pintura,
 * para a página não abrir clara e "piscar" para escura. Por isso a tag <html> leva suppressHydrationWarning:
 * o script coloca atributos nela que o servidor não conhece.
 */
import type { Metadata } from "next";
import type { ReactNode } from "react";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import SessaoProvider from "@/modules/autenticacao/SessaoProvider";
import { SCRIPT_TEMA_INICIAL } from "@/modules/preferencias/scriptInicial";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: { default: "Sysmusica", template: "%s | Sysmusica" },
  description: "Gestão de membros, eventos e presenças do Sysmusica.",
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="pt-BR" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: SCRIPT_TEMA_INICIAL }} />
      </head>
      <body className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
        <SessaoProvider>{children}</SessaoProvider>
      </body>
    </html>
  );
}
