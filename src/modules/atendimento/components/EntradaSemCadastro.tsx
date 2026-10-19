"use client";

/**
 * SysMúsica — Entrada SEM cadastro (candidato, visitante...). Não cria membro: registra só o cargo/categoria,
 * se vai tocar, o instrumento e a localidade de origem (opcional). A entrada entra na contagem do painel ao vivo.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import {
  agruparLinhas,
  precisaInstrumento,
  precisaPerguntar,
  textoDaLocalidade,
  validarEntradaAvulsa,
} from "../regrasEntrada";
import { registrarEntradaAvulsa } from "../services/entrada";
import type { LinhaEntrada, LocalidadeBusca, OpcoesEntrada } from "../tiposEntrada";
import BuscaLocalidade from "./BuscaLocalidade";
import PerguntaToca from "./PerguntaToca";

interface EntradaSemCadastroProps {
  portariaId: string;
  opcoes: OpcoesEntrada;
  onRegistrada: (descricao: string) => void;
}

export default function EntradaSemCadastro({ portariaId, opcoes, onRegistrada }: EntradaSemCadastroProps) {
  const [linhaCodigo, setLinhaCodigo] = useState("");
  const [toca, setToca] = useState<boolean | null>(null);
  const [instrumentoId, setInstrumentoId] = useState("");
  const [localidade, setLocalidade] = useState<LocalidadeBusca | null>(null);
  const [outra, setOutra] = useState(false);
  const [texto, setTexto] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const linha: LinhaEntrada | null = opcoes.linhas.find((item) => item.codigo === linhaCodigo) ?? null;
  const perguntar = precisaPerguntar(linha);
  const pedirInstrumento = precisaInstrumento(linha, toca);

  // Trocar a linha limpa as respostas que dependem dela
  function escolherLinha(codigo: string) {
    setLinhaCodigo(codigo);
    setToca(null);
    setInstrumentoId("");
    setErro(null);
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return;

    const mensagem = validarEntradaAvulsa({ linha, toca, instrumentoId, outraLocalidade: outra, localidadeTexto: texto });
    if (mensagem) return setErro(mensagem);

    setSalvando(true);
    setErro(null);
    try {
      await registrarEntradaAvulsa(portariaId, {
        linhaCodigo,
        toca: perguntar ? toca : null,
        instrumentoId: pedirInstrumento ? instrumentoId : null,
        origemCasaOracaoId: localidade?.casa_oracao_id ?? null,
        origemTexto: localidade ? null : textoDaLocalidade(outra, texto),
      });
      onRegistrada(linha?.rotulo ?? "Entrada sem cadastro");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível registrar a entrada.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} noValidate className="space-y-5">
      <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
        Não cria cadastro. A pessoa só entra na contagem do evento.
      </p>

      <div className="space-y-1.5">
        <label htmlFor="avulsa-linha" className="text-sm font-medium text-slate-700">
          Cargo / categoria
        </label>
        <select
          id="avulsa-linha"
          value={linhaCodigo}
          onChange={(e) => escolherLinha(e.target.value)}
          disabled={salvando}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
        >
          <option value="">Selecione</option>
          {agruparLinhas(opcoes.linhas).map((grupo) => (
            <optgroup key={grupo.bloco} label={grupo.rotulo}>
              {grupo.linhas.map((item) => (
                <option key={item.codigo} value={item.codigo}>
                  {item.rotulo}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
      </div>

      {(perguntar || pedirInstrumento) && (
        <PerguntaToca
          prefixo="avulsa"
          perguntar={perguntar}
          pedirInstrumento={pedirInstrumento}
          toca={toca}
          onToca={(valor) => {
            setToca(valor);
            if (!valor) setInstrumentoId("");
          }}
          instrumentoId={instrumentoId}
          onInstrumento={setInstrumentoId}
          instrumentos={opcoes.instrumentos}
          desabilitado={salvando}
        />
      )}

      <BuscaLocalidade
        escolhida={localidade}
        onEscolher={setLocalidade}
        outra={outra}
        onOutra={setOutra}
        texto={texto}
        onTexto={setTexto}
        desabilitado={salvando}
      />

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full py-3 text-base">
        {salvando ? "Registrando..." : "Registrar entrada"}
      </Button>
    </form>
  );
}
