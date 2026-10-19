"use client";

/**
 * SysMúsica — Árvore da organização: Estado > Região > Setor > Casa de Oração, com abrir/fechar e as ações de cada item.
 * Os botões só aparecem para quem tem a permissão (a tela repassa); o banco confere de novo em cada operação.
 * Casas de Oração que ainda não têm setor ficam numa seção própria, no fim, com o botão de transferir.
 */
import { useState, type ReactNode } from "react";
import { ArrowRightLeft, ChevronDown, ChevronRight, Pencil, Plus, Power, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { FILHO_DE, ROTULO_NIVEL, filhosDe } from "../regras";
import type { NivelOrganizacao, NoOrganizacao } from "../tipos";

interface ArvoreOrganizacaoProps {
  nos: NoOrganizacao[];
  podeCriar: boolean;
  podeEditar: boolean;
  podeTransferir: boolean;
  podeExcluir: boolean;
  onNovo: (nivel: NivelOrganizacao, pai: NoOrganizacao | null) => void;
  onEditar: (no: NoOrganizacao) => void;
  onAlternar: (no: NoOrganizacao) => void;
  onTransferir: (no: NoOrganizacao) => void;
  onExcluir: (no: NoOrganizacao) => void;
}

// Texto de contagem de cada item (ex.: "5 setores")
function contagem(no: NoOrganizacao): string {
  const n = no.qtd_filhos ?? 0;
  if (no.nivel === "ESTADO") return `${n} ${n === 1 ? "região" : "regiões"}`;
  if (no.nivel === "REGIAO") return `${n} ${n === 1 ? "setor" : "setores"}`;
  if (no.nivel === "SETOR") return `${n} ${n === 1 ? "casa de oração" : "casas de oração"}`;
  const m = no.qtd_membros ?? 0;
  return `${m} ${m === 1 ? "membro" : "membros"}`;
}

export default function ArvoreOrganizacao({
  nos,
  podeCriar,
  podeEditar,
  podeTransferir,
  podeExcluir,
  onNovo,
  onEditar,
  onAlternar,
  onTransferir,
  onExcluir,
}: ArvoreOrganizacaoProps) {
  // Começa com estados e regiões abertos
  const [abertos, setAbertos] = useState<Set<string>>(
    () => new Set(nos.filter((no) => no.nivel === "ESTADO" || no.nivel === "REGIAO").map((no) => no.id))
  );

  function alternarAberto(id: string) {
    setAbertos((anterior) => {
      const novos = new Set(anterior);
      if (novos.has(id)) novos.delete(id);
      else novos.add(id);
      return novos;
    });
  }

  // Linha de um item e, se estiver aberto, os filhos dele (função comum e não componente: é recursiva)
  function renderLinha(no: NoOrganizacao, profundidade: number): ReactNode {
    const nivelFilho = FILHO_DE[no.nivel];
    const filhos = nivelFilho ? filhosDe(nos, no.id, nivelFilho) : [];
    const aberto = abertos.has(no.id);
    const inativo = no.ativo === false;

    return (
      <li key={`${no.nivel}:${no.id}`}>
        <div
          className="flex items-center gap-2 rounded-lg py-1.5 pr-2 hover:bg-slate-50"
          style={{ paddingLeft: `${profundidade * 1.25 + 0.25}rem` }}
        >
          {filhos.length > 0 ? (
            <button
              type="button"
              onClick={() => alternarAberto(no.id)}
              aria-expanded={aberto}
              aria-label={`${aberto ? "Fechar" : "Abrir"} ${no.nome}`}
              className="rounded p-0.5 text-slate-500 hover:bg-slate-100"
            >
              {aberto ? <ChevronDown className="h-4 w-4" aria-hidden="true" /> : <ChevronRight className="h-4 w-4" aria-hidden="true" />}
            </button>
          ) : (
            <span className="inline-block w-5" aria-hidden="true" />
          )}

          <span className="min-w-0 flex-1">
            <span className="mr-2 text-xs font-semibold uppercase tracking-wide text-slate-400">
              {ROTULO_NIVEL[no.nivel]}
            </span>
            <span className={inativo ? "font-medium text-slate-400" : "font-medium text-slate-900"}>{no.nome}</span>
            <span className="ml-2 text-xs text-slate-500">
              {contagem(no)}
              {no.nivel === "CASA_ORACAO" && (no.bairro || no.cidade)
                ? ` · ${[no.bairro, no.cidade].filter(Boolean).join(", ")}`
                : ""}
            </span>
          </span>

          <Badge variante={inativo ? "perigo" : "sucesso"}>{inativo ? "Inativo" : "Ativo"}</Badge>

          <div className="flex shrink-0 gap-1">
            {podeCriar && nivelFilho && (
              <BotaoIcone
                icone={Plus}
                rotulo={`Adicionar ${ROTULO_NIVEL[nivelFilho].toLowerCase()} em ${no.nome}`}
                onClick={() => onNovo(nivelFilho, no)}
              />
            )}
            {podeTransferir && no.nivel === "CASA_ORACAO" && (
              <BotaoIcone icone={ArrowRightLeft} rotulo={`Transferir ${no.nome} para outro setor`} onClick={() => onTransferir(no)} />
            )}
            {podeEditar && (
              <>
                <BotaoIcone icone={Pencil} rotulo={`Editar ${no.nome}`} onClick={() => onEditar(no)} />
                <BotaoIcone
                  icone={Power}
                  rotulo={`${inativo ? "Ativar" : "Inativar"} ${no.nome}`}
                  onClick={() => onAlternar(no)}
                />
              </>
            )}
            {podeExcluir && (
              <>
                <BotaoIcone
                  icone={Trash2}
                  variante="perigo"
                  rotulo={`Excluir ${no.nome}`}
                  onClick={() => onExcluir(no)}
                />
              </>
            )}
          </div>
        </div>

        {aberto && filhos.length > 0 && <ul>{filhos.map((filho) => renderLinha(filho, profundidade + 1))}</ul>}
      </li>
    );
  }

  const estados = filhosDe(nos, null, "ESTADO");
  const semSetor = filhosDe(nos, null, "CASA_ORACAO");

  return (
    <div className="space-y-6">
      <div className="rounded-2xl border border-slate-200 bg-white p-3 shadow-sm">
        {estados.length === 0 ? (
          <p className="px-2 py-6 text-center text-sm text-slate-500">Nenhum estado cadastrado.</p>
        ) : (
          <ul>{estados.map((estado) => renderLinha(estado, 0))}</ul>
        )}
      </div>

      {semSetor.length > 0 && (
        <section className="rounded-2xl border border-amber-200 bg-amber-50/50 p-3 shadow-sm">
          <h2 className="px-2 pt-1 text-sm font-semibold text-slate-900">Casas de Oração sem setor ({semSetor.length})</h2>
          <p className="px-2 pb-2 text-xs text-slate-600">
            Enquanto uma casa de oração estiver sem setor, quem tem acesso restrito não vê nada dela (membros, eventos e
            portarias). Use o botão de transferir para vinculá-la a um setor.
          </p>
          <ul>{semSetor.map((casaOracao) => renderLinha(casaOracao, 0))}</ul>
        </section>
      )}
    </div>
  );
}
