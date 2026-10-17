"use client";

/**
 * SysMúsica — Formulário de membro (cadastro e edição) — conteúdo do painel lateral.
 * membro = null -> cadastrar; preenchido -> editar (inclui o status Ativo/Inativo).
 *
 * Instrumento (combobox): o campo sugere os instrumentos cadastrados.
 *  - Se o texto digitado já existe (sem diferenciar maiúsculas/acentos), usa o instrumento existente.
 *  - Se não existe, o instrumento é criado automaticamente (com a família inferida pelo nome).
 *  - A FAMÍLIA é automática e somente leitura; quem corrige uma classificação errada é quem
 *    tem permissão de editar instrumentos (tela Instrumentos e famílias).
 *  - Nome de família (ex: "Madeiras") não é aceito como instrumento.
 * O campo de instrumento só aparece para cargos com permite_instrumento = true.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { ehNomeDeFamilia, inferirFamilia } from "@/lib/familias";
import { normalizarTexto } from "@/lib/texto";
import { formatarNomeInstrumento } from "@/modules/instrumentos/regras";
import { obterOuCriarInstrumento } from "@/modules/instrumentos/services/instrumentos";
import { atualizarMembro, criarMembro } from "@/modules/membros/services/membros";
import type { Cargo, Familia, Instrumento, MembroPublico } from "@/types/database";

interface FormularioMembroProps {
  membro: MembroPublico | null; // null = cadastrar; preenchido = editar
  cargos: Cargo[];
  instrumentos: Instrumento[];
  familias: Familia[];
  carregando: boolean;
  erro: string | null;
  /** Chamado após salvar com sucesso, com a mensagem para o aviso da tela. */
  onSalvo: (mensagem: string) => void | Promise<void>;
}

// Classe compartilhada pelos campos (mesma identidade visual dos demais módulos).
// [color-scheme:light] mantém o ícone do seletor de data visível mesmo com o navegador em tema escuro.
const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60 " +
  "[color-scheme:light]";

export default function FormularioMembro({
  membro,
  cargos,
  instrumentos,
  familias,
  carregando,
  erro,
  onSalvo,
}: FormularioMembroProps) {
  const editando = membro !== null;

  // Valores iniciais: vazios no cadastro; os dados do membro na edição
  const instrumentoInicial = membro?.instrumento_id
    ? (instrumentos.find((instrumento) => instrumento.id === membro.instrumento_id)?.nome ?? "")
    : "";

  const [nome, setNome] = useState(membro?.nome ?? "");
  const [congregacao, setCongregacao] = useState(membro?.congregacao ?? "");
  const [cargoId, setCargoId] = useState(membro?.cargo_id ?? "");
  const [dataNascimento, setDataNascimento] = useState(membro?.data_nascimento ?? ""); // "AAAA-MM-DD"
  const [instrumentoTexto, setInstrumentoTexto] = useState(instrumentoInicial);
  const [status, setStatus] = useState(membro?.status ?? "Ativo");
  const [salvando, setSalvando] = useState(false);
  const [erroForm, setErroForm] = useState<string | null>(null);

  // O cargo escolhido define se o campo de instrumento aparece
  const cargoSelecionado = cargos.find((cargo) => cargo.id === cargoId);
  const permiteInstrumento = cargoSelecionado?.permite_instrumento ?? false;

  // Instrumento digitado: já existe na tabela? (comparação sem acento e sem diferenciar maiúsculas)
  const instrumentoDigitado = instrumentoTexto.trim();
  const instrumentoExistente = instrumentoDigitado
    ? instrumentos.find(
        (instrumento) => normalizarTexto(instrumento.nome) === normalizarTexto(instrumentoDigitado)
      )
    : undefined;

  // O texto digitado é o nome de uma família (ex: "Madeiras")? Isso não é um instrumento.
  const digitadoEhFamilia = instrumentoDigitado !== "" && ehNomeDeFamilia(instrumentoDigitado, familias);

  // Família AUTOMÁTICA: a do instrumento já cadastrado ou, se for novo, a inferida pelo nome
  const familiaAutomatica: Familia | null = instrumentoExistente
    ? (familias.find((familia) => familia.id === instrumentoExistente.familia_id) ?? null)
    : instrumentoDigitado && !digitadoEhFamilia
      ? inferirFamilia(instrumentoDigitado, familias)
      : null;

  // Texto mostrado no campo (somente leitura) "Família"
  const textoFamilia = familiaAutomatica
    ? familiaAutomatica.nome
    : instrumentoDigitado && !digitadoEhFamilia
      ? "Não identificada (poderá ser classificada depois)"
      : "";

  // Ao trocar de cargo, limpa o instrumento se o novo cargo não usar instrumento
  function trocarCargo(novoCargoId: string) {
    setCargoId(novoCargoId);
    const novoCargo = cargos.find((cargo) => cargo.id === novoCargoId);
    if (!novoCargo?.permite_instrumento) setInstrumentoTexto("");
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErroForm(null);

    // Barra campos obrigatórios vazios ou preenchidos só com espaços
    if (!nome.trim() || !congregacao.trim() || !cargoId) {
      return setErroForm("Preencha nome, cargo e congregação.");
    }

    // Família não é instrumento: pede o instrumento real
    if (permiteInstrumento && digitadoEhFamilia) {
      return setErroForm(
        `"${instrumentoDigitado}" é uma família de instrumentos. Informe o instrumento (ex.: Clarinete).`
      );
    }

    setSalvando(true);
    try {
      // Passo 1: resolve o instrumento (só se o cargo permitir e houver texto digitado)
      const instrumento =
        permiteInstrumento && instrumentoDigitado
          ? await obterOuCriarInstrumento(instrumentoDigitado, instrumentos, familias)
          : null;

      // Passo 2: grava o membro (criar ou atualizar)
      const dados = {
        nome: nome.trim(),
        congregacao: congregacao.trim(),
        cargo_id: cargoId,
        data_nascimento: dataNascimento || null,
        instrumento_id: instrumento?.id ?? null,
      };
      if (membro) await atualizarMembro(membro.id, { ...dados, status });
      else await criarMembro(dados);

      const complemento = instrumento?.criado
        ? ` Instrumento "${instrumento.nome}" criado${
            instrumento.familiaNome
              ? ` na família ${instrumento.familiaNome}`
              : " (família ainda não classificada)"
          }.`
        : "";
      await onSalvo(
        editando
          ? `Membro "${dados.nome}" atualizado.${complemento}`
          : `Membro "${dados.nome}" cadastrado.${complemento}`
      );
    } catch (e) {
      setErroForm(e instanceof Error ? e.message : "Não foi possível salvar o membro.");
    } finally {
      setSalvando(false);
    }
  }

  // ---------- Estados da tela ----------

  if (carregando) {
    return <p className="text-sm text-slate-600">Carregando os dados do formulário...</p>;
  }

  if (erro) {
    return (
      <p className="text-sm text-slate-600">
        Formulário indisponível porque os dados não puderam ser carregados.
      </p>
    );
  }

  // Sem cargos: a migração do banco ainda não foi aplicada
  if (cargos.length === 0) {
    return (
      <p className="text-sm text-slate-600">
        Nenhum cargo encontrado. Aplique as migrações do banco (pasta supabase/migrations) para criar
        os cargos padrão.
      </p>
    );
  }

  // Data máxima do campo de nascimento = hoje (formato AAAA-MM-DD, no fuso local)
  const hoje = new Date().toLocaleDateString("sv-SE");

  return (
    <form onSubmit={salvar} className="space-y-5">
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

      {/* Instrumento (combobox) + Família automática (somente leitura) */}
      {permiteInstrumento && (
        <>
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

            {/* Feedback ao vivo: família digitada, instrumento existente ou novo */}
            {instrumentoDigitado && (
              <p
                className={
                  "text-xs " +
                  (digitadoEhFamilia
                    ? "text-red-600"
                    : instrumentoExistente
                      ? "text-slate-500"
                      : "text-brand-700")
                }
              >
                {digitadoEhFamilia
                  ? `"${instrumentoDigitado}" é uma família. Digite o instrumento (ex.: Clarinete).`
                  : instrumentoExistente
                    ? `Instrumento cadastrado: ${instrumentoExistente.nome}`
                    : `Novo instrumento: "${formatarNomeInstrumento(instrumentoDigitado)}" será criado ao salvar.`}
              </p>
            )}
          </div>

          <div className="space-y-1.5">
            <label htmlFor="familia" className="text-sm font-medium text-slate-700">
              Família <span className="font-normal text-slate-400">(automática)</span>
            </label>
            <input
              id="familia"
              type="text"
              readOnly
              tabIndex={-1}
              value={textoFamilia}
              placeholder="Definida automaticamente pelo instrumento"
              className="w-full cursor-default rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-700 placeholder:text-slate-400 focus:outline-none"
            />
          </div>
        </>
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

      {/* Status: só na edição (todo membro novo nasce "Ativo") */}
      {editando && (
        <div className="space-y-1.5">
          <label htmlFor="status" className="text-sm font-medium text-slate-700">
            Status
          </label>
          <select
            id="status"
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            disabled={salvando}
            className={classeInput}
          >
            <option value="Ativo">Ativo</option>
            <option value="Inativo">Inativo</option>
          </select>
        </div>
      )}

      {erroForm && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erroForm}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Cadastrar membro"}
      </Button>
    </form>
  );
}
