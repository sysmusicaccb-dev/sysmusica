"use client";

/**
 * SysMúsica — Cadastro rápido de visitante na portaria (painel lateral).
 * Para o irmão de outra região (ou sem cadastro) que vem congregar: nome completo, cargo ou ministério,
 * instrumento e a IGREJA DE ORIGEM, escolhida em listas encadeadas que vêm do banco
 * (Estado > Região > Setor > Casa de Oração, cadastrados em Organização): nada de origem digitada à mão.
 *
 * Instrumento: o MESMO seletor do cadastro de membro (lista por família), obrigatório nos cargos que
 * exigem (o Músico), com a família preenchida automaticamente.
 * O visitante é cadastrado na CASA DE ORAÇÃO da portaria em atendimento e só a região dela o enxerga.
 * Depois de salvar, abre a conferência para registrar a entrada.
 * O banco confere permissão, portaria aprovada, abrangência, instrumento, origem e nome repetido na casa de oração.
 */
import { useEffect, useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import SeletorInstrumento, { FamiliaAutomatica } from "@/modules/instrumentos/components/SeletorInstrumento";
import CampoFoto from "@/modules/membros/components/CampoFoto";
import { descartarFoto, subirFotoNova } from "@/modules/membros/services/fotos";
import { validarInstrumentoDoCargo } from "@/modules/instrumentos/selecao";
import { filhosDe } from "@/modules/organizacao/regras";
import type { NoOrganizacao } from "@/modules/organizacao/tipos";
import { validarDadosVisitante } from "../regras";
import { cadastrarVisitante, listarOpcoesVisitante, listarOrigensVisitante } from "../services/atendimento";
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
  const [origens, setOrigens] = useState<NoOrganizacao[]>([]);
  const [nome, setNome] = useState("");
  const [cargoId, setCargoId] = useState("");
  const [instrumentoId, setInstrumentoId] = useState("");
  const [estadoId, setEstadoId] = useState("");
  const [regiaoId, setRegiaoId] = useState("");
  const [setorId, setSetorId] = useState("");
  const [casaOracaoId, setCasaOracaoId] = useState("");
  const [foto, setFoto] = useState<Blob | null>(null); // fotografia obrigatória do visitante
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  /* eslint-disable react-hooks/set-state-in-effect */
  useEffect(() => {
    let cancelado = false;
    void Promise.all([listarOpcoesVisitante(), listarOrigensVisitante()])
      .then(([listaOpcoes, listaOrigens]) => {
        if (cancelado) return;
        setOpcoes(listaOpcoes);
        setOrigens(listaOrigens);
        // Com um único estado cadastrado, ele já vem escolhido
        const estados = filhosDe(listaOrigens, null, "ESTADO");
        if (estados.length === 1) setEstadoId(estados[0].id);
      })
      .catch((e: unknown) => {
        if (cancelado) return;
        setOpcoes({ cargos: [], instrumentos: [], familias: [] });
        setErro(e instanceof Error ? e.message : "Não foi possível carregar as opções.");
      });
    return () => {
      cancelado = true;
    };
  }, []);
  /* eslint-enable react-hooks/set-state-in-effect */

  const cargo = opcoes?.cargos.find((item) => item.id === cargoId);
  const exigeInstrumento = cargo?.exige_instrumento === true;

  // Listas encadeadas: cada nível só mostra o que pertence à escolha anterior
  const estados = filhosDe(origens, null, "ESTADO");
  const regioes = estadoId ? filhosDe(origens, estadoId, "REGIAO") : [];
  const setores = regiaoId ? filhosDe(origens, regiaoId, "SETOR") : [];
  const casasOracao = setorId ? filhosDe(origens, setorId, "CASA_ORACAO") : [];

  // Ao trocar um nível, limpa os de baixo
  function trocarEstado(id: string) {
    setEstadoId(id);
    setRegiaoId("");
    setSetorId("");
    setCasaOracaoId("");
  }
  function trocarRegiao(id: string) {
    setRegiaoId(id);
    setSetorId("");
    setCasaOracaoId("");
  }
  function trocarSetor(id: string) {
    setSetorId(id);
    setCasaOracaoId("");
  }

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

    const erroDados = validarDadosVisitante({ nome, cargoId, origemCasaOracaoId: casaOracaoId });
    if (erroDados) return setErro(erroDados);
    const erroInstrumento = validarInstrumentoDoCargo(exigeInstrumento, instrumentoId, cargo?.nome);
    if (erroInstrumento) return setErro(erroInstrumento);
    if (!foto) return setErro("A fotografia do visitante é obrigatória. Tire a foto ou escolha uma imagem.");

    setSalvando(true);
    try {
      // O identificador do visitante é gerado aqui para a foto subir para a pasta dele antes do cadastro
      const membroId = crypto.randomUUID();
      const caminho = await subirFotoNova(membroId, foto);
      let cartao: CartaoMembro;
      try {
        cartao = await cadastrarVisitante(portariaId, {
          nome: nome.trim(),
          cargoId,
          instrumentoId: cargo?.permite_instrumento && instrumentoId ? instrumentoId : null,
          origemCasaOracaoId: casaOracaoId,
          membroId,
          fotoPath: caminho,
        });
      } catch (e) {
        await descartarFoto(caminho); // o cadastro falhou: não deixa a foto solta
        throw e;
      }
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
        O visitante é cadastrado na casa de oração desta portaria e só aparece para esta região. Depois de salvar, você
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

      {/* Instrumento: o mesmo seletor do cadastro de membro (obrigatório para Músico) + família automática */}
      {cargo?.permite_instrumento && (
        <>
          <div className="space-y-1.5">
            <label htmlFor="instrumento-visitante" className="text-sm font-medium text-slate-700">
              Instrumento{" "}
              {exigeInstrumento ? (
                <span className="font-normal text-red-600">(obrigatório)</span>
              ) : (
                <span className="font-normal text-slate-400">(opcional)</span>
              )}
            </label>
            <SeletorInstrumento
              id="instrumento-visitante"
              valor={instrumentoId}
              onChange={setInstrumentoId}
              instrumentos={opcoes.instrumentos}
              familias={opcoes.familias}
              obrigatorio={exigeInstrumento}
              disabled={salvando}
              className={classeInput}
            />
          </div>

          <FamiliaAutomatica
            instrumentoId={instrumentoId}
            instrumentos={opcoes.instrumentos}
            familias={opcoes.familias}
          />
        </>
      )}

      {/* Fotografia obrigatória: identifica o visitante e evita intrusos */}
      <div className="space-y-1.5">
        <span className="text-sm font-medium text-slate-700">
          Fotografia <span className="font-normal text-red-600">(obrigatória)</span>
        </span>
        <CampoFoto nome={nome.trim() || "Visitante"} obrigatoria onChange={setFoto} disabled={salvando} />
      </div>

      {/* Origem: listas encadeadas que vêm do banco (Organização) */}
      <fieldset className="space-y-3 rounded-xl border border-slate-200 p-4">
        <legend className="px-1 text-sm font-medium text-slate-700">Igreja de origem</legend>

        <div className="space-y-1.5">
          <label htmlFor="estado-visitante" className="text-xs font-medium text-slate-600">
            Estado
          </label>
          <select
            id="estado-visitante"
            value={estadoId}
            onChange={(e) => trocarEstado(e.target.value)}
            disabled={salvando}
            className={classeInput}
          >
            <option value="">Selecione o estado</option>
            {estados.map((item) => (
              <option key={item.id} value={item.id}>
                {item.nome}
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-1.5">
          <label htmlFor="regiao-visitante" className="text-xs font-medium text-slate-600">
            Região
          </label>
          <select
            id="regiao-visitante"
            value={regiaoId}
            onChange={(e) => trocarRegiao(e.target.value)}
            disabled={salvando || !estadoId}
            className={classeInput}
          >
            <option value="">Selecione a região</option>
            {regioes.map((item) => (
              <option key={item.id} value={item.id}>
                {item.nome}
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-1.5">
          <label htmlFor="setor-visitante" className="text-xs font-medium text-slate-600">
            Setor
          </label>
          <select
            id="setor-visitante"
            value={setorId}
            onChange={(e) => trocarSetor(e.target.value)}
            disabled={salvando || !regiaoId}
            className={classeInput}
          >
            <option value="">Selecione o setor</option>
            {setores.map((item) => (
              <option key={item.id} value={item.id}>
                {item.nome}
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-1.5">
          <label htmlFor="casa-oracao-visitante" className="text-xs font-medium text-slate-600">
            Casa de Oração
          </label>
          <select
            id="casa-oracao-visitante"
            value={casaOracaoId}
            onChange={(e) => setCasaOracaoId(e.target.value)}
            disabled={salvando || !setorId}
            className={classeInput}
          >
            <option value="">Selecione a casa de oração</option>
            {casasOracao.map((item) => (
              <option key={item.id} value={item.id}>
                {item.nome}
              </option>
            ))}
          </select>
        </div>

        <p className="text-xs text-slate-500">
          A cidade e a igreja de origem são preenchidas por esta escolha. Se a origem não aparecer na lista,
          peça a um administrador para cadastrá-la em Administração &gt; Organização.
        </p>
      </fieldset>

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
