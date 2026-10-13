"use client";

/**
 * SysMúsica — Formulário de cadastro de músico.
 *
 * Insere um registro na tabela "musicos" via cliente Supabase central.
 * Os campos id, status ("Ativo") e data_cadastro são preenchidos pelo banco.
 */
import { useState, type FormEvent } from "react";
import { supabase } from "@/lib/supabase";
import type { MusicoInsert } from "@/types/database";

interface FormularioMusicoProps {
  /** Chamado após salvar com sucesso, para a página recarregar a lista. */
  onMusicoAdicionado: () => void | Promise<void>;
}

// Classe compartilhada pelos três campos (evita repetição)
const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-indigo-500 focus:outline-none " +
  "focus:ring-2 focus:ring-indigo-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioMusico({ onMusicoAdicionado }: FormularioMusicoProps) {
  const [nome, setNome] = useState("");
  const [instrumento, setInstrumento] = useState("");
  const [congregacao, setCongregacao] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [sucesso, setSucesso] = useState(false);

  async function handleSubmit(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault();
    setErro(null);
    setSucesso(false);

    // Payload tipado com MusicoInsert (campos com valor padrão ficam de fora)
    const novoMusico: MusicoInsert = {
      nome: nome.trim(),
      instrumento: instrumento.trim(),
      congregacao: congregacao.trim(),
    };

    // Barra campos preenchidos só com espaços
    if (!novoMusico.nome || !novoMusico.instrumento || !novoMusico.congregacao) {
      setErro("Preencha todos os campos.");
      return;
    }

    setSalvando(true);
    try {
      const { error } = await supabase.from("musicos").insert(novoMusico);
      if (error) throw new Error(error.message);

      // Sucesso: limpa o formulário e avisa a página para recarregar a lista
      setNome("");
      setInstrumento("");
      setCongregacao("");
      setSucesso(true);
      await onMusicoAdicionado();
    } catch (e) {
      setErro(
        `Não foi possível salvar o músico: ${
          e instanceof Error ? e.message : "erro desconhecido."
        }`
      );
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="space-y-4 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"
    >
      <div>
        <h2 className="text-lg font-semibold text-slate-900">Novo músico</h2>
        <p className="text-sm text-slate-500">Preencha os dados para cadastrar.</p>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="nome" className="text-sm font-medium text-slate-700">
          Nome
        </label>
        <input
          id="nome"
          type="text"
          required
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={salvando}
          placeholder="Ex: João da Silva"
          className={classeInput}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="instrumento" className="text-sm font-medium text-slate-700">
          Instrumento
        </label>
        <input
          id="instrumento"
          type="text"
          required
          value={instrumento}
          onChange={(e) => setInstrumento(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Violino"
          className={classeInput}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="congregacao" className="text-sm font-medium text-slate-700">
          Congregação
        </label>
        <input
          id="congregacao"
          type="text"
          required
          value={congregacao}
          onChange={(e) => setCongregacao(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Central"
          className={classeInput}
        />
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}
      {sucesso && (
        <p role="status" className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
          Músico cadastrado com sucesso!
        </p>
      )}

      <button
        type="submit"
        disabled={salvando}
        className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-300 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {salvando ? "Salvando..." : "Cadastrar músico"}
      </button>
    </form>
  );
}
