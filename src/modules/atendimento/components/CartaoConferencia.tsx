"use client";

/**
 * SysMúsica — Conferência de identidade antes de registrar a entrada (janela sobre a tela).
 * Mostra a fotografia e os dados do membro. Avisa quando não há foto, quando o cadastro está inativo
 * ou quando a entrada já foi registrada nesta portaria (nesses dois últimos casos não deixa registrar).
 * Quando a pessoa foi localizada pelo NOME, é preciso marcar que a identidade foi conferida.
 */
import { useState } from "react";
import Button from "@/components/ui/Button";
import FotoMembro from "@/modules/membros/components/FotoMembro";
import FotoNaConferencia from "./FotoNaConferencia";
import { horaCurta } from "../regras";
import type { CartaoMembro, OrigemEntrada } from "../tipos";

interface CartaoConferenciaProps {
  membro: CartaoMembro;
  origem: OrigemEntrada;
  registrando: boolean;
  erro: string | null;
  onConfirmar: () => void;
  onCancelar: () => void;
  /** Quem tem a permissão Fotografia pode tirar a foto na hora, se o membro ainda não tiver. */
  podeFoto?: boolean;
  onFotoSalva?: () => Promise<void>;
}

export default function CartaoConferencia({
  membro,
  origem,
  registrando,
  erro,
  onConfirmar,
  onCancelar,
  podeFoto = false,
  onFotoSalva,
}: CartaoConferenciaProps) {
  const [conferi, setConferi] = useState(false);
  const manual = origem === "MANUAL";
  const inativo = membro.status !== "Ativo";
  const jaRegistrado = membro.ja_registrado_em !== null;
  const podeConfirmar = !inativo && !jaRegistrado && !registrando && (!manual || conferi);

  const dados: { rotulo: string; valor: string | null }[] = [
    { rotulo: "Cargo", valor: membro.cargo },
    { rotulo: "Instrumento", valor: membro.instrumento },
    { rotulo: "Congregação", valor: membro.congregacao },
    { rotulo: "Localidade", valor: [membro.bairro, membro.cidade].filter(Boolean).join(", ") || null },
  ];

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-slate-900/60 p-4 sm:items-center"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-conferencia"
    >
      <div className="max-h-full w-full max-w-md overflow-y-auto rounded-2xl bg-white p-5 shadow-xl">
        <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
          {manual ? "Localizado pelo nome" : "QR Code lido"} · confira os dados
        </p>

        <div className="mt-4 flex flex-col items-center gap-4 sm:flex-row sm:items-start">
          <FotoMembro caminho={membro.foto_path} nome={membro.nome} tamanho="grande" />
          <div className="min-w-0 flex-1 text-center sm:text-left">
            <h2 id="titulo-conferencia" className="text-lg font-semibold text-slate-900">
              {membro.nome}
            </h2>
            <dl className="mt-2 space-y-1 text-sm">
              {dados.map((item) =>
                item.valor ? (
                  <div key={item.rotulo}>
                    <dt className="inline text-slate-500">{item.rotulo}: </dt>
                    <dd className="inline text-slate-900">{item.valor}</dd>
                  </div>
                ) : null
              )}
            </dl>
          </div>
        </div>

        {/* Avisos */}
        <div className="mt-4 space-y-2">
          {!membro.foto_path && (
            <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
              Este membro não tem fotografia cadastrada: confirme a identidade por outro meio.
            </p>
          )}
          {podeFoto && !membro.foto_path && onFotoSalva && (
            <FotoNaConferencia membroId={membro.membro_id} nome={membro.nome} onSalva={onFotoSalva} />
          )}
          {inativo && (
            <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
              O cadastro deste membro está inativo. A entrada não pode ser registrada.
            </p>
          )}
          {jaRegistrado && membro.ja_registrado_em && (
            <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
              Este membro já tem entrada registrada neste evento às {horaCurta(membro.ja_registrado_em)} (pode ser um registro antigo, de antes das portarias).
            </p>
          )}
          {erro && (
            <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
              {erro}
            </p>
          )}
        </div>

        {manual && !inativo && !jaRegistrado && (
          <label className="mt-4 flex items-start gap-2 text-sm text-slate-700">
            <input
              type="checkbox"
              checked={conferi}
              onChange={(e) => setConferi(e.target.checked)}
              disabled={registrando}
              className="mt-0.5 h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300"
            />
            Conferi a identidade da pessoa pela foto e pelos dados.
          </label>
        )}

        <div className="mt-5 flex flex-col gap-2 sm:flex-row-reverse">
          <Button type="button" onClick={onConfirmar} disabled={!podeConfirmar} className="w-full py-3 text-base">
            {registrando ? "Registrando..." : "Registrar entrada"}
          </Button>
          <button
            type="button"
            onClick={onCancelar}
            disabled={registrando}
            className="w-full rounded-lg border border-slate-300 bg-white px-4 py-3 text-base font-medium text-slate-700 transition hover:bg-slate-50 disabled:opacity-60"
          >
            {jaRegistrado || inativo ? "Fechar" : "Cancelar"}
          </button>
        </div>
      </div>
    </div>
  );
}
