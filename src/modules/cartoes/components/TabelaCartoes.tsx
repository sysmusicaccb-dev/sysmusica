/**
 * Sysmusica — Tabela da tela "Cartões a Vencer" (componente de apresentação).
 * Recebe a lista pronta do banco; a cor do selo mostra a urgência (vencido, a vencer, sem validade).
 */
import Badge from "@/components/ui/Badge";
import { ROTULO_SITUACAO, VARIANTE_SITUACAO, formatarValidade, textoPrazo } from "../regras";
import type { LinhaCartao } from "../tipos";

const classeCabecalho = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function TabelaCartoes({ itens }: { itens: LinhaCartao[] }) {
  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>Nome</th>
              <th scope="col" className={classeCabecalho}>Cargo</th>
              <th scope="col" className={classeCabecalho}>Casa de Oração</th>
              <th scope="col" className={classeCabecalho}>Nº do cartão</th>
              <th scope="col" className={classeCabecalho}>Validade</th>
              <th scope="col" className={classeCabecalho}>Situação</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {itens.map((item) => (
              <tr key={item.membro_id} className="transition hover:bg-slate-50">
                <td className="px-4 py-3 font-medium text-slate-900">{item.nome}</td>
                <td className="px-4 py-3 text-slate-800">{item.cargo_nome ?? "—"}</td>
                <td className="px-4 py-3 text-slate-800">{item.casa_nome ?? "—"}</td>
                <td className="px-4 py-3 tabular-nums text-slate-700">{item.cartao_numero ?? "—"}</td>
                <td className="whitespace-nowrap px-4 py-3 tabular-nums text-slate-700">{formatarValidade(item.cartao_validade)}</td>
                <td className="px-4 py-3">
                  <Badge variante={VARIANTE_SITUACAO[item.situacao]}>{ROTULO_SITUACAO[item.situacao]}</Badge>
                  <div className="mt-1 text-xs text-slate-500">{textoPrazo(item.situacao, item.dias)}</div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
