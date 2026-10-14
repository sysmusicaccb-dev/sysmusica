"use client";

/**
 * SysMúsica — Página /eventos (listagem + cadastro).
 *
 * Client Component: o cliente Supabase usa a chave anon pública e roda no
 * navegador, então a busca e os estados (loading/erro) ficam aqui.
 */
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import type { Evento } from "@/types/database";
import FormularioEvento from "@/components/FormularioEvento";
import ListaEventos from "@/components/ListaEventos";

export default function EventosPage() {
  const [eventos, setEventos] = useState<Evento[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);

  // Busca todos os eventos, do mais recente para o mais antigo
  const buscarEventos = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from("eventos")
        .select("*")
        .order("data_evento", { ascending: false });

      if (error) throw new Error(error.message);

      setEventos((data ?? []) as Evento[]);
      setErro(null);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Erro desconhecido ao buscar eventos.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga ao abrir a página
  useEffect(() => {
    void buscarEventos();
  }, [buscarEventos]);

  // Botão "Tentar novamente": volta ao estado de loading e busca de novo
  function tentarNovamente() {
    setCarregando(true);
    void buscarEventos();
  }

  return (
    <main className="min-h-screen bg-slate-50 text-slate-900">
      <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
        <header className="mb-8">
          <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">Eventos</h1>
          <p className="mt-1 text-sm text-slate-600">
            Cadastre e acompanhe os ensaios e cultos do SysMúsica.
            {!carregando && !erro && ` ${eventos.length} cadastrado(s).`}
          </p>
        </header>

        {/* Mobile: empilhado | Desktop: formulário (1/3) + lista (2/3) */}
        <div className="grid gap-6 lg:grid-cols-3">
          <section className="lg:col-span-1">
            <FormularioEvento onEventoAdicionado={buscarEventos} />
          </section>

          <section className="lg:col-span-2">
            <ListaEventos
              eventos={eventos}
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
