"use client";

import SeletorComum from "@/modules/organizacao/components/SeletorComum";

/**
 * SysMúsica — Formulário de evento (cadastro e edição) — conteúdo do painel lateral.
 * evento = null -> cadastrar; preenchido -> editar.
 *
 * Finalidade (combobox): sugere as finalidades já cadastradas. Se a pessoa digita uma que ainda não
 * existe, ela é salva automaticamente e passa a aparecer como sugestão nos próximos eventos.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { datetimeLocalParaIso, isoParaDatetimeLocal } from "@/lib/dataLocal";
import { normalizarTexto } from "@/lib/texto";
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
  ROTULO_COMUM,
  ROTULO_DATA,
  ROTULO_FINALIDADE,
  ROTULO_LOCAL,
  ROTULO_TIPO,
} from "@/modules/eventos/camposEvento";
import { atualizarEvento, criarEvento } from "@/modules/eventos/services/eventos";
import { obterOuCriarFinalidade } from "@/modules/eventos/services/finalidades";

interface FormularioEventoProps {
  evento: Evento | null;
  finalidades: FinalidadeEvento[];
  sugestoesCidade: string[]; // cidades já cadastradas em outros eventos
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
  finalidades,
  sugestoesCidade,
  onSalvo,
}: FormularioEventoProps) {
  const editando = evento !== null;

  const finalidadeInicial = evento?.finalidade_id
    ? (finalidades.find((finalidade) => finalidade.id === evento.finalidade_id)?.nome ?? "")
    : "";

  const [tipo, setTipo] = useState(evento?.tipo ?? "");
  const [finalidadeTexto, setFinalidadeTexto] = useState(finalidadeInicial);
  const [dataEvento, setDataEvento] = useState(evento ? isoParaDatetimeLocal(evento.data_evento) : "");
  const [local, setLocal] = useState(evento?.local ?? "");
  const [cidade, setCidade] = useState(evento?.cidade ?? "");
  const [comumId, setComumId] = useState(evento?.comum_id ?? "");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [faltando, setFaltando] = useState<string[]>([]); // campos obrigatórios vazios (borda vermelha)

  // Borda vermelha no campo obrigatório que ficou vazio
  const classeCampo = (rotulo: string) =>
    classeInput + (faltando.includes(rotulo) ? " !border-red-500 !ring-2 !ring-red-200" : "");

  // A finalidade digitada já existe? (comparação sem acento e sem diferenciar maiúsculas)
  const finalidadeDigitada = finalidadeTexto.trim();
  const finalidadeExistente = finalidadeDigitada
    ? finalidades.find(
        (finalidade) => normalizarTexto(finalidade.nome) === normalizarTexto(finalidadeDigitada)
      )
    : undefined;

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    // Todos os campos são obrigatórios: o alerta lista os que faltam e eles ficam com borda vermelha
    const vazios = camposFaltando({ tipo, finalidade: finalidadeTexto, dataEvento, local, cidade, comumId });
    setFaltando(vazios);
    if (vazios.length > 0) return setErro(mensagemCamposFaltando(vazios));

    const erroFinalidade = validarFinalidade(finalidadeTexto);
    if (erroFinalidade) return setErro(erroFinalidade);

    // O datetime-local não traz fuso: new Date() o lê como hora LOCAL do navegador e a conversão
    // para ISO (UTC) é o que o campo timestamptz do banco espera.
    const dataIso = datetimeLocalParaIso(dataEvento);
    if (!dataIso) return setErro("Informe uma data e hora válidas.");

    // Não se agenda evento em data e hora que já passaram (ao editar, só vale se a data for alterada)
    const erroData = validarDataDoEvento(dataIso, Date.now(), evento?.data_evento ?? null);
    if (erroData) return setErro(erroData);

    setSalvando(true);
    try {
      // Passo 1: finalidade (usa a existente ou salva uma nova para os próximos eventos)
      const finalidade = await obterOuCriarFinalidade(finalidadeTexto, finalidades);

      // Passo 2: grava o evento
      const dados = {
        tipo: tipo.trim(),
        data_evento: dataIso,
        local: local.trim(),
        finalidade_id: finalidade.id,
        cidade: cidade.trim() || null,
        comum_id: comumId || null,
      };
      if (evento) await atualizarEvento(evento.id, dados);
      else await criarEvento(dados);

      const complemento = finalidade.criada
        ? ` A finalidade "${finalidade.nome}" foi salva para os próximos eventos.`
        : "";
      await onSalvo(
        editando ? `Evento atualizado.${complemento}` : `Evento cadastrado com sucesso!${complemento}`
      );
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
          Tipo <span className="text-red-600"> *</span>
        </label>
        {/* Campo livre com sugestões (datalist): aceita Ensaio, Culto ou qualquer outro tipo */}
        <input
          id="tipo"
          type="text"
          list="sugestoes-tipo-evento"
          required
          value={tipo}
          onChange={(e) => setTipo(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Ensaio, Culto"
          className={classeCampo(ROTULO_TIPO)}
        />
        <datalist id="sugestoes-tipo-evento">
          <option value="Ensaio" />
          <option value="Culto" />
        </datalist>
      </div>

      {/* Finalidade (combobox): escolha uma cadastrada ou digite uma nova */}
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
        <label htmlFor="comum-evento" className="text-sm font-medium text-slate-700">
          Comum <span className="text-red-600"> *</span> <span className="font-normal text-slate-400">(define o setor da portaria)</span>
        </label>
        <SeletorComum
          id="comum-evento"
          valor={comumId}
          onChange={setComumId}
          disabled={salvando}
          className={classeCampo(ROTULO_COMUM)}
        />
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
