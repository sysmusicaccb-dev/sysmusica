"use client";

/**
 * SysMúsica — Formulário de tipo de evento (novo ou edição) — conteúdo do painel lateral.
 * tipo = null -> criar; preenchido -> editar.
 *
 * O campo "Dados do Ensaio" diz se os eventos deste tipo usam a tela Dados do Ensaio e em qual modelo
 * (Local ou Regional). O banco não deixa trocar o modelo de um tipo que já tem ensaios preenchidos.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { DESCRICAO_MAXIMA, NOME_MAXIMO, ROTULO_MODELO, validarTipoEvento, type ModeloEnsaio, type TipoEvento } from "../regras";
import { salvarTipoEvento } from "../services/tiposEvento";

interface FormularioTipoEventoProps {
  tipo: TipoEvento | null;
  tipos: TipoEvento[]; // todos, para impedir nomes repetidos
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioTipoEvento({ tipo, tipos, onSalvo }: FormularioTipoEventoProps) {
  const editando = tipo !== null;
  const [nome, setNome] = useState(tipo?.nome ?? "");
  const [descricao, setDescricao] = useState(tipo?.descricao ?? "");
  const [modelo, setModelo] = useState<ModeloEnsaio | "">(tipo?.modelo_ensaio ?? "");
  const [ativo, setAtivo] = useState(tipo?.ativo ?? true);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    const erroForm = validarTipoEvento({ nome, descricao }, tipos, tipo?.id);
    if (erroForm) return setErro(erroForm);

    setSalvando(true);
    try {
      await salvarTipoEvento(tipo?.id ?? null, {
        nome: nome.trim().replace(/\s+/g, " "),
        descricao: descricao.trim(),
        modelo_ensaio: modelo === "" ? null : modelo,
        ativo,
      });
      await onSalvo(editando ? `Tipo "${nome.trim()}" atualizado.` : `Tipo "${nome.trim()}" criado.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar o tipo de evento.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      <div className="space-y-1.5">
        <label htmlFor="nome-tipo" className="text-sm font-medium text-slate-700">
          Nome do tipo
        </label>
        <input
          id="nome-tipo"
          type="text"
          required
          maxLength={NOME_MAXIMO}
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Ensaio Regional"
          className={classeInput}
        />
        {editando && (tipo?.em_uso ?? 0) > 0 && (
          <p className="text-xs text-slate-500">
            Ao renomear, os {tipo?.em_uso} evento(s) deste tipo passam a mostrar o novo nome.
          </p>
        )}
      </div>

      <div className="space-y-1.5">
        <label htmlFor="descricao-tipo" className="text-sm font-medium text-slate-700">
          Descrição <span className="font-normal text-slate-400">(opcional)</span>
        </label>
        <textarea
          id="descricao-tipo"
          rows={3}
          maxLength={DESCRICAO_MAXIMA}
          value={descricao}
          onChange={(e) => setDescricao(e.target.value)}
          disabled={salvando}
          className={classeInput}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="modelo-tipo" className="text-sm font-medium text-slate-700">
          Dados do Ensaio
        </label>
        <select
          id="modelo-tipo"
          value={modelo}
          onChange={(e) => setModelo(e.target.value as ModeloEnsaio | "")}
          disabled={salvando}
          className={classeInput}
        >
          <option value="">Não usa (sem tela de ensaio)</option>
          <option value="LOCAL">{ROTULO_MODELO.LOCAL}</option>
          <option value="REGIONAL">{ROTULO_MODELO.REGIONAL}</option>
        </select>
        <p className="text-xs text-slate-500">
          Regional: quem atende é sempre Ancião e há a palavra. Local: quem atende pode ser Ancião, Diácono ou
          Cooperador, sem palavra.
        </p>
      </div>

      <label className="flex items-center gap-2 text-sm text-slate-700">
        <input
          type="checkbox"
          checked={ativo}
          onChange={(e) => setAtivo(e.target.checked)}
          disabled={salvando}
          className="h-4 w-4 rounded border-slate-300"
        />
        Ativo (aparece na lista de tipos ao criar um evento)
      </label>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Criar tipo"}
      </Button>
    </form>
  );
}
