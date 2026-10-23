"use client";

/**
 * Sysmusica — Administração > Nomes do Menu (somente o administrador Master).
 * Troca o texto dos itens do menu lateral para TODOS os usuários. Rotas e permissões não mudam.
 */
import { useEffect, useState } from "react";
import { GRUPOS_MENU } from "@/components/layout/navegacao";
import Button from "@/components/ui/Button";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import { LIMITE_ROTULO, normalizarRotulo, rotuloEfetivo, validarRotulo } from "@/modules/menu/regras";
import { restaurarRotuloMenu, salvarRotuloMenu } from "@/modules/menu/services/rotulos";
import { carregarRotulos, definirRotuloLocal, useRotulosMenu } from "@/modules/menu/useRotulosMenu";

export default function NomesDoMenuPage() {
  const { rotulos, master, carregado } = useRotulosMenu();
  const [rascunhos, setRascunhos] = useState<Record<string, string>>({});
  const [ocupado, setOcupado] = useState<string | null>(null);
  const [erro, setErro] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  // Ao abrir, refaz a busca para conferir o papel de Master e os nomes mais recentes
  useEffect(() => {
    void carregarRotulos(true);
  }, []);

  if (!carregado) {
    return (
      <main className="text-slate-900">
        <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
          <p className="text-sm text-slate-600">Carregando...</p>
        </div>
      </main>
    );
  }

  if (!master) {
    return (
      <main className="text-slate-900">
        <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
          <PageHeader titulo="Nomes do Menu" />
          <p role="alert" className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">
            Somente o administrador Master pode alterar os nomes do menu.
          </p>
        </div>
      </main>
    );
  }

  async function salvar(href: string, padrao: string) {
    const texto = rascunhos[href] ?? rotuloEfetivo(href, padrao, rotulos);
    const problema = validarRotulo(texto);
    if (problema) {
      setErro(problema);
      return;
    }
    setErro(null);
    setOcupado(href);
    try {
      const limpo = normalizarRotulo(texto);
      if (limpo === padrao) await restaurarRotuloMenu(href);
      else await salvarRotuloMenu(href, limpo);
      definirRotuloLocal(href, limpo === padrao ? null : limpo);
      setRascunhos((atual) => {
        const resto = { ...atual };
        delete resto[href];
        return resto;
      });
      setAviso("Nome do menu salvo para todos os usuários.");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar.");
    } finally {
      setOcupado(null);
    }
  }

  async function restaurar(href: string) {
    setErro(null);
    setOcupado(href);
    try {
      await restaurarRotuloMenu(href);
      definirRotuloLocal(href, null);
      setRascunhos((atual) => {
        const resto = { ...atual };
        delete resto[href];
        return resto;
      });
      setAviso("Nome padrão restaurado.");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível restaurar.");
    } finally {
      setOcupado(null);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Nomes do Menu"
          descricao="Altere o texto dos itens do menu lateral. A mudança vale para todos os usuários, na próxima vez que carregarem o sistema."
        />

        {erro && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erro}
          </p>
        )}

        <div className="space-y-6">
          {GRUPOS_MENU.map((grupo) => (
            <section key={grupo.titulo ?? "principal"} className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
              <h2 className="mb-3 text-xs font-semibold uppercase tracking-wider text-slate-500">
                {grupo.titulo ?? "Principal"}
              </h2>
              <ul className="space-y-3">
                {grupo.itens.map((item) => {
                  const atual = rotuloEfetivo(item.href, item.rotulo, rotulos);
                  const valor = rascunhos[item.href] ?? atual;
                  const alterado = normalizarRotulo(valor) !== atual;
                  const personalizado = item.href in rotulos;
                  return (
                    <li key={item.href} className="grid items-center gap-2 sm:grid-cols-[14rem_1fr_auto]">
                      <span className="text-sm text-slate-600">
                        Padrão: <strong className="text-slate-800">{item.rotulo}</strong>
                      </span>
                      <input
                        type="text"
                        value={valor}
                        maxLength={LIMITE_ROTULO}
                        onChange={(e) => setRascunhos((a) => ({ ...a, [item.href]: e.target.value }))}
                        aria-label={`Nome do item ${item.rotulo}`}
                        disabled={ocupado !== null}
                        className="h-10 rounded-lg border border-slate-300 px-3 text-sm focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
                      />
                      <div className="flex gap-2">
                        <Button type="button" disabled={!alterado || ocupado !== null} onClick={() => void salvar(item.href, item.rotulo)}>
                          {ocupado === item.href ? "Salvando..." : "Salvar"}
                        </Button>
                        {personalizado && (
                          <button
                            type="button"
                            disabled={ocupado !== null}
                            onClick={() => void restaurar(item.href)}
                            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50 disabled:opacity-50"
                          >
                            Restaurar padrão
                          </button>
                        )}
                      </div>
                    </li>
                  );
                })}
              </ul>
            </section>
          ))}
        </div>
      </div>
      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
