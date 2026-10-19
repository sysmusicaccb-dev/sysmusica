/**
 * SysMúsica — "Resumo em tempo real" do painel ao vivo (componente de apresentação).
 * Total de participantes, os blocos Ministério, Músicos e Organistas (com as linhas de cada um) e o bloco
 * Instrumentos por família, com a quantidade e o percentual. Cada pessoa conta uma vez só no total; o bloco
 * Instrumentos é um recorte de quem toca e não soma de novo.
 */
import { Guitar, Keyboard, Music, Users, type LucideIcon } from "lucide-react";
import { agruparBlocos, montarFamilias } from "../regras";
import type { BlocoPainel, DadosPainel } from "../tipos";

const VISUAL_BLOCO: Record<BlocoPainel, { icone: LucideIcon; fundo: string; texto: string }> = {
  MINISTERIO: { icone: Users, fundo: "bg-blue-100", texto: "text-blue-700" },
  MUSICOS: { icone: Music, fundo: "bg-blue-100", texto: "text-blue-700" },
  ORGANISTAS: { icone: Keyboard, fundo: "bg-orange-100", texto: "text-orange-600" },
};

// Cor da bolinha de cada família no bloco Instrumentos
const COR_FAMILIA: Record<string, string> = {
  Cordas: "bg-amber-700",
  Madeiras: "bg-stone-700",
  Metais: "bg-yellow-500",
  Teclas: "bg-violet-500",
};

function CabecalhoDoBloco({
  icone: Icone,
  fundo,
  texto,
  titulo,
  total,
}: {
  icone: LucideIcon;
  fundo: string;
  texto: string;
  titulo: string;
  total: number;
}) {
  return (
    <div className="flex items-center justify-between px-4 py-3">
      <div className="flex items-center gap-2">
        <span className={`flex h-7 w-7 items-center justify-center rounded-full ${fundo} ${texto}`}>
          <Icone className="h-4 w-4" aria-hidden="true" />
        </span>
        <h3 className="text-sm font-semibold text-slate-900">{titulo}</h3>
      </div>
      <span className="text-xl font-bold tabular-nums text-slate-900">{total}</span>
    </div>
  );
}

export default function ResumoTempoReal({ dados }: { dados: DadosPainel }) {
  const blocos = agruparBlocos(dados.linhas);
  const { total: totalInstrumentos, familias } = montarFamilias(dados.instrumentos);

  return (
    <div className="mx-auto w-full max-w-md space-y-3">
      <h2 className="text-lg font-bold text-slate-900">Resumo em tempo real</h2>

      {/* Total de participantes (cada pessoa conta uma vez só) */}
      <section
        aria-label="Total de participantes"
        className="flex items-center gap-4 rounded-xl border border-slate-200 bg-white px-4 py-4 shadow-sm"
      >
        <span className="flex h-14 w-14 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-600">
          <Users className="h-8 w-8" aria-hidden="true" />
        </span>
        <div>
          <p className="text-sm font-medium text-slate-700">Total de participantes</p>
          <p className="text-4xl font-bold leading-tight tabular-nums text-slate-900">{dados.total}</p>
        </div>
      </section>

      {/* Ministério, Músicos e Organistas */}
      {blocos.map((bloco) => {
        const visual = VISUAL_BLOCO[bloco.bloco];
        return (
          <section
            key={bloco.bloco}
            aria-label={bloco.rotulo}
            className="rounded-xl border border-slate-200 bg-white shadow-sm"
          >
            <CabecalhoDoBloco {...visual} titulo={bloco.rotulo} total={bloco.total} />
            <ul className="divide-y divide-slate-100 border-t border-slate-100 px-4">
              {bloco.linhas.map((linha) => (
                <li key={linha.codigo} className="flex items-center justify-between py-1.5 text-sm">
                  <span className="text-slate-600">{linha.rotulo}</span>
                  <span className="font-medium tabular-nums text-slate-900">{linha.qtd}</span>
                </li>
              ))}
            </ul>
          </section>
        );
      })}

      {/* Instrumentos por família (recorte de quem toca; não soma ao total) */}
      <section aria-label="Instrumentos" className="rounded-xl border border-slate-200 bg-white shadow-sm">
        <CabecalhoDoBloco
          icone={Guitar}
          fundo="bg-emerald-100"
          texto="text-emerald-700"
          titulo="Instrumentos"
          total={totalInstrumentos}
        />
        <ul className="divide-y divide-slate-100 border-t border-slate-100 px-4">
          {familias.map((familia) => (
            <li key={familia.nome} className="flex items-center justify-between py-2 text-sm">
              <span className="flex items-center gap-2 text-slate-700">
                <span
                  className={`h-3 w-3 rounded-full ${COR_FAMILIA[familia.nome] ?? "bg-slate-400"}`}
                  aria-hidden="true"
                />
                {familia.nome}
              </span>
              <span className="tabular-nums text-slate-900">
                <span className="font-medium">{familia.qtd}</span>{" "}
                <span className="text-slate-500">({familia.percentual})</span>
              </span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
