"use client";

/**
 * Sysmusica — Formulário de edição de uma presença da portaria (conteúdo do painel lateral).
 * O membro e o evento são só informativos (não mudam: para outro membro ou evento, exclua e
 * registre de novo). Editáveis: status e, quando "Presente", as horas de entrada e saída.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { datetimeLocalParaIso, isoParaDatetimeLocal } from "@/lib/dataLocal";
import type { Presenca } from "@/types/database";
import { STATUS_PRESENCA, validarHorarios } from "../regras";
import { atualizarPresenca } from "../services/portaria";

interface FormularioEdicaoPresencaProps {
  presenca: Presenca;
  nomeMembro: string;
  descricaoEvento: string;
  /** Chamado após salvar com sucesso, com a mensagem para o aviso da tela. */
  onSalvo: (mensagem: string) => void | Promise<void>;
}

// Mesma identidade visual dos demais formulários.
// [color-scheme:light] mantém o ícone do seletor de data visível mesmo com o navegador em tema escuro.
const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 " +
  "disabled:cursor-not-allowed disabled:opacity-60 [color-scheme:light]";

export default function FormularioEdicaoPresenca({
  presenca,
  nomeMembro,
  descricaoEvento,
  onSalvo,
}: FormularioEdicaoPresencaProps) {
  const [status, setStatus] = useState(presenca.status);
  const [entrada, setEntrada] = useState(isoParaDatetimeLocal(presenca.hora_entrada));
  const [saida, setSaida] = useState(presenca.hora_saida ? isoParaDatetimeLocal(presenca.hora_saida) : "");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  // Os horários só importam para quem esteve presente
  const mostrarHorarios = status === "Presente";

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    if (mostrarHorarios) {
      const erroHorarios = validarHorarios(entrada, saida);
      if (erroHorarios) return setErro(erroHorarios);
    }

    setSalvando(true);
    try {
      // Se não é "Presente", mantém os horários como estavam (não foram editados)
      await atualizarPresenca(presenca.id, {
        status,
        hora_entrada: mostrarHorarios
          ? (datetimeLocalParaIso(entrada) ?? presenca.hora_entrada)
          : presenca.hora_entrada,
        hora_saida: mostrarHorarios
          ? saida.trim() === ""
            ? null
            : datetimeLocalParaIso(saida)
          : presenca.hora_saida,
      });
      await onSalvo(`Presença de "${nomeMembro}" atualizada.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar a presença.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      {/* Identificação (somente leitura) */}
      <div className="rounded-xl bg-slate-50 px-4 py-3 text-sm">
        <p className="font-medium text-slate-900">{nomeMembro}</p>
        <p className="mt-0.5 text-slate-600">{descricaoEvento}</p>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="status-presenca" className="text-sm font-medium text-slate-700">
          Status
        </label>
        <select
          id="status-presenca"
          value={status}
          onChange={(e) => setStatus(e.target.value)}
          disabled={salvando}
          className={classeInput}
        >
          {STATUS_PRESENCA.map((opcao) => (
            <option key={opcao} value={opcao}>
              {opcao}
            </option>
          ))}
        </select>
      </div>

      {mostrarHorarios && (
        <>
          <div className="space-y-1.5">
            <label htmlFor="hora-entrada" className="text-sm font-medium text-slate-700">
              Hora de entrada
            </label>
            <input
              id="hora-entrada"
              type="datetime-local"
              required
              value={entrada}
              onChange={(e) => setEntrada(e.target.value)}
              disabled={salvando}
              className={classeInput}
            />
          </div>

          <div className="space-y-1.5">
            <label htmlFor="hora-saida" className="text-sm font-medium text-slate-700">
              Hora de saída <span className="font-normal text-slate-400">(opcional)</span>
            </label>
            <input
              id="hora-saida"
              type="datetime-local"
              value={saida}
              onChange={(e) => setSaida(e.target.value)}
              disabled={salvando}
              className={classeInput}
            />
            <p className="text-xs text-slate-500">Deixe em branco se o membro ainda não saiu.</p>
          </div>
        </>
      )}

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : "Salvar alterações"}
      </Button>
    </form>
  );
}
