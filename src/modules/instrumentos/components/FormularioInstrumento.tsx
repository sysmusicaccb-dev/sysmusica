"use client";

/**
 * SysMúsica — Formulário de instrumento (novo ou edição) — conteúdo do painel lateral.
 * instrumento = null -> criar; preenchido -> editar.
 *
 * A família é AUTOMÁTICA: enquanto ninguém a escolhe à mão, ela acompanha o nome digitado
 * (classificação por palavras-chave). Só quem tem permissão de editar instrumentos pode
 * corrigi-la manualmente; os demais veem apenas a sugestão automática.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { inferirFamilia } from "@/lib/familias";
import type { Familia, Instrumento } from "@/types/database";
import { NOME_INSTRUMENTO_MAXIMO, validarNomeInstrumento } from "../regras";
import { atualizarInstrumento, criarInstrumento } from "../services/instrumentos";
import IlustracaoInstrumento from "./IlustracaoInstrumento";

interface FormularioInstrumentoProps {
  instrumento: Instrumento | null;
  instrumentos: Instrumento[]; // todos, para impedir nomes repetidos
  familias: Familia[];
  podeEscolherFamilia: boolean; // permissão instrumentos.editar
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioInstrumento({
  instrumento,
  instrumentos,
  familias,
  podeEscolherFamilia,
  onSalvo,
}: FormularioInstrumentoProps) {
  const editando = instrumento !== null;

  const [nome, setNome] = useState(instrumento?.nome ?? "");
  const [familiaId, setFamiliaId] = useState(instrumento?.familia_id ?? ""); // "" = não classificada
  // Se o instrumento já tem família, respeita; se não tem, a família acompanha o nome digitado
  const [familiaManual, setFamiliaManual] = useState(instrumento?.familia_id != null);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  // Ao digitar o nome, a família é sugerida automaticamente (enquanto não foi escolhida à mão)
  function alterarNome(novoNome: string) {
    setNome(novoNome);
    if (!familiaManual) setFamiliaId(inferirFamilia(novoNome, familias)?.id ?? "");
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    const erroNome = validarNomeInstrumento(nome, instrumentos, familias, instrumento?.id);
    if (erroNome) return setErro(erroNome);

    setSalvando(true);
    try {
      if (instrumento) {
        await atualizarInstrumento({ id: instrumento.id, nome, familiaId: familiaId || null });
        await onSalvo(`Instrumento "${nome.trim()}" atualizado.`);
      } else {
        const criado = await criarInstrumento({ nome, familiaId: familiaId || null });
        await onSalvo(`Instrumento "${criado.nome}" criado.`);
      }
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar o instrumento.");
    } finally {
      setSalvando(false);
    }
  }

  const familiaAtual = familias.find((familia) => familia.id === familiaId);

  return (
    <form onSubmit={salvar} className="space-y-5">
      <div className="space-y-1.5">
        <label htmlFor="nome-instrumento" className="text-sm font-medium text-slate-700">
          Nome do instrumento
        </label>
        <input
          id="nome-instrumento"
          type="text"
          required
          maxLength={NOME_INSTRUMENTO_MAXIMO}
          value={nome}
          onChange={(e) => alterarNome(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Clarinete"
          className={classeInput}
        />
      </div>

      {/* Prévia da ilustração: muda conforme o nome e a família (instrumento sem desenho usa o da família) */}
      {nome.trim() !== "" && (
        <div className="flex items-center gap-3 rounded-lg bg-slate-50 px-3 py-2">
          <IlustracaoInstrumento nome={nome} familia={familiaAtual?.nome} tamanho="grande" />
          <p className="text-xs text-slate-600">
            Ilustração que aparece nas listas. Se o instrumento não tiver desenho próprio, aparece o da família.
          </p>
        </div>
      )}

      <div className="space-y-1.5">
        <label htmlFor="familia-instrumento" className="text-sm font-medium text-slate-700">
          Família {!podeEscolherFamilia && <span className="font-normal text-slate-400">(automática)</span>}
        </label>
        {podeEscolherFamilia ? (
          <select
            id="familia-instrumento"
            value={familiaId}
            onChange={(e) => {
              setFamiliaId(e.target.value);
              setFamiliaManual(true); // a partir daqui a família não acompanha mais o nome
            }}
            disabled={salvando}
            className={classeInput}
          >
            <option value="">Não classificada</option>
            {familias.map((familia) => (
              <option key={familia.id} value={familia.id}>
                {familia.nome}
              </option>
            ))}
          </select>
        ) : (
          <input
            id="familia-instrumento"
            type="text"
            readOnly
            tabIndex={-1}
            value={familiaAtual?.nome ?? ""}
            placeholder="Definida automaticamente pelo nome"
            className="w-full cursor-default rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-700 placeholder:text-slate-400 focus:outline-none"
          />
        )}
        <p className="text-xs text-slate-500">
          {podeEscolherFamilia
            ? "Sugerida automaticamente pelo nome. Você pode corrigir se estiver errada."
            : "Definida automaticamente pelo nome do instrumento."}
        </p>
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Criar instrumento"}
      </Button>
    </form>
  );
}
