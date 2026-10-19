"use client";

/**
 * SysMúsica — Formulário de um item da organização (estado, região, setor ou casa de oração), novo ou em edição.
 * Em item novo, o "pai" (estado, região ou setor) vem de onde o botão + foi clicado. Para mudar uma
 * casa de oração de setor use a transferência (fica registrada). O banco confere permissão e nomes repetidos.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { ROTULO_NIVEL, validarNomeNo } from "../regras";
import { salvarNo } from "../services/organizacao";
import type { NivelOrganizacao, NoOrganizacao } from "../tipos";

export type ModoNo =
  | { tipo: "novo"; nivel: NivelOrganizacao; pai: NoOrganizacao | null }
  | { tipo: "editar"; no: NoOrganizacao };

interface FormularioNoProps {
  modo: ModoNo;
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 " +
  "shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60";

export default function FormularioNo({ modo, onSalvo }: FormularioNoProps) {
  const editando = modo.tipo === "editar";
  const nivel = modo.tipo === "novo" ? modo.nivel : modo.no.nivel;
  const atual = modo.tipo === "editar" ? modo.no : null;

  const [nome, setNome] = useState(atual?.nome ?? "");
  const [descricao, setDescricao] = useState(atual?.descricao ?? "");
  const [cidade, setCidade] = useState(atual?.cidade ?? "");
  const [bairro, setBairro] = useState(atual?.bairro ?? "");
  const [ativo, setAtivo] = useState(atual?.ativo !== false);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    const erroNome = validarNomeNo(nome);
    if (erroNome) return setErro(erroNome);

    const paiId = modo.tipo === "novo" ? (modo.pai?.id ?? null) : (atual?.parent_id ?? null);

    setSalvando(true);
    try {
      await salvarNo({
        nivel,
        id: atual?.id ?? null,
        paiId,
        nome: nome.trim(),
        descricao,
        ativo,
        cidade,
        bairro,
      });
      await onSalvo(`${ROTULO_NIVEL[nivel]} "${nome.trim()}" ${editando ? "atualizado(a)" : "cadastrado(a)"}.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      {modo.tipo === "novo" && modo.pai && (
        <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
          {ROTULO_NIVEL[nivel]} dentro de <strong className="text-slate-900">{modo.pai.nome}</strong>.
        </p>
      )}

      <div className="space-y-1.5">
        <label htmlFor="nome-no" className="text-sm font-medium text-slate-700">
          Nome
        </label>
        <input
          id="nome-no"
          type="text"
          required
          maxLength={80}
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={salvando}
          placeholder={nivel === "SETOR" ? "Ex: Setor 6" : nivel === "CASA_ORACAO" ? "Ex: Central Itinga" : "Nome"}
          className={classeInput}
        />
      </div>

      {nivel !== "CASA_ORACAO" && (
        <div className="space-y-1.5">
          <label htmlFor="descricao-no" className="text-sm font-medium text-slate-700">
            Descrição <span className="font-normal text-slate-400">(opcional)</span>
          </label>
          <input
            id="descricao-no"
            type="text"
            maxLength={200}
            value={descricao}
            onChange={(e) => setDescricao(e.target.value)}
            disabled={salvando}
            className={classeInput}
          />
        </div>
      )}

      {nivel === "CASA_ORACAO" && (
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-1.5">
            <label htmlFor="cidade-no" className="text-sm font-medium text-slate-700">
              Cidade <span className="font-normal text-slate-400">(opcional)</span>
            </label>
            <input
              id="cidade-no"
              type="text"
              maxLength={80}
              value={cidade}
              onChange={(e) => setCidade(e.target.value)}
              disabled={salvando}
              className={classeInput}
            />
          </div>
          <div className="space-y-1.5">
            <label htmlFor="bairro-no" className="text-sm font-medium text-slate-700">
              Bairro <span className="font-normal text-slate-400">(opcional)</span>
            </label>
            <input
              id="bairro-no"
              type="text"
              maxLength={80}
              value={bairro}
              onChange={(e) => setBairro(e.target.value)}
              disabled={salvando}
              className={classeInput}
            />
          </div>
        </div>
      )}

      {editando && (
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={ativo}
            onChange={(e) => setAtivo(e.target.checked)}
            disabled={salvando}
            className="h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300"
          />
          Ativo (inativo deixa de aparecer nas escolhas e bloqueia o acesso por esse item)
        </label>
      )}

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : editando ? "Salvar alterações" : `Cadastrar ${ROTULO_NIVEL[nivel].toLowerCase()}`}
      </Button>
    </form>
  );
}
