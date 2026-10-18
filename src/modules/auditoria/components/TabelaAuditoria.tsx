"use client";

/** SysMúsica — Tabela da Auditoria: quando, quem, o que fez e em qual item; o botão abre o antes e o depois. */
import { Eye } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { formatarDataHora } from "@/lib/datas";
import { resumoAlteracoes, rotuloAcao, rotuloDoItem } from "../regras";
import type { LinhaAuditoria } from "../tipos";

interface TabelaAuditoriaProps {
  linhas: LinhaAuditoria[];
  onDetalhes: (linha: LinhaAuditoria) => void;
}

const classeCabecalho = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function TabelaAuditoria({ linhas, onDetalhes }: TabelaAuditoriaProps) {
  return (
    <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
      <table className="min-w-full divide-y divide-slate-200 text-sm">
        <thead className="bg-slate-50">
          <tr>
            <th scope="col" className={classeCabecalho}>Quando</th>
            <th scope="col" className={classeCabecalho}>Quem</th>
            <th scope="col" className={classeCabecalho}>Ação</th>
            <th scope="col" className={classeCabecalho + " hidden md:table-cell"}>Item</th>
            <th scope="col" className={classeCabecalho + " text-right"}>Detalhes</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {linhas.map((linha) => {
            const resumo = resumoAlteracoes(linha.detalhes);
            return (
              <tr key={linha.id} className="align-top transition hover:bg-slate-50">
                <td className="whitespace-nowrap px-4 py-3 text-slate-700">{formatarDataHora(linha.ocorrido_em)}</td>
                <td className="px-4 py-3 text-slate-900">{linha.usuario_nome ?? "Sistema"}</td>
                <td className="px-4 py-3">
                  <Badge variante="neutro">{rotuloAcao(linha.acao)}</Badge>
                  {/* Telas pequenas: o item aparece aqui */}
                  <p className="mt-1 text-xs text-slate-500 md:hidden">{rotuloDoItem(linha)}</p>
                </td>
                <td className="hidden px-4 py-3 text-slate-700 md:table-cell">
                  {rotuloDoItem(linha)}
                  {resumo && <span className="block max-w-md truncate text-xs text-slate-500">{resumo}</span>}
                </td>
                <td className="px-4 py-3">
                  <div className="flex justify-end">
                    <BotaoIcone
                      icone={Eye}
                      rotulo={`Ver os detalhes: ${rotuloAcao(linha.acao)} em ${rotuloDoItem(linha)}`}
                      onClick={() => onDetalhes(linha)}
                    />
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
