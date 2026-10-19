"use client";

/**
 * SysMúsica — Formulário de membro (cadastro e edição) — conteúdo do painel lateral.
 * membro = null -> cadastrar; preenchido -> editar (inclui o status Ativo/Inativo).
 *
 * Comum: lista agrupada por Região › Setor (cadastrada em Organização). O nome da congregação sai da comum.
 * Cidade e bairro: texto com sugestões dos valores já cadastrados.
 * CPF: só aparece para quem tem a permissão membros.cpf (o banco também confere). É opcional,
 *      validado pelos dígitos verificadores e não pode repetir entre os membros.
 *
 * Instrumento: lista suspensa agrupada por família, igual em todo o sistema (só instrumentos cadastrados).
 *  - O campo só aparece para cargos com permite_instrumento = true.
 *  - É OBRIGATÓRIO nos cargos que exigem instrumento (o Músico); o banco também recusa sem ele.
 *  - A FAMÍLIA é automática e somente leitura (vem do cadastro do instrumento). Instrumento novo e
 *    correção de família: tela Instrumentos e famílias.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { formatarCpf, limparCpf, validarCpf } from "@/lib/cpf";
import SeletorInstrumento, { FamiliaAutomatica } from "@/modules/instrumentos/components/SeletorInstrumento";
import { validarInstrumentoDoCargo } from "@/modules/instrumentos/selecao";
import { atualizarMembro, criarMembro } from "@/modules/membros/services/membros";
import { CATEGORIAS, cargoUsaCategoria, validarCategoria } from "@/modules/painel/regras";
import SeletorComum from "@/modules/organizacao/components/SeletorComum";
import CampoFoto from "@/modules/membros/components/CampoFoto";
import FotoMembro from "@/modules/membros/components/FotoMembro";
import { descartarFoto, enviarFoto, subirFotoNova } from "@/modules/membros/services/fotos";
import type { Cargo, Familia, Instrumento, MembroPublico } from "@/types/database";

/** Listas de sugestões para os campos de localidade. */
export interface SugestoesLocalidade {
  congregacoes: string[];
  cidades: string[];
  bairros: string[];
}

interface FormularioMembroProps {
  membro: MembroPublico | null; // null = cadastrar; preenchido = editar
  cpfInicial: string | null; // CPF completo (só na edição e só para quem tem membros.cpf)
  podeCpf: boolean; // permissão membros.cpf
  podeFoto: boolean; // permissão membros.foto (trocar a fotografia de um membro já cadastrado)
  cargos: Cargo[];
  instrumentos: Instrumento[];
  familias: Familia[];
  sugestoes: SugestoesLocalidade;
  carregando: boolean;
  erro: string | null;
  /** Chamado após salvar com sucesso, com a mensagem para o aviso da tela. */
  onSalvo: (mensagem: string) => void | Promise<void>;
}

// Classe compartilhada pelos campos (mesma identidade visual dos demais módulos).
// [color-scheme:light] mantém o ícone do seletor de data visível mesmo com o navegador em tema escuro.
const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60 " +
  "[color-scheme:light]";

export default function FormularioMembro({
  membro,
  cpfInicial,
  podeCpf,
  podeFoto,
  cargos,
  instrumentos,
  familias,
  sugestoes,
  carregando,
  erro,
  onSalvo,
}: FormularioMembroProps) {
  const editando = membro !== null;

  // Valores iniciais: vazios no cadastro; os dados do membro na edição
  const [nome, setNome] = useState(membro?.nome ?? "");
  const [congregacao, setCongregacao] = useState(membro?.congregacao ?? "");
  const [comumId, setComumId] = useState(membro?.comum_id ?? ""); // a comum define o nome da congregação
  const [cidade, setCidade] = useState(membro?.cidade ?? "");
  const [bairro, setBairro] = useState(membro?.bairro ?? "");
  const [cpf, setCpf] = useState(cpfInicial ? formatarCpf(cpfInicial) : "");
  const [cargoId, setCargoId] = useState(membro?.cargo_id ?? "");
  const [dataNascimento, setDataNascimento] = useState(membro?.data_nascimento ?? ""); // "AAAA-MM-DD"
  const [instrumentoId, setInstrumentoId] = useState(membro?.instrumento_id ?? "");
  const [categoria, setCategoria] = useState(membro?.categoria ?? ""); // Oficializado, Culto Oficial ou RJM
  const [status, setStatus] = useState(membro?.status ?? "Ativo");
  const [foto, setFoto] = useState<Blob | null>(null); // foto nova já preparada (obrigatória no cadastro novo)
  const [salvando, setSalvando] = useState(false);
  const [erroForm, setErroForm] = useState<string | null>(null);

  // O cargo escolhido define se o campo de instrumento aparece e se ele é obrigatório
  const cargoSelecionado = cargos.find((cargo) => cargo.id === cargoId);
  const permiteInstrumento = cargoSelecionado?.permite_instrumento ?? false;
  const exigeInstrumento =
    (cargoSelecionado as (Cargo & { exige_instrumento?: boolean }) | undefined)?.exige_instrumento === true;
  // Só Músico e Organista têm categoria (as demais pessoas contam no painel pelo próprio cargo)
  const tipoCategoria = cargoUsaCategoria(cargoSelecionado?.nome);

  // Ao trocar de cargo, limpa o instrumento se o novo cargo não usar instrumento
  function trocarCargo(novoCargoId: string) {
    setCargoId(novoCargoId);
    const novoCargo = cargos.find((cargo) => cargo.id === novoCargoId);
    if (!novoCargo?.permite_instrumento) setInstrumentoId("");
    if (!cargoUsaCategoria(novoCargo?.nome)) setCategoria("");
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErroForm(null);

    // Barra campos obrigatórios vazios ou preenchidos só com espaços
    if (!nome.trim() || !comumId || !cargoId) {
      return setErroForm("Preencha nome, cargo e comum.");
    }

    // CPF (opcional): se preenchido, precisa ser válido
    const cpfDigitos = limparCpf(cpf);
    if (podeCpf && cpfDigitos !== "" && !validarCpf(cpfDigitos)) {
      return setErroForm("CPF inválido. Confira os números digitados.");
    }

    // Instrumento obrigatório nos cargos que exigem (o banco confere de novo)
    const erroInstrumento = validarInstrumentoDoCargo(exigeInstrumento, instrumentoId, cargoSelecionado?.nome);
    if (erroInstrumento) return setErroForm(erroInstrumento);

    // Categoria: obrigatória para Músico e Organista (define em qual linha do painel ao vivo ele conta)
    const erroCategoria = validarCategoria(cargoSelecionado?.nome, categoria);
    if (erroCategoria) return setErroForm(erroCategoria);

    // Fotografia: obrigatória no cadastro novo (o banco também recusa sem ela)
    if (!editando && !foto) {
      return setErroForm("A fotografia é obrigatória. Tire a foto ou escolha uma imagem.");
    }

    setSalvando(true);
    try {
      const dados = {
        nome: nome.trim(),
        congregacao: congregacao.trim(),
        comum_id: comumId,
        cidade: cidade.trim() || null,
        bairro: bairro.trim() || null,
        cargo_id: cargoId,
        data_nascimento: dataNascimento || null,
        instrumento_id: permiteInstrumento && instrumentoId ? instrumentoId : null,
        categoria: tipoCategoria && categoria ? categoria : null,
      };
      if (membro) {
        // O CPF só é enviado por quem tem a permissão (os demais nem tocam nele)
        await atualizarMembro(membro.id, {
          ...dados,
          status,
          ...(podeCpf ? { cpf: cpfDigitos || null } : {}),
        });
        // Foto nova (opcional na edição): só quem tem a permissão de fotografia a troca
        if (foto && podeFoto) await enviarFoto(membro.id, foto);
      } else {
        // Cadastro novo: o identificador é gerado aqui para a foto subir para a pasta do próprio membro
        // antes do cadastro; o banco confere o arquivo e recusa o cadastro sem foto.
        const novoId = crypto.randomUUID();
        const caminho = await subirFotoNova(novoId, foto as Blob);
        try {
          await criarMembro({
            ...dados,
            id: novoId,
            foto_path: caminho,
            ...(podeCpf && cpfDigitos ? { cpf: cpfDigitos } : {}),
          });
        } catch (e) {
          await descartarFoto(caminho); // o cadastro falhou: não deixa a foto solta
          throw e;
        }
      }

      await onSalvo(editando ? `Membro "${dados.nome}" atualizado.` : `Membro "${dados.nome}" cadastrado.`);
    } catch (e) {
      setErroForm(e instanceof Error ? e.message : "Não foi possível salvar o membro.");
    } finally {
      setSalvando(false);
    }
  }

  // ---------- Estados da tela ----------

  if (carregando) {
    return <p className="text-sm text-slate-600">Carregando os dados do formulário...</p>;
  }

  if (erro) {
    return (
      <p className="text-sm text-slate-600">
        Formulário indisponível porque os dados não puderam ser carregados.
      </p>
    );
  }

  // Sem cargos: a migração do banco ainda não foi aplicada
  if (cargos.length === 0) {
    return (
      <p className="text-sm text-slate-600">
        Nenhum cargo encontrado. Aplique as migrações do banco (pasta supabase/migrations) para criar
        os cargos padrão.
      </p>
    );
  }

  // Data máxima do campo de nascimento = hoje (formato AAAA-MM-DD, no fuso local)
  const hoje = new Date().toLocaleDateString("sv-SE");

  return (
    <form onSubmit={salvar} className="space-y-5">
      <div className="space-y-1.5">
        <label htmlFor="nome" className="text-sm font-medium text-slate-700">
          Nome completo
        </label>
        <input
          id="nome"
          type="text"
          required
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={salvando}
          placeholder="Ex: João da Silva"
          className={classeInput}
        />
      </div>

      {/* Fotografia: obrigatória no cadastro novo; na edição só troca quem tem a permissão de fotografia */}
      {!editando || podeFoto ? (
        <div className="space-y-1.5">
          <span className="text-sm font-medium text-slate-700">
            Fotografia{" "}
            {editando ? (
              <span className="font-normal text-slate-400">(opcional na edição)</span>
            ) : (
              <span className="font-normal text-red-600">(obrigatória)</span>
            )}
          </span>
          <CampoFoto
            nome={nome || "Membro"}
            fotoAtualCaminho={membro?.foto_path ?? null}
            obrigatoria={!editando}
            onChange={setFoto}
            disabled={salvando}
          />
        </div>
      ) : (
        <div className="space-y-1.5">
          <span className="text-sm font-medium text-slate-700">Fotografia</span>
          <FotoMembro caminho={membro?.foto_path ?? null} nome={nome || "Membro"} tamanho="grande" />
          <p className="text-xs text-slate-500">A fotografia só pode ser trocada por quem tem a permissão Fotografia.</p>
        </div>
      )}

      {/* CPF: só para quem tem a permissão membros.cpf */}
      {podeCpf && (
        <div className="space-y-1.5">
          <label htmlFor="cpf" className="text-sm font-medium text-slate-700">
            CPF <span className="font-normal text-slate-400">(opcional)</span>
          </label>
          <input
            id="cpf"
            type="text"
            inputMode="numeric"
            autoComplete="off"
            value={cpf}
            onChange={(e) => setCpf(formatarCpf(e.target.value))}
            disabled={salvando}
            placeholder="000.000.000-00"
            className={classeInput}
          />
          <p className="text-xs text-slate-500">
            Evita cadastros duplicados. O CPF é protegido: só quem tem permissão o vê por completo.
          </p>
        </div>
      )}

      <div className="space-y-1.5">
        <label htmlFor="cargo" className="text-sm font-medium text-slate-700">
          Cargo
        </label>
        <select
          id="cargo"
          required
          value={cargoId}
          onChange={(e) => trocarCargo(e.target.value)}
          disabled={salvando}
          className={classeInput}
        >
          <option value="">Selecione um cargo</option>
          {cargos.map((cargo) => (
            <option key={cargo.id} value={cargo.id}>
              {cargo.nome}
            </option>
          ))}
        </select>
      </div>

      {/* Instrumento (lista por família; obrigatório para Músico) + Família automática */}
      {permiteInstrumento && (
        <>
          <div className="space-y-1.5">
            <label htmlFor="instrumento" className="text-sm font-medium text-slate-700">
              Instrumento{" "}
              {exigeInstrumento ? (
                <span className="font-normal text-red-600">(obrigatório)</span>
              ) : (
                <span className="font-normal text-slate-400">(opcional)</span>
              )}
            </label>
            <SeletorInstrumento
              id="instrumento"
              valor={instrumentoId}
              onChange={setInstrumentoId}
              instrumentos={instrumentos}
              familias={familias}
              obrigatorio={exigeInstrumento}
              disabled={salvando}
              className={classeInput}
            />
            <p className="text-xs text-slate-500">
              Escolha na lista. Para incluir um instrumento novo, cadastre em Instrumentos e famílias.
            </p>
          </div>

          <FamiliaAutomatica instrumentoId={instrumentoId} instrumentos={instrumentos} familias={familias} />
        </>
      )}

      {/* Categoria: só para Músico e Organista (define em qual linha do painel ao vivo a pessoa conta) */}
      {tipoCategoria && (
        <div className="space-y-1.5">
          <label htmlFor="categoria" className="text-sm font-medium text-slate-700">
            Categoria <span className="font-normal text-red-600">(obrigatória)</span>
          </label>
          <select
            id="categoria"
            required
            value={categoria}
            onChange={(e) => setCategoria(e.target.value)}
            disabled={salvando}
            className={classeInput}
          >
            <option value="">Selecione a categoria</option>
            {CATEGORIAS.map((item) => (
              <option key={item.valor} value={item.valor}>
                {item[tipoCategoria]}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* Localidade: comum (lista do banco), cidade e bairro (com sugestões dos já cadastrados) */}
      <div className="space-y-1.5">
        <label htmlFor="comum-membro" className="text-sm font-medium text-slate-700">
          Comum
        </label>
        <SeletorComum
          id="comum-membro"
          valor={comumId}
          onChange={setComumId}
          onEscolherNome={setCongregacao}
          disabled={salvando}
          className={classeInput}
        />
        <p className="text-xs text-slate-500">
          A comum define o setor e quem enxerga o cadastro. Se a comum não aparecer, peça a um administrador para
          cadastrá-la em Administração &gt; Organização.
        </p>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="cidade" className="text-sm font-medium text-slate-700">
          Cidade <span className="font-normal text-slate-400">(opcional)</span>
        </label>
        <input
          id="cidade"
          type="text"
          list="sugestoes-cidade"
          autoComplete="off"
          value={cidade}
          onChange={(e) => setCidade(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Salvador, Lauro de Freitas"
          className={classeInput}
        />
        <datalist id="sugestoes-cidade">
          {sugestoes.cidades.map((valor) => (
            <option key={valor} value={valor} />
          ))}
        </datalist>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="bairro" className="text-sm font-medium text-slate-700">
          Bairro / igreja de referência <span className="font-normal text-slate-400">(opcional)</span>
        </label>
        <input
          id="bairro"
          type="text"
          list="sugestoes-bairro"
          autoComplete="off"
          value={bairro}
          onChange={(e) => setBairro(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Itinga"
          className={classeInput}
        />
        <datalist id="sugestoes-bairro">
          {sugestoes.bairros.map((valor) => (
            <option key={valor} value={valor} />
          ))}
        </datalist>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="data_nascimento" className="text-sm font-medium text-slate-700">
          Data de nascimento <span className="font-normal text-slate-400">(opcional)</span>
        </label>
        <input
          id="data_nascimento"
          type="date"
          max={hoje}
          value={dataNascimento}
          onChange={(e) => setDataNascimento(e.target.value)}
          disabled={salvando}
          className={classeInput}
        />
      </div>

      {/* Situação: só na edição */}
      {editando && (
        <div className="space-y-1.5">
          <label htmlFor="status" className="text-sm font-medium text-slate-700">
            Situação
          </label>
          <select
            id="status"
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            disabled={salvando}
            className={classeInput}
          >
            <option value="Ativo">Ativo</option>
            <option value="Inativo">Inativo</option>
          </select>
        </div>
      )}

      {erroForm && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erroForm}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Cadastrar membro"}
      </Button>
    </form>
  );
}
