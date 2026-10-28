"use client";

/**
 * Sysmusica — Lista de perfis de evento (cartão com tabela): editar, duplicar e excluir (lixeira).
 * Perfil usado por algum tipo de evento não pode ser excluído; o banco confere de novo.
 */
import { Copy, Pencil, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { cn } from "@/lib/cn";
import { rotuloDoModelo } from "@/modules/tiposEvento/regras";
import { motivoNaoExcluir, type PerfilEvento } from "../regras";

interface TabelaPerfisProps {
  perfis: PerfilEvento[];
  podeCriar: boolean; // duplicar
  podeEditar: boolean;
  podeExcluir: boolean;
  ocupadoId: string | null; // perfil com uma ação em andamento (trava os botões)
  onEditar: (perfil: PerfilEvento) => void;
  onDuplicar: (perfil: PerfilEvento) => void;
  onExcluir: (perfil: PerfilEvento) => void;
}

const classeCabecalho = "px-4 py-3 text-left text-sm font-semibold text-slate-800";

export default function TabelaPerfis({ perfis, podeCriar, podeEditar, podeExcluir, ocupadoId, onEditar, onDuplicar, onExcluir }: TabelaPerfisProps) {
  const mostrarAcoes = podeCriar || podeEditar || podeExcluir;
  const colunas = mostrarAcoes ? 6 : 5;

  return (
    <section className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={cn(classeCabecalho, "w-14")}>N°</th>
              <th scope="col" className={classeCabecalho}>Perfil</th>
              <th scope="col" className={classeCabecalho}>Descrição</th>
              <th scope="col" className={classeCabecalho}>Comportamento base</th>
              <th scope="col" className={classeCabecalho}>Status</th>
              {mostrarAcoes && <th scope="col" className={cn(classeCabecalho, "text-center")}>Ações</th>}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {perfis.length === 0 ? (
              <tr>
                <td colSpan={colunas} className="px-4 py-10 text-center text-sm text-slate-500">
                  Nenhum perfil de evento cadastrado.
                </td>
              </tr>
            ) : (
              perfis.map((perfil, indice) => {
                const bloqueio = motivoNaoExcluir(perfil);
                const ocupado = ocupadoId === perfil.id;
                return (
                  <tr key={perfil.id} className="transition hover:bg-slate-50">
                    <td className="px-4 py-3 tabular-nums text-slate-600">{indice + 1}</td>
                    <td className="px-4 py-3">
                      <p className="font-medium text-slate-900">{perfil.nome}</p>
                      <p className="text-xs text-slate-500">
                        {perfil.em_uso === 0 ? "Sem tipos de evento ligados" : `Usado por ${perfil.em_uso} tipo(s) de evento`}
                      </p>
                    </td>
                    <td className="px-4 py-3 text-slate-600">{perfil.descricao ?? "—"}</td>
                    <td className="px-4 py-3">
                      <Badge variante="marca">{rotuloDoModelo(perfil.modelo_base)}</Badge>
                    </td>
                    <td className="px-4 py-3">
                      <Badge variante={perfil.ativo ? "sucesso" : "neutro"}>{perfil.ativo ? "Ativo" : "Inativo"}</Badge>
                    </td>
                    {mostrarAcoes && (
                      <td className="px-4 py-3">
                        <div className="flex items-center justify-center gap-1">
                          {podeEditar && (
                            <BotaoIcone icone={Pencil} rotulo={`Editar ${perfil.nome}`} disabled={ocupado} onClick={() => onEditar(perfil)} />
                          )}
                          {podeCriar && (
                            <BotaoIcone icone={Copy} rotulo={`Duplicar ${perfil.nome}`} disabled={ocupado} onClick={() => onDuplicar(perfil)} />
                          )}
                          {podeExcluir && (
                            <BotaoIcone
                              icone={Trash2}
                              variante="perigo"
                              rotulo={bloqueio ?? `Excluir ${perfil.nome}`}
                              disabled={ocupado || bloqueio !== null}
                              onClick={() => onExcluir(perfil)}
                            />
                          )}
                        </div>
                      </td>
                    )}
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
      <p className="border-t border-slate-200 px-4 py-3 text-sm text-slate-600">Total: {perfis.length} perfil(is) de evento</p>
    </section>
  );
}
