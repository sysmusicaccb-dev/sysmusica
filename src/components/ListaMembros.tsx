/**
 * SysMúsica — Lista de membros (componente de apresentação).
 *
 * Não acessa o banco: recebe os dados e os estados (loading/erro) da página.
 * Cruza cada membro com seu cargo (cargo_id -> cargos) para exibir o nome do cargo.
 * Trata quatro cenários: carregando, erro, lista vazia e lista com dados.
 */
import type { Cargo, MembroPublico } from "@/types/database";

interface ListaMembrosProps {
  membros: MembroPublico[];
  cargos: Cargo[];
  carregando: boolean;
  erro: string | null;
  onTentarNovamente: () => void;
}

// Converte "AAAA-MM-DD" em "DD/MM/AAAA" na mão: new Date("AAAA-MM-DD") interpreta como UTC
// e poderia exibir o dia anterior no fuso do Brasil.
function formatarDataNascimento(data: string): string {
  const [ano, mes, dia] = data.split("-");
  return `${dia}/${mes}/${ano}`;
}

export default function ListaMembros({
  membros,
  cargos,
  carregando,
  erro,
  onTentarNovamente,
}: ListaMembrosProps) {
  // 1) Carregando: placeholders animados (skeleton)
  if (carregando) {
    return (
      <div role="status" aria-live="polite" className="grid gap-3 sm:grid-cols-2">
        <span className="sr-only">Carregando membros...</span>
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="h-28 animate-pulse rounded-2xl bg-slate-200" />
        ))}
      </div>
    );
  }

  // 2) Erro na comunicação com o banco
  if (erro) {
    return (
      <div role="alert" className="rounded-2xl border border-red-200 bg-red-50 p-6">
        <p className="font-semibold text-red-800">Não foi possível carregar os membros.</p>
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

  // 3) Nenhum membro cadastrado
  if (membros.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center">
        <p className="font-medium text-slate-700">Nenhum membro cadastrado ainda.</p>
        <p className="mt-1 text-sm text-slate-500">Use o formulário para cadastrar o primeiro.</p>
      </div>
    );
  }

  // Índice de cargos por id (cruzamento em memória)
  const cargoPorId = new Map(cargos.map((cargo): [string, Cargo] => [cargo.id, cargo]));

  // 4) Lista de membros
  return (
    <ul className="grid gap-3 sm:grid-cols-2">
      {membros.map((membro) => {
        const nomeCargo = cargoPorId.get(membro.cargo_id)?.nome ?? "Cargo não encontrado";

        return (
          <li
            key={membro.id}
            className="flex items-start gap-3 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"
          >
            {/* Avatar com a inicial do nome */}
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-indigo-100 text-sm font-bold text-indigo-700">
              {membro.nome.charAt(0).toUpperCase()}
            </div>

            <div className="min-w-0 flex-1">
              <div className="flex items-center justify-between gap-2">
                <p className="truncate font-semibold text-slate-900">{membro.nome}</p>
                <span
                  className={
                    "shrink-0 rounded-full px-2 py-0.5 text-xs font-medium " +
                    (membro.status === "Ativo"
                      ? "bg-emerald-100 text-emerald-700"
                      : "bg-slate-100 text-slate-600")
                  }
                >
                  {membro.status}
                </span>
              </div>

              {/* Cargo e, quando houver, a categoria do instrumento */}
              <p className="truncate text-sm text-slate-600">
                {nomeCargo}
                {membro.categoria_instrumento && ` · ${membro.categoria_instrumento}`}
              </p>

              <p className="truncate text-xs text-slate-500">
                {membro.congregacao}
                {membro.data_nascimento &&
                  ` · nasc. ${formatarDataNascimento(membro.data_nascimento)}`}
                {` · desde ${new Date(membro.data_cadastro).toLocaleDateString("pt-BR")}`}
              </p>
            </div>
          </li>
        );
      })}
    </ul>
  );
}
