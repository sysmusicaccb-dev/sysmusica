"use client";

/**
 * SysMúsica — Tabela de usuários, com busca por nome/e-mail e filtro por grupo.
 * Ações por linha (só para quem tem usuarios.editar): editar, redefinir senha e ativar/desativar.
 * Ninguém desativa a própria conta por aqui (o banco também recusa).
 */
import { useState } from "react";
import { KeyRound, MapPin, Pencil, Power, Search } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { formatarDataHora } from "@/lib/datas";
import { normalizarTexto } from "@/lib/texto";
import type { GrupoAcesso, UsuarioSistema } from "../tipos";

interface TabelaUsuariosProps {
  usuarios: UsuarioSistema[];
  grupos: GrupoAcesso[];
  meuId: string | null;
  podeEditar: boolean;
  onEditar: (usuario: UsuarioSistema) => void;
  onRedefinirSenha: (usuario: UsuarioSistema) => void;
  onAlterarStatus: (usuario: UsuarioSistema) => void;
  cidadesPorUsuario: Record<string, string[]>; // abrangência: cidades em que cada usuário atua
  onAbrangencia: (usuario: UsuarioSistema) => void;
}

// Valor especial do filtro de grupo: usuários que ainda não têm grupo
const FILTRO_SEM_GRUPO = "sem-grupo";

const classeCabecalho =
  "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function TabelaUsuarios({
  usuarios,
  grupos,
  meuId,
  podeEditar,
  onEditar,
  onRedefinirSenha,
  onAlterarStatus,
  cidadesPorUsuario,
  onAbrangencia,
}: TabelaUsuariosProps) {
  const [busca, setBusca] = useState("");
  const [grupoFiltro, setGrupoFiltro] = useState(""); // "" = todos

  const termo = normalizarTexto(busca);
  const filtrados = usuarios.filter((usuario) => {
    const passaBusca =
      termo === "" ||
      normalizarTexto(usuario.nome).includes(termo) ||
      normalizarTexto(usuario.email).includes(termo);
    const passaGrupo =
      grupoFiltro === "" ||
      (grupoFiltro === FILTRO_SEM_GRUPO ? usuario.grupo_id === null : usuario.grupo_id === grupoFiltro);
    return passaBusca && passaGrupo;
  });

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      {/* Barra de ferramentas: busca + filtro por grupo */}
      <div className="flex flex-col gap-3 border-b border-slate-200 p-4 sm:flex-row sm:items-center">
        <div className="relative min-w-0 flex-1">
          <label htmlFor="busca-usuario" className="sr-only">
            Pesquisar por nome ou e-mail
          </label>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="busca-usuario"
            type="search"
            autoComplete="off"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Pesquisar por nome ou e-mail..."
            className="w-full rounded-lg border border-slate-300 bg-white py-2 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
          />
        </div>
        <div className="sm:w-52">
          <label htmlFor="filtro-grupo-usuario" className="sr-only">
            Filtrar por grupo
          </label>
          <select
            id="filtro-grupo-usuario"
            value={grupoFiltro}
            onChange={(e) => setGrupoFiltro(e.target.value)}
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
          >
            <option value="">Todos os grupos</option>
            {grupos.map((grupo) => (
              <option key={grupo.id} value={grupo.id}>
                {grupo.nome}
              </option>
            ))}
            <option value={FILTRO_SEM_GRUPO}>Sem grupo</option>
          </select>
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>
                Usuário
              </th>
              <th scope="col" className={classeCabecalho}>
                Grupo
              </th>
              <th scope="col" className={classeCabecalho}>
                Status
              </th>
              <th scope="col" className={classeCabecalho + " hidden md:table-cell"}>
                Último acesso
              </th>
              <th scope="col" className={classeCabecalho + " hidden lg:table-cell"}>
                Abrangência
              </th>
              {podeEditar && (
                <th scope="col" className={classeCabecalho + " text-right"}>
                  Ações
                </th>
              )}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filtrados.length === 0 ? (
              <tr>
                <td colSpan={podeEditar ? 6 : 5} className="px-4 py-10 text-center text-sm text-slate-500">
                  Nenhum usuário encontrado com os filtros atuais.
                </td>
              </tr>
            ) : (
              filtrados.map((usuario) => {
                const souEu = usuario.id === meuId;

                return (
                  <tr key={usuario.id} className="transition hover:bg-slate-50">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-100 text-sm font-bold text-brand-700">
                          {usuario.nome.charAt(0).toUpperCase()}
                        </div>
                        <div className="min-w-0">
                          <p className="truncate font-medium text-slate-900">
                            {usuario.nome}
                            {souEu && <span className="ml-2 text-xs font-normal text-slate-500">(você)</span>}
                          </p>
                          <p className="truncate text-xs text-slate-500">{usuario.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      {usuario.grupo_nome ? (
                        <Badge variante="marca">{usuario.grupo_nome}</Badge>
                      ) : (
                        <Badge variante="alerta">Sem grupo</Badge>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <Badge variante={usuario.ativo ? "sucesso" : "neutro"}>
                        {usuario.ativo ? "Ativo" : "Inativo"}
                      </Badge>
                    </td>
                    <td className="hidden px-4 py-3 text-slate-600 md:table-cell">
                      {usuario.ultimo_acesso ? formatarDataHora(usuario.ultimo_acesso) : "Nunca acessou"}
                    </td>
                    <td className="hidden max-w-[16rem] px-4 py-3 text-slate-600 lg:table-cell">
                      {(cidadesPorUsuario[usuario.id] ?? []).join(", ") || "—"}
                    </td>
                    {podeEditar && (
                      <td className="px-4 py-3">
                        <div className="flex justify-end gap-1">
                          <BotaoIcone
                            icone={Pencil}
                            rotulo={`Editar ${usuario.nome}`}
                            onClick={() => onEditar(usuario)}
                          />
                          <BotaoIcone
                            icone={KeyRound}
                            rotulo={`Redefinir a senha de ${usuario.nome}`}
                            onClick={() => onRedefinirSenha(usuario)}
                          />
                          <BotaoIcone
                            icone={MapPin}
                            rotulo={`Definir a abrangência de ${usuario.nome}`}
                            onClick={() => onAbrangencia(usuario)}
                          />
                          <BotaoIcone
                            icone={Power}
                            variante={usuario.ativo ? "perigo" : "padrao"}
                            rotulo={
                              souEu && usuario.ativo
                                ? "Você não pode desativar a sua própria conta"
                                : usuario.ativo
                                  ? `Desativar ${usuario.nome}`
                                  : `Ativar ${usuario.nome}`
                            }
                            disabled={souEu && usuario.ativo}
                            onClick={() => onAlterarStatus(usuario)}
                          />
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

      <div className="border-t border-slate-200 bg-slate-50 px-4 py-3 text-xs text-slate-500">
        Exibindo {filtrados.length} de {usuarios.length} usuário(s)
      </div>
    </div>
  );
}
