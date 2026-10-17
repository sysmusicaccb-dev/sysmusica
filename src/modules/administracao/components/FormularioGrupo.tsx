"use client";

/**
 * SysMúsica — Formulário de grupo (novo ou edição), com a grade de permissões.
 * grupo = null  -> criar;  grupo preenchido -> editar.
 * O grupo protegido (Administrador) tem nome, status e permissões travados: só a descrição muda.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { atualizarGrupo, criarGrupo } from "../services/acesso";
import type { GrupoAcesso, PermissaoCatalogo } from "../tipos";
import MatrizPermissoes from "./MatrizPermissoes";

interface FormularioGrupoProps {
  grupo: GrupoAcesso | null;
  catalogo: PermissaoCatalogo[];
  /** Chamado após salvar com sucesso, com a mensagem para o aviso da tela. */
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:opacity-70";

export default function FormularioGrupo({ grupo, catalogo, onSalvo }: FormularioGrupoProps) {
  const editando = grupo !== null;
  const protegido = grupo?.sistema ?? false;

  const [nome, setNome] = useState(grupo?.nome ?? "");
  const [descricao, setDescricao] = useState(grupo?.descricao ?? "");
  const [ativo, setAtivo] = useState(grupo?.ativo ?? true);
  const [selecionadas, setSelecionadas] = useState<Set<string>>(() => new Set(grupo?.permissoes ?? []));
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    const nomeLimpo = nome.trim();
    if (nomeLimpo.length < 2 || nomeLimpo.length > 60) {
      setErro("O nome do grupo deve ter entre 2 e 60 caracteres.");
      return;
    }

    setSalvando(true);
    try {
      const permissoes = [...selecionadas];
      if (grupo) {
        await atualizarGrupo({ id: grupo.id, nome: nomeLimpo, descricao: descricao.trim(), ativo, permissoes });
        await onSalvo(`Grupo "${nomeLimpo}" atualizado.`);
      } else {
        await criarGrupo({ nome: nomeLimpo, descricao: descricao.trim(), permissoes });
        await onSalvo(`Grupo "${nomeLimpo}" criado.`);
      }
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar o grupo.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      {protegido && (
        <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
          Este grupo é protegido: ele sempre tem todas as permissões e não pode ser renomeado,
          desativado nem excluído. Só a descrição pode ser alterada.
        </p>
      )}

      <div className="space-y-1.5">
        <label htmlFor="nome-grupo" className="text-sm font-medium text-slate-700">
          Nome do grupo
        </label>
        <input
          id="nome-grupo"
          type="text"
          required
          maxLength={60}
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={salvando || protegido}
          placeholder="Ex: Secretaria"
          className={classeInput}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="descricao-grupo" className="text-sm font-medium text-slate-700">
          Descrição <span className="font-normal text-slate-400">(opcional)</span>
        </label>
        <textarea
          id="descricao-grupo"
          rows={2}
          maxLength={200}
          value={descricao}
          onChange={(e) => setDescricao(e.target.value)}
          disabled={salvando}
          placeholder="Para que serve este grupo"
          className={classeInput}
        />
      </div>

      {editando && (
        <label className="flex items-start gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={ativo}
            onChange={(e) => setAtivo(e.target.checked)}
            disabled={salvando || protegido}
            className="mt-0.5 h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300"
          />
          <span>
            Grupo ativo
            <span className="block text-xs text-slate-500">
              Usuários de um grupo inativo não conseguem acessar o sistema.
            </span>
          </span>
        </label>
      )}

      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <p className="text-sm font-medium text-slate-700">Permissões</p>
          <p className="text-xs text-slate-500">
            {protegido ? catalogo.length : selecionadas.size} de {catalogo.length} selecionadas
          </p>
        </div>
        <MatrizPermissoes
          catalogo={catalogo}
          selecionadas={
            protegido ? new Set(catalogo.map((permissao) => permissao.codigo)) : selecionadas
          }
          onAlterar={setSelecionadas}
          desabilitado={salvando || protegido}
        />
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Criar grupo"}
      </Button>
    </form>
  );
}
