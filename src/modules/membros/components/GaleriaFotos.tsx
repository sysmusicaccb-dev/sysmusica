"use client";

/**
 * SysMúsica — Lista de membros com a situação da fotografia (busca e filtro) e as ações de enviar,
 * trocar e remover. O envio e a remoção são feitos pela página; aqui só há a interface.
 */
import { useRef, useState, type ChangeEvent } from "react";
import { Search, Trash2, User } from "lucide-react";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { cn } from "@/lib/cn";
import { normalizarTexto } from "@/lib/texto";
import type { MembroFoto } from "../services/fotos";

interface GaleriaFotosProps {
  membros: MembroFoto[];
  urls: Record<string, string>; // caminho da foto -> URL temporária
  ocupadoId: string | null; // membro cujo envio/remoção está em andamento
  onEscolherArquivo: (membro: MembroFoto, arquivo: File) => void;
  onRemover: (membro: MembroFoto) => void;
}

type Filtro = "todos" | "sem" | "com";

const classeCampo =
  "rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200";

export default function GaleriaFotos({ membros, urls, ocupadoId, onEscolherArquivo, onRemover }: GaleriaFotosProps) {
  const [busca, setBusca] = useState("");
  const [filtro, setFiltro] = useState<Filtro>("todos");
  // Um único seletor de arquivo para a lista inteira; o membro-alvo fica guardado até a escolha
  const entradaRef = useRef<HTMLInputElement>(null);
  const alvoRef = useRef<MembroFoto | null>(null);

  const termo = normalizarTexto(busca);
  const filtrados = membros.filter((membro) => {
    const passaFiltro = filtro === "todos" || (filtro === "sem" ? !membro.foto_path : !!membro.foto_path);
    const texto = normalizarTexto(`${membro.nome} ${membro.congregacao ?? ""}`);
    return passaFiltro && (termo === "" || texto.includes(termo));
  });
  const semFoto = membros.filter((membro) => !membro.foto_path).length;

  function escolher(membro: MembroFoto) {
    alvoRef.current = membro;
    entradaRef.current?.click();
  }

  function aoSelecionar(evento: ChangeEvent<HTMLInputElement>) {
    const arquivo = evento.target.files?.[0];
    evento.target.value = ""; // permite escolher o mesmo arquivo de novo
    if (arquivo && alvoRef.current) onEscolherArquivo(alvoRef.current, arquivo);
  }

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <input
        ref={entradaRef}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="sr-only"
        tabIndex={-1}
        aria-hidden="true"
        onChange={aoSelecionar}
      />

      <div className="flex flex-col gap-3 border-b border-slate-200 p-4 sm:flex-row sm:items-center">
        <div className="relative min-w-0 flex-1">
          <label htmlFor="busca-foto" className="sr-only">
            Pesquisar membros
          </label>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="busca-foto"
            type="search"
            autoComplete="off"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Pesquisar por nome ou congregação..."
            className={classeCampo + " w-full pl-9 placeholder:text-slate-400"}
          />
        </div>
        <div className="sm:w-56">
          <label htmlFor="filtro-foto" className="sr-only">
            Filtrar por fotografia
          </label>
          <select
            id="filtro-foto"
            value={filtro}
            onChange={(e) => setFiltro(e.target.value as Filtro)}
            className={classeCampo + " w-full"}
          >
            <option value="todos">Todos os membros</option>
            <option value="sem">Sem fotografia ({semFoto})</option>
            <option value="com">Com fotografia</option>
          </select>
        </div>
      </div>

      <ul className="divide-y divide-slate-100">
        {filtrados.length === 0 ? (
          <li className="px-4 py-10 text-center text-sm text-slate-500">Nenhum membro encontrado.</li>
        ) : (
          filtrados.map((membro) => {
            const url = membro.foto_path ? urls[membro.foto_path] : undefined;
            const ocupado = ocupadoId === membro.id;
            return (
              <li key={membro.id} className="flex items-center gap-3 px-4 py-3">
                <div
                  role="img"
                  aria-label={url ? `Fotografia de ${membro.nome}` : `${membro.nome}: sem fotografia`}
                  style={url ? { backgroundImage: `url(${url})` } : undefined}
                  className="flex h-14 w-12 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-slate-100 bg-cover bg-center text-slate-400"
                >
                  {!url && <User className="h-5 w-5" aria-hidden="true" />}
                </div>

                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium text-slate-900">{membro.nome}</p>
                  <p className="truncate text-xs text-slate-500">{membro.congregacao ?? "—"}</p>
                  <p className={cn("text-xs", membro.foto_path ? "text-emerald-700" : "text-amber-700")}>
                    {ocupado ? "Enviando..." : membro.foto_path ? "Com fotografia" : "Sem fotografia"}
                  </p>
                </div>

                <div className="flex shrink-0 items-center gap-1">
                  <button
                    type="button"
                    onClick={() => escolher(membro)}
                    disabled={ocupadoId !== null}
                    className="rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    {membro.foto_path ? "Trocar foto" : "Adicionar foto"}
                  </button>
                  {membro.foto_path && (
                    <BotaoIcone
                      icone={Trash2}
                      rotulo={`Remover a fotografia de ${membro.nome}`}
                      onClick={() => onRemover(membro)}
                    />
                  )}
                </div>
              </li>
            );
          })
        )}
      </ul>

      <div className="border-t border-slate-200 bg-slate-50 px-4 py-3 text-xs text-slate-500">
        Exibindo {filtrados.length} de {membros.length} membro(s) · {semFoto} sem fotografia
      </div>
    </div>
  );
}
