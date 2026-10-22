"use client";

import SeletorCasaOracao from "@/modules/organizacao/components/SeletorCasaOracao";

/**
 * Sysmusica — Formulário de evento (cadastro e edição) — conteúdo do painel lateral.
 * evento = null -> cadastrar; preenchido -> editar.
 *
 * Campos: Tipo do evento (lista do cadastro Tipo do Evento), Data e hora, Casa de Oração e Cidade.
 *  - O tipo vem da lista cadastrada em "Tipo do Evento"; o banco grava o nome do tipo em eventos.tipo.
 *    Eventos antigos sem tipo escolhido pedem para escolher um ao serem editados.
 *  - A Finalidade saiu da tela (a coluna continua no banco; eventos antigos mantêm o valor).
 *  - O "Local" também saiu: o banco exige o campo, então gravamos nele o NOME da Casa de Oração escolhida.
 *  - A Cidade vem do cadastro da Casa de Oração (função dados_casa_oracao). Se a casa não tiver cidade
 *    cadastrada, o campo fica livre para digitar e um aviso orienta a completar o cadastro dela.
 */
import { useEffect, useRef, useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { datetimeLocalParaIso, isoParaDatetimeLocal } from "@/lib/dataLocal";
import type { Evento, FinalidadeEvento } from "@/types/database";
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
import { atualizarEvento, criarEvento } from "@/modules/eventos/services/eventos";
import { tiposParaEscolher, type TipoEvento } from "@/modules/tiposEvento/regras";
import { listarTiposEvento } from "@/modules/tiposEvento/services/tiposEvento";

interface FormularioEventoProps {
  evento: Evento | null;
  /** Legado: a finalidade saiu da tela. A página ainda envia a lista, mas ela não é mais usada aqui. */
  finalidades?: FinalidadeEvento[];
  sugestoesCidade: string[]; // cidades já cadastradas em outros eventos (usadas só se a casa não tiver cidade)
  /** Chamado após salvar com sucesso, com a mensagem para o aviso da tela. */
  onSalvo: (mensagem: string) => void | Promise<void>;
}

// Mesma identidade visual dos demais formulários.
// [color-scheme:light] mantém o ícone do seletor de data visível mesmo com o navegador em tema escuro.
const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60 " +
  "[color-scheme:light]";

export default function FormularioEvento({
  evento,
  sugestoesCidade,
  onSalvo,
}: FormularioEventoProps) {
  const editando = evento !== null;

  // Tipo do evento: escolhido na lista cadastrada (eventos antigos podem não ter tipo ligado ainda)
  const [tipoEventoId, setTipoEventoId] = useState(evento?.tipo_evento_id ?? "");
  const [tipos, setTipos] = useState<TipoEvento[]>([]);
  const [erroTipos, setErroTipos] = useState<string | null>(null);
  const tipoEscolhido = tipos.find((item) => item.id === tipoEventoId);

  // Carrega a lista de tipos ao abrir o formulário (os inativos só aparecem se já forem o tipo deste evento)
  useEffect(() => {
    let ativo = true;
    listarTiposEvento()
      .then((lista) => {
        if (ativo) setTipos(lista);
      })
      .catch(() => {
        if (ativo) setErroTipos("Não foi possível carregar os tipos de evento. Feche e abra o formulário novamente.");
      });
    return () => {
      ativo = false;
    };
  }, []);
  const [dataEvento, setDataEvento] = useState(evento ? isoParaDatetimeLocal(evento.data_evento) : "");
  // "local" não aparece mais na tela: guarda o NOME da Casa de Oração (o banco exige o campo).
  const [local, setLocal] = useState(evento?.local ?? "");
  const [cidade, setCidade] = useState(evento?.cidade ?? "");
  const [casaOracaoId, setCasaOracaoId] = useState(evento?.casa_oracao_id ?? "");
  const [cidadeTravada, setCidadeTravada] = useState(false); // true = a cidade veio do cadastro da casa
  const [avisoCidade, setAvisoCidade] = useState<string | null>(null);
  const escolhaAtual = useRef(0); // descarta a resposta antiga se a pessoa trocar de casa rapidamente
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [faltando, setFaltando] = useState<string[]>([]); // campos obrigatórios vazios (borda vermelha)

  // Borda vermelha no campo obrigatório que ficou vazio
  const classeCampo = (rotulo: string) =>
    classeInput + (faltando.includes(rotulo) ? " !border-red-500 !ring-2 !ring-red-200" : "");

  // Ao escolher a Casa de Oração: o nome vai para "local" (onEscolherNome do seletor) e a cidade vem do cadastro dela.
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
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    // Todos os campos são obrigatórios: o alerta lista os que faltam e eles ficam com borda vermelha
    const vazios = camposFaltando({ tipo: tipoEscolhido?.nome ?? "", dataEvento, cidade, casaOracaoId });
    setFaltando(vazios);
    if (vazios.length > 0) return setErro(mensagemCamposFaltando(vazios));

    // O banco exige o "local": ele vem do nome da casa escolhida na lista
    if (!local.trim()) return setErro("Escolha a Casa de Oração na lista.");

    // O datetime-local não traz fuso: new Date() o lê como hora LOCAL do navegador e a conversão
    // para ISO (UTC) é o que o campo timestamptz do banco espera.
    const dataIso = datetimeLocalParaIso(dataEvento);
    if (!dataIso) return setErro("Informe uma data e hora válidas.");

    // Não se agenda evento em data e hora que já passaram (ao editar, só vale se a data for alterada)
    const erroData = validarDataDoEvento(dataIso, Date.now(), evento?.data_evento ?? null);
    if (erroData) return setErro(erroData);

    setSalvando(true);
    try {
      // Grava o evento. A finalidade não é mais enviada: eventos antigos mantêm a que já tinham.
      const dados = {
        tipo: tipoEscolhido?.nome ?? "", // o banco mantém eventos.tipo igual ao nome do tipo escolhido
        tipo_evento_id: tipoEventoId,
        data_evento: dataIso,
        local: local.trim(),
        cidade: cidade.trim() || null,
        casa_oracao_id: casaOracaoId || null,
      };
      if (evento) await atualizarEvento(evento.id, dados);
      else await criarEvento(dados);

      await onSalvo(editando ? "Evento atualizado." : "Evento cadastrado com sucesso!");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar o evento.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} noValidate className="space-y-5">
      <p className="text-xs text-slate-500">Todos os campos são obrigatórios (marcados com *).</p>

      <div className="space-y-1.5">
        <label htmlFor="tipo" className="text-sm font-medium text-slate-700">
          Tipo do evento <span className="text-red-600"> *</span>
        </label>
        {/* Lista dos tipos cadastrados em "Tipo do Evento" (só os ativos, mais o tipo atual do evento) */}
        <select
          id="tipo"
          required
          value={tipoEventoId}
          onChange={(e) => setTipoEventoId(e.target.value)}
          disabled={salvando}
          className={classeCampo(ROTULO_TIPO)}
        >
          <option value="">Selecione o tipo...</option>
          {tiposParaEscolher(tipos, tipoEventoId || null).map((item) => (
            <option key={item.id} value={item.id}>
              {item.nome}
            </option>
          ))}
        </select>
        {evento && !evento.tipo_evento_id && (
          <p role="status" className="text-xs text-amber-700">
            Tipo antigo: “{evento.tipo}”. Escolha o tipo na lista para ligar este evento ao cadastro.
          </p>
        )}
        {erroTipos && (
          <p role="alert" className="text-xs text-red-700">
            {erroTipos}
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
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Cadastrar evento"}
      </Button>
    </form>
  );
}
