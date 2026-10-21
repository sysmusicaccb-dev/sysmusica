#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 4: Músicos / Organistas = "Cadastro Musical" completo (COM SQL 0038)
#
#  - Formulário de Músicos / Organistas vira o "Cadastro Musical" (estado civil, sexo, batismo, selado,
#    telefone/WhatsApp, e-mail, endereço, cartão de identificação, apresentado por, observação)
#  - Só os cargos do cadastro aparecem na lista (Encarregado Regional/Local, Examinadora, Instrutor(a), Músico, Organista)
#  - "Categoria" passa a se chamar "Status do cargo" (Oficializado / Culto Oficial / RJM)
#  - Lista: coluna Status mostra o nível, miniatura da foto, filtro "Sem fotografia"
#  - A tela Fotografias sai do menu (a foto é trocada/removida no Editar do músico); o link antigo redireciona
#  - ANTES do git push: rodar o SQL supabase/migrations/0038_cadastro_musical.sql no Supabase (SQL Editor)
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-parte4-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && bash instalar-parte4-cadastro-musical.sh
# Log:  /tmp/instalar-parte4.log
# =============================================================================

LOG=/tmp/instalar-parte4.log
BKP=/tmp/bkp-parte4-$(date +%Y%m%d-%H%M%S)
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
    ("src/components/FormularioMembro.tsx",
     r''' * Instrumento: lista suspensa agrupada por família, igual em todo o sistema (só instrumentos cadastrados).''',
     r''' * CADASTRO MUSICAL (migração 0038): além dos dados de "membros", o formulário coleta os dados pessoais
 *      (estado civil, sexo, batismo, selado, telefone/WhatsApp, e-mail, endereço, cartão de identificação,
 *      apresentado por, observação), gravados na tabela protegida membros_cadastro pelas funções do banco
 *      (services/cadastroMusical.ts). As regras e validações ficam em modules/membros/cadastroMusical.ts.
 *  - Só os cargos do cadastro aparecem na lista (o cargo atual do membro é mantido na edição).
 *  - Cargos com cartão de identificação (cargos.exige_cartao) mostram os campos do cartão.
 *  - "Status do cargo" (Oficializado / Culto Oficial / RJM) é o campo Categoria; outros cargos são Oficializado.
 *  - Os campos obrigatórios (*) valem no cadastro novo e em quem já tem o cadastro preenchido.
 *
 * Instrumento: lista suspensa agrupada por família, igual em todo o sistema (só instrumentos cadastrados).'''),
    ("src/components/FormularioMembro.tsx",
     r'''import { useState, type FormEvent } from "react";''',
     r'''import { useState, type FormEvent, type ReactNode } from "react";'''),
    ("src/components/FormularioMembro.tsx",
     r'''import type { Cargo, Familia, Instrumento, MembroPublico } from "@/types/database";''',
     r'''import {
  CADASTRO_VAZIO,
  ESTADOS_CIVIS,
  SEXOS,
  UFS,
  cargoExigeCartao,
  cargosDoCadastro,
  formatarCep,
  formatarTelefone,
  formatarWhatsapp,
  somenteDigitos,
  temAlgumDado,
  validarCadastro,
  type CadastroMusical,
  type SimNao,
} from "@/modules/membros/cadastroMusical";
import { salvarCadastroMusical } from "@/modules/membros/services/cadastroMusical";
import type { Cargo, Familia, Instrumento, MembroPublico } from "@/types/database";'''),
    ("src/components/FormularioMembro.tsx",
     r'''import { descartarFoto, enviarFoto, subirFotoNova } from "@/modules/membros/services/fotos";''',
     r'''import { descartarFoto, enviarFoto, removerFoto, subirFotoNova } from "@/modules/membros/services/fotos";'''),
    ("src/components/FormularioMembro.tsx",
     r'''  cpfInicial: string | null; // CPF completo (só na edição e só para quem tem membros.cpf)''',
     r'''  cpfInicial: string | null; // CPF completo (só na edição e só para quem tem membros.cpf)
  cadastroInicial: CadastroMusical | null; // dados pessoais já gravados (só na edição; null = ainda sem cadastro)'''),
    ("src/components/FormularioMembro.tsx",
     r'''  membro,
  cpfInicial,
  podeCpf,''',
     r'''  membro,
  cpfInicial,
  cadastroInicial,
  podeCpf,'''),
    ("src/components/FormularioMembro.tsx",
     r'''  const [foto, setFoto] = useState<Blob | null>(null); // foto nova já preparada (obrigatória no cadastro novo)''',
     r'''  const [foto, setFoto] = useState<Blob | null>(null); // foto nova já preparada (obrigatória no cadastro novo)
  const [cadastro, setCadastro] = useState<CadastroMusical>(cadastroInicial ?? CADASTRO_VAZIO); // dados pessoais
  const [confirmandoRemocaoFoto, setConfirmandoRemocaoFoto] = useState(false);'''),
    ("src/components/FormularioMembro.tsx",
     r'''  // O cargo escolhido define se o campo de instrumento aparece e se ele é obrigatório
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
    if (!nome.trim() || !casaOracaoId || !cargoId) {
      return setErroForm("Preencha nome, cargo e casa de oração.");
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
        casa_oracao_id: casaOracaoId,
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
''',
     r'''  // Cargos do Cadastro Musical (Ancião, Diácono, Cooperadores e Secretário da Música não têm mais cadastro;
  // na edição o cargo atual do membro continua na lista para não ser trocado sem querer)
  const cargosDisponiveis = cargosDoCadastro(cargos, membro?.cargo_id);

  // O cargo escolhido define se o campo de instrumento aparece e se ele é obrigatório
  const cargoSelecionado = cargos.find((cargo) => cargo.id === cargoId);
  const permiteInstrumento = cargoSelecionado?.permite_instrumento ?? false;
  const exigeInstrumento =
    (cargoSelecionado as (Cargo & { exige_instrumento?: boolean }) | undefined)?.exige_instrumento === true;
  // Só Músico e Organista têm categoria (as demais pessoas contam no painel pelo próprio cargo)
  const tipoCategoria = cargoUsaCategoria(cargoSelecionado?.nome);
  // Cartão de identificação: só para os cargos marcados (cargos.exige_cartao)
  const exigeCartao = cargoExigeCartao(cargoSelecionado as (Cargo & { exige_cartao?: boolean }) | undefined);
  // Campos obrigatórios (*): cadastro novo, ou edição de quem já tem o cadastro preenchido (ou começou a preencher)
  const completo = !editando || cadastroInicial !== null || temAlgumDado(cadastro);

  // Ao trocar de cargo, limpa o instrumento se o novo cargo não usar instrumento
  function trocarCargo(novoCargoId: string) {
    setCargoId(novoCargoId);
    const novoCargo = cargos.find((cargo) => cargo.id === novoCargoId);
    if (!novoCargo?.permite_instrumento) setInstrumentoId("");
    if (!cargoUsaCategoria(novoCargo?.nome)) setCategoria("");
  }

  // Atualiza um campo dos dados pessoais
  function mudar<K extends keyof CadastroMusical>(campo: K, valor: CadastroMusical[K]) {
    setCadastro((atual) => ({ ...atual, [campo]: valor }));
  }

  // "Tem WhatsApp? Sim" já preenche o número com o próprio telefone (pode ser trocado)
  function escolherWhatsapp(valor: SimNao) {
    setCadastro((atual) => ({
      ...atual,
      tem_whatsapp: valor,
      whatsapp: valor === "sim" && !atual.whatsapp ? `${atual.ddd}${atual.telefone}` : atual.whatsapp,
    }));
  }

  // Remove a fotografia atual (só na edição, com a permissão de fotografia, depois de confirmar)
  async function removerFotoAtual() {
    if (!membro || salvando) return;
    setErroForm(null);
    setSalvando(true);
    try {
      await removerFoto(membro.id);
      await onSalvo(`Fotografia de "${membro.nome}" removida.`);
    } catch (e) {
      setErroForm(e instanceof Error ? e.message : "Não foi possível remover a fotografia.");
    } finally {
      setSalvando(false);
      setConfirmandoRemocaoFoto(false);
    }
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErroForm(null);

    // Barra campos obrigatórios vazios ou preenchidos só com espaços
    if (!nome.trim() || !casaOracaoId || !cargoId) {
      return setErroForm("Preencha nome, cargo e casa de oração.");
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

    // Dados pessoais do Cadastro Musical (o banco confere tudo de novo)
    const erroCadastro = validarCadastro(cadastro, { completo, exigeCartao, cidade, bairro });
    if (erroCadastro) return setErroForm(erroCadastro);

    setSalvando(true);
    try {
      const dados = {
        nome: nome.trim(),
        congregacao: congregacao.trim(),
        casa_oracao_id: casaOracaoId,
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
        // Dados pessoais: depois do cargo, porque o banco confere o cartão pelo cargo atual do membro
        if (completo) await salvarCadastroMusical(membro.id, cadastro);
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
        try {
          await salvarCadastroMusical(novoId, cadastro);
        } catch (e) {
          // O membro já existe: fecha o formulário (evita cadastrar duas vezes) e avisa o que faltou
          const motivo = e instanceof Error ? e.message : "erro desconhecido";
          await onSalvo(
            `Membro "${dados.nome}" cadastrado, mas os dados pessoais NÃO foram salvos (${motivo}). ` +
              "Abra Editar e preencha de novo."
          );
          return;
        }
      }

      await onSalvo(editando ? `Membro "${dados.nome}" atualizado.` : `Membro "${dados.nome}" cadastrado.`);
    } catch (e) {
      setErroForm(e instanceof Error ? e.message : "Não foi possível salvar o membro.");
    } finally {
      setSalvando(false);
    }
  }
'''),
    ("src/components/FormularioMembro.tsx",
     r'''  // Data máxima do campo de nascimento = hoje (formato AAAA-MM-DD, no fuso local)
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

      {/* Localidade: casa de oração (lista do banco), cidade e bairro (com sugestões dos já cadastrados) */}
      <div className="space-y-1.5">
        <label htmlFor="casa-oracao-membro" className="text-sm font-medium text-slate-700">
          Casa de Oração
        </label>
        <SeletorCasaOracao
          id="casa-oracao-membro"
          valor={casaOracaoId}
          onChange={setCasaOracaoId}
          onEscolherNome={setCongregacao}
          disabled={salvando}
          className={classeInput}
        />
        <p className="text-xs text-slate-500">
          A casa de oração define o setor e quem enxerga o cadastro. Se a casa de oração não aparecer, peça a um administrador para
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
}''',
     r'''  // Data máxima do campo de nascimento = hoje (formato AAAA-MM-DD, no fuso local)
  const hoje = new Date().toLocaleDateString("sv-SE");
  const rotuloSimNao = (obrigatorio: boolean) => (obrigatorio ? "Selecione" : "—");

  return (
    <form onSubmit={salvar} className="space-y-6">
      {/* ---------- Fotografia ---------- */}
      {/* Obrigatória no cadastro novo; na edição só troca/remove quem tem a permissão de fotografia */}
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
          {editando && membro?.foto_path && (
            <div className="pt-1">
              {confirmandoRemocaoFoto ? (
                <div className="flex flex-wrap items-center gap-2 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">
                  <span>Remover a fotografia? Na portaria ele aparecerá sem foto.</span>
                  <button
                    type="button"
                    onClick={() => void removerFotoAtual()}
                    disabled={salvando}
                    className="rounded-lg bg-red-600 px-3 py-1 text-xs font-semibold text-white hover:bg-red-500 disabled:opacity-60"
                  >
                    Sim, remover
                  </button>
                  <button
                    type="button"
                    onClick={() => setConfirmandoRemocaoFoto(false)}
                    disabled={salvando}
                    className="rounded-lg border border-slate-300 bg-white px-3 py-1 text-xs font-medium text-slate-700 hover:bg-slate-50 disabled:opacity-60"
                  >
                    Cancelar
                  </button>
                </div>
              ) : (
                <button
                  type="button"
                  onClick={() => setConfirmandoRemocaoFoto(true)}
                  disabled={salvando}
                  className="text-xs font-semibold text-red-600 hover:underline disabled:opacity-60"
                >
                  Remover a fotografia atual
                </button>
              )}
            </div>
          )}
        </div>
      ) : (
        <div className="space-y-1.5">
          <span className="text-sm font-medium text-slate-700">Fotografia</span>
          <FotoMembro caminho={membro?.foto_path ?? null} nome={nome || "Membro"} tamanho="grande" />
          <p className="text-xs text-slate-500">A fotografia só pode ser trocada por quem tem a permissão Fotografia.</p>
        </div>
      )}

      {/* ---------- Identificação ---------- */}
      <Secao titulo="Identificação">
        <Campo id="nome" rotulo="Nome completo" obrigatorio>
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
        </Campo>

        {/* CPF: só para quem tem a permissão membros.cpf */}
        {podeCpf && (
          <Campo
            id="cpf"
            rotulo="CPF"
            dica="Evita cadastros duplicados. O CPF é protegido: só quem tem permissão o vê por completo."
          >
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
          </Campo>
        )}

        <Campo id="data_nascimento" rotulo="Data de nascimento">
          <input
            id="data_nascimento"
            type="date"
            max={hoje}
            value={dataNascimento}
            onChange={(e) => setDataNascimento(e.target.value)}
            disabled={salvando}
            className={classeInput}
          />
        </Campo>

        <div className="grid grid-cols-2 gap-3">
          <Campo id="estado_civil" rotulo="Estado civil">
            <select
              id="estado_civil"
              value={cadastro.estado_civil}
              onChange={(e) => mudar("estado_civil", e.target.value)}
              disabled={salvando}
              className={classeInput}
            >
              <option value="">—</option>
              {ESTADOS_CIVIS.map((item) => (
                <option key={item} value={item}>
                  {item}
                </option>
              ))}
            </select>
          </Campo>
          <Campo id="sexo" rotulo="Sexo">
            <select
              id="sexo"
              value={cadastro.sexo}
              onChange={(e) => mudar("sexo", e.target.value)}
              disabled={salvando}
              className={classeInput}
            >
              <option value="">—</option>
              {SEXOS.map((item) => (
                <option key={item} value={item}>
                  {item}
                </option>
              ))}
            </select>
          </Campo>
        </div>
      </Secao>

      {/* ---------- Vínculo e função ---------- */}
      <Secao titulo="Casa de Oração e cargo">
        {/* Casa de oração (lista do banco) */}
        <Campo
          id="casa-oracao-membro"
          rotulo="Casa de Oração"
          obrigatorio
          dica="A casa de oração define o setor e quem enxerga o cadastro. Se a casa de oração não aparecer, peça a um administrador para cadastrá-la em Administração > Organização."
        >
          <SeletorCasaOracao
            id="casa-oracao-membro"
            valor={casaOracaoId}
            onChange={setCasaOracaoId}
            onEscolherNome={setCongregacao}
            disabled={salvando}
            className={classeInput}
          />
        </Campo>

        <Campo id="cargo" rotulo="Cargo" obrigatorio>
          <select
            id="cargo"
            required
            value={cargoId}
            onChange={(e) => trocarCargo(e.target.value)}
            disabled={salvando}
            className={classeInput}
          >
            <option value="">Selecione um cargo</option>
            {cargosDisponiveis.map((cargo) => (
              <option key={cargo.id} value={cargo.id}>
                {cargo.nome}
              </option>
            ))}
          </select>
        </Campo>

        {/* Status do cargo (Categoria): só Músico e Organista informam; os demais cargos são Oficializado */}
        {tipoCategoria ? (
          <Campo id="categoria" rotulo="Status do cargo" obrigatorio>
            <select
              id="categoria"
              required
              value={categoria}
              onChange={(e) => setCategoria(e.target.value)}
              disabled={salvando}
              className={classeInput}
            >
              <option value="">Selecione o status</option>
              {CATEGORIAS.map((item) => (
                <option key={item.valor} value={item.valor}>
                  {item[tipoCategoria]}
                </option>
              ))}
            </select>
          </Campo>
        ) : (
          cargoSelecionado && (
            <p className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-600">
              Status do cargo: <strong>Oficializado</strong> (automático para este cargo).
            </p>
          )
        )}

        {/* Instrumento (lista por família; obrigatório para Músico) + Família automática */}
        {permiteInstrumento && (
          <>
            <Campo
              id="instrumento"
              rotulo="Instrumento"
              obrigatorio={exigeInstrumento}
              dica="Escolha na lista. Para incluir um instrumento novo, cadastre em Instrumentos e famílias."
            >
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
            </Campo>

            <FamiliaAutomatica instrumentoId={instrumentoId} instrumentos={instrumentos} familias={familias} />
          </>
        )}

        <div className="grid grid-cols-2 gap-3">
          <Campo id="data_batismo" rotulo="Data de batismo">
            <input
              id="data_batismo"
              type="date"
              max={hoje}
              value={cadastro.data_batismo}
              onChange={(e) => mudar("data_batismo", e.target.value)}
              disabled={salvando}
              className={classeInput}
            />
          </Campo>
          <Campo id="selado" rotulo="Selado(a)?" obrigatorio={completo}>
            <select
              id="selado"
              value={cadastro.selado}
              onChange={(e) => mudar("selado", e.target.value as SimNao)}
              disabled={salvando}
              className={classeInput}
            >
              <option value="">{rotuloSimNao(completo)}</option>
              <option value="sim">Sim</option>
              <option value="nao">Não</option>
            </select>
          </Campo>
        </div>
      </Secao>

      {/* ---------- Cartão de identificação (só para os cargos marcados em cargos.exige_cartao) ---------- */}
      {exigeCartao && (
        <Secao titulo="Cartão de identificação">
          <Campo id="cartao_numero" rotulo="Número do cartão" obrigatorio>
            <input
              id="cartao_numero"
              type="text"
              autoComplete="off"
              maxLength={40}
              value={cadastro.cartao_numero}
              onChange={(e) => mudar("cartao_numero", e.target.value)}
              disabled={salvando}
              className={classeInput}
            />
          </Campo>
          <div className="grid grid-cols-2 gap-3">
            <Campo id="cartao_emissao" rotulo="Emissão do cartão">
              <input
                id="cartao_emissao"
                type="date"
                value={cadastro.cartao_emissao}
                onChange={(e) => mudar("cartao_emissao", e.target.value)}
                disabled={salvando}
                className={classeInput}
              />
            </Campo>
            <Campo id="cartao_validade" rotulo="Validade do cartão" obrigatorio>
              <input
                id="cartao_validade"
                type="date"
                value={cadastro.cartao_validade}
                onChange={(e) => mudar("cartao_validade", e.target.value)}
                disabled={salvando}
                className={classeInput}
              />
            </Campo>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <Campo id="apresentado_em" rotulo="Apresentado em">
              <input
                id="apresentado_em"
                type="date"
                value={cadastro.apresentado_em}
                onChange={(e) => mudar("apresentado_em", e.target.value)}
                disabled={salvando}
                className={classeInput}
              />
            </Campo>
            <Campo id="apresentado_por" rotulo="Apresentado por" dica="Nome do ancião.">
              <input
                id="apresentado_por"
                type="text"
                autoComplete="off"
                maxLength={120}
                value={cadastro.apresentado_por}
                onChange={(e) => mudar("apresentado_por", e.target.value)}
                disabled={salvando}
                className={classeInput}
              />
            </Campo>
          </div>
        </Secao>
      )}

      {/* ---------- Contato ---------- */}
      <Secao titulo="Contato">
        <div className="grid grid-cols-3 gap-3">
          <Campo id="ddd" rotulo="DDD" obrigatorio={completo}>
            <input
              id="ddd"
              type="text"
              inputMode="numeric"
              autoComplete="off"
              value={cadastro.ddd}
              onChange={(e) => mudar("ddd", somenteDigitos(e.target.value, 2))}
              disabled={salvando}
              placeholder="71"
              className={classeInput}
            />
          </Campo>
          <div className="col-span-2">
            <Campo id="telefone" rotulo="Telefone" obrigatorio={completo}>
              <input
                id="telefone"
                type="text"
                inputMode="numeric"
                autoComplete="off"
                value={formatarTelefone(cadastro.telefone)}
                onChange={(e) => mudar("telefone", somenteDigitos(e.target.value, 9))}
                disabled={salvando}
                placeholder="99999-9999"
                className={classeInput}
              />
            </Campo>
          </div>
        </div>

        <Campo id="tem_whatsapp" rotulo="Tem WhatsApp?" obrigatorio={completo}>
          <select
            id="tem_whatsapp"
            value={cadastro.tem_whatsapp}
            onChange={(e) => escolherWhatsapp(e.target.value as SimNao)}
            disabled={salvando}
            className={classeInput}
          >
            <option value="">{rotuloSimNao(completo)}</option>
            <option value="sim">Sim</option>
            <option value="nao">Não</option>
          </select>
        </Campo>

        {cadastro.tem_whatsapp === "sim" && (
          <Campo id="whatsapp" rotulo="Número do WhatsApp" dica="Já vem com o telefone acima; troque se for outro número.">
            <input
              id="whatsapp"
              type="text"
              inputMode="numeric"
              autoComplete="off"
              value={formatarWhatsapp(cadastro.whatsapp)}
              onChange={(e) => mudar("whatsapp", somenteDigitos(e.target.value, 11))}
              disabled={salvando}
              placeholder="(71) 99999-9999"
              className={classeInput}
            />
          </Campo>
        )}

        <Campo id="email" rotulo="E-mail">
          <input
            id="email"
            type="email"
            autoComplete="off"
            maxLength={160}
            value={cadastro.email}
            onChange={(e) => mudar("email", e.target.value)}
            disabled={salvando}
            placeholder="nome@exemplo.com"
            className={classeInput}
          />
        </Campo>
      </Secao>

      {/* ---------- Endereço ---------- */}
      <Secao titulo="Endereço">
        <div className="grid grid-cols-2 gap-3">
          <Campo id="cep" rotulo="CEP" obrigatorio={completo}>
            <input
              id="cep"
              type="text"
              inputMode="numeric"
              autoComplete="off"
              value={formatarCep(cadastro.cep)}
              onChange={(e) => mudar("cep", somenteDigitos(e.target.value, 8))}
              disabled={salvando}
              placeholder="00000-000"
              className={classeInput}
            />
          </Campo>
          <Campo id="numero" rotulo="Número" obrigatorio={completo}>
            <input
              id="numero"
              type="text"
              autoComplete="off"
              maxLength={20}
              value={cadastro.numero}
              onChange={(e) => mudar("numero", e.target.value)}
              disabled={salvando}
              className={classeInput}
            />
          </Campo>
        </div>

        <Campo id="endereco" rotulo="Endereço" obrigatorio={completo}>
          <input
            id="endereco"
            type="text"
            autoComplete="off"
            maxLength={160}
            value={cadastro.endereco}
            onChange={(e) => mudar("endereco", e.target.value)}
            disabled={salvando}
            placeholder="Rua, avenida..."
            className={classeInput}
          />
        </Campo>

        <Campo id="complemento" rotulo="Complemento">
          <input
            id="complemento"
            type="text"
            autoComplete="off"
            maxLength={80}
            value={cadastro.complemento}
            onChange={(e) => mudar("complemento", e.target.value)}
            disabled={salvando}
            className={classeInput}
          />
        </Campo>

        <div className="grid grid-cols-3 gap-3">
          <Campo id="uf" rotulo="Estado" obrigatorio={completo}>
            <select
              id="uf"
              value={cadastro.uf}
              onChange={(e) => mudar("uf", e.target.value)}
              disabled={salvando}
              className={classeInput}
            >
              <option value="">UF</option>
              {UFS.map((sigla) => (
                <option key={sigla} value={sigla}>
                  {sigla}
                </option>
              ))}
            </select>
          </Campo>
          <div className="col-span-2">
            <Campo id="cidade" rotulo="Cidade" obrigatorio={completo}>
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
            </Campo>
          </div>
        </div>

        <Campo id="bairro" rotulo="Bairro" obrigatorio={completo}>
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
        </Campo>
      </Secao>

      {/* ---------- Observação e situação ---------- */}
      <Secao titulo="Outras informações">
        <Campo id="observacao" rotulo="Observação">
          <textarea
            id="observacao"
            rows={3}
            maxLength={500}
            value={cadastro.observacao}
            onChange={(e) => mudar("observacao", e.target.value)}
            disabled={salvando}
            className={classeInput}
          />
        </Campo>

        {/* Situação: só na edição */}
        {editando && (
          <Campo id="status" rotulo="Situação cadastral" obrigatorio>
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
          </Campo>
        )}
      </Secao>

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

/** Bloco do formulário com título (agrupa os campos por assunto). */
function Secao({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <section className="space-y-4">
      <h3 className="border-b border-slate-200 pb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
        {titulo}
      </h3>
      {children}
    </section>
  );
}

/** Campo com rótulo, marcação de obrigatório (*) ou (opcional) e dica opcional. */
function Campo({
  id,
  rotulo,
  obrigatorio = false,
  dica,
  children,
}: {
  id: string;
  rotulo: string;
  obrigatorio?: boolean;
  dica?: string;
  children: ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <label htmlFor={id} className="text-sm font-medium text-slate-700">
        {rotulo}{" "}
        {obrigatorio ? (
          <span className="font-normal text-red-600" aria-hidden="true">
            *
          </span>
        ) : (
          <span className="font-normal text-slate-400">(opcional)</span>
        )}
      </label>
      {children}
      {dica && <p className="text-xs text-slate-500">{dica}</p>}
    </div>
  );
}'''),
    ("src/components/ListaMembros.tsx",
     r''' *  - telas >= 768px: colunas Nome, Cargo, Instrumento, Família, Casa de Oração e Status;''',
     r''' *  - telas >= 768px: colunas Nome, Cargo, Instrumento, Família, Casa de Oração e Status (nível do cargo:
 *    Oficializado, Culto Oficial ou RJM; "Inativo" aparece ao lado quando a situação cadastral é Inativa);
 *  - filtro de fotografia (sem/com) e miniatura da foto no lugar da inicial do nome;'''),
    ("src/components/ListaMembros.tsx",
     r'''import type { Cargo, Familia, Instrumento, MembroPublico } from "@/types/database";''',
     r'''import { cargoUsaCategoria, rotuloDaCategoria } from "@/modules/painel/regras";
import type { Cargo, Familia, Instrumento, MembroPublico } from "@/types/database";'''),
    ("src/components/ListaMembros.tsx",
     r'''  onQr: (membro: MembroPublico) => void;
}''',
     r'''  onQr: (membro: MembroPublico) => void;
  urlsFotos?: Record<string, string>; // caminho da foto -> URL temporária (miniaturas da lista)
}'''),
    ("src/components/ListaMembros.tsx",
     r'''  podeQr,
  onQr,
}: ListaMembrosProps) {''',
     r'''  podeQr,
  onQr,
  urlsFotos = {},
}: ListaMembrosProps) {'''),
    ("src/components/ListaMembros.tsx",
     r'''  const [familiaFiltroId, setFamiliaFiltroId] = useState(""); // "" = todas as famílias''',
     r'''  const [familiaFiltroId, setFamiliaFiltroId] = useState(""); // "" = todas as famílias
  const [fotoFiltro, setFotoFiltro] = useState<"" | "sem" | "com">(""); // "" = com ou sem fotografia'''),
    ("src/components/ListaMembros.tsx",
     r'''    return passaNome && passaCargo && passaFamilia;
  });
  const filtrosAtivos = termo !== "" || cargoFiltroId !== "" || familiaFiltroId !== "";''',
     r'''    const passaFoto = fotoFiltro === "" || (fotoFiltro === "sem" ? !membro.foto_path : !!membro.foto_path);
    return passaNome && passaCargo && passaFamilia && passaFoto;
  });
  const filtrosAtivos = termo !== "" || cargoFiltroId !== "" || familiaFiltroId !== "" || fotoFiltro !== "";
  const semFoto = membros.filter((membro) => !membro.foto_path).length;'''),
    ("src/components/ListaMembros.tsx",
     r'''    setFamiliaFiltroId("");
  }''',
     r'''    setFamiliaFiltroId("");
    setFotoFiltro("");
  }'''),
    ("src/components/ListaMembros.tsx",
     r'''            <option value={FILTRO_SEM_FAMILIA}>Sem família</option>
          </select>
        </div>
      </div>''',
     r'''            <option value={FILTRO_SEM_FAMILIA}>Sem família</option>
          </select>
        </div>

        <div className="sm:w-44">
          <label htmlFor="filtro-foto" className="sr-only">
            Filtrar por fotografia
          </label>
          <select
            id="filtro-foto"
            value={fotoFiltro}
            onChange={(e) => setFotoFiltro(e.target.value as "" | "sem" | "com")}
            className={classeSelect}
          >
            <option value="">Todas as fotos</option>
            <option value="sem">Sem fotografia ({semFoto})</option>
            <option value="com">Com fotografia</option>
          </select>
        </div>
      </div>'''),
    ("src/components/ListaMembros.tsx",
     r'''                const nomeFamilia = familiaId ? (familiaPorId.get(familiaId)?.nome ?? null) : null;
''',
     r'''                const nomeFamilia = familiaId ? (familiaPorId.get(familiaId)?.nome ?? null) : null;
                const urlFoto = membro.foto_path ? urlsFotos[membro.foto_path] : undefined;
                // Status = nível do cargo: Músico e Organista informam (Oficializado, Culto Oficial, RJM);
                // os demais cargos são Oficializado automaticamente
                const tipoCategoria = cargoUsaCategoria(nomeCargo);
                const nivel = tipoCategoria
                  ? { rotulo: rotuloDaCategoria(membro.categoria, tipoCategoria), definido: !!membro.categoria }
                  : { rotulo: "Oficializado", definido: true };
'''),
    ("src/components/ListaMembros.tsx",
     r'''                        {/* Avatar com a inicial do nome */}
                        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-indigo-100 text-sm font-bold text-indigo-700">
                          {membro.nome.charAt(0).toUpperCase()}
                        </div>''',
     r'''                        {/* Miniatura da fotografia; sem foto, a inicial do nome */}
                        <div
                          role="img"
                          aria-label={urlFoto ? `Fotografia de ${membro.nome}` : `${membro.nome}: sem fotografia`}
                          style={urlFoto ? { backgroundImage: `url(${urlFoto})` } : undefined}
                          className={
                            "flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-cover bg-center text-sm font-bold " +
                            (urlFoto ? "bg-slate-100" : "bg-indigo-100 text-indigo-700")
                          }
                        >
                          {!urlFoto && membro.nome.charAt(0).toUpperCase()}
                        </div>'''),
    ("src/components/ListaMembros.tsx",
     r'''                          <p className="truncate font-medium text-slate-900">{membro.nome}</p>
''',
     r'''                          <p className="truncate font-medium text-slate-900">{membro.nome}</p>
                          {!membro.foto_path && <p className="text-xs text-amber-700">Sem fotografia</p>}
'''),
    ("src/components/ListaMembros.tsx",
     r'''                    <td className="px-4 py-3">
                      <span
                        className={
                          "rounded-full px-2 py-0.5 text-xs font-medium " +
                          (membro.status === "Ativo"
                            ? "bg-emerald-100 text-emerald-700"
                            : "bg-slate-100 text-slate-600")
                        }
                      >
                        {membro.status}
                      </span>
                    </td>''',
     r'''                    <td className="px-4 py-3">
                      <div className="flex flex-wrap items-center gap-1">
                        <span
                          className={
                            "rounded-full px-2 py-0.5 text-xs font-medium " +
                            (nivel.definido ? "bg-emerald-100 text-emerald-700" : "bg-amber-100 text-amber-800")
                          }
                        >
                          {nivel.rotulo}
                        </span>
                        {membro.status !== "Ativo" && (
                          <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600">
                            {membro.status}
                          </span>
                        )}
                      </div>
                    </td>'''),
    ("src/components/ListaMembros.tsx",
     r'''          Exibindo {membrosFiltrados.length} de {membros.length} membro(s)
''',
     r'''          Exibindo {membrosFiltrados.length} de {membros.length} membro(s) · {semFoto} sem fotografia
'''),
    ("src/app/(painel)/membros/page.tsx",
     r'''import QrMembro from "@/modules/membros/components/QrMembro";''',
     r'''import QrMembro from "@/modules/membros/components/QrMembro";
import type { CadastroMusical } from "@/modules/membros/cadastroMusical";
import { obterCadastroMusical } from "@/modules/membros/services/cadastroMusical";
import { urlsDasFotos } from "@/modules/membros/services/fotos";'''),
    ("src/app/(painel)/membros/page.tsx",
     r'''  | { tipo: "editar"; membro: MembroPublico; cpfInicial: string | null }''',
     r'''  | { tipo: "editar"; membro: MembroPublico; cpfInicial: string | null; cadastro: CadastroMusical | null }'''),
    ("src/app/(painel)/membros/page.tsx",
     r'''  const [membros, setMembros] = useState<MembroPublico[]>([]);''',
     r'''  const [membros, setMembros] = useState<MembroPublico[]>([]);
  const [urlsFotos, setUrlsFotos] = useState<Record<string, string>>({}); // miniaturas da lista'''),
    ("src/app/(painel)/membros/page.tsx",
     r'''      setMembros(dados.membros);
      setErro(null);''',
     r'''      setMembros(dados.membros);
      // Miniaturas: um único pedido de URLs temporárias para todas as fotos (se falhar, a lista fica sem miniaturas)
      setUrlsFotos(await urlsDasFotos(dados.membros.flatMap((m) => (m.foto_path ? [m.foto_path] : []))));
      setErro(null);'''),
    ("src/app/(painel)/membros/page.tsx",
     r'''      const cpfInicial = pode("membros.cpf") ? await obterCpfMembro(membro.id) : null;
      setPainel({ tipo: "editar", membro, cpfInicial });''',
     r'''      const [cpfInicial, cadastro] = await Promise.all([
        pode("membros.cpf") ? obterCpfMembro(membro.id) : Promise.resolve(null),
        obterCadastroMusical(membro.id), // dados pessoais do Cadastro Musical (null = membro antigo, sem cadastro)
      ]);
      setPainel({ tipo: "editar", membro, cpfInicial, cadastro });'''),
    ("src/app/(painel)/membros/page.tsx",
     r'''    painel?.tipo === "editar" ? "Editar membro" : painel?.tipo === "qr" ? "QR Code do membro" : "Novo membro";''',
     r'''    painel?.tipo === "editar"
      ? "Editar cadastro musical"
      : painel?.tipo === "qr"
        ? "QR Code do membro"
        : "Cadastro Musical";'''),
    ("src/app/(painel)/membros/page.tsx",
     r'''          painel?.tipo === "qr" ? "Identificação individual e permanente do membro." : "Preencha os dados do membro."''',
     r'''          painel?.tipo === "qr"
            ? "Identificação individual e permanente do membro."
            : "Campos com * são obrigatórios. A fotografia identifica a pessoa na portaria."'''),
    ("src/app/(painel)/membros/page.tsx",
     r'''          onTentarNovamente={tentarNovamente}
          podeEditar''',
     r'''          urlsFotos={urlsFotos}
          onTentarNovamente={tentarNovamente}
          podeEditar'''),
    ("src/app/(painel)/membros/page.tsx",
     r'''            cpfInicial={painel.tipo === "editar" ? painel.cpfInicial : null}
''',
     r'''            cpfInicial={painel.tipo === "editar" ? painel.cpfInicial : null}
            cadastroInicial={painel.tipo === "editar" ? painel.cadastro : null}
'''),
    ("src/components/layout/navegacao.ts",
     r'''  Building2,
  Camera,
  DatabaseBackup,''',
     r'''  Building2,
  DatabaseBackup,'''),
    ("src/components/layout/navegacao.ts",
     r'''      { href: "/relatorios", rotulo: "Relatórios", icone: FileText, permissao: "relatorios.visualizar" },
      { href: "/fotografias", rotulo: "Fotografias", icone: Camera, permissao: "membros.foto" },
''',
     r'''      { href: "/relatorios", rotulo: "Relatórios", icone: FileText, permissao: "relatorios.visualizar" },
'''),
    ("src/components/layout/navegacao.test.ts",
     r'''  it("quem só tem a permissão de fotografia vê apenas Fotografias", () => {
    expect(hrefs(["membros.foto"])).toEqual(["/fotografias"]);
  });''',
     r'''  it("a tela Fotografias saiu do menu: a foto agora é cadastrada em Músicos / Organistas", () => {
    expect(hrefs(["membros.foto"])).toEqual([]);
  });'''),
    ("src/app/(painel)/fotografias/page.tsx",
     r'''"use client";

/**
 * SysMúsica — Página /fotografias: cadastro, troca e remoção da fotografia dos membros.
 * A foto é reduzida no navegador (800 px, JPEG) e guardada em armazenamento privado. A fotografia
 * aparece para a portaria na hora de conferir a identidade (leitura do QR Code ou busca pelo nome).
 */
import { useCallback, useEffect, useState } from "react";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import GaleriaFotos from "@/modules/membros/components/GaleriaFotos";
import { prepararFoto } from "@/modules/membros/fotoImagem";
import {
  enviarFoto,
  listarMembrosParaFoto,
  removerFoto,
  urlsDasFotos,
  type MembroFoto,
} from "@/modules/membros/services/fotos";

export default function FotografiasPage() {
  const [membros, setMembros] = useState<MembroFoto[]>([]);
  const [urls, setUrls] = useState<Record<string, string>>({});
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [ocupadoId, setOcupadoId] = useState<string | null>(null);
  const [erroAcao, setErroAcao] = useState<string | null>(null);
  const [alvoRemocao, setAlvoRemocao] = useState<MembroFoto | null>(null);
  const [removendo, setRemovendo] = useState(false);
  const [aviso, setAviso] = useState<string | null>(null);

  // Busca os membros e as URLs temporárias das fotos já cadastradas
  const carregar = useCallback(async () => {
    try {
      const lista = await listarMembrosParaFoto();
      const mapa = await urlsDasFotos(lista.flatMap((membro) => (membro.foto_path ? [membro.foto_path] : [])));
      setMembros(lista);
      setUrls(mapa);
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar as fotografias:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar os membros.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga ao abrir a página
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona). Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  function tentarNovamente() {
    setCarregando(true);
    void carregar();
  }

  // Foto escolhida: reduz, envia, vincula ao membro e recarrega a lista
  async function aoEscolherArquivo(membro: MembroFoto, arquivo: File) {
    setOcupadoId(membro.id);
    setErroAcao(null);
    try {
      const imagem = await prepararFoto(arquivo);
      await enviarFoto(membro.id, imagem);
      await carregar();
      setAviso(`Fotografia de ${membro.nome} atualizada.`);
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível salvar a fotografia.");
    } finally {
      setOcupadoId(null);
    }
  }

  async function confirmarRemocao() {
    if (!alvoRemocao) return;
    setRemovendo(true);
    setErroAcao(null);
    try {
      await removerFoto(alvoRemocao.id);
      await carregar();
      setAviso(`Fotografia de ${alvoRemocao.nome} removida.`);
      setAlvoRemocao(null);
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível remover a fotografia.");
      setAlvoRemocao(null);
    } finally {
      setRemovendo(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Fotografias"
          descricao="Cadastre a fotografia dos membros: ela aparece para a portaria na conferência de identidade."
        />

        {erroAcao && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroAcao}
          </p>
        )}

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando membros...</span>
            <Skeleton className="h-14 rounded-2xl" />
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-16" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar os membros." mensagem={erro} onTentarNovamente={tentarNovamente} />
        ) : (
          <GaleriaFotos
            membros={membros}
            urls={urls}
            ocupadoId={ocupadoId}
            onEscolherArquivo={(membro, arquivo) => void aoEscolherArquivo(membro, arquivo)}
            onRemover={setAlvoRemocao}
          />
        )}
      </div>

      <ConfirmDialog
        aberto={alvoRemocao !== null}
        titulo="Remover fotografia?"
        mensagem={
          <p>
            A fotografia de <strong>{alvoRemocao?.nome}</strong> será apagada. Na portaria, ele aparecerá sem
            foto até que uma nova seja cadastrada.
          </p>
        }
        textoConfirmar="Remover"
        processando={removendo}
        onConfirmar={() => void confirmarRemocao()}
        onCancelar={() => setAlvoRemocao(null)}
      />

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}''',
     r'''/**
 * SysMúsica — Página /fotografias (APOSENTADA).
 * A tela Fotografias saiu do menu: a fotografia agora é cadastrada, trocada e removida em
 * Músicos / Organistas (botão Editar), onde também existem o filtro "Sem fotografia" e as miniaturas.
 * Esta página só mantém funcionando links e favoritos antigos.
 */
import { redirect } from "next/navigation";

export default function FotografiasPage() {
  redirect("/membros");
}'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    "src/modules/membros/cadastroMusical.ts": r'''/**
 * SysMúsica — Regras puras do "Cadastro Musical" (sem banco, sem tela). Testadas em cadastroMusical.test.ts.
 *
 * O cadastro tem duas partes:
 *  - dados que já ficavam em "membros" (nome, casa de oração, cargo, instrumento, categoria, cidade, bairro, CPF...);
 *  - dados pessoais novos (estado civil, sexo, telefone, endereço, cartão de identificação...), guardados na
 *    tabela PROTEGIDA membros_cadastro e lidos/gravados só pelas funções do banco obter_cadastro_musical e
 *    salvar_cadastro_musical (migração 0038). A tela nunca lê essa tabela diretamente.
 *
 * Para mudar quais cargos aparecem no cadastro: lista CARGOS_DO_CADASTRO abaixo.
 * Para mudar quais cargos exigem o cartão de identificação: coluna cargos.exige_cartao (banco);
 * enquanto a coluna não existir, vale a lista CARGOS_COM_CARTAO_PADRAO.
 */

export const ESTADOS_CIVIS = ["Casado(a)", "Solteiro(a)", "Viúvo(a)"] as const;
export const SEXOS = ["Masculino", "Feminino"] as const;
export const UFS = [
  "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA",
  "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO",
] as const;

/** Sim/Não dos campos de múltipla escolha ("" = ainda não respondido). */
export type SimNao = "" | "sim" | "nao";

/** Os dados do formulário (todos texto, para ligar direto nos campos da tela). */
export interface CadastroMusical {
  estado_civil: string;
  sexo: string;
  data_batismo: string; // AAAA-MM-DD
  selado: SimNao;
  ddd: string; // 2 dígitos
  telefone: string; // 8 ou 9 dígitos
  tem_whatsapp: SimNao;
  whatsapp: string; // DDD + número (10 ou 11 dígitos)
  email: string;
  cep: string; // 8 dígitos
  endereco: string;
  numero: string;
  complemento: string;
  uf: string;
  cartao_numero: string;
  cartao_emissao: string; // AAAA-MM-DD
  cartao_validade: string; // AAAA-MM-DD
  apresentado_em: string; // AAAA-MM-DD
  apresentado_por: string;
  observacao: string;
}

export const CADASTRO_VAZIO: CadastroMusical = {
  estado_civil: "",
  sexo: "",
  data_batismo: "",
  selado: "",
  ddd: "",
  telefone: "",
  tem_whatsapp: "",
  whatsapp: "",
  email: "",
  cep: "",
  endereco: "",
  numero: "",
  complemento: "",
  uf: "",
  cartao_numero: "",
  cartao_emissao: "",
  cartao_validade: "",
  apresentado_em: "",
  apresentado_por: "",
  observacao: "",
};

// ---------- Cargos ----------

/** O mínimo que precisamos de um cargo (o tipo Cargo do projeto atende a isto). */
export interface CargoCadastro {
  id: string;
  nome: string;
  exige_cartao?: boolean | null;
}

function semAcento(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim();
}

/**
 * Cargos que têm Cadastro Musical (início do nome, sem acento). Ancião, Diácono, Cooperadores e Secretário da
 * Música não têm mais cadastro: só entram nas contagens. "Candidato(a)" ficou de fora até a CCB confirmar.
 */
export const CARGOS_DO_CADASTRO = [
  "encarregado regional",
  "encarregado local",
  "examinadora",
  "instrutor",
  "musico",
  "organista",
] as const;

/** Cargos que exigem o cartão de identificação enquanto a coluna cargos.exige_cartao não decide. */
const CARGOS_COM_CARTAO_PADRAO = ["encarregado regional", "encarregado local", "examinadora"];

export function cargoEntraNoCadastro(nomeCargo: string | null | undefined): boolean {
  if (!nomeCargo) return false;
  const nome = semAcento(nomeCargo);
  return CARGOS_DO_CADASTRO.some((prefixo) => nome.startsWith(prefixo));
}

/**
 * Cargos oferecidos no formulário. Na edição, o cargo atual do membro continua na lista mesmo que seja
 * um cargo antigo (ex.: Ancião), para não apagar nem trocar o cargo sem querer.
 */
export function cargosDoCadastro<T extends CargoCadastro>(cargos: T[], cargoAtualId?: string | null): T[] {
  return cargos.filter((cargo) => cargoEntraNoCadastro(cargo.nome) || cargo.id === cargoAtualId);
}

/** O cargo exige o cartão de identificação (número, validade...)? */
export function cargoExigeCartao(cargo: CargoCadastro | null | undefined): boolean {
  if (!cargo) return false;
  if (typeof cargo.exige_cartao === "boolean") return cargo.exige_cartao;
  const nome = semAcento(cargo.nome);
  return CARGOS_COM_CARTAO_PADRAO.some((prefixo) => nome.startsWith(prefixo));
}

// ---------- Formatos de digitação ----------

export function somenteDigitos(texto: string, maximo?: number): string {
  const digitos = texto.replace(/\D/g, "");
  return maximo ? digitos.slice(0, maximo) : digitos;
}

/** "40000-000" (aceita digitação parcial). */
export function formatarCep(texto: string): string {
  const d = somenteDigitos(texto, 8);
  return d.length > 5 ? `${d.slice(0, 5)}-${d.slice(5)}` : d;
}

/** Telefone sem DDD: "99999-9999" (9 dígitos) ou "9999-9999" (8 dígitos). */
export function formatarTelefone(texto: string): string {
  const d = somenteDigitos(texto, 9);
  if (d.length > 8) return `${d.slice(0, 5)}-${d.slice(5)}`;
  return d.length > 4 ? `${d.slice(0, 4)}-${d.slice(4)}` : d;
}

/** WhatsApp com DDD: "(71) 99999-9999" (aceita digitação parcial). */
export function formatarWhatsapp(texto: string): string {
  const d = somenteDigitos(texto, 11);
  if (d.length <= 2) return d.length ? `(${d}` : "";
  const resto = d.slice(2);
  const corte = resto.length > 8 ? 5 : 4;
  return `(${d.slice(0, 2)}) ${resto.length > corte ? `${resto.slice(0, corte)}-${resto.slice(corte)}` : resto}`;
}

// ---------- Validação ----------

export function emailValido(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

/** Alguma informação do cadastro pessoal foi preenchida? (os campos "" e os Sim/Não vazios não contam) */
export function temAlgumDado(dados: CadastroMusical): boolean {
  return Object.values(dados).some((valor) => valor.trim() !== "");
}

export interface OpcoesValidacao {
  /** Exige todos os campos obrigatórios (cadastro novo, ou edição de quem já tem o cadastro preenchido). */
  completo: boolean;
  /** O cargo escolhido exige o cartão de identificação. */
  exigeCartao: boolean;
  /** Cidade e bairro ficam em "membros", mas são obrigatórios junto com o endereço. */
  cidade: string;
  bairro: string;
}

/** Confere o cadastro. Devolve a mensagem do primeiro problema ou null se estiver tudo certo. */
export function validarCadastro(dados: CadastroMusical, opcoes: OpcoesValidacao): string | null {
  const { completo, exigeCartao, cidade, bairro } = opcoes;
  const vazio = (texto: string) => texto.trim() === "";

  if (completo) {
    if (dados.selado === "") return "Informe se a pessoa é selada.";
    if (vazio(dados.ddd) || vazio(dados.telefone)) return "Informe o DDD e o telefone.";
    if (dados.tem_whatsapp === "") return "Informe se o telefone tem WhatsApp.";
    if (vazio(dados.cep)) return "Informe o CEP.";
    if (vazio(dados.endereco)) return "Informe o endereço.";
    if (vazio(dados.numero)) return "Informe o número do endereço.";
    if (vazio(dados.uf)) return "Informe o estado (UF).";
    if (vazio(cidade)) return "Informe a cidade.";
    if (vazio(bairro)) return "Informe o bairro.";
  }

  if (!vazio(dados.ddd) && !/^\d{2}$/.test(dados.ddd)) return "O DDD deve ter 2 números.";
  if (!vazio(dados.telefone) && !/^\d{8,9}$/.test(dados.telefone)) return "O telefone deve ter 8 ou 9 números.";
  if (dados.tem_whatsapp === "sim" && !vazio(dados.whatsapp) && !/^\d{10,11}$/.test(dados.whatsapp)) {
    return "O WhatsApp deve ter o DDD e 8 ou 9 números.";
  }
  if (!vazio(dados.email) && !emailValido(dados.email)) return "O e-mail informado não é válido.";
  if (!vazio(dados.cep) && !/^\d{8}$/.test(dados.cep)) return "O CEP deve ter 8 números.";
  if (!vazio(dados.uf) && !(UFS as readonly string[]).includes(dados.uf)) return "Escolha um estado (UF) da lista.";

  if (exigeCartao) {
    if (vazio(dados.cartao_numero)) return "Informe o número do cartão de identificação.";
    if (vazio(dados.cartao_validade)) return "Informe a validade do cartão de identificação.";
  }
  if (!vazio(dados.cartao_emissao) && !vazio(dados.cartao_validade) && dados.cartao_emissao > dados.cartao_validade) {
    return "A validade do cartão não pode ser anterior à emissão.";
  }
  return null;
}

// ---------- Conversão com o banco ----------

type Bruto = Record<string, unknown>;

const texto = (valor: unknown): string => (typeof valor === "string" ? valor : "");
const simNao = (valor: unknown): SimNao => (valor === true ? "sim" : valor === false ? "nao" : "");

/** Resposta de obter_cadastro_musical (JSON do banco) -> dados do formulário. */
export function deRetornoDoBanco(bruto: unknown): CadastroMusical {
  const b = (bruto && typeof bruto === "object" ? bruto : {}) as Bruto;
  return {
    estado_civil: texto(b.estado_civil),
    sexo: texto(b.sexo),
    data_batismo: texto(b.data_batismo),
    selado: simNao(b.selado),
    ddd: texto(b.ddd),
    telefone: texto(b.telefone),
    tem_whatsapp: simNao(b.tem_whatsapp),
    whatsapp: texto(b.whatsapp),
    email: texto(b.email),
    cep: texto(b.cep),
    endereco: texto(b.endereco),
    numero: texto(b.numero),
    complemento: texto(b.complemento),
    uf: texto(b.uf),
    cartao_numero: texto(b.cartao_numero),
    cartao_emissao: texto(b.cartao_emissao),
    cartao_validade: texto(b.cartao_validade),
    apresentado_em: texto(b.apresentado_em),
    apresentado_por: texto(b.apresentado_por),
    observacao: texto(b.observacao),
  };
}

/**
 * Dados do formulário -> JSON para salvar_cadastro_musical (campos vazios viram null).
 * Se tem WhatsApp e o número ficou vazio, usa o próprio telefone (DDD + número).
 * Se não tem WhatsApp, o número do WhatsApp não é guardado.
 */
export function paraEnvioAoBanco(dados: CadastroMusical): Record<string, string | boolean | null> {
  const t = (valor: string) => (valor.trim() === "" ? null : valor.trim());
  const b = (valor: SimNao) => (valor === "sim" ? true : valor === "nao" ? false : null);

  let whatsapp: string | null = null;
  if (dados.tem_whatsapp === "sim") {
    whatsapp = t(somenteDigitos(dados.whatsapp)) ?? t(`${dados.ddd}${dados.telefone}`);
  }
  return {
    estado_civil: t(dados.estado_civil),
    sexo: t(dados.sexo),
    data_batismo: t(dados.data_batismo),
    selado: b(dados.selado),
    ddd: t(dados.ddd),
    telefone: t(dados.telefone),
    tem_whatsapp: b(dados.tem_whatsapp),
    whatsapp,
    email: t(dados.email),
    cep: t(dados.cep),
    endereco: t(dados.endereco),
    numero: t(dados.numero),
    complemento: t(dados.complemento),
    uf: t(dados.uf),
    cartao_numero: t(dados.cartao_numero),
    cartao_emissao: t(dados.cartao_emissao),
    cartao_validade: t(dados.cartao_validade),
    apresentado_em: t(dados.apresentado_em),
    apresentado_por: t(dados.apresentado_por),
    observacao: t(dados.observacao),
  };
}
''',
    "src/modules/membros/cadastroMusical.test.ts": r'''import { describe, expect, it } from "vitest";
import {
  CADASTRO_VAZIO,
  cargoEntraNoCadastro,
  cargoExigeCartao,
  cargosDoCadastro,
  deRetornoDoBanco,
  emailValido,
  formatarCep,
  formatarTelefone,
  formatarWhatsapp,
  paraEnvioAoBanco,
  somenteDigitos,
  temAlgumDado,
  validarCadastro,
  type CadastroMusical,
} from "./cadastroMusical";

const completoOk: CadastroMusical = {
  ...CADASTRO_VAZIO,
  selado: "sim",
  ddd: "71",
  telefone: "999998888",
  tem_whatsapp: "sim",
  cep: "40000000",
  endereco: "Rua das Flores",
  numero: "10",
  uf: "BA",
};
const base = { completo: true, exigeCartao: false, cidade: "Salvador", bairro: "Itinga" };

describe("cargos do cadastro", () => {
  it("aceita os cargos do formulário (com ou sem acento, com (a))", () => {
    for (const nome of ["Encarregado Regional", "Encarregado Local", "Examinadora", "Instrutor (a)", "Músico", "Organista"]) {
      expect(cargoEntraNoCadastro(nome), nome).toBe(true);
    }
  });

  it("não aceita os cargos que só entram nas contagens", () => {
    for (const nome of ["Ancião", "Diácono", "Cooperador do Ofício Ministerial", "Secretário da Música", "Candidato (a)"]) {
      expect(cargoEntraNoCadastro(nome), nome).toBe(false);
    }
  });

  it("na edição mantém o cargo atual do membro, mesmo antigo", () => {
    const cargos = [
      { id: "1", nome: "Músico" },
      { id: "2", nome: "Ancião" },
      { id: "3", nome: "Diácono" },
    ];
    expect(cargosDoCadastro(cargos).map((c) => c.id)).toEqual(["1"]);
    expect(cargosDoCadastro(cargos, "2").map((c) => c.id)).toEqual(["1", "2"]);
  });

  it("exige o cartão: usa a coluna do banco; sem ela, a lista padrão", () => {
    expect(cargoExigeCartao({ id: "1", nome: "Músico", exige_cartao: true })).toBe(true);
    expect(cargoExigeCartao({ id: "1", nome: "Examinadora", exige_cartao: false })).toBe(false);
    expect(cargoExigeCartao({ id: "1", nome: "Encarregado Local" })).toBe(true);
    expect(cargoExigeCartao({ id: "1", nome: "Examinadora", exige_cartao: null })).toBe(true);
    expect(cargoExigeCartao({ id: "1", nome: "Organista" })).toBe(false);
    expect(cargoExigeCartao(undefined)).toBe(false);
  });
});

describe("formatos de digitação", () => {
  it("só dígitos", () => {
    expect(somenteDigitos("(71) 9 9999-8888")).toBe("71999998888");
    expect(somenteDigitos("abc123456", 4)).toBe("1234");
  });
  it("CEP", () => {
    expect(formatarCep("40000")).toBe("40000");
    expect(formatarCep("40000000")).toBe("40000-000");
    expect(formatarCep("40.000-000999")).toBe("40000-000");
  });
  it("telefone", () => {
    expect(formatarTelefone("9999")).toBe("9999");
    expect(formatarTelefone("99998888")).toBe("9999-8888");
    expect(formatarTelefone("999998888")).toBe("99999-8888");
  });
  it("WhatsApp", () => {
    expect(formatarWhatsapp("")).toBe("");
    expect(formatarWhatsapp("7")).toBe("(7");
    expect(formatarWhatsapp("71")).toBe("(71");
    expect(formatarWhatsapp("719999")).toBe("(71) 9999");
    expect(formatarWhatsapp("7199998888")).toBe("(71) 9999-8888");
    expect(formatarWhatsapp("71999998888")).toBe("(71) 99999-8888");
  });
});

describe("validarCadastro", () => {
  it("cadastro completo e correto passa", () => {
    expect(validarCadastro(completoOk, base)).toBeNull();
  });

  it("exige cada campo obrigatório quando completo", () => {
    const casos: [Partial<CadastroMusical>, string][] = [
      [{ selado: "" }, "selada"],
      [{ ddd: "" }, "DDD"],
      [{ telefone: "" }, "telefone"],
      [{ tem_whatsapp: "" }, "WhatsApp"],
      [{ cep: "" }, "CEP"],
      [{ endereco: " " }, "endereço"],
      [{ numero: "" }, "número"],
      [{ uf: "" }, "UF"],
    ];
    for (const [troca, trecho] of casos) {
      const erro = validarCadastro({ ...completoOk, ...troca }, base);
      expect(erro, trecho).toContain(trecho);
    }
    expect(validarCadastro(completoOk, { ...base, cidade: "" })).toContain("cidade");
    expect(validarCadastro(completoOk, { ...base, bairro: " " })).toContain("bairro");
  });

  it("sem exigir completo, aceita vazio mas confere o formato do que foi preenchido", () => {
    const solto = { ...base, completo: false };
    expect(validarCadastro(CADASTRO_VAZIO, solto)).toBeNull();
    expect(validarCadastro({ ...CADASTRO_VAZIO, ddd: "7" }, solto)).toContain("DDD");
    expect(validarCadastro({ ...CADASTRO_VAZIO, telefone: "123" }, solto)).toContain("telefone");
    expect(validarCadastro({ ...CADASTRO_VAZIO, cep: "123" }, solto)).toContain("CEP");
    expect(validarCadastro({ ...CADASTRO_VAZIO, uf: "XX" }, solto)).toContain("UF");
    expect(validarCadastro({ ...CADASTRO_VAZIO, email: "sem-arroba" }, solto)).toContain("e-mail");
    expect(
      validarCadastro({ ...CADASTRO_VAZIO, tem_whatsapp: "sim", whatsapp: "123" }, solto)
    ).toContain("WhatsApp");
  });

  it("cartão de identificação: número e validade obrigatórios quando o cargo exige", () => {
    const comCartao = { ...base, exigeCartao: true };
    expect(validarCadastro(completoOk, comCartao)).toContain("número do cartão");
    expect(validarCadastro({ ...completoOk, cartao_numero: "123" }, comCartao)).toContain("validade");
    expect(
      validarCadastro({ ...completoOk, cartao_numero: "123", cartao_validade: "2030-01-01" }, comCartao)
    ).toBeNull();
  });

  it("validade não pode ser anterior à emissão", () => {
    const erro = validarCadastro(
      { ...completoOk, cartao_emissao: "2025-05-01", cartao_validade: "2025-01-01" },
      base
    );
    expect(erro).toContain("anterior");
  });
});

describe("e-mail e dados preenchidos", () => {
  it("e-mail", () => {
    expect(emailValido("a@b.com")).toBe(true);
    expect(emailValido("a@b")).toBe(false);
    expect(emailValido("a b@c.com")).toBe(false);
  });
  it("detecta se há algum dado", () => {
    expect(temAlgumDado(CADASTRO_VAZIO)).toBe(false);
    expect(temAlgumDado({ ...CADASTRO_VAZIO, observacao: "x" })).toBe(true);
    expect(temAlgumDado({ ...CADASTRO_VAZIO, selado: "nao" })).toBe(true);
  });
});

describe("conversão com o banco", () => {
  it("envio: vazio vira null e booleanos viram true/false", () => {
    const envio = paraEnvioAoBanco({ ...completoOk, selado: "nao", complemento: "  " });
    expect(envio.selado).toBe(false);
    expect(envio.tem_whatsapp).toBe(true);
    expect(envio.complemento).toBeNull();
    expect(envio.email).toBeNull();
    expect(envio.uf).toBe("BA");
  });

  it("WhatsApp: vazio com 'sim' copia o telefone; com 'não' não guarda", () => {
    expect(paraEnvioAoBanco({ ...completoOk, whatsapp: "" }).whatsapp).toBe("71999998888");
    expect(paraEnvioAoBanco({ ...completoOk, whatsapp: "(71) 98888-7777" }).whatsapp).toBe("71988887777");
    expect(paraEnvioAoBanco({ ...completoOk, tem_whatsapp: "nao", whatsapp: "71999998888" }).whatsapp).toBeNull();
  });

  it("retorno do banco: aceita nulos e lixo sem quebrar", () => {
    expect(deRetornoDoBanco(null)).toEqual(CADASTRO_VAZIO);
    const lido = deRetornoDoBanco({ selado: true, tem_whatsapp: false, uf: "BA", ddd: null, numero: 5 });
    expect(lido.selado).toBe("sim");
    expect(lido.tem_whatsapp).toBe("nao");
    expect(lido.uf).toBe("BA");
    expect(lido.ddd).toBe("");
    expect(lido.numero).toBe("");
  });

  it("ida e volta mantém os dados", () => {
    const volta = deRetornoDoBanco(paraEnvioAoBanco(completoOk));
    expect(volta).toEqual({ ...completoOk, whatsapp: "71999998888" });
  });
});
''',
    "src/modules/membros/services/cadastroMusical.ts": r'''/**
 * SysMúsica — Serviço do Cadastro Musical (dados pessoais do membro: estado civil, telefone, endereço, cartão...).
 * Esses dados ficam na tabela protegida membros_cadastro: a tela só fala com as funções do banco, que conferem a
 * permissão (membros.criar / membros.editar) e a abrangência do usuário (casa de oração do membro).
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import { deRetornoDoBanco, paraEnvioAoBanco, type CadastroMusical } from "../cadastroMusical";

/** Dados pessoais do membro, ou null se ele ainda não tem o cadastro preenchido (membros antigos). */
export async function obterCadastroMusical(membroId: string): Promise<CadastroMusical | null> {
  const { data, error } = await supabase.rpc("obter_cadastro_musical", { p_membro: membroId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os dados do cadastro."));
  return data ? deRetornoDoBanco(data) : null;
}

/** Grava (ou atualiza) os dados pessoais do membro. O banco valida de novo todos os campos. */
export async function salvarCadastroMusical(membroId: string, dados: CadastroMusical): Promise<void> {
  const { error } = await supabase.rpc("salvar_cadastro_musical", {
    p_membro: membroId,
    p_dados: paraEnvioAoBanco(dados),
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar os dados do cadastro."));
}
''',
    "supabase/migrations/0038_cadastro_musical.sql": r'''-- =============================================================================
-- SysMúsica — Migração 0038: Cadastro Musical (dados pessoais do músico/organista)
--
--   * Tabela PROTEGIDA membros_cadastro: estado civil, sexo, batismo, selado, telefone, WhatsApp, e-mail,
--     endereço e cartão de identificação. Ninguém lê nem grava a tabela direto (sem permissão para
--     anon/authenticated e sem policy): só as funções abaixo, que conferem a permissão e a abrangência.
--   * obter_cadastro_musical(membro)  -> JSON com os dados (ou null se o membro ainda não tem cadastro)
--   * salvar_cadastro_musical(membro, json) -> grava/atualiza (permissão membros.criar ou membros.editar)
--   * cargos.exige_cartao: define quais cargos exigem o cartão de identificação (configurável por SQL).
--   * Sem permissão nova: criar/editar membros já cobre este cadastro.
--
-- OBS. para futuros administradores: esta tabela ainda NÃO entra no backup/restauração da tela Backup
-- (a lista de tabelas permitidas fica na função backup_aplicar). Incluir numa etapa própria.
-- É seguro rodar mais de uma vez.
-- =============================================================================

-- 1) Cartão de identificação por cargo ---------------------------------------
alter table public.cargos add column if not exists exige_cartao boolean not null default false;
grant select (exige_cartao) on public.cargos to authenticated;

update public.cargos
   set exige_cartao = true
 where public.normalizar_texto(nome) in ('encarregado regional', 'encarregado local', 'examinadora');

-- 2) Tabela protegida ---------------------------------------------------------
create table if not exists public.membros_cadastro (
  membro_id        uuid primary key references public.membros (id) on delete cascade,
  estado_civil     text check (estado_civil in ('Casado(a)', 'Solteiro(a)', 'Viúvo(a)')),
  sexo             text check (sexo in ('Masculino', 'Feminino')),
  data_batismo     date,
  selado           boolean,
  ddd              text check (ddd ~ '^[0-9]{2}$'),
  telefone         text check (telefone ~ '^[0-9]{8,9}$'),
  tem_whatsapp     boolean,
  whatsapp         text check (whatsapp ~ '^[0-9]{10,11}$'),
  email            text,
  cep              text check (cep ~ '^[0-9]{8}$'),
  endereco         text,
  numero           text,
  complemento      text,
  uf               text check (uf ~ '^[A-Z]{2}$'),
  cartao_numero    text,
  cartao_emissao   date,
  cartao_validade  date,
  apresentado_em   date,
  apresentado_por  text,
  observacao       text,
  criado_em        timestamptz not null default now(),
  atualizado_em    timestamptz not null default now(),
  constraint membros_cadastro_cartao_datas check (
    cartao_emissao is null or cartao_validade is null or cartao_emissao <= cartao_validade
  )
);

alter table public.membros_cadastro enable row level security;
revoke all on public.membros_cadastro from public, anon, authenticated;

-- 3) Ler o cadastro ----------------------------------------------------------
create or replace function public.obter_cadastro_musical(p_membro uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_casa uuid;
  v_res  jsonb;
begin
  if not (public.tem_permissao('membros.editar') or public.tem_permissao('membros.criar')) then
    raise exception 'Você não tem permissão para ver este cadastro.' using errcode = '42501';
  end if;

  select m.casa_oracao_id into v_casa
    from public.membros m
   where m.id = p_membro and m.excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.' using errcode = 'P0002';
  end if;
  if v_casa is not null and not public.casa_oracao_na_abrangencia(v_casa) then
    raise exception 'Você não tem acesso a este cadastro.' using errcode = '42501';
  end if;

  select to_jsonb(c) - 'membro_id' - 'criado_em' - 'atualizado_em'
    into v_res
    from public.membros_cadastro c
   where c.membro_id = p_membro;
  return v_res; -- null quando o membro ainda não tem o cadastro preenchido
end;
$$;

-- 4) Gravar o cadastro -------------------------------------------------------
create or replace function public.salvar_cadastro_musical(p_membro uuid, p_dados jsonb)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_casa   uuid;
  v_cargo  uuid;
  v_exige  boolean;
  v_estado_civil    text := nullif(btrim(p_dados ->> 'estado_civil'), '');
  v_sexo            text := nullif(btrim(p_dados ->> 'sexo'), '');
  v_data_batismo    date := nullif(btrim(p_dados ->> 'data_batismo'), '')::date;
  v_selado          boolean := (p_dados ->> 'selado')::boolean;
  v_ddd             text := nullif(btrim(p_dados ->> 'ddd'), '');
  v_telefone        text := nullif(btrim(p_dados ->> 'telefone'), '');
  v_tem_whatsapp    boolean := (p_dados ->> 'tem_whatsapp')::boolean;
  v_whatsapp        text := nullif(btrim(p_dados ->> 'whatsapp'), '');
  v_email           text := nullif(btrim(p_dados ->> 'email'), '');
  v_cep             text := nullif(btrim(p_dados ->> 'cep'), '');
  v_endereco        text := nullif(btrim(p_dados ->> 'endereco'), '');
  v_numero          text := nullif(btrim(p_dados ->> 'numero'), '');
  v_complemento     text := nullif(btrim(p_dados ->> 'complemento'), '');
  v_uf              text := nullif(btrim(p_dados ->> 'uf'), '');
  v_cartao_numero   text := nullif(btrim(p_dados ->> 'cartao_numero'), '');
  v_cartao_emissao  date := nullif(btrim(p_dados ->> 'cartao_emissao'), '')::date;
  v_cartao_validade date := nullif(btrim(p_dados ->> 'cartao_validade'), '')::date;
  v_apresentado_em  date := nullif(btrim(p_dados ->> 'apresentado_em'), '')::date;
  v_apresentado_por text := nullif(btrim(p_dados ->> 'apresentado_por'), '');
  v_observacao      text := nullif(btrim(p_dados ->> 'observacao'), '');
begin
  if not (public.tem_permissao('membros.criar') or public.tem_permissao('membros.editar')) then
    raise exception 'Você não tem permissão para salvar este cadastro.' using errcode = '42501';
  end if;

  select m.casa_oracao_id, m.cargo_id into v_casa, v_cargo
    from public.membros m
   where m.id = p_membro and m.excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.' using errcode = 'P0002';
  end if;
  if v_casa is not null and not public.casa_oracao_na_abrangencia(v_casa) then
    raise exception 'Você não tem acesso a este cadastro.' using errcode = '42501';
  end if;

  -- Validações com mensagem clara (as regras da tabela são a segunda barreira)
  if v_estado_civil is not null and v_estado_civil not in ('Casado(a)', 'Solteiro(a)', 'Viúvo(a)') then
    raise exception 'Estado civil inválido.' using errcode = '22023';
  end if;
  if v_sexo is not null and v_sexo not in ('Masculino', 'Feminino') then
    raise exception 'Sexo inválido.' using errcode = '22023';
  end if;
  if v_ddd is not null and v_ddd !~ '^[0-9]{2}$' then
    raise exception 'O DDD deve ter 2 números.' using errcode = '22023';
  end if;
  if v_telefone is not null and v_telefone !~ '^[0-9]{8,9}$' then
    raise exception 'O telefone deve ter 8 ou 9 números.' using errcode = '22023';
  end if;
  if v_whatsapp is not null and v_whatsapp !~ '^[0-9]{10,11}$' then
    raise exception 'O WhatsApp deve ter o DDD e 8 ou 9 números.' using errcode = '22023';
  end if;
  if v_email is not null and v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'O e-mail informado não é válido.' using errcode = '22023';
  end if;
  if v_cep is not null and v_cep !~ '^[0-9]{8}$' then
    raise exception 'O CEP deve ter 8 números.' using errcode = '22023';
  end if;
  if v_uf is not null and v_uf !~ '^[A-Z]{2}$' then
    raise exception 'Estado (UF) inválido.' using errcode = '22023';
  end if;
  if v_cartao_emissao is not null and v_cartao_validade is not null and v_cartao_emissao > v_cartao_validade then
    raise exception 'A validade do cartão não pode ser anterior à emissão.' using errcode = '22023';
  end if;

  -- Cargos que exigem o cartão de identificação (coluna cargos.exige_cartao)
  select c.exige_cartao into v_exige from public.cargos c where c.id = v_cargo;
  if coalesce(v_exige, false) and (v_cartao_numero is null or v_cartao_validade is null) then
    raise exception 'Este cargo exige o número e a validade do cartão de identificação.' using errcode = '22023';
  end if;

  -- Sem WhatsApp: não guarda número de WhatsApp
  if v_tem_whatsapp is not true then
    v_whatsapp := null;
  end if;

  insert into public.membros_cadastro as c (
    membro_id, estado_civil, sexo, data_batismo, selado, ddd, telefone, tem_whatsapp, whatsapp, email,
    cep, endereco, numero, complemento, uf, cartao_numero, cartao_emissao, cartao_validade,
    apresentado_em, apresentado_por, observacao
  ) values (
    p_membro, v_estado_civil, v_sexo, v_data_batismo, v_selado, v_ddd, v_telefone, v_tem_whatsapp, v_whatsapp, v_email,
    v_cep, v_endereco, v_numero, v_complemento, v_uf, v_cartao_numero, v_cartao_emissao, v_cartao_validade,
    v_apresentado_em, v_apresentado_por, v_observacao
  )
  on conflict (membro_id) do update set
    estado_civil = excluded.estado_civil, sexo = excluded.sexo, data_batismo = excluded.data_batismo,
    selado = excluded.selado, ddd = excluded.ddd, telefone = excluded.telefone,
    tem_whatsapp = excluded.tem_whatsapp, whatsapp = excluded.whatsapp, email = excluded.email,
    cep = excluded.cep, endereco = excluded.endereco, numero = excluded.numero,
    complemento = excluded.complemento, uf = excluded.uf, cartao_numero = excluded.cartao_numero,
    cartao_emissao = excluded.cartao_emissao, cartao_validade = excluded.cartao_validade,
    apresentado_em = excluded.apresentado_em, apresentado_por = excluded.apresentado_por,
    observacao = excluded.observacao, atualizado_em = now();
end;
$$;

-- 5) Quem pode chamar --------------------------------------------------------
revoke all on function public.obter_cadastro_musical(uuid) from public, anon;
revoke all on function public.salvar_cadastro_musical(uuid, jsonb) from public, anon;
grant execute on function public.obter_cadastro_musical(uuid) to authenticated;
grant execute on function public.salvar_cadastro_musical(uuid, jsonb) to authenticated;
''',
}


# Arquivos a REMOVER: só são apagados se o conteúdo for idêntico ao esperado (cópia fica no backup)
REMOVER = {
    "src/app/(painel)/fotografias/layout.tsx": r'''import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela de fotografias: só quem tem a permissão de fotografia dos membros entra. */
export default function FotografiasLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="membros.foto">{children}</RequerPermissao>;
}

''',
    "src/modules/membros/components/GaleriaFotos.tsx": r'''"use client";

/**
 * SysMúsica — Lista de membros com a situação da fotografia (busca e filtro) e as ações de enviar,
 * trocar e remover. O envio e a remoção são feitos pela página; aqui só há a interface.
 */
import { useRef, useState, type ChangeEvent } from "react";
import { Search, Trash2, User } from "lucide-react";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { cn } from "@/lib/cn";
import { normalizarTexto } from "@/lib/texto";
import type { MembroFoto } from "../services/fotos";

interface GaleriaFotosProps {
  membros: MembroFoto[];
  urls: Record<string, string>; // caminho da foto -> URL temporária
  ocupadoId: string | null; // membro cujo envio/remoção está em andamento
  onEscolherArquivo: (membro: MembroFoto, arquivo: File) => void;
  onRemover: (membro: MembroFoto) => void;
}

type Filtro = "todos" | "sem" | "com";

const classeCampo =
  "rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200";

export default function GaleriaFotos({ membros, urls, ocupadoId, onEscolherArquivo, onRemover }: GaleriaFotosProps) {
  const [busca, setBusca] = useState("");
  const [filtro, setFiltro] = useState<Filtro>("todos");
  // Um único seletor de arquivo para a lista inteira; o membro-alvo fica guardado até a escolha
  const entradaRef = useRef<HTMLInputElement>(null);
  const alvoRef = useRef<MembroFoto | null>(null);

  const termo = normalizarTexto(busca);
  const filtrados = membros.filter((membro) => {
    const passaFiltro = filtro === "todos" || (filtro === "sem" ? !membro.foto_path : !!membro.foto_path);
    const texto = normalizarTexto(`${membro.nome} ${membro.congregacao ?? ""}`);
    return passaFiltro && (termo === "" || texto.includes(termo));
  });
  const semFoto = membros.filter((membro) => !membro.foto_path).length;

  function escolher(membro: MembroFoto) {
    alvoRef.current = membro;
    entradaRef.current?.click();
  }

  function aoSelecionar(evento: ChangeEvent<HTMLInputElement>) {
    const arquivo = evento.target.files?.[0];
    evento.target.value = ""; // permite escolher o mesmo arquivo de novo
    if (arquivo && alvoRef.current) onEscolherArquivo(alvoRef.current, arquivo);
  }

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <input
        ref={entradaRef}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="sr-only"
        tabIndex={-1}
        aria-hidden="true"
        onChange={aoSelecionar}
      />

      <div className="flex flex-col gap-3 border-b border-slate-200 p-4 sm:flex-row sm:items-center">
        <div className="relative min-w-0 flex-1">
          <label htmlFor="busca-foto" className="sr-only">
            Pesquisar membros
          </label>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="busca-foto"
            type="search"
            autoComplete="off"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Pesquisar por nome ou congregação..."
            className={classeCampo + " w-full pl-9 placeholder:text-slate-400"}
          />
        </div>
        <div className="sm:w-56">
          <label htmlFor="filtro-foto" className="sr-only">
            Filtrar por fotografia
          </label>
          <select
            id="filtro-foto"
            value={filtro}
            onChange={(e) => setFiltro(e.target.value as Filtro)}
            className={classeCampo + " w-full"}
          >
            <option value="todos">Todos os membros</option>
            <option value="sem">Sem fotografia ({semFoto})</option>
            <option value="com">Com fotografia</option>
          </select>
        </div>
      </div>

      <ul className="divide-y divide-slate-100">
        {filtrados.length === 0 ? (
          <li className="px-4 py-10 text-center text-sm text-slate-500">Nenhum membro encontrado.</li>
        ) : (
          filtrados.map((membro) => {
            const url = membro.foto_path ? urls[membro.foto_path] : undefined;
            const ocupado = ocupadoId === membro.id;
            return (
              <li key={membro.id} className="flex items-center gap-3 px-4 py-3">
                <div
                  role="img"
                  aria-label={url ? `Fotografia de ${membro.nome}` : `${membro.nome}: sem fotografia`}
                  style={url ? { backgroundImage: `url(${url})` } : undefined}
                  className="flex h-14 w-12 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-slate-100 bg-cover bg-center text-slate-400"
                >
                  {!url && <User className="h-5 w-5" aria-hidden="true" />}
                </div>

                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium text-slate-900">{membro.nome}</p>
                  <p className="truncate text-xs text-slate-500">{membro.congregacao ?? "—"}</p>
                  <p className={cn("text-xs", membro.foto_path ? "text-emerald-700" : "text-amber-700")}>
                    {ocupado ? "Enviando..." : membro.foto_path ? "Com fotografia" : "Sem fotografia"}
                  </p>
                </div>

                <div className="flex shrink-0 items-center gap-1">
                  <button
                    type="button"
                    onClick={() => escolher(membro)}
                    disabled={ocupadoId !== null}
                    className="rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    {membro.foto_path ? "Trocar foto" : "Adicionar foto"}
                  </button>
                  {membro.foto_path && (
                    <BotaoIcone
                      icone={Trash2}
                      rotulo={`Remover a fotografia de ${membro.nome}`}
                      onClick={() => onRemover(membro)}
                    />
                  )}
                </div>
              </li>
            );
          })
        )}
      </ul>

      <div className="border-t border-slate-200 bg-slate-50 px-4 py-3 text-xs text-slate-500">
        Exibindo {filtrados.length} de {membros.length} membro(s) · {semFoto} sem fotografia
      </div>
    </div>
  );
}

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

for arq, esperado in REMOVER.items():
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"PARA REMOVER, NÃO ENCONTRADO: {arq}")
    elif ler(caminho).replace("\r\n", "\n").strip() != esperado.replace("\r\n", "\n").strip():
        problemas.append(f"PARA REMOVER, CONTEÚDO DIFERENTE DO ESPERADO (não vou apagar): {arq}")

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

removidos = []
for arq in REMOVER:
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    os.remove(origem)
    removidos.append(arq)

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
print(f"OK: {len(EDITS)} trocas em {len(alterados)} arquivos + {len(criados)} arquivos novos + {len(removidos)} removidos. Backup em {BKP}")
PYSCRIPT
rc=$?
[ $rc -eq 0 ] || { echo "Nada foi alterado (veja acima)."; exit 1; }

reverter() {
  echo "↩ Desfazendo as alterações a partir de $BKP ..."
  ( cd "$BKP" && find . -type f ! -name .arquivos ! -name .novos -print0 | while IFS= read -r -d '' f; do cp "$f" "$RAIZ/$f"; done )
  while IFS= read -r n; do [ -n "$n" ] && { rm -f "$RAIZ/$n"; rmdir -p "$(dirname "$RAIZ/$n")" 2>/dev/null; }; done < "$BKP/.novos"
  true
}

passo() {
  nome="$1"; shift
  echo "▶ $nome"
  if "$@" > /tmp/p4-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p4-passo.out
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
echo "ATENÇÃO: há SQL nesta parte. Rode supabase/migrations/0038_cadastro_musical.sql no Supabase ANTES do git push."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
