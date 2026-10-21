#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 2: formulário de EVENTO
#
#  - Remove "Finalidade do evento" da tela (a coluna e os dados antigos continuam no banco)
#  - "Tipo" passa a se chamar "Descrição do evento"
#  - Remove "Local": o campo "Casa de Oração" ocupa o lugar dele, e o NOME da casa é gravado em "local"
#    (o banco exige esse campo)
#  - Ao escolher a Casa de Oração, a CIDADE é preenchida com a cidade cadastrada nela
#    (nova função do banco: migração 0037 — NÃO altera tabelas)
#  - Lista de eventos: coluna "Descrição do evento" e "Casa de Oração"; some a coluna Finalidade
#
# ORDEM CERTA:  1) rodar este instalador   2) rodar o SQL 0037 no Supabase   3) conferir as telas   4) git push
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-parte2-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && bash instalar-parte2-eventos.sh
# Log:  /tmp/instalar-parte2.log
# =============================================================================

LOG=/tmp/instalar-parte2.log
BKP=/tmp/bkp-parte2-$(date +%Y%m%d-%H%M%S)
RAIZ="$(pwd)"

(
[ -f package.json ] && [ -d src ] || { echo "ERRO: rode dentro da pasta sysmusica (onde está o package.json)."; exit 1; }
mkdir -p "$BKP"
export BKP RAIZ

echo "== 1/3  Conferindo e aplicando as alterações =="
python3 - <<'PYSCRIPT'
import os, shutil, sys

RAIZ = os.environ["RAIZ"]
BKP = os.environ["BKP"]

# (arquivo, trecho antigo, trecho novo) — cada "antigo" precisa existir EXATAMENTE 1 vez no arquivo.
# Os trechos usam \n; o instalador converte para o fim de linha do próprio arquivo (CRLF ou LF).
EDITS = [
    ("src/components/FormularioEvento.tsx",
     r''' * Finalidade (combobox): sugere as finalidades já cadastradas. Se a pessoa digita uma que ainda não
 * existe, ela é salva automaticamente e passa a aparecer como sugestão nos próximos eventos.
 */''',
     r''' * Campos: Descrição do evento, Data e hora, Casa de Oração e Cidade.
 *  - A Finalidade saiu da tela (a coluna continua no banco; eventos antigos mantêm o valor).
 *  - O "Local" também saiu: o banco exige o campo, então gravamos nele o NOME da Casa de Oração escolhida.
 *  - A Cidade vem do cadastro da Casa de Oração (função dados_casa_oracao). Se a casa não tiver cidade
 *    cadastrada, o campo fica livre para digitar e um aviso orienta a completar o cadastro dela.
 */'''),
    ("src/components/FormularioEvento.tsx",
     r'''import { useState, type FormEvent } from "react";''',
     r'''import { useRef, useState, type FormEvent } from "react";'''),
    ("src/components/FormularioEvento.tsx",
     r'''import { normalizarTexto } from "@/lib/texto";
import type { Evento, FinalidadeEvento } from "@/types/database";
import {
  FINALIDADE_MAXIMO,
  formatarNomeFinalidade,
  validarFinalidade,
} from "@/modules/eventos/regras";
import { validarDataDoEvento } from "@/modules/eventos/dataEvento";
import {
  camposFaltando,
  mensagemCamposFaltando,
  ROTULO_CIDADE,
  ROTULO_CASA_ORACAO,
  ROTULO_DATA,
  ROTULO_FINALIDADE,
  ROTULO_LOCAL,
  ROTULO_TIPO,
} from "@/modules/eventos/camposEvento";
import { atualizarEvento, criarEvento } from "@/modules/eventos/services/eventos";
import { obterOuCriarFinalidade } from "@/modules/eventos/services/finalidades";''',
     r'''import type { Evento, FinalidadeEvento } from "@/types/database";
import { validarDataDoEvento } from "@/modules/eventos/dataEvento";
import {
  camposFaltando,
  mensagemCamposFaltando,
  ROTULO_CIDADE,
  ROTULO_CASA_ORACAO,
  ROTULO_DATA,
  ROTULO_TIPO,
} from "@/modules/eventos/camposEvento";
import { cidadeDaCasa } from "@/modules/eventos/casaDoEvento";
import { buscarDadosDaCasa } from "@/modules/eventos/services/casaDoEvento";
import { atualizarEvento, criarEvento } from "@/modules/eventos/services/eventos";'''),
    ("src/components/FormularioEvento.tsx",
     r'''  finalidades: FinalidadeEvento[];
  sugestoesCidade: string[]; // cidades já cadastradas em outros eventos''',
     r'''  /** Legado: a finalidade saiu da tela. A página ainda envia a lista, mas ela não é mais usada aqui. */
  finalidades?: FinalidadeEvento[];
  sugestoesCidade: string[]; // cidades já cadastradas em outros eventos (usadas só se a casa não tiver cidade)'''),
    ("src/components/FormularioEvento.tsx",
     r'''  finalidades,
  sugestoesCidade,''',
     r'''  sugestoesCidade,'''),
    ("src/components/FormularioEvento.tsx",
     r'''  const finalidadeInicial = evento?.finalidade_id
    ? (finalidades.find((finalidade) => finalidade.id === evento.finalidade_id)?.nome ?? "")
    : "";

  const [tipo, setTipo] = useState(evento?.tipo ?? "");
  const [finalidadeTexto, setFinalidadeTexto] = useState(finalidadeInicial);''',
     r'''  const [tipo, setTipo] = useState(evento?.tipo ?? "");'''),
    ("src/components/FormularioEvento.tsx",
     r'''  const [local, setLocal] = useState(evento?.local ?? "");
  const [cidade, setCidade] = useState(evento?.cidade ?? "");
  const [casaOracaoId, setCasaOracaoId] = useState(evento?.casa_oracao_id ?? "");''',
     r'''  // "local" não aparece mais na tela: guarda o NOME da Casa de Oração (o banco exige o campo).
  const [local, setLocal] = useState(evento?.local ?? "");
  const [cidade, setCidade] = useState(evento?.cidade ?? "");
  const [casaOracaoId, setCasaOracaoId] = useState(evento?.casa_oracao_id ?? "");
  const [cidadeTravada, setCidadeTravada] = useState(false); // true = a cidade veio do cadastro da casa
  const [avisoCidade, setAvisoCidade] = useState<string | null>(null);
  const escolhaAtual = useRef(0); // descarta a resposta antiga se a pessoa trocar de casa rapidamente'''),
    ("src/components/FormularioEvento.tsx",
     r'''  // A finalidade digitada já existe? (comparação sem acento e sem diferenciar maiúsculas)
  const finalidadeDigitada = finalidadeTexto.trim();
  const finalidadeExistente = finalidadeDigitada
    ? finalidades.find(
        (finalidade) => normalizarTexto(finalidade.nome) === normalizarTexto(finalidadeDigitada)
      )
    : undefined;''',
     r'''  // Ao escolher a Casa de Oração: o nome vai para "local" (onEscolherNome do seletor) e a cidade vem do cadastro dela.
  async function aoEscolherCasa(id: string) {
    setCasaOracaoId(id);
    setAvisoCidade(null);
    const escolha = ++escolhaAtual.current;
    if (!id) {
      setCidade("");
      setCidadeTravada(false);
      return;
    }
    try {
      const resultado = cidadeDaCasa(await buscarDadosDaCasa(id));
      if (escolha !== escolhaAtual.current) return; // chegou depois de outra escolha: ignora
      setCidade(resultado.cidade);
      setCidadeTravada(resultado.travada);
      setAvisoCidade(resultado.aviso);
    } catch {
      if (escolha !== escolhaAtual.current) return;
      setCidade("");
      setCidadeTravada(false);
      setAvisoCidade("Não foi possível buscar a cidade desta Casa de Oração. Informe a cidade abaixo.");
    }
  }'''),
    ("src/components/FormularioEvento.tsx",
     r'''    const vazios = camposFaltando({ tipo, finalidade: finalidadeTexto, dataEvento, local, cidade, casaOracaoId });
    setFaltando(vazios);
    if (vazios.length > 0) return setErro(mensagemCamposFaltando(vazios));

    const erroFinalidade = validarFinalidade(finalidadeTexto);
    if (erroFinalidade) return setErro(erroFinalidade);''',
     r'''    const vazios = camposFaltando({ tipo, dataEvento, cidade, casaOracaoId });
    setFaltando(vazios);
    if (vazios.length > 0) return setErro(mensagemCamposFaltando(vazios));

    // O banco exige o "local": ele vem do nome da casa escolhida na lista
    if (!local.trim()) return setErro("Escolha a Casa de Oração na lista.");'''),
    ("src/components/FormularioEvento.tsx",
     r'''      // Passo 1: finalidade (usa a existente ou salva uma nova para os próximos eventos)
      const finalidade = await obterOuCriarFinalidade(finalidadeTexto, finalidades);

      // Passo 2: grava o evento
      const dados = {
        tipo: tipo.trim(),
        data_evento: dataIso,
        local: local.trim(),
        finalidade_id: finalidade.id,
        cidade: cidade.trim() || null,
        casa_oracao_id: casaOracaoId || null,
      };
      if (evento) await atualizarEvento(evento.id, dados);
      else await criarEvento(dados);

      const complemento = finalidade.criada
        ? ` A finalidade "${finalidade.nome}" foi salva para os próximos eventos.`
        : "";
      await onSalvo(
        editando ? `Evento atualizado.${complemento}` : `Evento cadastrado com sucesso!${complemento}`
      );''',
     r'''      // Grava o evento. A finalidade não é mais enviada: eventos antigos mantêm a que já tinham.
      const dados = {
        tipo: tipo.trim(),
        data_evento: dataIso,
        local: local.trim(),
        cidade: cidade.trim() || null,
        casa_oracao_id: casaOracaoId || null,
      };
      if (evento) await atualizarEvento(evento.id, dados);
      else await criarEvento(dados);

      await onSalvo(editando ? "Evento atualizado." : "Evento cadastrado com sucesso!");'''),
    ("src/components/FormularioEvento.tsx",
     r'''Tipo <span className="text-red-600"> *</span>''',
     r'''Descrição do evento <span className="text-red-600"> *</span>'''),
    ("src/components/FormularioEvento.tsx",
     r'''placeholder="Ex: Ensaio, Culto"''',
     r'''placeholder="Ex: Ensaio Regional, Culto Oficial"'''),
    ("src/components/FormularioEvento.tsx",
     r'''      {/* Finalidade (combobox): escolha uma cadastrada ou digite uma nova */}
      <div className="space-y-1.5">
        <label htmlFor="finalidade" className="text-sm font-medium text-slate-700">
          Finalidade do evento <span className="text-red-600"> *</span>
        </label>
        <input
          id="finalidade"
          type="text"
          list="lista-finalidades"
          autoComplete="off"
          required
          maxLength={FINALIDADE_MAXIMO}
          value={finalidadeTexto}
          onChange={(e) => setFinalidadeTexto(e.target.value)}
          disabled={salvando}
          placeholder="Digite ou escolha uma finalidade"
          className={classeCampo(ROTULO_FINALIDADE)}
        />
        <datalist id="lista-finalidades">
          {finalidades.map((finalidade) => (
            <option key={finalidade.id} value={finalidade.nome} />
          ))}
        </datalist>
        {/* Feedback ao vivo: finalidade já cadastrada ou nova (será salva para os próximos eventos) */}
        {finalidadeDigitada && (
          <p className={"text-xs " + (finalidadeExistente ? "text-slate-500" : "text-brand-700")}>
            {finalidadeExistente
              ? "Finalidade já cadastrada."
              : `Nova finalidade: "${formatarNomeFinalidade(finalidadeDigitada)}" será salva para os próximos eventos.`}
          </p>
        )}
      </div>

      <div className="space-y-1.5">
        <label htmlFor="data_evento" className="text-sm font-medium text-slate-700">
          Data e hora <span className="text-red-600"> *</span>
        </label>
        <input
          id="data_evento"
          type="datetime-local"
          required
          value={dataEvento}
          onChange={(e) => setDataEvento(e.target.value)}
          disabled={salvando}
          className={classeCampo(ROTULO_DATA)}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="local" className="text-sm font-medium text-slate-700">
          Local <span className="text-red-600"> *</span>
        </label>
        <input
          id="local"
          type="text"
          required
          value={local}
          onChange={(e) => setLocal(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Congregação Central"
          className={classeCampo(ROTULO_LOCAL)}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="cidade-evento" className="text-sm font-medium text-slate-700">
          Cidade <span className="text-red-600"> *</span>
        </label>
        <datalist id="sugestoes-cidade-evento">
          {sugestoesCidade.map((sugestao) => (
            <option key={sugestao} value={sugestao} />
          ))}
        </datalist>
        <input
          id="cidade-evento"
          type="text"
          list="sugestoes-cidade-evento"
          autoComplete="off"
          value={cidade}
          onChange={(e) => setCidade(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Lauro de Freitas"
          className={classeCampo(ROTULO_CIDADE)}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="casa-oracao-evento" className="text-sm font-medium text-slate-700">
          Casa de Oração <span className="text-red-600"> *</span> <span className="font-normal text-slate-400">(define o setor da portaria)</span>
        </label>
        <SeletorCasaOracao
          id="casa-oracao-evento"
          valor={casaOracaoId}
          onChange={setCasaOracaoId}
          disabled={salvando}
          className={classeCampo(ROTULO_CASA_ORACAO)}
        />
      </div>''',
     r'''      <div className="space-y-1.5">
        <label htmlFor="data_evento" className="text-sm font-medium text-slate-700">
          Data e hora <span className="text-red-600"> *</span>
        </label>
        <input
          id="data_evento"
          type="datetime-local"
          required
          value={dataEvento}
          onChange={(e) => setDataEvento(e.target.value)}
          disabled={salvando}
          className={classeCampo(ROTULO_DATA)}
        />
      </div>

      {/* Casa de Oração (no lugar do antigo "Local"): o nome vai para "local" e a cidade vem do cadastro dela */}
      <div className="space-y-1.5">
        <label htmlFor="casa-oracao-evento" className="text-sm font-medium text-slate-700">
          Casa de Oração <span className="text-red-600"> *</span> <span className="font-normal text-slate-400">(define o setor da portaria)</span>
        </label>
        <SeletorCasaOracao
          id="casa-oracao-evento"
          valor={casaOracaoId}
          onChange={(id) => void aoEscolherCasa(id)}
          onEscolherNome={setLocal}
          disabled={salvando}
          className={classeCampo(ROTULO_CASA_ORACAO)}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="cidade-evento" className="text-sm font-medium text-slate-700">
          Cidade <span className="text-red-600"> *</span>
        </label>
        <datalist id="sugestoes-cidade-evento">
          {sugestoesCidade.map((sugestao) => (
            <option key={sugestao} value={sugestao} />
          ))}
        </datalist>
        {/* Cidade vinda do cadastro da casa fica travada; sem cidade cadastrada, a pessoa digita */}
        <input
          id="cidade-evento"
          type="text"
          list="sugestoes-cidade-evento"
          autoComplete="off"
          value={cidade}
          onChange={(e) => setCidade(e.target.value)}
          readOnly={cidadeTravada}
          disabled={salvando}
          placeholder="Preenchida ao escolher a Casa de Oração"
          className={classeCampo(ROTULO_CIDADE) + " read-only:bg-slate-50 read-only:text-slate-600"}
        />
        {cidadeTravada && <p className="text-xs text-slate-500">Preenchida pelo cadastro da Casa de Oração.</p>}
        {avisoCidade && (
          <p role="status" className="text-xs text-amber-700">
            {avisoCidade}
          </p>
        )}
      </div>'''),
    ("src/components/ListaEventos.tsx",
     r'''              <th scope="col" className={classeCabecalho}>
                Tipo
              </th>''',
     r'''              <th scope="col" className={classeCabecalho}>
                Descrição do evento
              </th>'''),
    ("src/components/ListaEventos.tsx",
     r'''              <th scope="col" className={classeCabecalho + " hidden md:table-cell"}>
                Finalidade
              </th>
''',
     r''''''),
    ("src/components/ListaEventos.tsx",
     r'''              <th scope="col" className={classeCabecalho + " hidden md:table-cell"}>
                Local
              </th>''',
     r'''              <th scope="col" className={classeCabecalho + " hidden md:table-cell"}>
                Casa de Oração
              </th>'''),
    ("src/components/ListaEventos.tsx",
     r'''colSpan={mostrarAcoes ? 6 : 5}''',
     r'''colSpan={mostrarAcoes ? 5 : 4}'''),
    ("src/components/ListaEventos.tsx",
     r'''                    <td className="hidden max-w-sm px-4 py-3 text-slate-700 md:table-cell">
                      {finalidade ?? <span className="text-slate-400">—</span>}
                    </td>
''',
     r''''''),
    ("src/components/ListaEventos.tsx",
     r'''            Pesquisar por finalidade, local ou tipo
          </label>''',
     r'''            Pesquisar por descrição ou Casa de Oração
          </label>'''),
    ("src/components/ListaEventos.tsx",
     r'''placeholder="Pesquisar por finalidade, local ou tipo..."''',
     r'''placeholder="Pesquisar por descrição ou Casa de Oração..."'''),
    ("src/modules/eventos/camposEvento.ts",
     r'''export interface CamposEvento {
  tipo: string;
  finalidade: string;
  dataEvento: string; // valor do campo data e hora (vazio = não preenchido)
  local: string;
  cidade: string;
  casaOracaoId: string;
}''',
     r'''export interface CamposEvento {
  tipo: string; // "Descrição do evento" na tela
  dataEvento: string; // valor do campo data e hora (vazio = não preenchido)
  cidade: string;
  casaOracaoId: string;
}'''),
    ("src/modules/eventos/camposEvento.ts",
     r'''export const ROTULO_TIPO = "Tipo";
export const ROTULO_FINALIDADE = "Finalidade do evento";
export const ROTULO_DATA = "Data e hora";
export const ROTULO_LOCAL = "Local";
export const ROTULO_CIDADE = "Cidade";''',
     r'''export const ROTULO_TIPO = "Descrição do evento";
export const ROTULO_DATA = "Data e hora";
export const ROTULO_CIDADE = "Cidade";'''),
    ("src/modules/eventos/camposEvento.ts",
     r'''  if (!campos.tipo.trim()) faltando.push(ROTULO_TIPO);
  if (!campos.finalidade.trim()) faltando.push(ROTULO_FINALIDADE);
  if (!campos.dataEvento.trim()) faltando.push(ROTULO_DATA);
  if (!campos.local.trim()) faltando.push(ROTULO_LOCAL);
  if (!campos.cidade.trim()) faltando.push(ROTULO_CIDADE);
  if (!campos.casaOracaoId.trim()) faltando.push(ROTULO_CASA_ORACAO);''',
     r'''  // Ordem do formulário: Descrição do evento, Data e hora, Casa de Oração, Cidade
  if (!campos.tipo.trim()) faltando.push(ROTULO_TIPO);
  if (!campos.dataEvento.trim()) faltando.push(ROTULO_DATA);
  if (!campos.casaOracaoId.trim()) faltando.push(ROTULO_CASA_ORACAO);
  if (!campos.cidade.trim()) faltando.push(ROTULO_CIDADE);'''),
    ("src/modules/eventos/camposEvento.test.ts",
     r'''const completo: CamposEvento = {
  tipo: "Ensaio",
  finalidade: "Ensaio Regional",
  dataEvento: "2026-10-25T10:00",
  local: "Casa de Oração de Cidade Nova",
  cidade: "Jequié",
  casaOracaoId: "abc",
};''',
     r'''const completo: CamposEvento = {
  tipo: "Ensaio Regional",
  dataEvento: "2026-10-25T10:00",
  cidade: "Jequié",
  casaOracaoId: "abc",
};'''),
    ("src/modules/eventos/camposEvento.test.ts",
     r'''  it("aponta o Local vazio (caso do print) e a ordem do formulário", () => {
    expect(camposFaltando({ ...completo, local: "" })).toEqual(["Local"]);
    expect(camposFaltando({ tipo: "", finalidade: "", dataEvento: "", local: "", cidade: "", casaOracaoId: "" })).toEqual([
      "Tipo",
      "Finalidade do evento",
      "Data e hora",
      "Local",
      "Cidade",
      "Casa de Oração",
    ]);
  });''',
     r'''  it("aponta o campo vazio e respeita a ordem do formulário", () => {
    expect(camposFaltando({ ...completo, cidade: "" })).toEqual(["Cidade"]);
    expect(camposFaltando({ tipo: "", dataEvento: "", cidade: "", casaOracaoId: "" })).toEqual([
      "Descrição do evento",
      "Data e hora",
      "Casa de Oração",
      "Cidade",
    ]);
  });'''),
    ("src/modules/eventos/camposEvento.test.ts",
     r'''  it("espaços em branco contam como vazio", () => {
    expect(camposFaltando({ ...completo, cidade: "   ", local: " " })).toEqual(["Local", "Cidade"]);
  });''',
     r'''  it("espaços em branco contam como vazio", () => {
    expect(camposFaltando({ ...completo, cidade: "   ", tipo: " " })).toEqual(["Descrição do evento", "Cidade"]);
  });'''),
    ("src/modules/eventos/services/eventos.ts",
     r'''  finalidade_id: string | null;''',
     r'''  finalidade_id?: string | null; // opcional: a tela não envia mais (mantém o valor atual)'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    "src/modules/eventos/casaDoEvento.ts": r'''/**
 * SysMúsica — Regra pura: cidade do evento a partir da Casa de Oração escolhida (sem banco).
 * A cidade vem do cadastro da casa e fica travada na tela. Se a casa não tem cidade cadastrada
 * (ou o cadastro não pôde ser lido), o campo fica livre para digitar e um aviso orienta a completar o cadastro.
 */
export interface DadosDaCasa {
  nome: string;
  cidade: string | null;
}

export interface CidadeDaCasa {
  cidade: string; // texto para o campo Cidade ("" = a pessoa precisa informar)
  travada: boolean; // true = veio do cadastro da casa (campo somente leitura)
  aviso: string | null;
}

export const AVISO_SEM_CIDADE =
  "Esta Casa de Oração ainda não tem cidade cadastrada. Informe a cidade abaixo e depois complete o cadastro dela em Organização.";

export function cidadeDaCasa(casa: DadosDaCasa | null): CidadeDaCasa {
  const cidade = casa?.cidade?.trim() ?? "";
  if (cidade) return { cidade, travada: true, aviso: null };
  return { cidade: "", travada: false, aviso: AVISO_SEM_CIDADE };
}
''',
    "src/modules/eventos/casaDoEvento.test.ts": r'''import { describe, expect, it } from "vitest";
import { AVISO_SEM_CIDADE, cidadeDaCasa } from "./casaDoEvento";

describe("cidadeDaCasa", () => {
  it("usa a cidade cadastrada na casa e trava o campo", () => {
    expect(cidadeDaCasa({ nome: "Cidade Nova", cidade: "Jequié" })).toEqual({
      cidade: "Jequié",
      travada: true,
      aviso: null,
    });
  });

  it("tira espaços extras da cidade", () => {
    expect(cidadeDaCasa({ nome: "Cidade Nova", cidade: "  Jequié  " }).cidade).toBe("Jequié");
  });

  it("casa sem cidade cadastrada: campo livre e aviso", () => {
    for (const cidade of [null, "", "   "]) {
      expect(cidadeDaCasa({ nome: "Cidade Nova", cidade })).toEqual({
        cidade: "",
        travada: false,
        aviso: AVISO_SEM_CIDADE,
      });
    }
  });

  it("casa não encontrada (fora da abrangência): campo livre e aviso", () => {
    expect(cidadeDaCasa(null)).toEqual({ cidade: "", travada: false, aviso: AVISO_SEM_CIDADE });
  });
});
''',
    "src/modules/eventos/services/casaDoEvento.ts": r'''/**
 * SysMúsica — Busca os dados de UMA Casa de Oração para o formulário de evento (nome e cidade).
 * Usa a função do banco dados_casa_oracao (migração 0037), que respeita a abrangência do usuário:
 * fora dela devolve nulo e a tela pede a cidade manualmente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { DadosDaCasa } from "../casaDoEvento";

export async function buscarDadosDaCasa(casaOracaoId: string): Promise<DadosDaCasa | null> {
  const { data, error } = await supabase.rpc("dados_casa_oracao", { p_casa_oracao: casaOracaoId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível buscar os dados da Casa de Oração."));
  return (data ?? null) as DadosDaCasa | null;
}
''',
    "supabase/migrations/0037_dados_casa_oracao.sql": r'''-- =====================================================================
-- SysMúsica — Migração 0037: dados de uma Casa de Oração para o formulário de evento
--
-- Devolve nome e cidade de UMA casa de oração, respeitando a abrangência do usuário
-- (mesma regra do seletor de casas). A tela de eventos usa para preencher a Cidade
-- quando a pessoa escolhe a Casa de Oração. NÃO altera nenhuma tabela.
-- =====================================================================

create or replace function public.dados_casa_oracao(p_casa_oracao uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v jsonb;
begin
  -- Fora da abrangência do usuário (ou id vazio): devolve nulo; a tela pede a cidade manualmente.
  if p_casa_oracao is null or not public.casa_oracao_na_abrangencia(p_casa_oracao) then
    return null;
  end if;

  select jsonb_build_object('id', c.id, 'nome', c.nome, 'cidade', c.cidade, 'bairro', c.bairro)
    into v
    from public.casas_oracao c
   where c.id = p_casa_oracao;

  return v;
end;
$$;

-- Só usuários logados chamam (nunca anônimos).
revoke all on function public.dados_casa_oracao(uuid) from public;
revoke all on function public.dados_casa_oracao(uuid) from anon;
grant execute on function public.dados_casa_oracao(uuid) to authenticated;
''',
}


def ler(caminho):
    with open(caminho, "r", encoding="utf-8", newline="") as f:
        return f.read()

def eol_de(txt):
    return "\r\n" if "\r\n" in txt else "\n"

def adaptar(trecho, eol):
    return trecho.replace("\n", eol) if eol != "\n" else trecho

conteudo, problemas = {}, []
for arq, antigo, novo in EDITS:
    if arq in conteudo:
        continue
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"ARQUIVO NÃO ENCONTRADO: {arq}")
        conteudo[arq] = None
    else:
        conteudo[arq] = ler(caminho)

for arq, antigo, novo in EDITS:
    txt = conteudo.get(arq)
    if txt is None:
        continue
    n = txt.count(adaptar(antigo, eol_de(txt)))
    if n != 1:
        resumo = antigo.strip().split("\n")[0][:80]
        problemas.append(f"{arq}: trecho «{resumo}…» aparece {n} vez(es) (esperado 1)")

for arq in NOVOS:
    if os.path.exists(os.path.join(RAIZ, arq)):
        problemas.append(f"JÁ EXISTE (não vou sobrescrever): {arq}")

if problemas:
    print("NADA FOI ALTERADO. Divergências encontradas:")
    for p in problemas:
        print("  -", p)
    print("Se TODOS dizem 0 vez(es) / JÁ EXISTE, esta parte provavelmente já foi aplicada.")
    sys.exit(2)

alterados, criados = [], []
for arq in dict.fromkeys(a for a, _, _ in EDITS):
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    txt = conteudo[arq]
    eol = eol_de(txt)
    for a, antigo, novo in EDITS:
        if a != arq:
            continue
        ant = adaptar(antigo, eol)
        if txt.count(ant) != 1:
            print(f"ERRO: {arq}: trecho mudou durante a aplicação. Nada foi gravado.")
            sys.exit(2)
        txt = txt.replace(ant, adaptar(novo, eol), 1)
    with open(origem, "w", encoding="utf-8", newline="") as f:
        f.write(txt)
    alterados.append(arq)

for arq, cont in NOVOS.items():
    destino = os.path.join(RAIZ, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    with open(destino, "w", encoding="utf-8", newline="") as f:
        f.write(cont)
    criados.append(arq)

with open(os.path.join(BKP, ".arquivos"), "w", encoding="utf-8") as f:
    f.write("\n".join(a for a in alterados + criados if a.endswith((".ts", ".tsx"))) + "\n")
with open(os.path.join(BKP, ".novos"), "w", encoding="utf-8") as f:
    f.write("\n".join(criados) + "\n")
print(f"OK: {len(EDITS)} trocas em {len(alterados)} arquivos + {len(criados)} arquivos novos. Backup em {BKP}")
PYSCRIPT
rc=$?
[ $rc -eq 0 ] || { echo "Nada foi alterado (veja acima)."; exit 1; }

reverter() {
  echo "↩ Desfazendo as alterações a partir de $BKP ..."
  ( cd "$BKP" && find . -type f ! -name .arquivos ! -name .novos -print0 | while IFS= read -r -d '' f; do cp "$f" "$RAIZ/$f"; done )
  while IFS= read -r n; do [ -n "$n" ] && rm -f "$RAIZ/$n"; done < "$BKP/.novos"
}

passo() {
  nome="$1"; shift
  echo "▶ $nome"
  if "$@" > /tmp/p2-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p2-passo.out
    reverter; echo "Alterações desfeitas. Me envie o log: $LOG"
    exit 1
  fi
}

echo; echo "== 2/3  Verificações =="
mapfile -t ARQ < <(grep -v '^$' "$BKP/.arquivos")
passo "tipos (tsc)"      npx tsc --noEmit
passo "testes (vitest)"  npx vitest run
passo "lint (eslint)"    npx eslint "${ARQ[@]}"
passo "build"            npm run build

echo; echo "== 3/3  PRONTO =="
echo "Backup: $BKP"
echo "PRÓXIMO PASSO (antes do git push): rodar o SQL no Supabase —"
echo "  abra supabase/migrations/0037_dados_casa_oracao.sql no Explorer, copie tudo,"
echo "  cole no Supabase > SQL Editor > New query > Run (se pedir, clique em 'Run without RLS')."
) 2>&1 | tee "$LOG"
