"use client";

/**
 * SysMúsica — Formulário de cadastro de membro.
 *
 * Insere um registro na tabela "membros" via cliente Supabase central.
 * Os campos id, status ("Ativo"), qr_secret e data_cadastro são preenchidos pelo banco.
 * Os cargos chegam da página (lidos da tabela "cargos") e alimentam o select.
 * O campo de categoria do instrumento só aparece para cargos com permite_instrumento = true.
 */
import { useState, type FormEvent } from "react";
import { supabase } from "@/lib/supabase";
import type { Cargo, MembroInsert } from "@/types/database";

interface FormularioMembroProps {
  cargos: Cargo[];
  carregando: boolean;
  erro: string | null;
  /** Chamado após salvar com sucesso, para a página recarregar a lista. */
  onMembroAdicionado: () => void | Promise<void>;
}

// Classe compartilhada pelos campos (mesma identidade visual dos demais módulos).
// [color-scheme:light] mantém o ícone do seletor de data visível mesmo com o navegador em tema escuro.
const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-indigo-500 focus:outline-none " +
  "focus:ring-2 focus:ring-indigo-200 disabled:cursor-not-allowed disabled:opacity-60 " +
  "[color-scheme:light]";

export default function FormularioMembro({
  cargos,
  carregando,
  erro,
  onMembroAdicionado,
}: FormularioMembroProps) {
  const [nome, setNome] = useState("");
  const [congregacao, setCongregacao] = useState("");
  const [cargoId, setCargoId] = useState("");
  const [dataNascimento, setDataNascimento] = useState(""); // formato do input date: "AAAA-MM-DD"
  const [categoria, setCategoria] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erroForm, setErroForm] = useState<string | null>(null);
  const [sucesso, setSucesso] = useState(false);

  // O cargo escolhido define se o campo de instrumento aparece
  const cargoSelecionado = cargos.find((cargo) => cargo.id === cargoId);
  const permiteInstrumento = cargoSelecionado?.permite_instrumento ?? false;

  // Ao trocar de cargo, limpa a categoria se o novo cargo não usar instrumento
  function trocarCargo(novoCargoId: string) {
    setCargoId(novoCargoId);
    const novoCargo = cargos.find((cargo) => cargo.id === novoCargoId);
    if (!novoCargo?.permite_instrumento) setCategoria("");
    setSucesso(false);
  }

  async function handleSubmit(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    setErroForm(null);
    setSucesso(false);

    // Barra campos obrigatórios vazios ou preenchidos só com espaços
    if (!nome.trim() || !congregacao.trim() || !cargoId) {
      setErroForm("Preencha nome, cargo e congregação.");
      return;
    }

    // Payload tipado com MembroInsert (campos com valor padrão no banco ficam de fora)
    const novoMembro: MembroInsert = {
      nome: nome.trim(),
      congregacao: congregacao.trim(),
      cargo_id: cargoId,
      data_nascimento: dataNascimento || null,
      categoria_instrumento: permiteInstrumento && categoria.trim() ? categoria.trim() : null,
    };

    setSalvando(true);
    try {
      const { error } = await supabase.from("membros").insert(novoMembro);
      if (error) throw new Error(error.message);

      // Sucesso: limpa o formulário e avisa a página para recarregar a lista
      setNome("");
      setCongregacao("");
      setCargoId("");
      setDataNascimento("");
      setCategoria("");
      setSucesso(true);
      await onMembroAdicionado();
    } catch (e) {
      setErroForm(
        `Não foi possível salvar o membro: ${
          e instanceof Error ? e.message : "erro desconhecido."
        }`
      );
    } finally {
      setSalvando(false);
    }
  }

  // ---------- Estados da tela ----------

  // Carregando: skeleton
  if (carregando) {
    return (
      <div
        role="status"
        aria-live="polite"
        className="space-y-4 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"
      >
        <span className="sr-only">Carregando formulário...</span>
        <div className="h-6 w-1/2 animate-pulse rounded bg-slate-200" />
        <div className="h-10 animate-pulse rounded-lg bg-slate-200" />
        <div className="h-10 animate-pulse rounded-lg bg-slate-200" />
        <div className="h-10 animate-pulse rounded-lg bg-slate-200" />
      </div>
    );
  }

  // Erro ao buscar dados (o botão "Tentar novamente" fica na lista ao lado)
  if (erro) {
    return (
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-slate-900">Novo membro</h2>
        <p className="mt-2 text-sm text-slate-600">
          Formulário indisponível porque os dados não puderam ser carregados.
        </p>
      </div>
    );
  }

  // Sem cargos: o seed do schema.sql ainda não foi aplicado
  if (cargos.length === 0) {
    return (
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-slate-900">Novo membro</h2>
        <p className="mt-2 text-sm text-slate-600">
          Nenhum cargo encontrado. Execute o arquivo supabase/schema.sql no SQL Editor do Supabase
          para criar os cargos padrão.
        </p>
      </div>
    );
  }

  // Data máxima do campo de nascimento = hoje (formato AAAA-MM-DD, no fuso local)
  const hoje = new Date().toLocaleDateString("sv-SE");

  return (
    <form
      onSubmit={handleSubmit}
      className="space-y-4 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"
    >
      <div>
        <h2 className="text-lg font-semibold text-slate-900">Novo membro</h2>
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
        <label htmlFor="cargo" className="text-sm font-medium text-slate-700">
          Cargo
        </label>
        <select
          id="cargo"
          required
          value={cargoId}
          onChange={(e) => trocarCargo(e.target.value)}
          disabled={salvando}
          className={classeInput}
        >
          <option value="">Selecione um cargo</option>
          {cargos.map((cargo) => (
            <option key={cargo.id} value={cargo.id}>
              {cargo.nome}
            </option>
          ))}
        </select>
      </div>

      {/* Categoria do instrumento: só para cargos com permite_instrumento = true */}
      {permiteInstrumento && (
        <div className="space-y-1.5">
          <label htmlFor="categoria" className="text-sm font-medium text-slate-700">
            Categoria do instrumento <span className="font-normal text-slate-400">(opcional)</span>
          </label>
          <input
            id="categoria"
            type="text"
            list="sugestoes-categoria-instrumento"
            value={categoria}
            onChange={(e) => setCategoria(e.target.value)}
            disabled={salvando}
            placeholder="Ex: Madeiras"
            className={classeInput}
          />
          {/* Sugestões; o campo continua livre */}
          <datalist id="sugestoes-categoria-instrumento">
            <option value="Cordas" />
            <option value="Madeiras" />
            <option value="Metais" />
            <option value="Órgão" />
          </datalist>
        </div>
      )}

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

      <div className="space-y-1.5">
        <label htmlFor="data_nascimento" className="text-sm font-medium text-slate-700">
          Data de nascimento <span className="font-normal text-slate-400">(opcional)</span>
        </label>
        <input
          id="data_nascimento"
          type="date"
          max={hoje}
          value={dataNascimento}
          onChange={(e) => setDataNascimento(e.target.value)}
          disabled={salvando}
          className={classeInput}
        />
      </div>

      {erroForm && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erroForm}
        </p>
      )}
      {sucesso && (
        <p role="status" className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
          Membro cadastrado com sucesso!
        </p>
      )}

      <button
        type="submit"
        disabled={salvando}
        className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-300 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {salvando ? "Salvando..." : "Cadastrar membro"}
      </button>
    </form>
  );
}
