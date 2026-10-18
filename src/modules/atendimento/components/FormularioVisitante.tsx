"use client";

/**
 * SysMúsica — Cadastro rápido de visitante na portaria (painel lateral).
 * Para o irmão de outra região (ou sem cadastro) que vem congregar: nome completo, cargo ou ministério,
 * instrumento (opcional) e de onde vem. O visitante é cadastrado na COMUM da portaria em atendimento e
 * só a região dela o enxerga. Depois de salvar, abre a conferência para registrar a entrada.
 * O banco confere permissão, portaria aprovada, abrangência e nome repetido na comum.
 */
import { useEffect, useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { validarDadosVisitante } from "../regras";
import { cadastrarVisitante, listarOpcoesVisitante } from "../services/atendimento";
import type { CartaoMembro, OpcoesVisitante } from "../tipos";

interface FormularioVisitanteProps {
  portariaId: string;
  onCadastrado: (cartao: CartaoMembro) => void;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 " +
  "shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60";

export default function FormularioVisitante({ portariaId, onCadastrado }: FormularioVisitanteProps) {
  const [opcoes, setOpcoes] = useState<OpcoesVisitante | null>(null); // nulo = carregando
  const [nome, setNome] = useState("");
  const [cargoId, setCargoId] = useState("");
  const [instrumentoId, setInstrumentoId] = useState("");
  const [igreja, setIgreja] = useState("");
  const [cidade, setCidade] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  /* eslint-disable react-hooks/set-state-in-effect */
  useEffect(() => {
    let cancelado = false;
    void listarOpcoesVisitante()
      .then((lista) => {
        if (!cancelado) setOpcoes(lista);
      })
      .catch((e: unknown) => {
        if (cancelado) return;
        setOpcoes({ cargos: [], instrumentos: [] });
        setErro(e instanceof Error ? e.message : "Não foi possível carregar as opções.");
      });
    return () => {
      cancelado = true;
    };
  }, []);
  /* eslint-enable react-hooks/set-state-in-effect */

  const cargo = opcoes?.cargos.find((item) => item.id === cargoId);

  // Ao trocar o cargo, limpa o instrumento se o novo cargo não usar instrumento
  function trocarCargo(novoId: string) {
    setCargoId(novoId);
    const novo = opcoes?.cargos.find((item) => item.id === novoId);
    if (!novo?.permite_instrumento) setInstrumentoId("");
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    const erroDados = validarDadosVisitante({ nome, cargoId, igreja, cidade });
    if (erroDados) return setErro(erroDados);

    setSalvando(true);
    try {
      const cartao = await cadastrarVisitante(portariaId, {
        nome: nome.trim(),
        cargoId,
        instrumentoId: cargo?.permite_instrumento && instrumentoId ? instrumentoId : null,
        igreja: igreja.trim(),
        cidade: cidade.trim(),
      });
      onCadastrado(cartao);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível cadastrar o visitante.");
    } finally {
      setSalvando(false);
    }
  }

  if (opcoes === null) return <p className="text-sm text-slate-600">Carregando...</p>;

  return (
    <form onSubmit={salvar} className="space-y-5">
      <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
        O visitante é cadastrado na comum desta portaria e só aparece para esta região. Depois de salvar, você
        confere os dados e registra a entrada.
      </p>

      <div className="space-y-1.5">
        <label htmlFor="nome-visitante" className="text-sm font-medium text-slate-700">
          Nome completo
        </label>
        <input
          id="nome-visitante"
          type="text"
          required
          maxLength={120}
          autoComplete="off"
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={salvando}
          placeholder="Ex: João da Silva Santos"
          className={classeInput}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="cargo-visitante" className="text-sm font-medium text-slate-700">
          Cargo ou ministério
        </label>
        <select
          id="cargo-visitante"
          required
          value={cargoId}
          onChange={(e) => trocarCargo(e.target.value)}
          disabled={salvando}
          className={classeInput}
        >
          <option value="">Selecione</option>
          {opcoes.cargos.map((item) => (
            <option key={item.id} value={item.id}>
              {item.nome}
            </option>
          ))}
        </select>
      </div>

      {cargo?.permite_instrumento && (
        <div className="space-y-1.5">
          <label htmlFor="instrumento-visitante" className="text-sm font-medium text-slate-700">
            Instrumento <span className="font-normal text-slate-400">(opcional)</span>
          </label>
          <select
            id="instrumento-visitante"
            value={instrumentoId}
            onChange={(e) => setInstrumentoId(e.target.value)}
            disabled={salvando}
            className={classeInput}
          >
            <option value="">Sem instrumento / não informado</option>
            {opcoes.instrumentos.map((item) => (
              <option key={item.id} value={item.id}>
                {item.nome}
              </option>
            ))}
          </select>
        </div>
      )}

      <div className="space-y-1.5">
        <label htmlFor="igreja-visitante" className="text-sm font-medium text-slate-700">
          Igreja ou comum de origem <span className="font-normal text-slate-400">(opcional)</span>
        </label>
        <input
          id="igreja-visitante"
          type="text"
          maxLength={80}
          autoComplete="off"
          value={igreja}
          onChange={(e) => setIgreja(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Central de Jequié"
          className={classeInput}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="cidade-visitante" className="text-sm font-medium text-slate-700">
          Cidade, estado ou país de origem <span className="font-normal text-slate-400">(opcional)</span>
        </label>
        <input
          id="cidade-visitante"
          type="text"
          maxLength={80}
          autoComplete="off"
          value={cidade}
          onChange={(e) => setCidade(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Jequié, Bahia"
          className={classeInput}
        />
        <p className="text-xs text-slate-500">Informe pelo menos a igreja ou a cidade de origem.</p>
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Cadastrando..." : "Cadastrar e conferir"}
      </Button>
    </form>
  );
}
