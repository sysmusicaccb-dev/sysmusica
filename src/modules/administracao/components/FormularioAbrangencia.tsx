"use client";

/**
 * Sysmusica — Abrangência de atuação de um usuário (painel lateral).
 * REGRA PROVISÓRIA (aguarda definição administrativa): aprovar portarias e registrar presenças só
 * vale em portarias das cidades marcadas aqui. Sem nenhuma cidade, o usuário não atua em nenhuma.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { valoresDistintos } from "@/lib/listas";
import { normalizarTexto } from "@/lib/texto";
import { definirAbrangencia } from "../services/acesso";
import type { UsuarioSistema } from "../tipos";

interface FormularioAbrangenciaProps {
  usuario: UsuarioSistema;
  cidadesConhecidas: string[];
  selecionadasIniciais: string[];
  onSalvo: (mensagem: string) => void | Promise<void>;
}

export default function FormularioAbrangencia({
  usuario,
  cidadesConhecidas,
  selecionadasIniciais,
  onSalvo,
}: FormularioAbrangenciaProps) {
  // Cidades exibidas (conhecidas + já marcadas) e as marcadas (pela forma normalizada)
  const [lista, setLista] = useState<string[]>(() => valoresDistintos([...cidadesConhecidas, ...selecionadasIniciais]));
  const [marcadas, setMarcadas] = useState<Set<string>>(
    () => new Set(selecionadasIniciais.map((cidade) => normalizarTexto(cidade)))
  );
  const [novaCidade, setNovaCidade] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  function alternar(cidade: string) {
    const chave = normalizarTexto(cidade);
    setMarcadas((anterior) => {
      const novas = new Set(anterior);
      if (novas.has(chave)) novas.delete(chave);
      else novas.add(chave);
      return novas;
    });
  }

  // Inclui uma cidade nova na lista, já marcada
  function adicionar() {
    const limpa = novaCidade.trim().replace(/\s+/g, " ");
    if (!limpa) return;
    setLista((anterior) => valoresDistintos([...anterior, limpa]));
    setMarcadas((anterior) => new Set(anterior).add(normalizarTexto(limpa)));
    setNovaCidade("");
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);
    setSalvando(true);
    try {
      await definirAbrangencia(usuario.id, lista.filter((cidade) => marcadas.has(normalizarTexto(cidade))));
      await onSalvo(`Abrangência de "${usuario.nome}" atualizada.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar a abrangência.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
        <strong className="text-slate-900">{usuario.nome}</strong> só aprova portarias e registra presenças em
        portarias das cidades marcadas. Sem nenhuma cidade, não atua em nenhuma.
      </p>

      {lista.length === 0 ? (
        <p className="text-sm text-slate-500">
          Ainda não há cidades cadastradas. Informe a cidade abaixo (ela também aparece nos eventos).
        </p>
      ) : (
        <fieldset className="space-y-2">
          <legend className="text-sm font-medium text-slate-700">Cidades</legend>
          {lista.map((cidade) => (
            <label key={cidade} className="flex items-center gap-2 text-sm text-slate-700">
              <input
                type="checkbox"
                checked={marcadas.has(normalizarTexto(cidade))}
                onChange={() => alternar(cidade)}
                disabled={salvando}
                className="h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300"
              />
              {cidade}
            </label>
          ))}
        </fieldset>
      )}

      <div className="space-y-1.5">
        <label htmlFor="nova-cidade" className="text-sm font-medium text-slate-700">
          Adicionar cidade
        </label>
        <div className="flex gap-2">
          <input
            id="nova-cidade"
            type="text"
            maxLength={80}
            value={novaCidade}
            onChange={(e) => setNovaCidade(e.target.value)}
            onKeyDown={(e) => {
              // Enter adiciona a cidade (e não envia o formulário)
              if (e.key === "Enter") {
                e.preventDefault();
                adicionar();
              }
            }}
            disabled={salvando}
            placeholder="Ex: Lauro de Freitas"
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm placeholder:text-slate-400 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
          />
          <Button type="button" variante="secundario" onClick={adicionar} disabled={salvando || novaCidade.trim() === ""}>
            Adicionar
          </Button>
        </div>
        <p className="text-xs text-slate-500">
          Escreva a cidade como nos eventos (acentos e maiúsculas não importam).
        </p>
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : "Salvar abrangência"}
      </Button>
    </form>
  );
}
