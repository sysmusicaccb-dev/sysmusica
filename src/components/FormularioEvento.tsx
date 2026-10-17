"use client";

/**
 * SysMúsica — Formulário de cadastro de evento.
 *
 * Insere um registro na tabela "eventos" via cliente Supabase central.
 * O campo id é gerado pelo banco.
 */
import { useState, type FormEvent } from "react";
import { supabase } from "@/lib/supabase";
import type { EventoInsert } from "@/types/database";

interface FormularioEventoProps {
  /** Chamado após salvar com sucesso, para a página recarregar a lista. */
  onEventoAdicionado: (mensagem: string) => void | Promise<void>;
}

// Classe compartilhada pelos três campos (mesma identidade visual do módulo de músicos).
// [color-scheme:light] mantém o ícone do seletor de data visível mesmo com o navegador em tema escuro.
const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-indigo-500 focus:outline-none " +
  "focus:ring-2 focus:ring-indigo-200 disabled:cursor-not-allowed disabled:opacity-60 " +
  "[color-scheme:light]";

export default function FormularioEvento({ onEventoAdicionado }: FormularioEventoProps) {
  const [tipo, setTipo] = useState("");
  const [dataEvento, setDataEvento] = useState(""); // formato do datetime-local: "AAAA-MM-DDTHH:mm"
  const [local, setLocal] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [sucesso, setSucesso] = useState(false);

  async function handleSubmit(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    setErro(null);
    setSucesso(false);

    // Barra campos vazios ou preenchidos só com espaços
    if (!tipo.trim() || !dataEvento || !local.trim()) {
      setErro("Preencha todos os campos.");
      return;
    }

    // O datetime-local não traz fuso horário. new Date() o interpreta como horário
    // LOCAL do navegador e toISOString() converte para UTC, que é o que o
    // campo timestamptz do banco espera (evita eventos salvos com horário deslocado).
    const dataConvertida = new Date(dataEvento);
    if (Number.isNaN(dataConvertida.getTime())) {
      setErro("Informe uma data e hora válidas.");
      return;
    }

    // Payload tipado com EventoInsert (o id fica por conta do banco)
    const novoEvento: EventoInsert = {
      tipo: tipo.trim(),
      data_evento: dataConvertida.toISOString(),
      local: local.trim(),
    };

    setSalvando(true);
    try {
      const { error } = await supabase.from("eventos").insert(novoEvento);
      if (error) throw new Error(error.message);

      // Sucesso: limpa o formulário e avisa a página para recarregar a lista
      setTipo("");
      setDataEvento("");
      setLocal("");
      setSucesso(true);
      await onEventoAdicionado("Evento cadastrado com sucesso!");
    } catch (e) {
      setErro(
        `Não foi possível salvar o evento: ${
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
      className="space-y-4"
    >
      <div className="space-y-1.5">
        <label htmlFor="tipo" className="text-sm font-medium text-slate-700">
          Tipo
        </label>
        {/* Campo livre com sugestões (datalist): aceita Ensaio, Culto ou qualquer outro tipo */}
        <input
          id="tipo"
          type="text"
          list="sugestoes-tipo-evento"
          required
          value={tipo}
          onChange={(e) => setTipo(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Ensaio, Culto"
          className={classeInput}
        />
        <datalist id="sugestoes-tipo-evento">
          <option value="Ensaio" />
          <option value="Culto" />
        </datalist>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="data_evento" className="text-sm font-medium text-slate-700">
          Data do evento
        </label>
        <input
          id="data_evento"
          type="datetime-local"
          required
          value={dataEvento}
          onChange={(e) => setDataEvento(e.target.value)}
          disabled={salvando}
          className={classeInput}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="local" className="text-sm font-medium text-slate-700">
          Local
        </label>
        <input
          id="local"
          type="text"
          required
          value={local}
          onChange={(e) => setLocal(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Congregação Central"
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
          Evento cadastrado com sucesso!
        </p>
      )}

      <button
        type="submit"
        disabled={salvando}
        className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-300 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {salvando ? "Salvando..." : "Cadastrar evento"}
      </button>
    </form>
  );
}
