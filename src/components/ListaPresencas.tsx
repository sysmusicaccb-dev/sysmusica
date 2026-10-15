/**
 * SysMúsica — Histórico de presenças (componente de apresentação).
 *
 * Não acessa o banco: recebe presenças, membros e eventos da página e faz o
 * cruzamento (join) em memória, agrupando por evento (mais recente primeiro).
 * Trata quatro cenários: carregando, erro, vazio e lista com dados.
 */
import type { Evento, Instrumento, MembroPublico, Presenca } from "@/types/database";

interface ListaPresencasProps {
  presencas: Presenca[];
  membros: MembroPublico[];
  instrumentos: Instrumento[]; // usado para exibir o nome do instrumento de cada membro
  eventos: Evento[]; // já chega ordenado do mais recente para o mais antigo
  carregando: boolean;
  erro: string | null;
  onTentarNovamente: () => void;
}

// Selo de status (Presente / Ausente / Justificado)
function classeStatus(status: string): string {
  if (status === "Presente") return "bg-emerald-100 text-emerald-700";
  if (status === "Ausente") return "bg-red-100 text-red-700";
  if (status === "Justificado") return "bg-amber-100 text-amber-700";
  return "bg-slate-100 text-slate-600";
}

// Selo do tipo de evento (mesmas cores do módulo de eventos)
function classeTipo(tipo: string): string {
  const normalizado = tipo.trim().toLowerCase();
  if (normalizado === "ensaio") return "bg-indigo-100 text-indigo-700";
  if (normalizado === "culto") return "bg-amber-100 text-amber-700";
  return "bg-slate-100 text-slate-600";
}

// Os três status usados no resumo de cada evento
const STATUS_RESUMO = ["Presente", "Ausente", "Justificado"] as const;

export default function ListaPresencas({
  presencas,
  membros,
  instrumentos,
  eventos,
  carregando,
  erro,
  onTentarNovamente,
}: ListaPresencasProps) {
  // 1) Carregando: placeholders animados (skeleton)
  if (carregando) {
    return (
      <div role="status" aria-live="polite" className="grid gap-4">
        <span className="sr-only">Carregando presenças...</span>
        {[0, 1, 2].map((i) => (
          <div key={i} className="h-36 animate-pulse rounded-2xl bg-slate-200" />
        ))}
      </div>
    );
  }

  // 2) Erro na comunicação com o banco
  if (erro) {
    return (
      <div role="alert" className="rounded-2xl border border-red-200 bg-red-50 p-6">
        <p className="font-semibold text-red-800">Não foi possível carregar as presenças.</p>
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

  // Cruzamento em memória: índice de membros por id e presenças agrupadas por evento
  const membroPorId = new Map(membros.map((membro): [string, MembroPublico] => [membro.id, membro]));
  const presencasPorEvento = new Map<string, Presenca[]>();
  for (const presenca of presencas) {
    const grupo = presencasPorEvento.get(presenca.evento_id) ?? [];
    grupo.push(presenca);
    presencasPorEvento.set(presenca.evento_id, grupo);
  }

  // Só eventos que têm presenças, mantendo a ordem (mais recente primeiro)
  const eventosComPresenca = eventos.filter((evento) => presencasPorEvento.has(evento.id));

  // 3) Nenhuma presença registrada
  if (eventosComPresenca.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center">
        <p className="font-medium text-slate-700">Nenhuma presença registrada ainda.</p>
        <p className="mt-1 text-sm text-slate-500">
          Escolha um evento no formulário para registrar a primeira.
        </p>
      </div>
    );
  }

  // 4) Histórico agrupado por evento
  return (
    <ul className="grid gap-4">
      {eventosComPresenca.map((evento) => {
        // Monta as linhas (presença + dados do membro) em ordem alfabética
        const linhas = (presencasPorEvento.get(evento.id) ?? [])
          .map((presenca) => ({
            presenca,
            nome: membroPorId.get(presenca.membro_id)?.nome ?? "Membro não encontrado",
            categoria: instrumentos.find(
              (instrumento) =>
                instrumento.id === membroPorId.get(presenca.membro_id)?.instrumento_id
            )?.nome ?? "",
          }))
          .sort((a, b) => a.nome.localeCompare(b.nome, "pt-BR"));

        // O banco devolve ISO 8601 (UTC); o navegador exibe no fuso local
        const dataHora = new Date(evento.data_evento)
          .toLocaleString("pt-BR", {
            day: "2-digit",
            month: "2-digit",
            year: "numeric",
            hour: "2-digit",
            minute: "2-digit",
          })
          .replace(", ", " às ");

        return (
          <li
            key={evento.id}
            className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"
          >
            {/* Cabeçalho do evento */}
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="min-w-0">
                <p className="truncate font-semibold text-slate-900">{evento.local}</p>
                <p className="text-xs text-slate-500">{dataHora}</p>
              </div>
              <span
                className={
                  "shrink-0 rounded-full px-2 py-0.5 text-xs font-medium " + classeTipo(evento.tipo)
                }
              >
                {evento.tipo}
              </span>
            </div>

            {/* Resumo: contagem por status */}
            <div className="mt-3 flex flex-wrap gap-1.5">
              {STATUS_RESUMO.map((status) => (
                <span
                  key={status}
                  className={"rounded-full px-2 py-0.5 text-xs font-medium " + classeStatus(status)}
                >
                  {status}: {linhas.filter((linha) => linha.presenca.status === status).length}
                </span>
              ))}
            </div>

            {/* Membros e seus status */}
            <ul className="mt-3 divide-y divide-slate-100">
              {linhas.map(({ presenca, nome, categoria }) => (
                <li key={presenca.id} className="flex items-center justify-between gap-2 py-2">
                  <p className="min-w-0 truncate text-sm text-slate-900">
                    {nome}
                    {categoria && <span className="ml-2 text-xs text-slate-500">{categoria}</span>}
                  </p>
                  <span
                    className={
                      "shrink-0 rounded-full px-2 py-0.5 text-xs font-medium " +
                      classeStatus(presenca.status)
                    }
                  >
                    {presenca.status}
                  </span>
                </li>
              ))}
            </ul>
          </li>
        );
      })}
    </ul>
  );
}
