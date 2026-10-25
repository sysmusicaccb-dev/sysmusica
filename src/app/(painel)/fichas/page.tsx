"use client";

/**
 * Sysmusica — Administrativo > Fichas Musicais: catálogo das fichas da Comissão Musical e lista das fichas
 * já preenchidas na região de quem consulta. As telas de preenchimento entram aos poucos; as que ainda não
 * existem aparecem como "Em breve".
 */
import { useCallback, useEffect, useState } from "react";
import Badge from "@/components/ui/Badge";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import { formatarDataHora } from "@/lib/datas";
import { FICHAS, rotuloDoResultado, tituloDaFicha } from "@/modules/fichas/regras";
import { listarFichas } from "@/modules/fichas/services/fichas";
import type { LinhaFicha } from "@/modules/fichas/tipos";

export default function FichasPage() {
  const [itens, setItens] = useState<LinhaFicha[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    try {
      setItens(await listarFichas());
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar as fichas:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar as fichas.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga inicial. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Fichas Musicais"
          descricao="Fichas e pedidos da Comissão Musical: preencher, guardar, imprimir e marcar o resultado."
        />

        {/* Catálogo das fichas */}
        <section aria-label="Fichas disponíveis" className="mb-8 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {FICHAS.map((ficha) => (
            <article key={ficha.tipo} className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
              <div className="mb-1 flex items-start justify-between gap-2">
                <h2 className="text-sm font-bold text-slate-900">
                  {ficha.codigo === "Ficha" || ficha.codigo === "Formulário" ? "" : `${ficha.codigo} · `}
                  {ficha.titulo}
                </h2>
                <Badge variante={ficha.disponivel ? "sucesso" : "neutro"}>{ficha.disponivel ? "Disponível" : "Em breve"}</Badge>
              </div>
              <p className="text-xs text-slate-500">{ficha.descricao}</p>
            </article>
          ))}
        </section>

        {/* Fichas já preenchidas */}
        <h2 className="mb-3 text-base font-bold text-slate-900">Fichas preenchidas</h2>
        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando as fichas...</span>
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState
            titulo="Não foi possível carregar as fichas."
            mensagem={erro}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar();
            }}
          />
        ) : itens.length === 0 ? (
          <EmptyState titulo="Nenhuma ficha preenchida ainda." descricao="As fichas preenchidas na sua região aparecem aqui." />
        ) : (
          <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
            <table className="w-full text-left text-sm">
              <thead className="bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
                <tr>
                  <th scope="col" className="px-4 py-3">Ficha</th>
                  <th scope="col" className="px-4 py-3">Pessoa</th>
                  <th scope="col" className="px-4 py-3">Casa de Oração</th>
                  <th scope="col" className="px-4 py-3">Criada em</th>
                  <th scope="col" className="px-4 py-3">Resultado</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {itens.map((ficha) => (
                  <tr key={ficha.id}>
                    <td className="px-4 py-3 font-medium">{tituloDaFicha(ficha.tipo)}</td>
                    <td className="px-4 py-3">{ficha.membro_nome ?? "—"}</td>
                    <td className="px-4 py-3">{ficha.casa_nome ?? "—"}</td>
                    <td className="px-4 py-3 tabular-nums">{formatarDataHora(ficha.criado_em)}</td>
                    <td className="px-4 py-3">
                      <Badge variante={ficha.resultado === "APTO" ? "sucesso" : ficha.resultado === "NAO_APTO" ? "perigo" : "neutro"}>
                        {rotuloDoResultado(ficha.resultado)}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </main>
  );
}
