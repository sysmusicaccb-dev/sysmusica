"use client";

/**
 * SysMúsica — Formulário de cadastro de membro.
 *
 * Insere um registro na tabela "membros" via cliente Supabase central.
 * Os campos id, status ("Ativo"), qr_secret e data_cadastro são preenchidos pelo banco.
 *
 * Instrumento (combobox): o campo sugere os instrumentos da tabela "instrumentos".
 *  - Se o texto digitado já existe (sem diferenciar maiúsculas/acentos), usa o id existente.
 *  - Se não existe, faz um INSERT automático em "instrumentos", resgata o novo id e
 *    vincula ao membro (membros.instrumento_id).
 * O campo só aparece para cargos com permite_instrumento = true.
 */
import { useState, type FormEvent } from "react";
import { supabase } from "@/lib/supabase";
import { normalizarTexto } from "@/lib/texto";
import type { Cargo, Instrumento, InstrumentoInsert, MembroInsert } from "@/types/database";

interface FormularioMembroProps {
  cargos: Cargo[];
  instrumentos: Instrumento[];
  carregando: boolean;
  erro: string | null;
  /** Chamado após salvar com sucesso, para a página recarregar os dados (inclui instrumentos novos). */
  onMembroAdicionado: () => void | Promise<void>;
}

// Classe compartilhada pelos campos (mesma identidade visual dos demais módulos).
// [color-scheme:light] mantém o ícone do seletor de data visível mesmo com o navegador em tema escuro.
const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-indigo-500 focus:outline-none " +
  "focus:ring-2 focus:ring-indigo-200 disabled:cursor-not-allowed disabled:opacity-60 " +
  "[color-scheme:light]";

// Ajusta o nome digitado antes de salvar: tira espaços extras e põe a 1ª letra em maiúscula
// (ex: "  sax   soprano " -> "Sax soprano")
function formatarNomeInstrumento(texto: string): string {
  const limpo = texto.trim().replace(/\s+/g, " ");
  return limpo.charAt(0).toUpperCase() + limpo.slice(1);
}

export default function FormularioMembro({
  cargos,
  instrumentos,
  carregando,
  erro,
  onMembroAdicionado,
}: FormularioMembroProps) {
  const [nome, setNome] = useState("");
  const [congregacao, setCongregacao] = useState("");
  const [cargoId, setCargoId] = useState("");
  const [dataNascimento, setDataNascimento] = useState(""); // formato do input date: "AAAA-MM-DD"
  const [instrumentoTexto, setInstrumentoTexto] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erroForm, setErroForm] = useState<string | null>(null);
  const [mensagemSucesso, setMensagemSucesso] = useState<string | null>(null);

  // O cargo escolhido define se o campo de instrumento aparece
  const cargoSelecionado = cargos.find((cargo) => cargo.id === cargoId);
  const permiteInstrumento = cargoSelecionado?.permite_instrumento ?? false;

  // Instrumento digitado: já existe na tabela? (comparação sem acento e sem diferenciar maiúsculas)
  const instrumentoDigitado = instrumentoTexto.trim();
  const instrumentoExistente = instrumentoDigitado
    ? instrumentos.find(
        (instrumento) =>
          normalizarTexto(instrumento.nome) === normalizarTexto(instrumentoDigitado)
      )
    : undefined;

  // Ao trocar de cargo, limpa o instrumento se o novo cargo não usar instrumento
  function trocarCargo(novoCargoId: string) {
    setCargoId(novoCargoId);
    const novoCargo = cargos.find((cargo) => cargo.id === novoCargoId);
    if (!novoCargo?.permite_instrumento) setInstrumentoTexto("");
    setMensagemSucesso(null);
  }

  // Descobre o id do instrumento digitado: usa o existente ou cria um novo (INSERT automático)
  async function resolverInstrumentoId(
    texto: string
  ): Promise<{ id: string; nome: string; criado: boolean }> {
    const chave = normalizarTexto(texto);

    // 1) Já existe na lista carregada? Então só reaproveita o id
    const existente = instrumentos.find(
      (instrumento) => normalizarTexto(instrumento.nome) === chave
    );
    if (existente) return { id: existente.id, nome: existente.nome, criado: false };

    // 2) Não existe: cria e resgata o novo registro (.select().single() devolve a linha inserida)
    const novoInstrumento: InstrumentoInsert = { nome: formatarNomeInstrumento(texto) };
    const { data, error } = await supabase
      .from("instrumentos")
      .insert(novoInstrumento)
      .select()
      .single();
    if (!error && data) {
      const criado = data as Instrumento;
      return { id: criado.id, nome: criado.nome, criado: true };
    }

    // 3) 23505 = nome duplicado: outra pessoa criou o mesmo instrumento agora há pouco.
    //    Busca a lista de novo e reaproveita o registro que já existe.
    if (error?.code === "23505") {
      const { data: lista, error: erroBusca } = await supabase.from("instrumentos").select("*");
      if (erroBusca) throw new Error(erroBusca.message);
      const achado = ((lista ?? []) as Instrumento[]).find(
        (instrumento) => normalizarTexto(instrumento.nome) === chave
      );
      if (achado) return { id: achado.id, nome: achado.nome, criado: false };
    }

    throw new Error(error?.message ?? "Não foi possível criar o instrumento.");
  }

  async function handleSubmit(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    setErroForm(null);
    setMensagemSucesso(null);

    // Barra campos obrigatórios vazios ou preenchidos só com espaços
    if (!nome.trim() || !congregacao.trim() || !cargoId) {
      setErroForm("Preencha nome, cargo e congregação.");
      return;
    }

    setSalvando(true);
    try {
      // Passo 1: resolve o instrumento (só se o cargo permitir e houver texto digitado)
      const instrumento =
        permiteInstrumento && instrumentoDigitado
          ? await resolverInstrumentoId(instrumentoDigitado)
          : null;

      // Passo 2: grava o membro vinculado ao instrumento (ou sem instrumento)
      const novoMembro: MembroInsert = {
        nome: nome.trim(),
        congregacao: congregacao.trim(),
        cargo_id: cargoId,
        data_nascimento: dataNascimento || null,
        instrumento_id: instrumento?.id ?? null,
      };
      const { error } = await supabase.from("membros").insert(novoMembro);
      if (error) throw new Error(error.message);

      // Sucesso: limpa o formulário e avisa a página para recarregar os dados
      setNome("");
      setCongregacao("");
      setCargoId("");
      setDataNascimento("");
      setInstrumentoTexto("");
      setMensagemSucesso(
        instrumento?.criado
          ? `Membro cadastrado! O instrumento "${instrumento.nome}" também foi criado.`
          : "Membro cadastrado com sucesso!"
      );
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

      {/* Instrumento (combobox): digite para filtrar ou escolha na lista; texto novo cria o instrumento */}
      {permiteInstrumento && (
        <div className="space-y-1.5">
          <label htmlFor="instrumento" className="text-sm font-medium text-slate-700">
            Instrumento <span className="font-normal text-slate-400">(opcional)</span>
          </label>
          <input
            id="instrumento"
            type="text"
            list="lista-instrumentos"
            autoComplete="off"
            value={instrumentoTexto}
            onChange={(e) => setInstrumentoTexto(e.target.value)}
            disabled={salvando}
            placeholder="Digite ou escolha um instrumento"
            className={classeInput}
          />
          <datalist id="lista-instrumentos">
            {instrumentos.map((instrumento) => (
              <option key={instrumento.id} value={instrumento.nome} />
            ))}
          </datalist>

          {/* Feedback ao vivo: informa se o instrumento já existe ou se será criado */}
          {instrumentoDigitado && (
            <p
              className={
                "text-xs " + (instrumentoExistente ? "text-slate-500" : "text-indigo-600")
              }
            >
              {instrumentoExistente
                ? `Instrumento cadastrado: ${instrumentoExistente.nome}`
                : `Novo instrumento: "${formatarNomeInstrumento(instrumentoDigitado)}" será criado ao salvar.`}
            </p>
          )}
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
      {mensagemSucesso && (
        <p role="status" className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
          {mensagemSucesso}
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
