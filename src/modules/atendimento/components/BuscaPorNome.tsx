"use client";

/**
 * Sysmusica — Busca pelo nome completo (quando o membro não consegue mostrar o QR Code).
 * Exige nome e sobrenome. Mostra até 6 resultados com foto; ao escolher, abre a conferência.
 */
import { useState, type FormEvent } from "react";
import FotoMembro from "@/modules/membros/components/FotoMembro";
import { horaCurta, nomeCompletoValido, normalizarNomeBusca } from "../regras";
import { buscarMembrosPorNome } from "../services/atendimento";
import type { CartaoMembro } from "../tipos";

interface BuscaPorNomeProps {
  portariaId: string;
  desabilitado: boolean;
  onEscolher: (membro: CartaoMembro) => void;
}

export default function BuscaPorNome({ portariaId, desabilitado, onEscolher }: BuscaPorNomeProps) {
  const [nome, setNome] = useState("");
  const [buscando, setBuscando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [resultados, setResultados] = useState<CartaoMembro[] | null>(null);

  async function buscar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (buscando || desabilitado) return;
    setErro(null);

    if (!nomeCompletoValido(nome)) {
      setResultados(null);
      return setErro("Digite o nome completo do membro (nome e sobrenome).");
    }

    setBuscando(true);
    try {
      setResultados(await buscarMembrosPorNome(portariaId, normalizarNomeBusca(nome)));
    } catch (e) {
      setResultados(null);
      setErro(e instanceof Error ? e.message : "Não foi possível buscar o membro.");
    } finally {
      setBuscando(false);
    }
  }

  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      <h2 className="text-sm font-semibold text-slate-900">Sem QR Code? Busque pelo nome completo</h2>
      <p className="mt-1 text-xs text-slate-500">
        Digite nome e sobrenome. A foto e os dados aparecem para você conferir se é mesmo a pessoa.
      </p>

      <form onSubmit={buscar} className="mt-3 flex gap-2">
        <label htmlFor="busca-nome-completo" className="sr-only">
          Nome completo do membro
        </label>
        <input
          id="busca-nome-completo"
          type="search"
          autoComplete="off"
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={desabilitado}
          placeholder="Ex: Maria da Silva Santos"
          className="min-w-0 flex-1 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm placeholder:text-slate-400 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
        />
        <button
          type="submit"
          disabled={desabilitado || buscando}
          className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {buscando ? "Buscando..." : "Buscar"}
        </button>
      </form>

      {erro && (
        <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      {resultados !== null && resultados.length === 0 && !erro && (
        <p className="mt-3 text-sm text-slate-500">Nenhum membro encontrado com esse nome.</p>
      )}

      {resultados !== null && resultados.length > 0 && (
        <ul className="mt-3 space-y-2">
          {resultados.map((membro) => (
            <li key={membro.membro_id}>
              <button
                type="button"
                onClick={() => onEscolher(membro)}
                disabled={desabilitado}
                className="flex w-full items-center gap-3 rounded-xl border border-slate-200 p-3 text-left transition hover:bg-slate-50 disabled:opacity-60"
              >
                <FotoMembro caminho={membro.foto_path} nome={membro.nome} />
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-medium text-slate-900">{membro.nome}</span>
                  <span className="block truncate text-xs text-slate-500">
                    {[membro.cargo, membro.congregacao].filter(Boolean).join(" · ")}
                  </span>
                  {membro.ja_registrado_em && (
                    <span className="block text-xs text-amber-700">
                      Já registrado às {horaCurta(membro.ja_registrado_em)}
                    </span>
                  )}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
