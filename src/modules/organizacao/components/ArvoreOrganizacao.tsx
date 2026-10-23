"use client";

/**
 * Sysmusica — Árvore da organização: Estado › RRM › RA › ADM › Setor (opcional) › Casa de Oração,
 * com abrir/fechar e as ações de cada item.
 * RRM = Reunião Regional Ministerial · RA = Regional Administrativa · ADM = Administração.
 * Uma casa de oração pode ficar dentro de um setor OU ligada direto à ADM (o setor é opcional).
 * Os botões só aparecem para quem tem a permissão (a tela repassa); o banco confere de novo em cada operação.
 */
import { useState, type ReactNode } from "react";
import { ArrowRightLeft, ChevronDown, ChevronRight, Pencil, Plus, Power, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { FILHOS_DE, NOME_COMPLETO_NIVEL, ROTULO_NIVEL, filhosDe, filhosDoNo } from "../regras";
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

const plural = (n: number, singular: string, plurais: string) => `${n} ${n === 1 ? singular : plurais}`;

// Todos os níveis começam abertos: quem administra uma região já vê a estrutura completa (RA, ADM, setores e casas)
const ABERTOS_NO_INICIO: NivelOrganizacao[] = ["ESTADO", "RRM", "RA", "ADM", "SETOR"];

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
  const [abertos, setAbertos] = useState<Set<string>>(
    () => new Set(nos.filter((no) => ABERTOS_NO_INICIO.includes(no.nivel)).map((no) => no.id))
  );

  function alternarAberto(id: string) {
    setAbertos((anterior) => {
      const novos = new Set(anterior);
      if (novos.has(id)) novos.delete(id);
      else novos.add(id);
      return novos;
    });
  }

  // Texto de contagem de cada item (ex.: "2 setores · 3 casas de oração")
  function contagem(no: NoOrganizacao): string {
    if (no.nivel === "ESTADO") return plural(no.qtd_filhos ?? 0, "RRM", "RRMs");
    if (no.nivel === "RRM") return plural(no.qtd_filhos ?? 0, "RA", "RAs");
    if (no.nivel === "RA") return plural(no.qtd_filhos ?? 0, "ADM", "ADMs");
    if (no.nivel === "ADM") {
      const setores = filhosDe(nos, no.id, "SETOR").length;
      const casas = filhosDe(nos, no.id, "CASA_ORACAO").length;
      return `${plural(setores, "setor", "setores")} · ${plural(casas, "casa de oração sem setor", "casas de oração sem setor")}`;
    }
    if (no.nivel === "SETOR") return plural(no.qtd_filhos ?? 0, "casa de oração", "casas de oração");
    return plural(no.qtd_membros ?? 0, "membro", "membros");
  }

  // Linha de um item e, se estiver aberto, os filhos dele (função comum e não componente: é recursiva)
  function renderLinha(no: NoOrganizacao, profundidade: number): ReactNode {
    const filhos = filhosDoNo(nos, no);
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
            <span
              className="mr-2 text-xs font-semibold uppercase tracking-wide text-slate-400"
              title={NOME_COMPLETO_NIVEL[no.nivel]}
            >
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
            {/* Um botão + para cada tipo de filho (a ADM tem dois: setor e casa de oração) */}
            {podeCriar &&
              FILHOS_DE[no.nivel].map((nivelFilho) => (
                <BotaoIcone
                  key={nivelFilho}
                  icone={Plus}
                  rotulo={`Adicionar ${ROTULO_NIVEL[nivelFilho]} em ${no.nome}`}
                  onClick={() => onNovo(nivelFilho, no)}
                />
              ))}
            {podeTransferir && no.nivel === "CASA_ORACAO" && (
              <BotaoIcone icone={ArrowRightLeft} rotulo={`Transferir ${no.nome} para outra ADM ou setor`} onClick={() => onTransferir(no)} />
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
              <BotaoIcone icone={Trash2} variante="perigo" rotulo={`Excluir ${no.nome}`} onClick={() => onExcluir(no)} />
            )}
          </div>
        </div>

        {aberto && filhos.length > 0 && <ul>{filhos.map((filho) => renderLinha(filho, profundidade + 1))}</ul>}
      </li>
    );
  }

  const estados = filhosDe(nos, null, "ESTADO");

  return (
    <div className="space-y-6">
      <div className="rounded-2xl border border-slate-200 bg-white p-3 shadow-sm">
        {estados.length === 0 ? (
          <p className="px-2 py-6 text-center text-sm text-slate-500">Nenhum estado cadastrado.</p>
        ) : (
          <ul>{estados.map((estado) => renderLinha(estado, 0))}</ul>
        )}
      </div>
      <p className="px-1 text-xs text-slate-500">
        RRM = Reunião Regional Ministerial · RA = Regional Administrativa · ADM = Administração. O setor é opcional: uma
        casa de oração pode ficar ligada direto à ADM.
      </p>
    </div>
  );
}
