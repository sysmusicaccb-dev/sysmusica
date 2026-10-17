"use client";

/**
 * SysMúsica — Formulário de lançamento de presenças na Portaria (painel lateral).
 * Fluxo: escolher a PORTARIA aprovada -> marcar o status de cada membro -> salvar (em lote: ou
 * salva todos, ou nenhum). Só aparecem portarias APROVADAS que o usuário pode usar. O banco confere
 * de novo tudo (aprovada, mesma cidade, membro ativo, sem duplicidade) e define a hora de entrada,
 * quem registrou e a origem. Membros já registrados no evento ficam travados (corrigir: Editar/Excluir).
 */
import { useMemo, useState, type FormEvent } from "react";
import Link from "next/link";
import Button from "@/components/ui/Button";
import { formatarDataHora } from "@/lib/datas";
import { mensagemDoErro } from "@/lib/erros";
import { supabase } from "@/lib/supabase";
import type { PortariaDetalhada } from "@/modules/portarias/tipos";
import type { Evento, Instrumento, MembroPublico, Presenca, PresencaInsert } from "@/types/database";

interface FormularioPresencaProps {
  portarias: PortariaDetalhada[]; // somente as APROVADAS
  eventos?: Evento[]; // (obsoleto) a página ainda envia; a portaria já traz os dados do evento
  membros: MembroPublico[];
  instrumentos: Instrumento[]; // usado para exibir o nome do instrumento de cada membro
  presencas: Presenca[]; // usado para travar quem já foi registrado no evento
  carregando: boolean;
  erro: string | null;
  /** Chamado após salvar com sucesso, com a mensagem para o aviso da tela. */
  onPresencaAdicionada: (mensagem: string) => void | Promise<void>;
}

// Opções de status e a cor de cada botão quando selecionado (classes por extenso para o Tailwind).
const OPCOES_STATUS = [
  { valor: "Presente", classe: "peer-checked:border-emerald-600 peer-checked:bg-emerald-600 peer-checked:text-white" },
  { valor: "Ausente", classe: "peer-checked:border-red-600 peer-checked:bg-red-600 peer-checked:text-white" },
  { valor: "Justificado", classe: "peer-checked:border-amber-500 peer-checked:bg-amber-500 peer-checked:text-white" },
] as const;

// Selo de status para membros já registrados
function classeStatus(status: string): string {
  if (status === "Presente") return "bg-emerald-100 text-emerald-700";
  if (status === "Ausente") return "bg-red-100 text-red-700";
  if (status === "Justificado") return "bg-amber-100 text-amber-700";
  return "bg-slate-100 text-slate-600";
}

// Texto de cada opção do select: "Ensaio · 18/10/2026 14:00 · Local (Cidade)"
function rotuloPortaria(portaria: PortariaDetalhada): string {
  const data = portaria.evento_data ? formatarDataHora(portaria.evento_data) : "Evento removido";
  return `${portaria.evento_tipo ?? "Evento"} · ${data} · ${portaria.evento_local ?? ""} (${portaria.cidade})`;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

const classeBotaoSecundario =
  "rounded-lg border border-slate-300 bg-white px-2.5 py-1 text-xs font-medium text-slate-700 " +
  "transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioPresenca({
  portarias,
  membros,
  instrumentos,
  presencas,
  carregando,
  erro,
  onPresencaAdicionada,
}: FormularioPresencaProps) {
  const [portariaId, setPortariaId] = useState("");
  const [marcacoes, setMarcacoes] = useState<Record<string, string>>({}); // membro_id -> status (não salvo)
  const [salvando, setSalvando] = useState(false);
  const [erroForm, setErroForm] = useState<string | null>(null);

  const portaria = portarias.find((item) => item.id === portariaId);

  // Presenças já gravadas para o evento da portaria escolhida: membro_id -> status
  const jaRegistrados = useMemo(() => {
    const mapa = new Map<string, string>();
    if (!portaria) return mapa;
    for (const presenca of presencas) {
      if (presenca.evento_id === portaria.evento_id) mapa.set(presenca.membro_id, presenca.status);
    }
    return mapa;
  }, [presencas, portaria]);

  const pendentes = membros.filter((membro) => !jaRegistrados.has(membro.id));
  const qtdMarcados = Object.keys(marcacoes).length;

  // Ao trocar de portaria, zera marcações e mensagens
  function trocarPortaria(novaPortariaId: string) {
    setPortariaId(novaPortariaId);
    setMarcacoes({});
    setErroForm(null);
  }

  function marcar(membroId: string, status: string) {
    setMarcacoes((anterior) => ({ ...anterior, [membroId]: status }));
  }

  // Atalho: marca todos os membros pendentes como "Presente"
  function marcarTodosPresentes() {
    const todos: Record<string, string> = {};
    for (const membro of pendentes) todos[membro.id] = "Presente";
    setMarcacoes(todos);
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErroForm(null);

    if (!portaria) return setErroForm("Selecione uma portaria aprovada.");

    // Lote tipado (ignora quem já estava registrado). Hora, autor e origem ficam por conta do banco.
    const registros: PresencaInsert[] = Object.entries(marcacoes)
      .filter(([membroId]) => !jaRegistrados.has(membroId))
      .map(([membroId, status]) => ({
        membro_id: membroId,
        evento_id: portaria.evento_id,
        status,
        portaria_id: portaria.id,
      }));

    if (registros.length === 0) return setErroForm("Marque a presença de pelo menos um membro.");

    setSalvando(true);
    try {
      const { error } = await supabase.from("presencas").insert(registros);
      if (error) {
        throw new Error(
          mensagemDoErro(
            error,
            "Não foi possível salvar as presenças.",
            "Algum membro já tem presença registrada nesta portaria. Recarregue a página e tente novamente."
          )
        );
      }
      // Sucesso: limpa as marcações (a portaria continua selecionada) e recarrega os dados
      setMarcacoes({});
      await onPresencaAdicionada("Presenças registradas com sucesso!");
    } catch (e) {
      setErroForm(e instanceof Error ? e.message : "Não foi possível salvar as presenças.");
    } finally {
      setSalvando(false);
    }
  }

  // ---------- Estados da tela ----------
  if (carregando) return <p className="text-sm text-slate-600">Carregando os dados do formulário...</p>;

  if (erro) {
    return <p className="text-sm text-slate-600">Formulário indisponível porque os dados não puderam ser carregados.</p>;
  }

  // Sem portaria aprovada disponível: explica o caminho
  if (portarias.length === 0) {
    return (
      <div className="space-y-3 text-sm text-slate-600">
        <p>
          Não há portarias <strong>aprovadas</strong> disponíveis para você. Só é possível registrar presenças em
          uma portaria aprovada, da sua abrangência.
        </p>
        <Link href="/portarias" className="font-semibold text-brand-700 hover:underline">
          Ver as portarias
        </Link>
      </div>
    );
  }

  if (membros.length === 0) {
    return (
      <div className="space-y-3 text-sm text-slate-600">
        <p>Para registrar presenças é preciso ter ao menos um membro cadastrado.</p>
        <Link href="/membros" className="font-semibold text-brand-700 hover:underline">
          Cadastrar membro
        </Link>
      </div>
    );
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      <div className="space-y-1.5">
        <label htmlFor="portaria" className="text-sm font-medium text-slate-700">
          Portaria
        </label>
        <select
          id="portaria"
          value={portariaId}
          onChange={(e) => trocarPortaria(e.target.value)}
          disabled={salvando}
          className={classeInput}
        >
          <option value="">Selecione uma portaria aprovada</option>
          {portarias.map((item) => (
            <option key={item.id} value={item.id}>
              {rotuloPortaria(item)}
            </option>
          ))}
        </select>
      </div>

      {/* Lista de membros: aparece depois de escolher a portaria */}
      {portaria && (
        <div className="space-y-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <p className="text-sm font-medium text-slate-700">
              Membros ({qtdMarcados} de {pendentes.length} marcados)
            </p>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={marcarTodosPresentes}
                disabled={salvando || pendentes.length === 0}
                className={classeBotaoSecundario}
              >
                Todos presentes
              </button>
              <button
                type="button"
                onClick={() => setMarcacoes({})}
                disabled={salvando || qtdMarcados === 0}
                className={classeBotaoSecundario}
              >
                Limpar
              </button>
            </div>
          </div>

          <ul className="max-h-96 space-y-2 overflow-y-auto pr-1">
            {membros.map((membro) => {
              const statusRegistrado = jaRegistrados.get(membro.id);
              const statusAtual = marcacoes[membro.id];
              const instrumento = instrumentos.find((item) => item.id === membro.instrumento_id);

              return (
                <li key={membro.id} className="rounded-xl border border-slate-200 p-3">
                  <p className="truncate text-sm font-medium text-slate-900">
                    {membro.nome}
                    {instrumento && <span className="ml-2 text-xs font-normal text-slate-500">{instrumento.nome}</span>}
                  </p>

                  {statusRegistrado ? (
                    // Já registrado neste evento: somente leitura
                    <p className="mt-2 text-xs text-slate-500">
                      Já registrado:{" "}
                      <span className={"rounded-full px-2 py-0.5 font-medium " + classeStatus(statusRegistrado)}>
                        {statusRegistrado}
                      </span>
                    </p>
                  ) : (
                    // Botões de seleção (radio escondido + rótulo estilizado)
                    <div role="radiogroup" aria-label={`Presença de ${membro.nome}`} className="mt-2 flex flex-wrap gap-1.5">
                      {OPCOES_STATUS.map((opcao) => (
                        <label key={opcao.valor} className="cursor-pointer">
                          <input
                            type="radio"
                            name={`presenca-${membro.id}`}
                            value={opcao.valor}
                            checked={statusAtual === opcao.valor}
                            onChange={() => marcar(membro.id, opcao.valor)}
                            disabled={salvando}
                            className="peer sr-only"
                          />
                          <span
                            className={
                              "block rounded-lg border border-slate-300 bg-white px-2.5 py-1.5 " +
                              "text-xs font-medium text-slate-600 transition " +
                              "peer-focus-visible:ring-2 peer-focus-visible:ring-brand-300 " +
                              "peer-disabled:opacity-60 " +
                              opcao.classe
                            }
                          >
                            {opcao.valor}
                          </span>
                        </label>
                      ))}
                    </div>
                  )}
                </li>
              );
            })}
          </ul>
        </div>
      )}

      {erroForm && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erroForm}
        </p>
      )}

      <Button type="submit" disabled={salvando || !portaria} className="w-full">
        {salvando ? "Salvando..." : qtdMarcados > 0 ? `Salvar presenças (${qtdMarcados})` : "Salvar presenças"}
      </Button>
    </form>
  );
}
