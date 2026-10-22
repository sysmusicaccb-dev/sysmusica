"use client";

/**
 * Sysmusica — Tabela de grupos de acesso.
 * Ações por linha (só aparecem para quem tem a permissão): editar e excluir.
 * Excluir fica desabilitado (com o motivo na dica) para o grupo protegido e para grupos com usuários.
 */
import { Pencil, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import type { GrupoAcesso } from "../tipos";

interface TabelaGruposProps {
  grupos: GrupoAcesso[];
  totalPermissoes: number;
  podeEditar: boolean;
  podeExcluir: boolean;
  onEditar: (grupo: GrupoAcesso) => void;
  onExcluir: (grupo: GrupoAcesso) => void;
}

const classeCabecalho =
  "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function TabelaGrupos({
  grupos,
  totalPermissoes,
  podeEditar,
  podeExcluir,
  onEditar,
  onExcluir,
}: TabelaGruposProps) {
  const mostrarAcoes = podeEditar || podeExcluir;

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>
                Grupo
              </th>
              <th scope="col" className={classeCabecalho + " hidden md:table-cell"}>
                Descrição
              </th>
              <th scope="col" className={classeCabecalho}>
                Usuários
              </th>
              <th scope="col" className={classeCabecalho + " hidden sm:table-cell"}>
                Permissões
              </th>
              <th scope="col" className={classeCabecalho}>
                Status
              </th>
              {mostrarAcoes && (
                <th scope="col" className={classeCabecalho + " text-right"}>
                  Ações
                </th>
              )}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {grupos.map((grupo) => {
              // Motivo pelo qual a exclusão está indisponível (vazio = pode excluir)
              const motivoSemExcluir = grupo.sistema
                ? "grupo protegido"
                : grupo.qtd_usuarios > 0
                  ? "ainda tem usuários"
                  : "";

              return (
                <tr key={grupo.id} className="transition hover:bg-slate-50">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-slate-900">{grupo.nome}</span>
                      {grupo.sistema && <Badge variante="alerta">Protegido</Badge>}
                    </div>
                  </td>
                  <td className="hidden max-w-xs truncate px-4 py-3 text-slate-600 md:table-cell">
                    {grupo.descricao ?? "—"}
                  </td>
                  <td className="px-4 py-3 text-slate-700">{grupo.qtd_usuarios}</td>
                  <td className="hidden px-4 py-3 text-slate-700 sm:table-cell">
                    {grupo.sistema ? totalPermissoes : grupo.permissoes.length} de {totalPermissoes}
                  </td>
                  <td className="px-4 py-3">
                    <Badge variante={grupo.ativo ? "sucesso" : "neutro"}>
                      {grupo.ativo ? "Ativo" : "Inativo"}
                    </Badge>
                  </td>
                  {mostrarAcoes && (
                    <td className="px-4 py-3">
                      <div className="flex justify-end gap-1">
                        {podeEditar && (
                          <BotaoIcone
                            icone={Pencil}
                            rotulo={`Editar o grupo ${grupo.nome}`}
                            onClick={() => onEditar(grupo)}
                          />
                        )}
                        {podeExcluir && (
                          <BotaoIcone
                            icone={Trash2}
                            variante="perigo"
                            rotulo={
                              motivoSemExcluir
                                ? `Excluir indisponível: ${motivoSemExcluir}`
                                : `Excluir o grupo ${grupo.nome}`
                            }
                            disabled={motivoSemExcluir !== ""}
                            onClick={() => onExcluir(grupo)}
                          />
                        )}
                      </div>
                    </td>
                  )}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <div className="border-t border-slate-200 bg-slate-50 px-4 py-3 text-xs text-slate-500">
        {grupos.length} grupo(s)
      </div>
    </div>
  );
}
