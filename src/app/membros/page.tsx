"use client";

/**
 * SysMúsica — Página /membros (cadastro + tabela com filtros).
 *
 * Client Component: o cliente Supabase usa a chave anon pública e roda no
 * navegador. A página busca cargos, instrumentos e membros de uma vez e distribui
 * os dados para o formulário (selects/combobox) e para a tabela (nomes e filtros).
 */
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import {
  COLUNAS_MEMBRO_PUBLICO,
  type Cargo,
  type Instrumento,
  type MembroPublico,
} from "@/types/database";
import FormularioMembro from "@/components/FormularioMembro";
import ListaMembros from "@/components/ListaMembros";

export default function MembrosPage() {
  const [cargos, setCargos] = useState<Cargo[]>([]);
  const [instrumentos, setInstrumentos] = useState<Instrumento[]>([]);
  const [membros, setMembros] = useState<MembroPublico[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);

  // Busca as três tabelas em paralelo
  const buscarDados = useCallback(async () => {
    try {
      const [resCargos, resInstrumentos, resMembros] = await Promise.all([
        supabase.from("cargos").select("*").order("nome", { ascending: true }),
        supabase.from("instrumentos").select("*").order("nome", { ascending: true }),
        // Lista explícita de colunas: select("*") falharia por causa do qr_secret (protegido)
        supabase
          .from("membros")
          .select(COLUNAS_MEMBRO_PUBLICO)
          .order("nome", { ascending: true }),
      ]);

      // Se qualquer uma das consultas falhar, trata como erro único
      const erroBanco = resCargos.error ?? resInstrumentos.error ?? resMembros.error;
      if (erroBanco) throw new Error(erroBanco.message);

      setCargos((resCargos.data ?? []) as Cargo[]);
      setInstrumentos((resInstrumentos.data ?? []) as Instrumento[]);
      // Cast duplo: com lista de colunas, o cliente (sem tipagem gerada) não infere a linha
      setMembros((resMembros.data ?? []) as unknown as MembroPublico[]);
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
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <header className="mb-8">
          <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">Membros</h1>
          <p className="mt-1 text-sm text-slate-600">
            Cadastre e acompanhe os membros do SysMúsica.
            {!carregando && !erro && ` ${membros.length} cadastrado(s).`}
          </p>
        </header>

        {/* Mobile: empilhado | Desktop: formulário (1/3) + tabela (2/3) */}
        <div className="grid gap-6 lg:grid-cols-3">
          <section className="lg:col-span-1">
            <FormularioMembro
              cargos={cargos}
              instrumentos={instrumentos}
              carregando={carregando}
              erro={erro}
              onMembroAdicionado={buscarDados}
            />
          </section>

          <section className="min-w-0 lg:col-span-2">
            <ListaMembros
              membros={membros}
              cargos={cargos}
              instrumentos={instrumentos}
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
