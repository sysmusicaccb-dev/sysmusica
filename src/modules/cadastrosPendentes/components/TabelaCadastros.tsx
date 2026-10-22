"use client";

/**
 * Sysmusica — Lista de cadastros enviados pelo link público. Clicar em "Abrir" mostra o detalhe.
 * O CPF aparece escondido (***.123.***-45); o completo só no detalhe, para quem tem a permissão CPF.
 */
import { Eye } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { ROTULO_STATUS, ROTULO_TIPO, VARIANTE_STATUS, diasParaVencer, formatarDataHora } from "../regras";
import type { ResumoCadastro } from "../tipos";

const classeCabecalho = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function TabelaCadastros({ itens, onAbrir }: { itens: ResumoCadastro[]; onAbrir: (item: ResumoCadastro) => void }) {
  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>Nome</th>
              <th scope="col" className={classeCabecalho}>Cargo</th>
              <th scope="col" className={classeCabecalho}>Casa de Oração</th>
              <th scope="col" className={classeCabecalho}>Tipo</th>
              <th scope="col" className={classeCabecalho}>Enviado em</th>
              <th scope="col" className={classeCabecalho}>Situação</th>
              <th scope="col" className={classeCabecalho + " text-right"}>Ações</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {itens.map((item) => (
              <tr key={item.id} className="transition hover:bg-slate-50">
                <td className="px-4 py-3">
                  <div className="font-medium text-slate-900">{item.nome ?? "(dados removidos)"}</div>
                  <div className="text-xs tabular-nums text-slate-500">{item.cpf_mascarado ?? ""}</div>
                  <div className="mt-1 flex flex-wrap gap-1">
                    {item.menor && <Badge variante="marca">Menor de idade</Badge>}
                    {item.cpf_conflito && <Badge variante="perigo">CPF com outra data de nascimento</Badge>}
                    {item.outros_pendentes > 0 && <Badge variante="alerta">{item.outros_pendentes} outro(s) pedido(s) com este CPF</Badge>}
                  </div>
                </td>
                <td className="px-4 py-3 text-slate-800">{item.cargo_nome ?? "—"}</td>
                <td className="px-4 py-3 text-slate-800">
                  {item.casa_nome ?? "—"}
                  {item.casa_nao_cadastrada && (
                    <div className="mt-1">
                      <Badge variante="alerta">Casa não cadastrada</Badge>
                    </div>
                  )}
                </td>
                <td className="px-4 py-3 text-slate-800">{ROTULO_TIPO[item.tipo]}</td>
                <td className="whitespace-nowrap px-4 py-3 tabular-nums text-slate-700">
                  {formatarDataHora(item.criado_em)}
                  {item.status === "PENDENTE" && (
                    <div className="text-xs text-slate-500">vence em {diasParaVencer(item.expira_em)} dia(s)</div>
                  )}
                </td>
                <td className="px-4 py-3">
                  <Badge variante={VARIANTE_STATUS[item.status]}>{ROTULO_STATUS[item.status]}</Badge>
                </td>
                <td className="px-4 py-3">
                  <div className="flex justify-end">
                    <BotaoIcone icone={Eye} rotulo={`Abrir o cadastro de ${item.nome ?? "pessoa sem nome"}`} onClick={() => onAbrir(item)} />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
