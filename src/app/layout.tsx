/**
 * SysMúsica — Layout raiz (HTML, fontes e metadados).
 *
 * A estrutura visual do painel (menu lateral, topo, breadcrumbs) fica em
 * src/app/(painel)/layout.tsx. Assim, telas públicas (ex: login, Fase 2) podem ter
 * um layout próprio, sem o menu.
 */
import type { Metadata } from "next";
import type { ReactNode } from "react";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import SessaoProvider from "@/modules/autenticacao/SessaoProvider";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: { default: "SysMúsica", template: "%s | SysMúsica" },
  description: "Gestão de membros, eventos e presenças do SysMúsica.",
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="pt-BR">
      <body className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
        <SessaoProvider>{children}</SessaoProvider>
      </body>
    </html>
  );
}
