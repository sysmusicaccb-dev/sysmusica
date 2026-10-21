"use client";

/**
 * SysMúsica — Transferência de uma casa de oração para outro local (painel lateral).
 * O destino é uma ADM (a casa fica sem setor) ou um setor de uma ADM. Exige a permissão de transferir; fica no
 * histórico da casa de oração e na auditoria. As portarias da casa de oração passam a valer para o destino novo
 * (elas seguem a casa de oração do evento).
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { agruparDestinosTransferencia, ancestraisDe } from "../regras";
import { transferirCasaOracao } from "../services/organizacao";
import type { NoOrganizacao } from "../tipos";

interface FormularioTransferenciaProps {
  casaOracao: NoOrganizacao;
  nos: NoOrganizacao[];
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 " +
  "shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60";

export default function FormularioTransferencia({ casaOracao, nos, onSalvo }: FormularioTransferenciaProps) {
  const [destinoId, setDestinoId] = useState("");
  const [justificativa, setJustificativa] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const grupos = agruparDestinosTransferencia(nos);
  // Onde a casa está agora (ADM e, se tiver, setor): "Ipiaú › Setor 1" ou só "Ipiaú"
  const localAtual = ancestraisDe(nos, casaOracao)
    .filter((no) => no.nivel === "ADM" || no.nivel === "SETOR")
    .map((no) => no.nome)
    .join(" › ");

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);
    if (!destinoId) return setErro("Escolha o destino (ADM ou setor).");

    setSalvando(true);
    try {
      await transferirCasaOracao(casaOracao.id, destinoId, justificativa);
      await onSalvo(`Casa de Oração "${casaOracao.nome}" transferida.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível transferir a casa de oração.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
        <strong className="text-slate-900">{casaOracao.nome}</strong>
        {localAtual ? <> está em {localAtual}.</> : <> ainda não tem local definido.</>}
      </p>

      <div className="space-y-1.5">
        <label htmlFor="destino-transferencia" className="text-sm font-medium text-slate-700">
          Destino
        </label>
        <select
          id="destino-transferencia"
          value={destinoId}
          onChange={(e) => setDestinoId(e.target.value)}
          disabled={salvando}
          className={classeInput}
        >
          <option value="">Selecione a ADM ou o setor</option>
          {grupos.map((grupo) => (
            <optgroup key={grupo.rotulo} label={grupo.rotulo}>
              {grupo.opcoes.map((opcao) => (
                <option key={opcao.id} value={opcao.id}>
                  {opcao.nome}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
        <p className="text-xs text-slate-500">
          “Sem setor” deixa a casa ligada direto à ADM. O setor é opcional.
        </p>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="justificativa-transferencia" className="text-sm font-medium text-slate-700">
          Justificativa <span className="font-normal text-slate-400">(opcional)</span>
        </label>
        <textarea
          id="justificativa-transferencia"
          rows={3}
          maxLength={300}
          value={justificativa}
          onChange={(e) => setJustificativa(e.target.value)}
          disabled={salvando}
          className={classeInput}
        />
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Transferindo..." : "Transferir casa de oração"}
      </Button>
    </form>
  );
}
