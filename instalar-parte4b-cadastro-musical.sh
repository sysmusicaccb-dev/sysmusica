#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 4-B: Cadastro Musical (CEP automático, campos obrigatórios, Batizado, documento, Órgão)
#
#  ATENÇÃO: rode ANTES o SQL supabase/migrations/0040_cadastro_musical_obrigatorios.sql no Supabase (SQL Editor).
#  Este instalador altera o formulário de Músicos/Organistas, cria os arquivos novos (consulta de CEP, envio de
#  documentos) e coloca a migração na pasta supabase/migrations (para o histórico do projeto).
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-parte4b-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && bash instalar-parte4b-ilustracoes.sh
# Log:  /tmp/instalar-parte4b.log
# =============================================================================

LOG=/tmp/instalar-parte4b.log
BKP=/tmp/bkp-parte4b-$(date +%Y%m%d-%H%M%S)
RAIZ="$(pwd)"

(
[ -f package.json ] && [ -d src ] || { echo "ERRO: rode dentro da pasta sysmusica (onde está o package.json)."; exit 1; }
mkdir -p "$BKP"
export BKP RAIZ

echo "== 1/3  Conferindo e aplicando as alterações =="
# (se o SQL 0040 ainda não foi rodado no Supabase, salvar o cadastro musical dará erro até rodar)
python3 - <<'PYSCRIPT'
import os, shutil, sys, hashlib

RAIZ = os.environ["RAIZ"]
BKP = os.environ["BKP"]

# (arquivo, trecho antigo, trecho novo) — cada "antigo" precisa existir EXATAMENTE 1 vez no arquivo.
# Os trechos usam \n; o instalador converte para o fim de linha do próprio arquivo (CRLF ou LF).
EDITS = [
    ("src/components/FormularioMembro.tsx",
     r''' *  - Os campos obrigatórios (*) valem no cadastro novo e em quem já tem o cadastro preenchido.
''',
     r''' *  - Os campos obrigatórios (*) valem no cadastro novo e em quem já tem o cadastro preenchido.
 *
 * MIGRAÇÃO 0040: no cadastro completo também são obrigatórios CPF, data de nascimento, estado civil, sexo, instrumento
 *      (nos cargos que usam instrumento), Batizado (Sim/Não; sendo Sim, a data do batismo) e a frente e o verso do
 *      documento de identificação (armazenamento privado). Organista, Examinadora, Instrutor e Instrutora só aceitam
 *      o instrumento Órgão (cargos.somente_orgao). Ao digitar o CEP, o endereço é consultado online (ViaCEP).
'''),
    ("src/components/FormularioMembro.tsx",
     r'''import { useState, type FormEvent, type ReactNode } from "react";''',
     r'''import { useRef, useState, type FormEvent, type ReactNode } from "react";'''),
    ("src/components/FormularioMembro.tsx",
     r'''import CampoFoto from "@/modules/membros/components/CampoFoto";
''',
     r'''import CampoFoto from "@/modules/membros/components/CampoFoto";
import CampoDocumento from "@/modules/membros/components/CampoDocumento";
'''),
    ("src/components/FormularioMembro.tsx",
     r'''import { descartarFoto, enviarFoto, removerFoto, subirFotoNova } from "@/modules/membros/services/fotos";
''',
     r'''import { descartarFoto, enviarFoto, removerFoto, subirFotoNova } from "@/modules/membros/services/fotos";
import { buscarEnderecoPorCep } from "@/modules/membros/services/cep";
import { descartarDocumentos, subirDocumento } from "@/modules/membros/services/documentos";
'''),
    ("src/components/FormularioMembro.tsx",
     r'''  cargoExigeCartao,
  cargosDoCadastro,
  formatarCep,
''',
     r'''  cargoExigeCartao,
  cargoSomenteOrgao,
  cargosDoCadastro,
  formatarCep,
'''),
    ("src/components/FormularioMembro.tsx",
     r'''  formatarWhatsapp,
  somenteDigitos,
''',
     r'''  formatarWhatsapp,
  instrumentosDoCargo,
  somenteDigitos,
'''),
    ("src/components/FormularioMembro.tsx",
     r'''  podeFoto: boolean; // permissão membros.foto (trocar a fotografia de um membro já cadastrado)
''',
     r'''  podeFoto: boolean; // permissão membros.foto (trocar a fotografia de um membro já cadastrado)
  podeDocumento: boolean; // permissão membros.cpf (ver o documento de identificação já anexado)
'''),
    ("src/components/FormularioMembro.tsx",
     r'''  podeFoto,
  cargos,
''',
     r'''  podeFoto,
  podeDocumento,
  cargos,
'''),
    ("src/components/FormularioMembro.tsx",
     r'''  const [foto, setFoto] = useState<Blob | null>(null); // foto nova já preparada (obrigatória no cadastro novo)
''',
     r'''  const [foto, setFoto] = useState<Blob | null>(null); // foto nova já preparada (obrigatória no cadastro novo)
  const [docFrente, setDocFrente] = useState<Blob | null>(null); // imagem nova da frente do documento
  const [docVerso, setDocVerso] = useState<Blob | null>(null); // imagem nova do verso do documento
  const [statusCep, setStatusCep] = useState<StatusCep>(""); // andamento da consulta do endereço pelo CEP
  const ultimoCepConsultado = useRef(""); // evita consultar o mesmo CEP de novo e descarta resposta atrasada
'''),
    ("src/components/FormularioMembro.tsx",
     r'''  const completo = !editando || cadastroInicial !== null || temAlgumDado(cadastro);
''',
     r'''  const completo = !editando || cadastroInicial !== null || temAlgumDado(cadastro);
  // Cargo travado no Órgão (Organista, Examinadora, Instrutor, Instrutora): só os instrumentos Órgão aparecem
  const somenteOrgao = cargoSomenteOrgao(cargoSelecionado);
  const instrumentosDisponiveis = instrumentosDoCargo(instrumentos, somenteOrgao);
  // O instrumento é obrigatório nos cargos que o usam, no cadastro completo (e sempre nos cargos que exigem)
  const instrumentoObrigatorio = permiteInstrumento && (exigeInstrumento || completo);
'''),
    ("src/components/FormularioMembro.tsx",
     r'''    if (!novoCargo?.permite_instrumento) setInstrumentoId("");
''',
     r'''    if (!novoCargo?.permite_instrumento) {
      setInstrumentoId("");
    } else if (cargoSomenteOrgao(novoCargo)) {
      // Cargo travado no Órgão: escolhe o Órgão sozinho (se só houver um) e tira um instrumento que não seja Órgão
      const orgaos = instrumentosDoCargo(instrumentos, true);
      setInstrumentoId((atual) => (orgaos.some((item) => item.id === atual) ? atual : orgaos.length === 1 ? orgaos[0].id : ""));
    }
'''),
    ("src/components/FormularioMembro.tsx",
     r'''  // Remove a fotografia atual (só na edição, com a permissão de fotografia, depois de confirmar)
''',
     r'''  // "Batizado? Não" apaga a data do batismo (só quem é batizado tem data)
  function escolherBatizado(valor: SimNao) {
    setCadastro((atual) => ({ ...atual, batizado: valor, data_batismo: valor === "sim" ? atual.data_batismo : "" }));
  }

  // CEP: ao completar os 8 números, consulta o endereço online (ViaCEP) e preenche rua, bairro, cidade, UF e
  // complemento. Tudo continua editável; se a consulta falhar, a pessoa digita o endereço normalmente.
  async function mudarCep(valor: string) {
    const digitos = somenteDigitos(valor, 8);
    mudar("cep", digitos);
    if (digitos.length < 8) {
      ultimoCepConsultado.current = "";
      setStatusCep("");
      return;
    }
    if (digitos === ultimoCepConsultado.current) return;
    ultimoCepConsultado.current = digitos;
    setStatusCep("buscando");
    const resultado = await buscarEnderecoPorCep(digitos);
    if (ultimoCepConsultado.current !== digitos) return; // o CEP mudou enquanto a consulta andava
    if (resultado.tipo !== "ok") {
      setStatusCep(resultado.tipo);
      return;
    }
    const achado = resultado.endereco;
    setCadastro((atual) => ({
      ...atual,
      endereco: achado.endereco || atual.endereco,
      complemento: achado.complemento || atual.complemento,
      uf: achado.uf || atual.uf,
    }));
    if (achado.cidade) setCidade(achado.cidade);
    if (achado.bairro) setBairro(achado.bairro);
    setStatusCep("encontrado");
  }

  // Remove a fotografia atual (só na edição, com a permissão de fotografia, depois de confirmar)
'''),
    ("src/components/FormularioMembro.tsx",
     r'''    // Dados pessoais do Cadastro Musical (o banco confere tudo de novo)
    const erroCadastro = validarCadastro(cadastro, { completo, exigeCartao, cidade, bairro });
''',
     r'''    // Cargo travado no Órgão: o instrumento precisa ser um dos Órgãos (o banco confere de novo)
    if (somenteOrgao && instrumentoId && !instrumentosDisponiveis.some((item) => item.id === instrumentoId)) {
      return setErroForm(`O cargo ${cargoSelecionado?.nome ?? "escolhido"} só pode usar o instrumento Órgão.`);
    }

    // O CPF é obrigatório no cadastro novo, mas só quem tem a permissão CPF consegue preenchê-lo
    if (!editando && !podeCpf) {
      return setErroForm("O CPF é obrigatório e o seu perfil não tem a permissão CPF. Peça a um administrador para liberá-la.");
    }

    // Dados pessoais do Cadastro Musical (o banco confere tudo de novo)
    const erroCadastro = validarCadastro(cadastro, {
      completo,
      exigeCartao,
      cidade,
      bairro,
      cpf: cpfDigitos,
      cpfObrigatorio: completo && podeCpf,
      dataNascimento,
      instrumentoId: permiteInstrumento ? instrumentoId : "",
      instrumentoObrigatorio,
      temDocumentoFrente: docFrente !== null || cadastro.documento_frente_path !== "",
      temDocumentoVerso: docVerso !== null || cadastro.documento_verso_path !== "",
    });
'''),
    ("src/components/FormularioMembro.tsx",
     r'''        // Dados pessoais: depois do cargo, porque o banco confere o cartão pelo cargo atual do membro
        if (completo) await salvarCadastroMusical(membro.id, cadastro);
''',
     r'''        // Dados pessoais: depois do cargo, porque o banco confere o cartão pelo cargo atual do membro
        if (completo) {
          const dadosCadastro = { ...cadastro };
          const docsNovos: string[] = [];
          try {
            // Documento novo (opcional na edição se já houver um anexado): sobe para a pasta do membro
            if (docFrente) {
              dadosCadastro.documento_frente_path = await subirDocumento(membro.id, "frente", docFrente);
              docsNovos.push(dadosCadastro.documento_frente_path);
            }
            if (docVerso) {
              dadosCadastro.documento_verso_path = await subirDocumento(membro.id, "verso", docVerso);
              docsNovos.push(dadosCadastro.documento_verso_path);
            }
            await salvarCadastroMusical(membro.id, dadosCadastro);
          } catch (e) {
            await descartarDocumentos(docsNovos); // não deixa arquivo solto se o cadastro não foi salvo
            throw e;
          }
          // Documento trocado: apaga o arquivo antigo (se não conseguir, ele só fica sem uso)
          await descartarDocumentos([
            docFrente ? cadastro.documento_frente_path : "",
            docVerso ? cadastro.documento_verso_path : "",
          ]);
        }
'''),
    ("src/components/FormularioMembro.tsx",
     r'''        const caminho = await subirFotoNova(novoId, foto as Blob);
        try {
          await criarMembro({''',
     r'''        const caminho = await subirFotoNova(novoId, foto as Blob);
        // Documento (frente e verso): sobem antes, para a pasta do próprio membro; o banco confere os arquivos ao salvar
        const cadastroNovo = { ...cadastro };
        const docsNovos: string[] = [];
        try {
          if (docFrente) {
            cadastroNovo.documento_frente_path = await subirDocumento(novoId, "frente", docFrente);
            docsNovos.push(cadastroNovo.documento_frente_path);
          }
          if (docVerso) {
            cadastroNovo.documento_verso_path = await subirDocumento(novoId, "verso", docVerso);
            docsNovos.push(cadastroNovo.documento_verso_path);
          }
        } catch (e) {
          await descartarFoto(caminho);
          await descartarDocumentos(docsNovos);
          throw e;
        }
        try {
          await criarMembro({'''),
    ("src/components/FormularioMembro.tsx",
     r'''          await descartarFoto(caminho); // o cadastro falhou: não deixa a foto solta
''',
     r'''          await descartarFoto(caminho); // o cadastro falhou: não deixa a foto solta
          await descartarDocumentos(docsNovos);
'''),
    ("src/components/FormularioMembro.tsx",
     r'''          await salvarCadastroMusical(novoId, cadastro);
''',
     r'''          await salvarCadastroMusical(novoId, cadastroNovo);
'''),
    ("src/components/FormularioMembro.tsx",
     r'''          const motivo = e instanceof Error ? e.message : "erro desconhecido";
''',
     r'''          const motivo = e instanceof Error ? e.message : "erro desconhecido";
          await descartarDocumentos(docsNovos); // os documentos precisarão ser anexados de novo na edição
'''),
    ("src/components/FormularioMembro.tsx",
     r'''            id="cpf"
            rotulo="CPF"
            dica="Evita cadastros duplicados. O CPF é protegido: só quem tem permissão o vê por completo."
          >''',
     r'''            id="cpf"
            rotulo="CPF"
            obrigatorio={completo}
            dica="Evita cadastros duplicados. O CPF é protegido: só quem tem permissão o vê por completo."
          >'''),
    ("src/components/FormularioMembro.tsx",
     r'''        <Campo id="data_nascimento" rotulo="Data de nascimento">
''',
     r'''        {/* Sem a permissão CPF não dá para preencher o CPF obrigatório de um cadastro novo */}
        {!podeCpf && !editando && (
          <p role="alert" className="rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
            O CPF é obrigatório no cadastro e o seu perfil não tem a permissão CPF. Peça a um administrador para liberá-la
            em Administração &gt; Grupos de acesso.
          </p>
        )}

        <Campo id="data_nascimento" rotulo="Data de nascimento" obrigatorio={completo}>
'''),
    ("src/components/FormularioMembro.tsx",
     r'''        <div className="grid grid-cols-2 gap-3">
          <Campo id="estado_civil" rotulo="Estado civil">
''',
     r'''        <div className="grid grid-cols-2 gap-3">
          <Campo id="estado_civil" rotulo="Estado civil" obrigatorio={completo}>
'''),
    ("src/components/FormularioMembro.tsx",
     r'''              onChange={(e) => mudar("estado_civil", e.target.value)}
              disabled={salvando}
              className={classeInput}
            >
              <option value="">—</option>''',
     r'''              onChange={(e) => mudar("estado_civil", e.target.value)}
              disabled={salvando}
              className={classeInput}
            >
              <option value="">{rotuloSimNao(completo)}</option>'''),
    ("src/components/FormularioMembro.tsx",
     r'''          <Campo id="sexo" rotulo="Sexo">
''',
     r'''          <Campo id="sexo" rotulo="Sexo" obrigatorio={completo}>
'''),
    ("src/components/FormularioMembro.tsx",
     r'''              onChange={(e) => mudar("sexo", e.target.value)}
              disabled={salvando}
              className={classeInput}
            >
              <option value="">—</option>''',
     r'''              onChange={(e) => mudar("sexo", e.target.value)}
              disabled={salvando}
              className={classeInput}
            >
              <option value="">{rotuloSimNao(completo)}</option>'''),
    ("src/components/FormularioMembro.tsx",
     r'''              obrigatorio={exigeInstrumento}
              dica="Escolha na lista. Para incluir um instrumento novo, cadastre em Instrumentos e famílias."
            >
              <SeletorInstrumento
                id="instrumento"
                valor={instrumentoId}
                onChange={setInstrumentoId}
                instrumentos={instrumentos}
                familias={familias}
                obrigatorio={exigeInstrumento}
                disabled={salvando}''',
     r'''              obrigatorio={instrumentoObrigatorio}
              dica={
                somenteOrgao
                  ? instrumentosDisponiveis.length === 0
                    ? "Este cargo só usa o instrumento Órgão, mas nenhum Órgão está cadastrado. Cadastre em Instrumentos e famílias."
                    : "Este cargo só usa o instrumento Órgão (escolhido automaticamente)."
                  : "Escolha na lista. Para incluir um instrumento novo, cadastre em Instrumentos e famílias."
              }
            >
              <SeletorInstrumento
                id="instrumento"
                valor={instrumentoId}
                onChange={setInstrumentoId}
                instrumentos={instrumentosDisponiveis}
                familias={familias}
                obrigatorio={instrumentoObrigatorio}
                disabled={salvando || (somenteOrgao && instrumentosDisponiveis.length === 1)}'''),
    ("src/components/FormularioMembro.tsx",
     r'''          <Campo id="data_batismo" rotulo="Data de batismo">
            <input
              id="data_batismo"
              type="date"
              max={hoje}
              value={cadastro.data_batismo}
              onChange={(e) => mudar("data_batismo", e.target.value)}
              disabled={salvando}
              className={classeInput}
            />
          </Campo>''',
     r'''          <Campo id="batizado" rotulo="Batizado(a)?" obrigatorio={completo}>
            <select
              id="batizado"
              value={cadastro.batizado}
              onChange={(e) => escolherBatizado(e.target.value as SimNao)}
              disabled={salvando}
              className={classeInput}
            >
              <option value="">{rotuloSimNao(completo)}</option>
              <option value="sim">Sim</option>
              <option value="nao">Não</option>
            </select>
          </Campo>'''),
    ("src/components/FormularioMembro.tsx",
     r'''        </div>
      </Secao>

      {/* ---------- Cartão de identificação (só para os cargos marcados em cargos.exige_cartao) ---------- */}''',
     r'''        </div>

        {/* Data do batismo: só aparece (e é obrigatória) para quem é batizado */}
        {cadastro.batizado === "sim" && (
          <Campo id="data_batismo" rotulo="Data do batismo" obrigatorio>
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
        )}
      </Secao>

      {/* ---------- Cartão de identificação (só para os cargos marcados em cargos.exige_cartao) ---------- */}'''),
    ("src/components/FormularioMembro.tsx",
     r'''      {/* ---------- Contato ---------- */}
''',
     r'''      {/* ---------- Documento de identificação (frente e verso; armazenamento privado) ---------- */}
      <Secao titulo="Documento de identificação">
        <p className="text-xs text-slate-500">
          Anexe uma foto da frente e uma do verso do documento. Os arquivos ficam em armazenamento privado: só quem tem a
          permissão CPF consegue vê-los.
        </p>
        <CampoDocumento
          id="doc-frente"
          rotulo="Frente do documento"
          obrigatorio={completo}
          caminhoAtual={cadastro.documento_frente_path || null}
          podeVer={podeDocumento}
          onChange={setDocFrente}
          disabled={salvando}
        />
        <CampoDocumento
          id="doc-verso"
          rotulo="Verso do documento"
          obrigatorio={completo}
          caminhoAtual={cadastro.documento_verso_path || null}
          podeVer={podeDocumento}
          onChange={setDocVerso}
          disabled={salvando}
        />
      </Secao>

      {/* ---------- Contato ---------- */}
'''),
    ("src/components/FormularioMembro.tsx",
     r'''          <Campo id="cep" rotulo="CEP" obrigatorio={completo}>
''',
     r'''          <Campo id="cep" rotulo="CEP" obrigatorio={completo} dica={textoDoStatusCep(statusCep)}>
'''),
    ("src/components/FormularioMembro.tsx",
     r'''              onChange={(e) => mudar("cep", somenteDigitos(e.target.value, 8))}
''',
     r'''              onChange={(e) => void mudarCep(e.target.value)}
'''),
    ("src/components/FormularioMembro.tsx",
     r'''/** Bloco do formulário com título (agrupa os campos por assunto). */
''',
     r'''/** Andamento da consulta de endereço pelo CEP ("" = nada a mostrar). */
type StatusCep = "" | "buscando" | "encontrado" | "nao_encontrado" | "indisponivel";

function textoDoStatusCep(status: StatusCep): string | undefined {
  switch (status) {
    case "buscando":
      return "Buscando o endereço...";
    case "encontrado":
      return "Endereço preenchido pelo CEP. Confira e complete o número.";
    case "nao_encontrado":
      return "CEP não encontrado. Confira os números ou preencha o endereço à mão.";
    case "indisponivel":
      return "Não foi possível consultar o CEP agora. Preencha o endereço à mão.";
    default:
      return undefined;
  }
}

/** Bloco do formulário com título (agrupa os campos por assunto). */
'''),
    ("src/app/(painel)/membros/page.tsx",
     r'''            podeFoto={pode("membros.foto")}
''',
     r'''            podeFoto={pode("membros.foto")}
            podeDocumento={pode("membros.cpf")}
'''),
    ("src/types/database.ts",
     r'''  permite_instrumento: boolean; // true = o cargo informa instrumento
}''',
     r'''  permite_instrumento: boolean; // true = o cargo informa instrumento
  somente_orgao?: boolean; // true = o cargo só aceita o instrumento Órgão (migração 0040)
}'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    "supabase/migrations/0040_cadastro_musical_obrigatorios.sql": r'''-- =============================================================================
-- SysMúsica — Migração 0040: Cadastro Musical — campos obrigatórios, Batizado, documento e instrumento Órgão
--
--   * Estado civil passa a ser "Casado (a)", "Solteiro (a)", "Viúvo (a)" (os cadastros já gravados são convertidos).
--   * membros_cadastro ganha: batizado (Sim/Não), documento_frente_path e documento_verso_path.
--   * Bucket PRIVADO documentos-membros (frente e verso do documento de identificação):
--       - anexar / trocar / descartar: quem tem membros.criar ou membros.editar;
--       - VER o documento (URL temporária): só quem tem a permissão membros.cpf.
--   * cargos.somente_orgao: cargos que só podem usar o instrumento Órgão (Organista, Examinadora, Instrutor,
--     Instrutora). O banco recusa outro instrumento (gatilho trg_membros_somente_orgao). Para mudar a lista:
--         update public.cargos set somente_orgao = true|false where nome = '...';
--   * Cargo "Instrutor (a)" vira "Instrutor" e é criado o cargo "Instrutora".
--   * salvar_cadastro_musical passa a EXIGIR: CPF, data de nascimento, estado civil, sexo, batizado (e a data do
--     batismo quando for batizado), instrumento (nos cargos que usam instrumento) e a frente e o verso do documento.
--     (A função só é chamada para o cadastro completo; membros antigos sem cadastro continuam como estão.)
--
-- Tudo roda numa transação só: se der erro em qualquer ponto, NADA é alterado.
-- É seguro rodar mais de uma vez.
-- =============================================================================
begin;

-- 1) Cargos -----------------------------------------------------------------
alter table public.cargos add column if not exists somente_orgao boolean not null default false;
grant select (somente_orgao) on public.cargos to authenticated;

-- "Instrutor (a)" -> "Instrutor" (ninguém usa ainda; se já existir "Instrutor", não mexe)
update public.cargos c
   set nome = 'Instrutor'
 where c.nome = 'Instrutor (a)'
   and not exists (select 1 from public.cargos x where x.nome = 'Instrutor');

-- Novo cargo "Instrutora"
insert into public.cargos (nome, permite_instrumento, exige_instrumento, exige_cartao)
select 'Instrutora', true, true, false
 where not exists (select 1 from public.cargos x where x.nome = 'Instrutora');

-- Cargos travados no Órgão: o instrumento passa a ser obrigatório
update public.cargos
   set somente_orgao = true,
       permite_instrumento = true,
       exige_instrumento = true
 where public.normalizar_texto(nome) like 'organista%'
    or public.normalizar_texto(nome) like 'examinadora%'
    or public.normalizar_texto(nome) like 'instrutor%';

-- Confere os membros que já existem: ninguém pode estar com instrumento diferente de Órgão nesses cargos
do $$
declare v_qtd integer;
begin
  select count(*) into v_qtd
    from public.membros m
    join public.cargos c on c.id = m.cargo_id and c.somente_orgao
    join public.instrumentos i on i.id = m.instrumento_id
   where m.excluido_em is null
     and not public.instrumento_e_orgao(i.nome);
  if v_qtd > 0 then
    raise exception 'Existem % membro(s) em cargo travado no Órgão com outro instrumento. Corrija antes de rodar esta migração.', v_qtd;
  end if;
end $$;

-- Gatilho: o cargo travado só aceita instrumento Órgão (vale também para visitantes)
create or replace function public.membros_somente_orgao()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_somente boolean;
  v_cargo   text;
  v_instr   text;
begin
  -- Restauração de backup: os dados antigos entram como estavam
  if current_setting('sysmusica.restaurando', true) = 'sim' then
    return new;
  end if;
  if new.instrumento_id is null then
    return new; -- a obrigatoriedade do instrumento é conferida por outro gatilho
  end if;
  select c.somente_orgao, c.nome into v_somente, v_cargo from public.cargos c where c.id = new.cargo_id;
  if not coalesce(v_somente, false) then
    return new;
  end if;
  select i.nome into v_instr from public.instrumentos i where i.id = new.instrumento_id;
  if not public.instrumento_e_orgao(v_instr) then
    raise exception 'O cargo % só pode usar o instrumento Órgão.', v_cargo using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_membros_somente_orgao on public.membros;
create trigger trg_membros_somente_orgao
  before insert or update of cargo_id, instrumento_id on public.membros
  for each row execute function public.membros_somente_orgao();

-- 2) Cadastro musical: novas colunas e estado civil ---------------------------
alter table public.membros_cadastro add column if not exists batizado boolean;
alter table public.membros_cadastro add column if not exists documento_frente_path text;
alter table public.membros_cadastro add column if not exists documento_verso_path text;

-- Quem já tinha data de batismo é batizado
update public.membros_cadastro set batizado = true where batizado is null and data_batismo is not null;

alter table public.membros_cadastro drop constraint if exists membros_cadastro_batizado_data;
alter table public.membros_cadastro add constraint membros_cadastro_batizado_data check (
  (batizado is not true or data_batismo is not null) and (batizado is not false or data_batismo is null)
);

-- Estado civil: apaga a regra antiga (qualquer nome), converte os valores e cria a nova
do $$
declare r record;
begin
  for r in
    select conname from pg_constraint
     where conrelid = 'public.membros_cadastro'::regclass and contype = 'c'
       and pg_get_constraintdef(oid) ilike '%estado_civil%'
  loop
    execute format('alter table public.membros_cadastro drop constraint %I', r.conname);
  end loop;
end $$;

update public.membros_cadastro set estado_civil = 'Casado (a)'   where estado_civil = 'Casado(a)';
update public.membros_cadastro set estado_civil = 'Solteiro (a)' where estado_civil = 'Solteiro(a)';
update public.membros_cadastro set estado_civil = 'Viúvo (a)'    where estado_civil = 'Viúvo(a)';

alter table public.membros_cadastro add constraint membros_cadastro_estado_civil_check
  check (estado_civil in ('Casado (a)', 'Solteiro (a)', 'Viúvo (a)'));

-- 3) Armazenamento PRIVADO dos documentos --------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documentos-membros', 'documentos-membros', false, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
   set public = false, file_size_limit = 3145728, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists documentos_membros_envio   on storage.objects;
drop policy if exists documentos_membros_leitura on storage.objects;
drop policy if exists documentos_membros_exclusao on storage.objects;

-- Anexar: quem cadastra ou edita membros
create policy documentos_membros_envio on storage.objects for insert to authenticated
  with check (bucket_id = 'documentos-membros' and public.tem_alguma_permissao(array['membros.criar', 'membros.editar']));
-- Ver o documento (URL temporária): só quem tem a permissão CPF (dado sensível)
create policy documentos_membros_leitura on storage.objects for select to authenticated
  using (bucket_id = 'documentos-membros' and public.tem_permissao('membros.cpf'));
-- Apagar (cadastro que falhou ou documento substituído)
create policy documentos_membros_exclusao on storage.objects for delete to authenticated
  using (bucket_id = 'documentos-membros' and public.tem_alguma_permissao(array['membros.criar', 'membros.editar']));

-- 4) Gravar o cadastro (agora com as exigências) ---------------------------------
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
  v_permite_instr boolean;
  v_cpf    text;
  v_nasc   date;
  v_instr  uuid;
  v_estado_civil    text := nullif(btrim(p_dados ->> 'estado_civil'), '');
  v_sexo            text := nullif(btrim(p_dados ->> 'sexo'), '');
  v_batizado        boolean := (p_dados ->> 'batizado')::boolean;
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
  v_doc_frente      text := nullif(btrim(p_dados ->> 'documento_frente_path'), '');
  v_doc_verso       text := nullif(btrim(p_dados ->> 'documento_verso_path'), '');
begin
  if not (public.tem_permissao('membros.criar') or public.tem_permissao('membros.editar')) then
    raise exception 'Você não tem permissão para salvar este cadastro.' using errcode = '42501';
  end if;

  select m.casa_oracao_id, m.cargo_id, m.cpf, m.data_nascimento, m.instrumento_id
    into v_casa, v_cargo, v_cpf, v_nasc, v_instr
    from public.membros m
   where m.id = p_membro and m.excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.' using errcode = 'P0002';
  end if;
  if v_casa is not null and not public.casa_oracao_na_abrangencia(v_casa) then
    raise exception 'Você não tem acesso a este cadastro.' using errcode = '42501';
  end if;

  -- Obrigatórios do Cadastro Musical (a tela confere antes; o banco é a segunda barreira)
  if v_cpf is null then
    raise exception 'O CPF é obrigatório. Quem tem a permissão CPF precisa preenchê-lo.' using errcode = '22023';
  end if;
  if v_nasc is null then
    raise exception 'Informe a data de nascimento.' using errcode = '22023';
  end if;
  if v_estado_civil is null then
    raise exception 'Informe o estado civil.' using errcode = '22023';
  end if;
  if v_sexo is null then
    raise exception 'Informe o sexo.' using errcode = '22023';
  end if;
  if v_batizado is null then
    raise exception 'Informe se a pessoa é batizada.' using errcode = '22023';
  end if;
  if v_batizado and v_data_batismo is null then
    raise exception 'Informe a data do batismo.' using errcode = '22023';
  end if;
  if not v_batizado then
    v_data_batismo := null; -- sem batismo, não guarda data
  end if;
  if v_data_batismo is not null and v_data_batismo < v_nasc then
    raise exception 'A data do batismo não pode ser anterior ao nascimento.' using errcode = '22023';
  end if;

  select c.permite_instrumento into v_permite_instr from public.cargos c where c.id = v_cargo;
  if coalesce(v_permite_instr, false) and v_instr is null then
    raise exception 'Informe o instrumento.' using errcode = '22023';
  end if;

  -- Documento (frente e verso): o arquivo precisa existir no armazenamento, na pasta do próprio membro
  if v_doc_frente is null then
    raise exception 'Anexe a frente do documento.' using errcode = '22023';
  end if;
  if v_doc_verso is null then
    raise exception 'Anexe o verso do documento.' using errcode = '22023';
  end if;
  if left(v_doc_frente, 37) <> p_membro::text || '/' or left(v_doc_verso, 37) <> p_membro::text || '/' then
    raise exception 'Documento inválido: envie o arquivo de novo.' using errcode = '22023';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'documentos-membros' and o.name = v_doc_frente) then
    raise exception 'O arquivo da frente do documento não foi encontrado. Envie de novo.' using errcode = '22023';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'documentos-membros' and o.name = v_doc_verso) then
    raise exception 'O arquivo do verso do documento não foi encontrado. Envie de novo.' using errcode = '22023';
  end if;

  -- Validações de formato
  if v_estado_civil not in ('Casado (a)', 'Solteiro (a)', 'Viúvo (a)') then
    raise exception 'Estado civil inválido.' using errcode = '22023';
  end if;
  if v_sexo not in ('Masculino', 'Feminino') then
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
    membro_id, estado_civil, sexo, batizado, data_batismo, selado, ddd, telefone, tem_whatsapp, whatsapp, email,
    cep, endereco, numero, complemento, uf, cartao_numero, cartao_emissao, cartao_validade,
    apresentado_em, apresentado_por, observacao, documento_frente_path, documento_verso_path
  ) values (
    p_membro, v_estado_civil, v_sexo, v_batizado, v_data_batismo, v_selado, v_ddd, v_telefone, v_tem_whatsapp, v_whatsapp, v_email,
    v_cep, v_endereco, v_numero, v_complemento, v_uf, v_cartao_numero, v_cartao_emissao, v_cartao_validade,
    v_apresentado_em, v_apresentado_por, v_observacao, v_doc_frente, v_doc_verso
  )
  on conflict (membro_id) do update set
    estado_civil = excluded.estado_civil, sexo = excluded.sexo, batizado = excluded.batizado,
    data_batismo = excluded.data_batismo,
    selado = excluded.selado, ddd = excluded.ddd, telefone = excluded.telefone,
    tem_whatsapp = excluded.tem_whatsapp, whatsapp = excluded.whatsapp, email = excluded.email,
    cep = excluded.cep, endereco = excluded.endereco, numero = excluded.numero,
    complemento = excluded.complemento, uf = excluded.uf, cartao_numero = excluded.cartao_numero,
    cartao_emissao = excluded.cartao_emissao, cartao_validade = excluded.cartao_validade,
    apresentado_em = excluded.apresentado_em, apresentado_por = excluded.apresentado_por,
    observacao = excluded.observacao,
    documento_frente_path = excluded.documento_frente_path, documento_verso_path = excluded.documento_verso_path,
    atualizado_em = now();
end;
$$;

revoke all on function public.salvar_cadastro_musical(uuid, jsonb) from public, anon;
grant execute on function public.salvar_cadastro_musical(uuid, jsonb) to authenticated;

commit;
''',
    "src/modules/membros/services/cep.ts": r'''/**
 * SysMúsica — Consulta de endereço pelo CEP (ViaCEP, serviço público e gratuito).
 * A consulta sai do navegador de quem está cadastrando e leva só o CEP (8 números); nenhum outro dado da pessoa.
 * Se o serviço estiver fora do ar ou sem internet, o formulário continua funcionando: a pessoa digita o endereço.
 * A conversão da resposta fica em cadastroMusical.ts (enderecoDoViaCep), onde é testada.
 */
import { enderecoDoViaCep, type EnderecoDoCep } from "../cadastroMusical";

export type ResultadoCep =
  | { tipo: "ok"; endereco: EnderecoDoCep }
  | { tipo: "nao_encontrado" } // o CEP não existe
  | { tipo: "indisponivel" }; // sem internet, serviço fora do ar ou demorou demais

const TEMPO_MAXIMO_MS = 8000;

/** Busca o endereço de um CEP de 8 números. Nunca lança erro: devolve "indisponivel" se algo falhar. */
export async function buscarEnderecoPorCep(cep: string): Promise<ResultadoCep> {
  if (!/^\d{8}$/.test(cep)) return { tipo: "nao_encontrado" };
  const controle = new AbortController();
  const relogio = setTimeout(() => controle.abort(), TEMPO_MAXIMO_MS);
  try {
    const resposta = await fetch(`https://viacep.com.br/ws/${cep}/json/`, { signal: controle.signal });
    if (resposta.status === 400 || resposta.status === 404) return { tipo: "nao_encontrado" };
    if (!resposta.ok) return { tipo: "indisponivel" };
    const endereco = enderecoDoViaCep(await resposta.json());
    return endereco ? { tipo: "ok", endereco } : { tipo: "nao_encontrado" };
  } catch {
    return { tipo: "indisponivel" };
  } finally {
    clearTimeout(relogio);
  }
}
''',
    "src/modules/membros/services/documentos.ts": r'''/**
 * SysMúsica — Serviço dos documentos de identificação dos membros (frente e verso).
 * Ficam em um bucket PRIVADO (documentos-membros), dentro da pasta do próprio membro:
 *   <id do membro>/frente-<código>.jpg  e  <id do membro>/verso-<código>.jpg
 * Quem cadastra ou edita membros pode anexar; VER o documento exige a permissão membros.cpf (o armazenamento
 * confere). O banco (salvar_cadastro_musical) confere se os dois arquivos existem antes de gravar o cadastro.
 */
import { supabase } from "@/lib/supabase";

export const BUCKET_DOCUMENTOS = "documentos-membros";

export type LadoDocumento = "frente" | "verso";

/** Envia o arquivo (já reduzido) para a pasta do membro e devolve o caminho. */
export async function subirDocumento(membroId: string, lado: LadoDocumento, imagem: Blob): Promise<string> {
  const caminho = `${membroId}/${lado}-${crypto.randomUUID()}.jpg`;
  const { error } = await supabase.storage
    .from(BUCKET_DOCUMENTOS)
    .upload(caminho, imagem, { contentType: "image/jpeg", upsert: false });
  if (error) {
    throw new Error("Não foi possível enviar o documento. Verifique a conexão e tente novamente.");
  }
  return caminho;
}

/**
 * Apaga arquivos enviados que não chegaram a ser usados (o cadastro falhou) ou que foram substituídos.
 * Nunca lança erro: se não for possível apagar, o arquivo só fica sem uso no armazenamento privado.
 */
export async function descartarDocumentos(caminhos: string[]): Promise<void> {
  const lista = caminhos.filter((caminho) => caminho !== "");
  if (lista.length === 0) return;
  try {
    await supabase.storage.from(BUCKET_DOCUMENTOS).remove(lista);
  } catch {
    /* sem permissão ou sem conexão: o arquivo fica sem uso */
  }
}

/** Endereço temporário (5 minutos) para ver o documento; null se não houver permissão ou o arquivo sumiu. */
export async function urlDoDocumento(caminho: string): Promise<string | null> {
  const { data, error } = await supabase.storage.from(BUCKET_DOCUMENTOS).createSignedUrl(caminho, 300);
  if (error || !data) return null;
  return data.signedUrl;
}
''',
    "src/modules/membros/documentoImagem.ts": r'''/**
 * SysMúsica — Preparo da foto do documento no navegador antes do envio.
 * Reduz a imagem (lado maior de 1600 px, para o texto continuar legível) e converte para JPEG.
 * O armazenamento confere de novo o tipo (JPEG, PNG ou WebP) e o tamanho (máximo de 3 MB).
 * (Mesma ideia de fotoImagem.ts, com a imagem maior e mais nítida porque é um documento.)
 */

const LADO_MAXIMO = 1600;
const QUALIDADE_JPEG = 0.85;
const TAMANHO_MAXIMO_ORIGINAL = 15 * 1024 * 1024; // 15 MB de entrada (a saída é bem menor)

export async function prepararDocumento(arquivo: File): Promise<Blob> {
  if (!arquivo.type.startsWith("image/")) {
    throw new Error("Escolha uma foto do documento (JPG, PNG ou WebP).");
  }
  if (arquivo.size > TAMANHO_MAXIMO_ORIGINAL) {
    throw new Error("A imagem é grande demais (máximo de 15 MB).");
  }

  // "from-image" respeita a rotação gravada pela câmera do celular; se o navegador não aceitar, tenta sem ela
  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(arquivo, { imageOrientation: "from-image" });
  } catch {
    try {
      bitmap = await createImageBitmap(arquivo);
    } catch {
      throw new Error("Não foi possível ler esta imagem. Tente outra foto.");
    }
  }

  const escala = Math.min(1, LADO_MAXIMO / Math.max(bitmap.width, bitmap.height));
  const largura = Math.max(1, Math.round(bitmap.width * escala));
  const altura = Math.max(1, Math.round(bitmap.height * escala));

  const canvas = document.createElement("canvas");
  canvas.width = largura;
  canvas.height = altura;
  const contexto = canvas.getContext("2d");
  if (!contexto) {
    bitmap.close();
    throw new Error("Não foi possível processar a imagem neste navegador.");
  }
  contexto.drawImage(bitmap, 0, 0, largura, altura);
  bitmap.close();

  const imagem = await new Promise<Blob | null>((resolver) => canvas.toBlob(resolver, "image/jpeg", QUALIDADE_JPEG));
  if (!imagem) throw new Error("Não foi possível processar a imagem.");
  return imagem;
}
''',
    "src/modules/membros/components/CampoDocumento.tsx": r'''"use client";

/**
 * SysMúsica — Campo para anexar UM lado do documento de identificação (frente ou verso).
 * "Tirar foto" abre a câmera no celular; "Escolher da galeria" abre o seletor de arquivos. A imagem é reduzida
 * no navegador e só é enviada quando o formulário salva. Se já existe um documento anexado, o campo avisa;
 * ver o arquivo só é possível para quem tem a permissão membros.cpf (o armazenamento também confere).
 */
import { useEffect, useRef, useState, type ChangeEvent } from "react";
import { Camera, Eye, ImagePlus, Trash2 } from "lucide-react";
import { prepararDocumento } from "../documentoImagem";
import { urlDoDocumento } from "../services/documentos";

interface CampoDocumentoProps {
  id: string;
  rotulo: string; // ex.: "Frente do documento"
  obrigatorio?: boolean;
  caminhoAtual?: string | null; // arquivo já anexado (edição)
  podeVer?: boolean; // permissão membros.cpf
  onChange: (imagem: Blob | null) => void; // a imagem nova já preparada, ou nulo ao remover a escolha
  disabled?: boolean;
}

const classeBotao =
  "inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium " +
  "text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";

export default function CampoDocumento({
  id,
  rotulo,
  obrigatorio = false,
  caminhoAtual = null,
  podeVer = false,
  onChange,
  disabled = false,
}: CampoDocumentoProps) {
  const cameraRef = useRef<HTMLInputElement>(null);
  const galeriaRef = useRef<HTMLInputElement>(null);
  const [previa, setPrevia] = useState<string | null>(null);
  const [processando, setProcessando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  // Libera o endereço temporário da pré-visualização quando ela troca ou o campo sai da tela
  useEffect(() => {
    return () => {
      if (previa) URL.revokeObjectURL(previa);
    };
  }, [previa]);

  async function aoEscolher(evento: ChangeEvent<HTMLInputElement>) {
    const arquivo = evento.target.files?.[0];
    evento.target.value = ""; // permite escolher o mesmo arquivo de novo
    if (!arquivo) return;
    setErro(null);
    setProcessando(true);
    try {
      const imagem = await prepararDocumento(arquivo);
      setPrevia(URL.createObjectURL(imagem));
      onChange(imagem);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível preparar a imagem.");
    } finally {
      setProcessando(false);
    }
  }

  function removerEscolha() {
    setPrevia(null);
    onChange(null);
  }

  // Abre o documento já anexado em outra aba (endereço temporário)
  async function verAtual() {
    if (!caminhoAtual) return;
    setErro(null);
    const url = await urlDoDocumento(caminhoAtual);
    if (!url) return setErro("Não foi possível abrir o documento (sem permissão ou arquivo indisponível).");
    window.open(url, "_blank", "noopener,noreferrer");
  }

  const bloqueado = disabled || processando;

  return (
    <div className="space-y-2">
      <span className="text-sm font-medium text-slate-700">
        {rotulo}{" "}
        {obrigatorio ? (
          <span className="font-normal text-red-600" aria-hidden="true">
            *
          </span>
        ) : (
          <span className="font-normal text-slate-400">(opcional)</span>
        )}
      </span>

      <input
        ref={cameraRef}
        id={`${id}-camera`}
        type="file"
        accept="image/*"
        capture="environment"
        className="sr-only"
        tabIndex={-1}
        aria-hidden="true"
        onChange={(e) => void aoEscolher(e)}
      />
      <input
        ref={galeriaRef}
        id={`${id}-galeria`}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="sr-only"
        tabIndex={-1}
        aria-hidden="true"
        onChange={(e) => void aoEscolher(e)}
      />

      <div className="flex items-start gap-4">
        {previa && (
          <div
            role="img"
            aria-label={`Nova imagem: ${rotulo}`}
            style={{ backgroundImage: `url(${previa})` }}
            className="h-28 w-40 shrink-0 rounded-lg bg-slate-100 bg-cover bg-center"
          />
        )}
        <div className="flex flex-col gap-2">
          <button type="button" className={classeBotao} onClick={() => cameraRef.current?.click()} disabled={bloqueado}>
            <Camera className="h-4 w-4" aria-hidden="true" />
            Tirar foto
          </button>
          <button type="button" className={classeBotao} onClick={() => galeriaRef.current?.click()} disabled={bloqueado}>
            <ImagePlus className="h-4 w-4" aria-hidden="true" />
            Escolher da galeria
          </button>
          {previa && (
            <button type="button" className={classeBotao} onClick={removerEscolha} disabled={bloqueado}>
              <Trash2 className="h-4 w-4" aria-hidden="true" />
              Remover a nova imagem
            </button>
          )}
          {!previa && caminhoAtual && podeVer && (
            <button type="button" className={classeBotao} onClick={() => void verAtual()} disabled={bloqueado}>
              <Eye className="h-4 w-4" aria-hidden="true" />
              Ver o documento anexado
            </button>
          )}
        </div>
      </div>

      {processando && <p className="text-xs text-slate-500">Preparando a imagem...</p>}
      {!previa && caminhoAtual && (
        <p className="text-xs text-emerald-700">Documento já anexado. Envie outra imagem só se quiser trocá-lo.</p>
      )}
      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}
    </div>
  );
}
''',
}


# Arquivos a REMOVER: só são apagados se o conteúdo for idêntico ao esperado (cópia fica no backup)
REMOVER = {
}


# Arquivos SUBSTITUÍDOS por inteiro: só troca se o original tiver o hash (sha256, fim de linha normalizado) esperado
SUBST = {
    "src/modules/membros/cadastroMusical.ts": {'sha': "2bf6af1cc4c9403efd1cd078d1f6d9501e2fb7f717d271808b23c01c0c46ba67", 'novo': r'''/**
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
 * Para mudar quais cargos só aceitam o instrumento Órgão: coluna cargos.somente_orgao (banco, migração 0040);
 * enquanto a coluna não existir, vale a lista CARGOS_SOMENTE_ORGAO_PADRAO.
 *
 * Migração 0040: estado civil com os rótulos "Casado (a)"..., campo Batizado (Sim/Não), documento de identificação
 * (frente e verso, em armazenamento privado) e consulta de endereço pelo CEP (ViaCEP).
 */

// Estes textos são os mesmos aceitos pelo banco (migração 0040): mudou aqui, muda lá.
export const ESTADOS_CIVIS = ["Casado (a)", "Solteiro (a)", "Viúvo (a)"] as const;
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
  batizado: SimNao;
  data_batismo: string; // AAAA-MM-DD (só quando batizado = "sim")
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
  documento_frente_path: string; // caminho do arquivo no armazenamento privado (documentos-membros)
  documento_verso_path: string;
}

export const CADASTRO_VAZIO: CadastroMusical = {
  estado_civil: "",
  sexo: "",
  batizado: "",
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
  documento_frente_path: "",
  documento_verso_path: "",
};

// ---------- Cargos ----------

/** O mínimo que precisamos de um cargo (o tipo Cargo do projeto atende a isto). */
export interface CargoCadastro {
  id: string;
  nome: string;
  exige_cartao?: boolean | null;
  somente_orgao?: boolean | null;
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

/** Cargos que só aceitam o instrumento Órgão enquanto a coluna cargos.somente_orgao não decide. */
const CARGOS_SOMENTE_ORGAO_PADRAO = ["organista", "examinadora", "instrutor"];

/** O cargo só pode usar o instrumento Órgão? (Organista, Examinadora, Instrutor e Instrutora.) */
export function cargoSomenteOrgao(cargo: CargoCadastro | null | undefined): boolean {
  if (!cargo) return false;
  if (typeof cargo.somente_orgao === "boolean") return cargo.somente_orgao;
  const nome = semAcento(cargo.nome);
  return CARGOS_SOMENTE_ORGAO_PADRAO.some((prefixo) => nome.startsWith(prefixo));
}

/** O instrumento é um Órgão? (mesma regra do banco: o nome tem "orgao", sem acento.) */
export function instrumentoEOrgao(nome: string | null | undefined): boolean {
  return !!nome && semAcento(nome).includes("orgao");
}

/** Instrumentos que o cargo aceita: todos, ou só os Órgãos nos cargos travados. */
export function instrumentosDoCargo<T extends { nome: string }>(instrumentos: T[], somenteOrgao: boolean): T[] {
  return somenteOrgao ? instrumentos.filter((instrumento) => instrumentoEOrgao(instrumento.nome)) : instrumentos;
}

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
  /** CPF só com os números. Obrigatório quando completo e o usuário pode vê-lo (permissão membros.cpf). */
  cpf: string;
  cpfObrigatorio: boolean;
  /** Data de nascimento (AAAA-MM-DD), que fica em "membros". */
  dataNascimento: string;
  /** Instrumento escolhido e se o cargo pede instrumento (obrigatório no cadastro completo). */
  instrumentoId: string;
  instrumentoObrigatorio: boolean;
  /** Já há (ou foi escolhido agora) um arquivo para a frente e para o verso do documento. */
  temDocumentoFrente: boolean;
  temDocumentoVerso: boolean;
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
    if (opcoes.cpfObrigatorio && vazio(opcoes.cpf)) return "Informe o CPF.";
    if (vazio(opcoes.dataNascimento)) return "Informe a data de nascimento.";
    if (vazio(dados.estado_civil)) return "Informe o estado civil.";
    if (vazio(dados.sexo)) return "Informe o sexo.";
    if (opcoes.instrumentoObrigatorio && vazio(opcoes.instrumentoId)) return "Informe o instrumento.";
    if (dados.batizado === "") return "Informe se a pessoa é batizada.";
    if (dados.batizado === "sim" && vazio(dados.data_batismo)) return "Informe a data do batismo.";
    if (dados.selado === "") return "Informe se a pessoa é selada.";
    if (vazio(dados.ddd) || vazio(dados.telefone)) return "Informe o DDD e o telefone.";
    if (dados.tem_whatsapp === "") return "Informe se o telefone tem WhatsApp.";
    if (vazio(dados.cep)) return "Informe o CEP.";
    if (vazio(dados.endereco)) return "Informe o endereço.";
    if (vazio(dados.numero)) return "Informe o número do endereço.";
    if (vazio(dados.uf)) return "Informe o estado (UF).";
    if (vazio(cidade)) return "Informe a cidade.";
    if (vazio(bairro)) return "Informe o bairro.";
    if (!opcoes.temDocumentoFrente) return "Anexe a frente do documento.";
    if (!opcoes.temDocumentoVerso) return "Anexe o verso do documento.";
  }

  if (
    dados.batizado === "sim" &&
    !vazio(dados.data_batismo) &&
    !vazio(opcoes.dataNascimento) &&
    dados.data_batismo < opcoes.dataNascimento
  ) {
    return "A data do batismo não pode ser anterior ao nascimento.";
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
    // Cadastros antigos (sem a coluna preenchida): quem tem data de batismo é batizado
    batizado: typeof b.batizado === "boolean" ? simNao(b.batizado) : texto(b.data_batismo) !== "" ? "sim" : "",
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
    documento_frente_path: texto(b.documento_frente_path),
    documento_verso_path: texto(b.documento_verso_path),
  };
}

/**
 * Dados do formulário -> JSON para salvar_cadastro_musical (campos vazios viram null).
 * Se tem WhatsApp e o número ficou vazio, usa o próprio telefone (DDD + número).
 * Se não tem WhatsApp, o número do WhatsApp não é guardado.
 * Se não é batizado, a data do batismo não é guardada.
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
    batizado: b(dados.batizado),
    data_batismo: dados.batizado === "sim" ? t(dados.data_batismo) : null,
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
    documento_frente_path: t(dados.documento_frente_path),
    documento_verso_path: t(dados.documento_verso_path),
  };
}

// ---------- Endereço pelo CEP (ViaCEP) ----------

/** O que o CEP preenche no formulário (campo vazio = o serviço não trouxe aquele dado). */
export interface EnderecoDoCep {
  endereco: string; // logradouro (rua, avenida...)
  complemento: string;
  bairro: string;
  cidade: string;
  uf: string;
}

/**
 * Resposta do ViaCEP (https://viacep.com.br/ws/CEP/json/) -> dados do formulário.
 * Devolve null quando o CEP não existe (o serviço responde {"erro": true}) ou a resposta é inválida.
 * CEP "geral" de cidade pequena vem sem rua e sem bairro: o que faltar o usuário digita.
 */
export function enderecoDoViaCep(bruto: unknown): EnderecoDoCep | null {
  if (!bruto || typeof bruto !== "object") return null;
  const b = bruto as Bruto;
  if (b.erro === true || b.erro === "true") return null;
  const uf = texto(b.uf).trim().toUpperCase();
  const cidade = texto(b.localidade).trim();
  if (!(UFS as readonly string[]).includes(uf) && cidade === "") return null; // resposta sem nada útil
  return {
    endereco: texto(b.logradouro).trim(),
    complemento: texto(b.complemento).trim(),
    bairro: texto(b.bairro).trim(),
    cidade,
    uf: (UFS as readonly string[]).includes(uf) ? uf : "",
  };
}
'''},
    "src/modules/membros/cadastroMusical.test.ts": {'sha': "ca60162afad233222b049e230455ce602984ed133603cf9839d4124daf40a407", 'novo': r'''import { describe, expect, it } from "vitest";
import {
  CADASTRO_VAZIO,
  ESTADOS_CIVIS,
  cargoEntraNoCadastro,
  cargoExigeCartao,
  cargoSomenteOrgao,
  cargosDoCadastro,
  deRetornoDoBanco,
  emailValido,
  enderecoDoViaCep,
  formatarCep,
  formatarTelefone,
  formatarWhatsapp,
  instrumentoEOrgao,
  instrumentosDoCargo,
  paraEnvioAoBanco,
  somenteDigitos,
  temAlgumDado,
  validarCadastro,
  type CadastroMusical,
} from "./cadastroMusical";

const completoOk: CadastroMusical = {
  ...CADASTRO_VAZIO,
  estado_civil: "Solteiro (a)",
  sexo: "Feminino",
  batizado: "sim",
  data_batismo: "2015-06-01",
  selado: "sim",
  ddd: "71",
  telefone: "999998888",
  tem_whatsapp: "sim",
  cep: "40000000",
  endereco: "Rua das Flores",
  numero: "10",
  uf: "BA",
  documento_frente_path: "m1/frente-1.jpg",
  documento_verso_path: "m1/verso-1.jpg",
};
const base = {
  completo: true,
  exigeCartao: false,
  cidade: "Salvador",
  bairro: "Itinga",
  cpf: "52998224725",
  cpfObrigatorio: true,
  dataNascimento: "1990-05-10",
  instrumentoId: "i1",
  instrumentoObrigatorio: true,
  temDocumentoFrente: true,
  temDocumentoVerso: true,
};

describe("cargos do cadastro", () => {
  it("aceita os cargos do formulário (com ou sem acento, com (a))", () => {
    for (const nome of ["Encarregado Regional", "Encarregado Local", "Examinadora", "Instrutor (a)", "Instrutor", "Instrutora", "Músico", "Organista"]) {
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

describe("instrumento Órgão", () => {
  it("cargos travados: usa a coluna do banco; sem ela, a lista padrão", () => {
    expect(cargoSomenteOrgao({ id: "1", nome: "Músico", somente_orgao: true })).toBe(true);
    expect(cargoSomenteOrgao({ id: "1", nome: "Organista", somente_orgao: false })).toBe(false);
    for (const nome of ["Organista", "Examinadora", "Instrutor", "Instrutora", "Instrutor (a)"]) {
      expect(cargoSomenteOrgao({ id: "1", nome }), nome).toBe(true);
    }
    for (const nome of ["Músico", "Encarregado Local", "Encarregado Regional"]) {
      expect(cargoSomenteOrgao({ id: "1", nome }), nome).toBe(false);
    }
    expect(cargoSomenteOrgao(undefined)).toBe(false);
  });

  it("reconhece o Órgão pelo nome (com ou sem acento)", () => {
    expect(instrumentoEOrgao("Orgão Eletrônico")).toBe(true);
    expect(instrumentoEOrgao("Órgão")).toBe(true);
    expect(instrumentoEOrgao("Violino")).toBe(false);
    expect(instrumentoEOrgao(null)).toBe(false);
  });

  it("filtra os instrumentos do cargo travado", () => {
    const lista = [{ nome: "Violino" }, { nome: "Orgão Eletrônico" }, { nome: "Órgão de tubos" }];
    expect(instrumentosDoCargo(lista, true).map((i) => i.nome)).toEqual(["Orgão Eletrônico", "Órgão de tubos"]);
    expect(instrumentosDoCargo(lista, false)).toHaveLength(3);
  });
});

describe("estado civil", () => {
  it("usa os rótulos com espaço antes do (a)", () => {
    expect([...ESTADOS_CIVIS]).toEqual(["Casado (a)", "Solteiro (a)", "Viúvo (a)"]);
  });
});

describe("endereço pelo CEP (ViaCEP)", () => {
  it("converte a resposta do serviço", () => {
    const resposta = {
      cep: "40000-000", logradouro: "Rua das Flores", complemento: "lado par", bairro: "Itinga",
      localidade: "Lauro de Freitas", uf: "ba",
    };
    expect(enderecoDoViaCep(resposta)).toEqual({
      endereco: "Rua das Flores", complemento: "lado par", bairro: "Itinga", cidade: "Lauro de Freitas", uf: "BA",
    });
  });

  it("CEP geral (sem rua e bairro) preenche só cidade e UF", () => {
    expect(enderecoDoViaCep({ logradouro: "", bairro: "", localidade: "Ipiaú", uf: "BA" })).toEqual({
      endereco: "", complemento: "", bairro: "", cidade: "Ipiaú", uf: "BA",
    });
  });

  it("CEP inexistente ou resposta inválida devolve null", () => {
    expect(enderecoDoViaCep({ erro: true })).toBeNull();
    expect(enderecoDoViaCep({ erro: "true" })).toBeNull();
    expect(enderecoDoViaCep(null)).toBeNull();
    expect(enderecoDoViaCep("texto")).toBeNull();
    expect(enderecoDoViaCep({})).toBeNull();
  });

  it("UF desconhecida não é aceita no campo", () => {
    expect(enderecoDoViaCep({ localidade: "Algum lugar", uf: "XX" })?.uf).toBe("");
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
      [{ estado_civil: "" }, "estado civil"],
      [{ sexo: "" }, "sexo"],
      [{ batizado: "" }, "batizada"],
      [{ data_batismo: "" }, "batismo"],
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

  it("CPF, data de nascimento e instrumento são obrigatórios no cadastro completo", () => {
    expect(validarCadastro(completoOk, { ...base, cpf: "" })).toContain("CPF");
    expect(validarCadastro(completoOk, { ...base, dataNascimento: "" })).toContain("nascimento");
    expect(validarCadastro(completoOk, { ...base, instrumentoId: "" })).toContain("instrumento");
    // quem não vê o CPF (sem a permissão) não é cobrado por ele; cargo sem instrumento não pede instrumento
    expect(validarCadastro(completoOk, { ...base, cpf: "", cpfObrigatorio: false })).toBeNull();
    expect(validarCadastro(completoOk, { ...base, instrumentoId: "", instrumentoObrigatorio: false })).toBeNull();
  });

  it("batizado: a data só é cobrada para quem é batizado e não pode ser anterior ao nascimento", () => {
    expect(validarCadastro({ ...completoOk, batizado: "nao", data_batismo: "" }, base)).toBeNull();
    expect(validarCadastro({ ...completoOk, data_batismo: "1980-01-01" }, base)).toContain("anterior ao nascimento");
  });

  it("documento: frente e verso são obrigatórios no cadastro completo", () => {
    expect(validarCadastro(completoOk, { ...base, temDocumentoFrente: false })).toContain("frente");
    expect(validarCadastro(completoOk, { ...base, temDocumentoVerso: false })).toContain("verso");
    expect(
      validarCadastro(CADASTRO_VAZIO, { ...base, completo: false, temDocumentoFrente: false, temDocumentoVerso: false })
    ).toBeNull();
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
    expect(envio.batizado).toBe(true);
    expect(envio.documento_frente_path).toBe("m1/frente-1.jpg");
  });

  it("não batizado: a data do batismo não é enviada", () => {
    const envio = paraEnvioAoBanco({ ...completoOk, batizado: "nao", data_batismo: "2015-06-01" });
    expect(envio.batizado).toBe(false);
    expect(envio.data_batismo).toBeNull();
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
    expect(lido.batizado).toBe("");
  });

  it("cadastro antigo sem a coluna batizado: quem tem data de batismo é batizado", () => {
    expect(deRetornoDoBanco({ data_batismo: "2010-01-01" }).batizado).toBe("sim");
    expect(deRetornoDoBanco({ batizado: false }).batizado).toBe("nao");
  });

  it("ida e volta mantém os dados", () => {
    const volta = deRetornoDoBanco(paraEnvioAoBanco(completoOk));
    expect(volta).toEqual({ ...completoOk, whatsapp: "71999998888" });
  });
});
'''},
}


def ler(caminho):
    with open(caminho, "r", encoding="utf-8", newline="") as f:
        return f.read()

def eol_de(txt):
    return "\r\n" if "\r\n" in txt else "\n"

def adaptar(trecho, eol):
    return trecho.replace("\n", eol) if eol != "\n" else trecho

def norm(t):
    return t.replace("\r\n", "\n").rstrip("\n")

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

for arq in list(NOVOS):
    p = os.path.join(RAIZ, arq)
    if os.path.exists(p):
        if norm(ler(p)) == norm(NOVOS[arq]):
            print(f"já existe, idêntico (mantido): {arq}")
            del NOVOS[arq]
        else:
            problemas.append(f"JÁ EXISTE E É DIFERENTE (não vou sobrescrever): {arq}")

for arq, esperado in REMOVER.items():
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"PARA REMOVER, NÃO ENCONTRADO: {arq}")
    elif ler(caminho).replace("\r\n", "\n").strip() != esperado.replace("\r\n", "\n").strip():
        problemas.append(f"PARA REMOVER, CONTEÚDO DIFERENTE DO ESPERADO (não vou apagar): {arq}")

for arq, info in SUBST.items():
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"PARA SUBSTITUIR, NÃO ENCONTRADO: {arq}")
    elif hashlib.sha256(norm(ler(caminho)).encode("utf-8")).hexdigest() != info["sha"]:
        problemas.append(f"PARA SUBSTITUIR, O ARQUIVO É DIFERENTE DO ESPERADO (não vou sobrescrever): {arq}")

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

substituidos = []
for arq, info in SUBST.items():
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    eol = eol_de(ler(origem))
    with open(origem, "w", encoding="utf-8", newline="") as f:
        f.write(adaptar(info["novo"].rstrip("\n") + "\n", eol))
    substituidos.append(arq)

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
    f.write("\n".join(a for a in alterados + substituidos + criados if a.endswith((".ts", ".tsx"))) + "\n")
with open(os.path.join(BKP, ".novos"), "w", encoding="utf-8") as f:
    f.write("\n".join(criados) + "\n")
print(f"OK: {len(EDITS)} trocas em {len(alterados)} arquivos + {len(substituidos)} substituídos + {len(criados)} arquivos novos + {len(removidos)} removidos. Backup em {BKP}")
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
  if "$@" > /tmp/p4b-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p4b-passo.out
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
echo "Lembrete: o SQL 0040 precisa ter sido rodado no Supabase ANTES de testar as telas."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
