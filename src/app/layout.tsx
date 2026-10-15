/**
 * SysMúsica — Layout raiz da aplicação.
 *
 * Define o cabeçalho (nome do sistema + menu) compartilhado por todas as telas.
 * O fundo claro fica neste wrapper (e não no <body>) para a interface continuar
 * legível mesmo quando o navegador está em tema escuro.
 */
import type { Metadata } from "next";
import type { ReactNode } from "react";
import Link from "next/link";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import MenuNavegacao from "@/components/MenuNavegacao";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "SysMúsica",
  description: "Gestão de membros, eventos e presenças do SysMúsica.",
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="pt-BR">
      <body className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
        {/* Wrapper em coluna: o cabeçalho ocupa o topo e o conteúdo preenche o resto da tela */}
        <div className="flex min-h-screen flex-col bg-slate-50 text-slate-900">
          <header className="sticky top-0 z-40 border-b border-slate-200 bg-white/90 backdrop-blur">
            <div className="mx-auto flex max-w-7xl flex-col gap-2 px-4 py-3 sm:flex-row sm:items-center sm:justify-between sm:px-6 lg:px-8">
              {/* Marca do sistema */}
              <Link href="/membros" className="flex items-center gap-2.5">
                <span
                  aria-hidden="true"
                  className="flex h-9 w-9 items-center justify-center rounded-lg bg-indigo-600 text-lg text-white shadow-sm"
                >
                  ♪
                </span>
                <span className="text-xl font-bold tracking-tight text-slate-900">SysMúsica</span>
              </Link>

              {/* Menu de navegação (Membros, Eventos, Presenças) */}
              <MenuNavegacao />
            </div>
          </header>

          <div className="flex-1">{children}</div>
        </div>
      </body>
    </html>
  );
}
