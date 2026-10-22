"use client";

/**
 * SysMúsica — Filtros do relatório. Mostra só os filtros do tipo escolhido. RA, setor e casa de oração são
 * listas encadeadas que vêm do banco (Organização): cada uma só mostra o que pertence à escolha anterior.
 */
import type { ReactNode } from "react";
import { formatarDataHora } from "@/lib/datas";
import { ROTULO_STATUS } from "@/modules/portarias/regras";
import { opcoesAdm, opcoesCasaOracao, opcoesRegiao, opcoesRrm, opcoesSetor } from "../regras";
import type { CampoFiltro, FiltrosRelatorio, OpcoesFiltros } from "../tipos";

interface FiltrosDoRelatorioProps {
  campos: CampoFiltro[];
  valores: FiltrosRelatorio;
  onChange: (novos: FiltrosRelatorio) => void;
  opcoes: OpcoesFiltros | null;
  desabilitado: boolean;
}

const classeCampo =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 " +
  "disabled:cursor-not-allowed disabled:opacity-60 [color-scheme:light]";

const STATUS_PRESENCA = ["Presente", "Ausente", "Justificado"];

function Campo({ id, rotulo, children }: { id: string; rotulo: string; children: ReactNode }) {
  return (
    <div className="space-y-1.5">
      <label htmlFor={id} className="text-xs font-medium text-slate-600">
        {rotulo}
      </label>
      {children}
    </div>
  );
}

export default function FiltrosDoRelatorio({ campos, valores, onChange, opcoes, desabilitado }: FiltrosDoRelatorioProps) {
  const tem = (campo: CampoFiltro) => campos.includes(campo);
  const mudar = (parcial: Partial<FiltrosRelatorio>) => onChange({ ...valores, ...parcial });
  const organizacao = opcoes?.organizacao ?? [];

  if (campos.length === 0) {
    return <p className="text-sm text-slate-500">Este relatório não tem filtros: traz tudo o que você pode ver.</p>;
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {tem("periodo") && (
        <>
          <Campo id="rel-inicio" rotulo="De (data do evento)">
            <input
              id="rel-inicio"
              type="date"
              value={valores.inicio}
              onChange={(e) => mudar({ inicio: e.target.value })}
              disabled={desabilitado}
              className={classeCampo}
            />
          </Campo>
          <Campo id="rel-fim" rotulo="Até (data do evento)">
            <input
              id="rel-fim"
              type="date"
              value={valores.fim}
              onChange={(e) => mudar({ fim: e.target.value })}
              disabled={desabilitado}
              className={classeCampo}
            />
          </Campo>
        </>
      )}

      {tem("evento") && (
        <Campo id="rel-evento" rotulo="Evento">
          <select
            id="rel-evento"
            value={valores.eventoId}
            onChange={(e) => mudar({ eventoId: e.target.value })}
            disabled={desabilitado}
            className={classeCampo}
          >
            <option value="">Todos os eventos do período</option>
            {(opcoes?.eventos ?? []).map((evento) => (
              <option key={evento.id} value={evento.id}>
                {formatarDataHora(evento.data_evento)} · {evento.tipo} · {evento.local}
              </option>
            ))}
          </select>
        </Campo>
      )}

      {tem("rrm") && (
        <Campo id="rel-rrm" rotulo="RRM (Reunião Regional Ministerial)">
          <select
            id="rel-rrm"
            value={valores.rrmId ?? ""}
            onChange={(e) => mudar({ rrmId: e.target.value, regiaoId: "", admId: "", setorId: "", casaOracaoId: "" })}
            disabled={desabilitado}
            className={classeCampo}
          >
            <option value="">Todas as RRMs</option>
            {opcoesRrm(organizacao).map((opcao) => (
              <option key={opcao.id} value={opcao.id}>
                {opcao.rotulo}
              </option>
            ))}
          </select>
        </Campo>
      )}

      {tem("regiao") && (
        <Campo id="rel-regiao" rotulo="RA (Regional Administrativa)">
          <select
            id="rel-regiao"
            value={valores.regiaoId}
            onChange={(e) => mudar({ regiaoId: e.target.value, admId: "", setorId: "", casaOracaoId: "" })}
            disabled={desabilitado}
            className={classeCampo}
          >
            <option value="">Todas as RAs</option>
            {opcoesRegiao(organizacao, valores.rrmId).map((opcao) => (
              <option key={opcao.id} value={opcao.id}>
                {opcao.rotulo}
              </option>
            ))}
          </select>
        </Campo>
      )}

      {tem("adm") && (
        <Campo id="rel-adm" rotulo="ADM (Administração)">
          <select
            id="rel-adm"
            value={valores.admId ?? ""}
            onChange={(e) => mudar({ admId: e.target.value, setorId: "", casaOracaoId: "" })}
            disabled={desabilitado || !valores.regiaoId}
            className={classeCampo}
          >
            <option value="">{valores.regiaoId ? "Todas as ADMs" : "Escolha a RA primeiro"}</option>
            {opcoesAdm(organizacao, valores.regiaoId).map((opcao) => (
              <option key={opcao.id} value={opcao.id}>
                {opcao.rotulo}
              </option>
            ))}
          </select>
        </Campo>
      )}

      {tem("setor") && (
        <Campo id="rel-setor" rotulo="Setor">
          <select
            id="rel-setor"
            value={valores.setorId}
            onChange={(e) => mudar({ setorId: e.target.value, casaOracaoId: "" })}
            disabled={desabilitado || !valores.regiaoId}
            className={classeCampo}
          >
            <option value="">{valores.regiaoId ? "Todos os setores" : "Escolha a RA primeiro"}</option>
            {opcoesSetor(organizacao, valores.regiaoId, valores.admId).map((opcao) => (
              <option key={opcao.id} value={opcao.id}>
                {opcao.rotulo}
              </option>
            ))}
          </select>
        </Campo>
      )}

      {tem("casa_oracao") && (
        <Campo id="rel-casa-oracao" rotulo="Casa de Oração">
          <select
            id="rel-casa-oracao"
            value={valores.casaOracaoId}
            onChange={(e) => mudar({ casaOracaoId: e.target.value })}
            disabled={desabilitado || !valores.regiaoId}
            className={classeCampo}
          >
            <option value="">{valores.regiaoId ? "Todas as casas de oração" : "Escolha a RA primeiro"}</option>
            {opcoesCasaOracao(organizacao, valores.regiaoId, valores.setorId, valores.admId).map((opcao) => (
              <option key={opcao.id} value={opcao.id}>
                {opcao.rotulo}
              </option>
            ))}
          </select>
        </Campo>
      )}

      {tem("cargo") && (
        <Campo id="rel-cargo" rotulo="Cargo">
          <select
            id="rel-cargo"
            value={valores.cargoId}
            onChange={(e) => mudar({ cargoId: e.target.value })}
            disabled={desabilitado}
            className={classeCampo}
          >
            <option value="">Todos os cargos</option>
            {(opcoes?.cargos ?? []).map((cargo) => (
              <option key={cargo.id} value={cargo.id}>
                {cargo.nome}
              </option>
            ))}
          </select>
        </Campo>
      )}

      {tem("instrumento") && (
        <Campo id="rel-instrumento" rotulo="Instrumento">
          <select
            id="rel-instrumento"
            value={valores.instrumentoId}
            onChange={(e) => mudar({ instrumentoId: e.target.value })}
            disabled={desabilitado}
            className={classeCampo}
          >
            <option value="">Todos os instrumentos</option>
            {(opcoes?.instrumentos ?? []).map((instrumento) => (
              <option key={instrumento.id} value={instrumento.id}>
                {instrumento.nome}
              </option>
            ))}
          </select>
        </Campo>
      )}

      {tem("situacaoMembro") && (
        <Campo id="rel-situacao-membro" rotulo="Situação do membro">
          <select
            id="rel-situacao-membro"
            value={valores.situacao}
            onChange={(e) => mudar({ situacao: e.target.value })}
            disabled={desabilitado}
            className={classeCampo}
          >
            <option value="">Todas</option>
            <option value="Ativo">Ativo</option>
            <option value="Inativo">Inativo</option>
          </select>
        </Campo>
      )}

      {tem("statusPresenca") && (
        <Campo id="rel-status-presenca" rotulo="Situação da presença">
          <select
            id="rel-status-presenca"
            value={valores.statusPresenca}
            onChange={(e) => mudar({ statusPresenca: e.target.value })}
            disabled={desabilitado}
            className={classeCampo}
          >
            <option value="">Todas</option>
            {STATUS_PRESENCA.map((status) => (
              <option key={status} value={status}>
                {status}
              </option>
            ))}
          </select>
        </Campo>
      )}

      {tem("visitante") && (
        <Campo id="rel-visitante" rotulo="Visitantes">
          <select
            id="rel-visitante"
            value={valores.visitante}
            onChange={(e) => mudar({ visitante: e.target.value })}
            disabled={desabilitado}
            className={classeCampo}
          >
            <option value="">Todos</option>
            <option value="sim">Somente visitantes</option>
            <option value="nao">Sem visitantes</option>
          </select>
        </Campo>
      )}

      {tem("situacaoPortaria") && (
        <Campo id="rel-situacao-portaria" rotulo="Situação da portaria">
          <select
            id="rel-situacao-portaria"
            value={valores.situacao}
            onChange={(e) => mudar({ situacao: e.target.value })}
            disabled={desabilitado}
            className={classeCampo}
          >
            <option value="">Todas</option>
            {Object.entries(ROTULO_STATUS).map(([codigo, rotulo]) => (
              <option key={codigo} value={codigo}>
                {rotulo}
              </option>
            ))}
          </select>
        </Campo>
      )}
    </div>
  );
}
