"use client";

/**
 * SysMúsica — Escolha da portaria do atendimento. Lista as portarias aprovadas a que o usuário tem
 * acesso, das mais próximas do horário atual para as mais distantes. Se houver mais de uma no mesmo
 * horário, avisa para conferir o local antes de escolher.
 */
import { formatarDataHora } from "@/lib/datas";
import type { PortariaDetalhada } from "@/modules/portarias/tipos";

interface SelecaoPortariaProps {
  portarias: PortariaDetalhada[];
  onEscolher: (portariaId: string) => void;
}

export default function SelecaoPortaria({ portarias, onEscolher }: SelecaoPortariaProps) {
  // Há mais de uma portaria no mesmo horário?
  const contagemPorHorario = new Map<string, number>();
  for (const portaria of portarias) {
    const chave = portaria.evento_data ?? "";
    contagemPorHorario.set(chave, (contagemPorHorario.get(chave) ?? 0) + 1);
  }
  const haConcorrentes = [...contagemPorHorario.values()].some((quantidade) => quantidade > 1);

  return (
    <section className="space-y-4">
      <div>
        <h2 className="text-base font-semibold text-slate-900">Selecione a portaria do atendimento</h2>
        <p className="mt-1 text-sm text-slate-500">Depois de escolher, a leitura do QR Code já fica pronta.</p>
      </div>

      {haConcorrentes && (
        <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
          Há portarias no mesmo horário. Confira o local e a cidade antes de escolher.
        </p>
      )}

      <ul className="grid gap-3 sm:grid-cols-2">
        {portarias.map((portaria) => (
          <li key={portaria.id}>
            <button
              type="button"
              onClick={() => onEscolher(portaria.id)}
              className="w-full rounded-2xl border border-slate-200 bg-white p-4 text-left shadow-sm transition hover:border-brand-300 hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
            >
              <p className="text-sm font-semibold text-slate-900">
                {portaria.evento_data ? formatarDataHora(portaria.evento_data) : "Evento removido"}
              </p>
              <p className="mt-1 text-sm text-slate-700">
                {[portaria.evento_tipo, portaria.evento_finalidade].filter(Boolean).join(" · ")}
              </p>
              <p className="mt-1 text-xs text-slate-500">
                {[portaria.evento_local, portaria.cidade].filter(Boolean).join(" · ")}
              </p>
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}
