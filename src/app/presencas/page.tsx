"use client";

/**
 * SysMúsica — Página /presencas (registro + histórico).
 *
 * Client Component: o cliente Supabase usa a chave anon pública e roda no
 * navegador. A página busca eventos, músicos e presenças de uma só vez e
 * distribui os dados para o formulário e para a lista.
 */
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import type { Evento, Musico, Presenca } from "@/types/database";
import FormularioPresenca from "@/components/FormularioPresenca";
import ListaPresencas from "@/components/ListaPresencas";

export default function PresencasPage() {
  const [eventos, setEventos] = useState<Evento[]>([]);
  const [musicos, setMusicos] = useState<Musico[]>([]);
  const [presencas, setPresencas] = useState<Presenca[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);

  // Busca as três tabelas em paralelo
  const buscarDados = useCallback(async () => {
    try {
      const [resEventos, resMusicos, resPresencas] = await Promise.all([
        supabase.from("eventos").select("*").order("data_evento", { ascending: false }),
        supabase.from("musicos").select("*").order("nome", { ascending: true }),
        supabase.from("presencas").select("*"),
      ]);

      // Se qualquer uma das consultas falhar, trata como erro único
      const erroBanco = resEventos.error ?? resMusicos.error ?? resPresencas.error;
      if (erroBanco) throw new Error(erroBanco.message);

      setEventos((resEventos.data ?? []) as Evento[]);
      setMusicos((resMusicos.data ?? []) as Musico[]);
      setPresencas((resPresencas.data ?? []) as Presenca[]);
      setErro(null);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Erro desconhecido ao buscar os dados.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga ao abrir a página
  useEffect(() => {
    void buscarDados();
  }, [buscarDados]);

  // Botão "Tentar novamente": volta ao estado de loading e busca de novo
  function tentarNovamente() {
    setCarregando(true);
    void buscarDados();
  }

  return (
    <main className="min-h-screen bg-slate-50 text-slate-900">
      <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
        <header className="mb-8">
          <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">Presenças</h1>
          <p className="mt-1 text-sm text-slate-600">
            Registre e acompanhe a presença dos músicos nos eventos.
            {!carregando && !erro && ` ${presencas.length} registro(s).`}
          </p>
        </header>

        {/* Mobile: empilhado | Desktop: formulário (1/3) + histórico (2/3) */}
        <div className="grid gap-6 lg:grid-cols-3">
          <section className="lg:col-span-1">
            <FormularioPresenca
              eventos={eventos}
              musicos={musicos}
              presencas={presencas}
              carregando={carregando}
              erro={erro}
              onPresencaAdicionada={buscarDados}
            />
          </section>

          <section className="lg:col-span-2">
            <ListaPresencas
              presencas={presencas}
              musicos={musicos}
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
