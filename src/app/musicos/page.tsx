"use client";

/**
 * SysMúsica — Página /musicos (listagem + cadastro).
 *
 * Client Component: o cliente Supabase usa a chave anon pública e roda no
 * navegador, então a busca e os estados (loading/erro) ficam aqui.
 */
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import type { Musico } from "@/types/database";
import FormularioMusico from "@/components/FormularioMusico";
import ListaMusicos from "@/components/ListaMusicos";

export default function MusicosPage() {
  const [musicos, setMusicos] = useState<Musico[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);

  // Busca todos os músicos, em ordem alfabética
  const buscarMusicos = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from("musicos")
        .select("*")
        .order("nome", { ascending: true });

      if (error) throw new Error(error.message);

      setMusicos((data ?? []) as Musico[]);
      setErro(null);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Erro desconhecido ao buscar músicos.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga ao abrir a página
  useEffect(() => {
    void buscarMusicos();
  }, [buscarMusicos]);

  // Botão "Tentar novamente": volta ao estado de loading e busca de novo
  function tentarNovamente() {
    setCarregando(true);
    void buscarMusicos();
  }

  return (
    <main className="min-h-screen bg-slate-50 text-slate-900">
      <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
        <header className="mb-8">
          <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">Músicos</h1>
          <p className="mt-1 text-sm text-slate-600">
            Cadastre e acompanhe os músicos do SysMúsica.
            {!carregando && !erro && ` ${musicos.length} cadastrado(s).`}
          </p>
        </header>

        {/* Mobile: empilhado | Desktop: formulário (1/3) + lista (2/3) */}
        <div className="grid gap-6 lg:grid-cols-3">
          <section className="lg:col-span-1">
            <FormularioMusico onMusicoAdicionado={buscarMusicos} />
          </section>

          <section className="lg:col-span-2">
            <ListaMusicos
              musicos={musicos}
              carregando={carregando}
              erro={erro}
              onTentarNovamente={tentarNovamente}
            />
          </section>
        </div>
      </div>
    </main>
  );
}
