"use client";

/**
 * SysMúsica — Importar lista de hinos (conteúdo do painel lateral).
 * Cole um hino por linha ("001 - Título", "1. Título" ou "Coro 1 - Título"). A tela mostra uma prévia antes de
 * gravar. A importação só ACRESCENTA: número que já existe é ignorado (nada é alterado nem apagado).
 */
import { useMemo, useState } from "react";
import Button from "@/components/ui/Button";
import { IMPORTACAO_MAXIMA, interpretarLista, resumirImportacao, rotuloHino, type CategoriaHino, type Hino } from "../regras";
import { importarHinos } from "../services/hinos";

interface ImportarHinosProps {
  existentes: Hino[];
  onImportado: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function ImportarHinos({ existentes, onImportado }: ImportarHinosProps) {
  const [texto, setTexto] = useState("");
  const [categoriaPadrao, setCategoriaPadrao] = useState<CategoriaHino>("HINO");
  const [importando, setImportando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const lista = useMemo(() => interpretarLista(texto, categoriaPadrao), [texto, categoriaPadrao]);
  const resumo = useMemo(() => resumirImportacao(lista.itens, existentes), [lista.itens, existentes]);
  const acimaDoLimite = lista.itens.length > IMPORTACAO_MAXIMA;

  async function importar() {
    if (importando || lista.itens.length === 0 || acimaDoLimite) return;
    setImportando(true);
    setErro(null);
    try {
      const r = await importarHinos(lista.itens);
      await onImportado(
        `${r.novos} cadastrado(s)${r.ja_existiam > 0 ? `, ${r.ja_existiam} já existia(m) e foi(ram) mantido(s)` : ""}.`
      );
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível importar a lista.");
    } finally {
      setImportando(false);
    }
  }

  return (
    <div className="space-y-5">
      <div className="space-y-1.5">
        <label htmlFor="categoria-importar" className="text-sm font-medium text-slate-700">
          Linhas sem “Coro” são
        </label>
        <select
          id="categoria-importar"
          value={categoriaPadrao}
          onChange={(e) => setCategoriaPadrao(e.target.value as CategoriaHino)}
          disabled={importando}
          className={classeInput}
        >
          <option value="HINO">Hinos do hinário</option>
          <option value="CORO">Coros (corinhos)</option>
        </select>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="texto-importar" className="text-sm font-medium text-slate-700">
          Lista (um por linha)
        </label>
        <textarea
          id="texto-importar"
          rows={10}
          value={texto}
          onChange={(e) => setTexto(e.target.value)}
          disabled={importando}
          placeholder={"001 - Título do hino\n002 - Outro hino\nCoro 1 - Título do coro"}
          className={classeInput + " font-mono"}
        />
      </div>

      {texto.trim() !== "" && (
        <div className="space-y-2 rounded-xl bg-slate-50 p-3 text-sm text-slate-700" aria-live="polite">
          <p>
            <strong>{lista.itens.length}</strong> linha(s) lida(s): <strong>{resumo.novos}</strong> nova(s),{" "}
            <strong>{resumo.jaExistem}</strong> já cadastrada(s)
            {resumo.tituloDiferente > 0 && ` (${resumo.tituloDiferente} com título diferente — o título atual será mantido)`}.
          </p>
          {lista.itens.length > 0 && (
            <p className="text-xs text-slate-500">
              Primeira: {rotuloHino(lista.itens[0].categoria, lista.itens[0].numero)} – {lista.itens[0].nome}
            </p>
          )}
          {acimaDoLimite && (
            <p role="alert" className="text-red-700">
              Máximo de {IMPORTACAO_MAXIMA} itens por vez. Divida a lista.
            </p>
          )}
          {lista.problemas.length > 0 && (
            <div>
              <p className="font-medium text-amber-800">{lista.problemas.length} linha(s) ignorada(s):</p>
              <ul className="mt-1 max-h-40 list-disc space-y-0.5 overflow-y-auto pl-5 text-xs text-amber-900">
                {lista.problemas.slice(0, 50).map((p) => (
                  <li key={p.linha}>
                    Linha {p.linha}: {p.motivo} <span className="text-slate-500">“{p.texto.slice(0, 60)}”</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button onClick={() => void importar()} disabled={importando || lista.itens.length === 0 || acimaDoLimite} className="w-full">
        {importando ? "Importando..." : `Importar ${resumo.novos} novo(s)`}
      </Button>
    </div>
  );
}
