"use client";

/**
 * Sysmusica — Vínculos organizacionais de um usuário (painel lateral).
 * O usuário pode ser ligado a um estado, RRM, RA, ADM, setor ou casa de oração: o acesso desce em cascata (uma ADM
 * inclui todas as casas de oração dele). Sem nenhum vínculo, ele não vê nenhum dado (membros, eventos,
 * presenças e portarias). Quem tem acesso total não precisa de vínculo. Fica na auditoria.
 */
import { useState, type FormEvent, type ReactNode } from "react";
import Button from "@/components/ui/Button";
import { chaveVinculo, filhosDe, filhosDoNo, lerChaveVinculo, ROTULO_NIVEL } from "@/modules/organizacao/regras";
import { definirVinculos } from "@/modules/organizacao/services/organizacao";
import type { NoOrganizacao, VinculoRotulado, VinculoUsuario } from "@/modules/organizacao/tipos";
import type { UsuarioSistema } from "../tipos";

interface FormularioVinculosProps {
  usuario: UsuarioSistema;
  arvore: NoOrganizacao[];
  vinculosIniciais: VinculoRotulado[];
  onSalvo: (mensagem: string) => void | Promise<void>;
}

export default function FormularioVinculos({ usuario, arvore, vinculosIniciais, onSalvo }: FormularioVinculosProps) {
  const [marcados, setMarcados] = useState<Set<string>>(
    () => new Set(vinculosIniciais.map((vinculo) => chaveVinculo(vinculo.nivel, vinculo.alvo_id)))
  );
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  function alternar(chave: string) {
    setMarcados((anterior) => {
      const novos = new Set(anterior);
      if (novos.has(chave)) novos.delete(chave);
      else novos.add(chave);
      return novos;
    });
  }

  // Item com caixa de seleção e os filhos dele (inativos só aparecem se já estiverem marcados)
  function renderNo(no: NoOrganizacao, profundidade: number): ReactNode {
    const chave = chaveVinculo(no.nivel, no.id);
    if (no.ativo === false && !marcados.has(chave)) return null;
    const filhos = filhosDoNo(arvore, no); // na ADM: setores e casas de oração sem setor

    return (
      <li key={chave}>
        <label
          className="flex items-center gap-2 rounded py-1 text-sm text-slate-700 hover:bg-slate-50"
          style={{ paddingLeft: `${profundidade * 1.1}rem` }}
        >
          <input
            type="checkbox"
            checked={marcados.has(chave)}
            onChange={() => alternar(chave)}
            disabled={salvando}
            className="h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300"
          />
          <span className="text-xs uppercase tracking-wide text-slate-400">{ROTULO_NIVEL[no.nivel]}</span>
          <span className={no.ativo === false ? "text-slate-400" : "font-medium text-slate-900"}>
            {no.nome}
            {no.ativo === false ? " (inativo)" : ""}
          </span>
        </label>
        {filhos.length > 0 && <ul>{filhos.map((filho) => renderNo(filho, profundidade + 1))}</ul>}
      </li>
    );
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);
    setSalvando(true);
    try {
      const lista: VinculoUsuario[] = [...marcados].flatMap((chave) => {
        const vinculo = lerChaveVinculo(chave);
        return vinculo ? [vinculo] : [];
      });
      await definirVinculos(usuario.id, lista);
      await onSalvo(`Vínculos de "${usuario.nome}" atualizados.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar os vínculos.");
    } finally {
      setSalvando(false);
    }
  }

  const estados = filhosDe(arvore, null, "ESTADO");
  const semSetor = filhosDe(arvore, null, "CASA_ORACAO");

  return (
    <form onSubmit={salvar} className="space-y-5">
      <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
        <strong className="text-slate-900">{usuario.nome}</strong> só vê e usa os dados das áreas marcadas.
        Marcar um nível inclui tudo que está abaixo dele: a ADM inclui os setores e as casas de oração dela; a RA inclui
        as ADMs; a RRM inclui as RAs; o estado inclui tudo. Sem nenhuma marcação, não vê nada.
      </p>

      {arvore.length === 0 ? (
        <p className="text-sm text-slate-500">
          A organização ainda não foi carregada ou está vazia. Cadastre em Administração &gt; Organização.
        </p>
      ) : (
        <div className="max-h-96 overflow-y-auto rounded-lg border border-slate-200 p-3">
          <ul>{estados.map((estado) => renderNo(estado, 0))}</ul>
          {semSetor.length > 0 && (
            <div className="mt-3 border-t border-slate-100 pt-2">
              <p className="mb-1 text-xs font-semibold text-slate-500">Casas de Oração sem setor</p>
              <ul>{semSetor.map((casaOracao) => renderNo(casaOracao, 0))}</ul>
            </div>
          )}
        </div>
      )}

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : "Salvar vínculos"}
      </Button>
    </form>
  );
}
