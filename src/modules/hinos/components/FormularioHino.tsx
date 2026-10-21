"use client";

/**
 * SysMúsica — Formulário de hino/coro (novo ou edição) — conteúdo do painel lateral.
 * Hino do hinário aparece como "002"; coro (corinho) aparece como "Coro 2".
 * Se o hino já foi usado em algum ensaio, o banco não deixa trocar o número/categoria (só o título e o status).
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import {
  NUMERO_MAXIMO,
  NUMERO_MINIMO,
  TITULO_MAXIMO,
  formatarTitulo,
  rotuloHino,
  validarHino,
  type CategoriaHino,
  type Hino,
} from "../regras";
import { salvarHino } from "../services/hinos";

interface FormularioHinoProps {
  hino: Hino | null;
  hinos: Hino[]; // todos, para avisar de número repetido
  categoriaInicial: CategoriaHino;
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioHino({ hino, hinos, categoriaInicial, onSalvo }: FormularioHinoProps) {
  const editando = hino !== null;
  const [categoria, setCategoria] = useState<CategoriaHino>(hino?.categoria ?? categoriaInicial);
  const [numero, setNumero] = useState(hino ? String(hino.numero) : "");
  const [nome, setNome] = useState(hino?.nome ?? "");
  const [ativo, setAtivo] = useState(hino?.ativo ?? true);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const travado = editando && (hino?.em_uso ?? 0) > 0; // número e categoria não mudam se já foi usado

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return;
    setErro(null);

    const n = numero.trim() === "" ? null : Number(numero);
    const erroForm = validarHino({ categoria, numero: n, nome });
    if (erroForm) return setErro(erroForm);
    if (hinos.some((h) => h.id !== hino?.id && h.categoria === categoria && h.numero === n)) {
      return setErro(`Já existe ${categoria === "CORO" ? "o" : "o hino"} ${rotuloHino(categoria, n as number)} cadastrado.`);
    }

    setSalvando(true);
    try {
      await salvarHino(hino?.id ?? null, { categoria, numero: n as number, nome: formatarTitulo(nome), ativo });
      await onSalvo(`${rotuloHino(categoria, n as number)} ${editando ? "atualizado" : "cadastrado"}.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar o hino.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <label htmlFor="categoria-hino" className="text-sm font-medium text-slate-700">
            Categoria
          </label>
          <select
            id="categoria-hino"
            value={categoria}
            onChange={(e) => setCategoria(e.target.value as CategoriaHino)}
            disabled={salvando || travado}
            className={classeInput}
          >
            <option value="HINO">Hino</option>
            <option value="CORO">Coro (corinho)</option>
          </select>
        </div>
        <div className="space-y-1.5">
          <label htmlFor="numero-hino" className="text-sm font-medium text-slate-700">
            Número
          </label>
          <input
            id="numero-hino"
            type="number"
            inputMode="numeric"
            required
            min={NUMERO_MINIMO}
            max={NUMERO_MAXIMO}
            value={numero}
            onChange={(e) => setNumero(e.target.value)}
            disabled={salvando || travado}
            className={classeInput}
          />
        </div>
      </div>
      {travado && (
        <p className="text-xs text-slate-500">
          Este hino já foi usado em {hino?.em_uso} ensaio(s): só o título e o status podem ser alterados.
        </p>
      )}

      <div className="space-y-1.5">
        <label htmlFor="titulo-hino" className="text-sm font-medium text-slate-700">
          Título
        </label>
        <input
          id="titulo-hino"
          type="text"
          required
          maxLength={TITULO_MAXIMO}
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Oh! quão suave é confiar em Jesus"
          className={classeInput}
        />
      </div>

      <label className="flex items-center gap-2 text-sm text-slate-700">
        <input
          type="checkbox"
          checked={ativo}
          onChange={(e) => setAtivo(e.target.checked)}
          disabled={salvando}
          className="h-4 w-4 rounded border-slate-300"
        />
        Ativo (pode ser escolhido nos Dados do Ensaio)
      </label>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Cadastrar"}
      </Button>
    </form>
  );
}
