/** Sysmusica — Detalhe de um registro da Auditoria (painel lateral): quando, quem, o quê e o antes e o depois. */
import { formatarDataHora } from "@/lib/datas";
import { descreverDetalhes, rotuloAcao, rotuloDoItem } from "../regras";
import type { LinhaAuditoria } from "../tipos";

export default function DetalheAuditoria({ linha }: { linha: LinhaAuditoria }) {
  const itens = descreverDetalhes(linha.detalhes);

  return (
    <div className="space-y-5">
      <dl className="space-y-1 rounded-xl bg-slate-50 px-4 py-3 text-sm">
        <div className="flex justify-between gap-3">
          <dt className="text-slate-500">Quando</dt>
          <dd className="text-right text-slate-900">{formatarDataHora(linha.ocorrido_em)}</dd>
        </div>
        <div className="flex justify-between gap-3">
          <dt className="text-slate-500">Quem</dt>
          <dd className="text-right text-slate-900">{linha.usuario_nome ?? "Sistema"}</dd>
        </div>
        <div className="flex justify-between gap-3">
          <dt className="text-slate-500">Ação</dt>
          <dd className="text-right text-slate-900">{rotuloAcao(linha.acao)}</dd>
        </div>
        <div className="flex justify-between gap-3">
          <dt className="text-slate-500">Item</dt>
          <dd className="text-right text-slate-900">{rotuloDoItem(linha)}</dd>
        </div>
        {linha.entidade_id && (
          <div className="flex justify-between gap-3">
            <dt className="text-slate-500">Identificador</dt>
            <dd className="break-all text-right text-xs text-slate-600">{linha.entidade_id}</dd>
          </div>
        )}
      </dl>

      {itens.length === 0 ? (
        <p className="text-sm text-slate-500">Sem detalhes registrados para esta ação.</p>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-slate-200">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
              <tr>
                <th scope="col" className="px-3 py-2 text-left">Campo</th>
                <th scope="col" className="px-3 py-2 text-left">Antes</th>
                <th scope="col" className="px-3 py-2 text-left">Depois</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {itens.map((item, indice) => (
                <tr key={`${item.campo}-${indice}`} className="align-top">
                  <td className="px-3 py-2 font-medium text-slate-900">{item.campo}</td>
                  <td className="px-3 py-2 text-slate-600">{item.de ?? "—"}</td>
                  <td className="px-3 py-2 text-slate-900">{item.para ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <p className="text-xs text-slate-500">
        Identificadores aparecem abreviados. CPF e QR Code nunca são gravados na auditoria.
      </p>
    </div>
  );
}
