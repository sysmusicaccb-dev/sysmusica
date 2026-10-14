/**
 * SysMúsica — Lista de eventos (componente de apresentação).
 *
 * Não acessa o banco: recebe os dados e os estados (loading/erro) da página.
 * Trata quatro cenários: carregando, erro, lista vazia e lista com dados.
 */
import type { Evento } from "@/types/database";

interface ListaEventosProps {
  eventos: Evento[];
  carregando: boolean;
  erro: string | null;
  onTentarNovamente: () => void;
}

// Cor do selo conforme o tipo do evento (tipos desconhecidos usam o cinza padrão)
function classeTipo(tipo: string): string {
  const normalizado = tipo.trim().toLowerCase();
  if (normalizado === "ensaio") return "bg-indigo-100 text-indigo-700";
  if (normalizado === "culto") return "bg-amber-100 text-amber-700";
  return "bg-slate-100 text-slate-600";
}

export default function ListaEventos({
  eventos,
  carregando,
  erro,
  onTentarNovamente,
}: ListaEventosProps) {
  // 1) Carregando: placeholders animados (skeleton)
  if (carregando) {
    return (
      <div role="status" aria-live="polite" className="grid gap-3">
        <span className="sr-only">Carregando eventos...</span>
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="h-24 animate-pulse rounded-2xl bg-slate-200" />
        ))}
      </div>
    );
  }

  // 2) Erro na comunicação com o banco
  if (erro) {
    return (
      <div role="alert" className="rounded-2xl border border-red-200 bg-red-50 p-6">
        <p className="font-semibold text-red-800">Não foi possível carregar os eventos.</p>
        <p className="mt-1 text-sm text-red-700">{erro}</p>
        <button
          type="button"
          onClick={onTentarNovamente}
          className="mt-4 rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-red-500"
        >
          Tentar novamente
        </button>
      </div>
    );
  }

  // 3) Nenhum evento cadastrado
  if (eventos.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center">
        <p className="font-medium text-slate-700">Nenhum evento cadastrado ainda.</p>
        <p className="mt-1 text-sm text-slate-500">Use o formulário para cadastrar o primeiro.</p>
      </div>
    );
  }

  // 4) Lista de eventos (já chega ordenada do mais recente para o mais antigo)
  return (
    <ul className="grid gap-3">
      {eventos.map((evento) => {
        // O banco devolve ISO 8601 (UTC); o navegador exibe no fuso local do usuário
        const data = new Date(evento.data_evento);
        const dia = data.toLocaleDateString("pt-BR", { day: "2-digit" });
        const mes = data.toLocaleDateString("pt-BR", { month: "short" }).replace(".", "");
        const diaSemanaData = data.toLocaleDateString("pt-BR", {
          weekday: "long",
          day: "2-digit",
          month: "2-digit",
          year: "numeric",
        });
        const hora = data.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });

        return (
          <li
            key={evento.id}
            className="flex items-start gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"
          >
            {/* Bloco de data: dia e mês abreviado */}
            <div className="flex h-14 w-14 shrink-0 flex-col items-center justify-center rounded-xl bg-indigo-50 text-indigo-700">
              <span className="text-lg font-bold leading-none">{dia}</span>
              <span className="mt-0.5 text-xs font-medium uppercase">{mes}</span>
            </div>

            <div className="min-w-0 flex-1">
              <div className="flex items-center justify-between gap-2">
                <p className="truncate font-semibold text-slate-900">{evento.local}</p>
                <span
                  className={
                    "shrink-0 rounded-full px-2 py-0.5 text-xs font-medium " + classeTipo(evento.tipo)
                  }
                >
                  {evento.tipo}
                </span>
              </div>
              <p className="text-sm capitalize text-slate-600">{diaSemanaData}</p>
              <p className="text-xs text-slate-500">às {hora}</p>
            </div>
          </li>
        );
      })}
    </ul>
  );
}
