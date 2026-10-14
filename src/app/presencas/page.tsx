"use client";

/**
 * SysMúsica — Página /presencas (registro + histórico).
 *
 * Client Component: o cliente Supabase usa a chave anon pública e roda no
 * navegador. A página busca eventos, membros e presenças de uma só vez e
 * distribui os dados para o formulário e para a lista.
 */
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import {
  COLUNAS_MEMBRO_PUBLICO,
  type Evento,
  type MembroPublico,
  type Presenca,
} from "@/types/database";
import FormularioPresenca from "@/components/FormularioPresenca";
import ListaPresencas from "@/components/ListaPresencas";

export default function PresencasPage() {
  const [eventos, setEventos] = useState<Evento[]>([]);
  const [membros, setMembros] = useState<MembroPublico[]>([]);
  const [presencas, setPresencas] = useState<Presenca[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);

  // Busca as três tabelas em paralelo
  const buscarDados = useCallback(async () => {
    try {
      const [resEventos, resMembros, resPresencas] = await Promise.all([
        supabase.from("eventos").select("*").order("data_evento", { ascending: false }),
        // Lista explícita de colunas: select("*") falharia por causa do qr_secret (protegido)
        supabase
          .from("membros")
          .select(COLUNAS_MEMBRO_PUBLICO)
          .order("nome", { ascending: true }),
        supabase.from("presencas").select("*"),
      ]);

      // Se qualquer uma das consultas falhar, trata como erro único
      const erroBanco = resEventos.error ?? resMembros.error ?? resPresencas.error;
      if (erroBanco) throw new Error(erroBanco.message);

      setEventos((resEventos.data ?? []) as Evento[]);
      // Cast duplo: com lista de colunas, o cliente (sem tipagem gerada) não infere a linha
      setMembros((resMembros.data ?? []) as unknown as MembroPublico[]);
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
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga inicial. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
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
            Registre e acompanhe a presença dos membros nos eventos.
            {!carregando && !erro && ` ${presencas.length} registro(s).`}
          </p>
        </header>

        {/* Mobile: empilhado | Desktop: formulário (1/3) + histórico (2/3) */}
        <div className="grid gap-6 lg:grid-cols-3">
          <section className="lg:col-span-1">
            <FormularioPresenca
              eventos={eventos}
              membros={membros}
              presencas={presencas}
              carregando={carregando}
              erro={erro}
              onPresencaAdicionada={buscarDados}
            />
          </section>

          <section className="lg:col-span-2">
            <ListaPresencas
              presencas={presencas}
              membros={membros}
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
