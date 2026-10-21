#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 9 (ajuste 5): corrige o erro "O telefone deve ter 8 ou 9 números" no formulário público
#
#  Não precisa de SQL. Exige o ajuste 4 já instalado. Troca só src/modules/cadastroPublico/components/FormularioPublico.tsx.
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-parte9aj5-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-parte9-ajuste5.sh
# Log:  /tmp/instalar-parte9aj5.log
# =============================================================================

LOG=/tmp/instalar-parte9aj5.log
BKP=/tmp/bkp-parte9aj5-$(date +%Y%m%d-%H%M%S)
RAIZ="$(pwd)"

(
[ -f package.json ] && [ -d src ] || { echo "ERRO: rode dentro da pasta sysmusica (onde está o package.json)."; exit 1; }
mkdir -p "$BKP"
export BKP RAIZ

echo "== 1/3  Conferindo e aplicando as alterações =="
# (ajuste simples: sem SQL)
python3 - <<'PYSCRIPT'
import os, shutil, sys, hashlib

RAIZ = os.environ["RAIZ"]
BKP = os.environ["BKP"]

# (arquivo, trecho antigo, trecho novo) — cada "antigo" precisa existir EXATAMENTE 1 vez no arquivo.
# Os trechos usam \n; o instalador converte para o fim de linha do próprio arquivo (CRLF ou LF).
EDITS = []


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {}


# Arquivos a REMOVER: só são apagados se o conteúdo for idêntico ao esperado (cópia fica no backup)
REMOVER = {}


# Arquivos SUBSTITUÍDOS por inteiro: só troca se o original tiver o hash (sha256, fim de linha normalizado) esperado
SUBST = {
    "src/modules/cadastroPublico/components/FormularioPublico.tsx": {"sha": "6549d960db3db4e5bed29cf532316b43521693231e27d1be392c443735f2d737", "novo": r'''"use client";

/**
 * SysMúsica — Formulário PÚBLICO do Cadastro Musical (sem login). Página: /cadastro.
 * Mesmos campos do cadastro interno, mais: aviso de privacidade (LGPD), responsável (menores de 18 anos) e
 * verificação anti-robô. O envio NÃO cria o membro: gera um pedido que a secretaria aprova em "Cadastros pendentes".
 * Depois de enviar, a tela é sempre a mesma, exista ou não um cadastro anterior com o mesmo CPF.
 */
import { useCallback, useMemo, useState, type FormEvent } from "react";
import { CheckCircle2, Send } from "lucide-react";
import CampoFoto from "@/modules/membros/components/CampoFoto";
import CampoDocumento from "@/modules/membros/components/CampoDocumento";
import SeletorInstrumento, { FamiliaAutomatica } from "@/modules/instrumentos/components/SeletorInstrumento";
import { buscarEnderecoPorCep } from "@/modules/membros/services/cep";
import {
  ESTADOS_CIVIS,
  SEXOS,
  UFS,
  CADASTRO_VAZIO,
  cargoExigeCartao,
  formatarCep,
  formatarTelefone,
  formatarWhatsapp,
  somenteDigitos,
  type CadastroMusical,
  type SimNao,
} from "@/modules/membros/cadastroMusical";
import { CATEGORIAS, cargoUsaCategoria } from "@/modules/painel/regras";
import { cpfValido, formatarCpfParcial, soDigitos } from "../cpf";
import { itensDoAviso } from "../aviso";
import { enviarCadastroPublico } from "../services/envio";
import {
  MENSAGEM_ENVIO_RECEBIDO,
  cargosDoFormularioPublico,
  ehMenorDeIdade,
  formularioVazio,
  instrumentosDoFormularioPublico,
  montarCargaPublica,
  validarEnvioPublico,
  type DadosFormularioPublico,
  type OpcoesCadastroPublico,
} from "../regras";
import { Campo, Secao, classeInput } from "./Campos";
import SeletorCasaPublico from "./SeletorCasaPublico";
import Turnstile from "./Turnstile";

/** Data de hoje (AAAA-MM-DD) no fuso do navegador. */
function hojeIso(): string {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** Mensagem vermelha junto do campo (para a pessoa ver exatamente o que falta). */
function ErroCampo({ id, mensagem }: { id: string; mensagem?: string }) {
  if (!mensagem) return null;
  return (
    <p id={id} role="alert" className="text-xs font-medium text-red-700">
      {mensagem}
    </p>
  );
}

/** Confirmação verde de que a imagem já foi anexada. */
function Anexada({ ok, texto }: { ok: boolean; texto: string }) {
  if (!ok) return null;
  return (
    <p className="flex items-center gap-1 text-xs font-medium text-emerald-700">
      <CheckCircle2 className="h-3.5 w-3.5" aria-hidden="true" /> {texto}
    </p>
  );
}

/** Mensagem do CPF digitado: só fala quando os 11 números já foram digitados (ou ao sair do campo). */
function problemaDoCpf(texto: string, terminou: boolean): string | undefined {
  const n = soDigitos(texto);
  if (n.length === 11) return cpfValido(n) ? undefined : "CPF inválido. Confira os números digitados.";
  if (terminou) return n.length === 0 ? "Informe o CPF." : "CPF incompleto: são 11 números.";
  return undefined;
}

/** Rola a tela até o campo (pelo id do bloco) para a pessoa ver o que corrigir. */
function irParaCampo(id: string) {
  if (typeof document === "undefined") return;
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "center" });
}

export default function FormularioPublico({ opcoes }: { opcoes: OpcoesCadastroPublico }) {
  const [dados, setDados] = useState<DadosFormularioPublico>(() => formularioVazio(CADASTRO_VAZIO));
  const [foto, setFoto] = useState<Blob | null>(null);
  const [frente, setFrente] = useState<Blob | null>(null);
  const [verso, setVerso] = useState<Blob | null>(null);
  const [token, setToken] = useState("");
  const [reiniciarTurnstile, setReiniciarTurnstile] = useState(0);
  const [enviando, setEnviando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [enviado, setEnviado] = useState(false);
  const [avisoCep, setAvisoCep] = useState<string | null>(null);
  const [buscandoCep, setBuscandoCep] = useState(false);
  const [cpfTocado, setCpfTocado] = useState(false); // saiu do campo CPF pelo menos uma vez
  const [errosCampo, setErrosCampo] = useState<{ foto?: string; frente?: string; verso?: string }>({});

  const cargos = useMemo(() => cargosDoFormularioPublico(opcoes.cargos), [opcoes.cargos]);
  const cargo = cargos.find((c) => c.id === dados.cargoId);
  const tipoCategoria = cargoUsaCategoria(cargo?.nome);
  const instrumentos = instrumentosDoFormularioPublico(opcoes.instrumentos, cargo);
  const menor = ehMenorDeIdade(dados.dataNascimento, hojeIso());
  const itens = useMemo(() => itensDoAviso(process.env.NEXT_PUBLIC_CONTATO_PRIVACIDADE), []);

  const mudar = <K extends keyof DadosFormularioPublico>(campo: K, valor: DadosFormularioPublico[K]) =>
    setDados((d) => ({ ...d, [campo]: valor }));
  const mudarCad = <K extends keyof CadastroMusical>(campo: K, valor: CadastroMusical[K]) =>
    setDados((d) => ({ ...d, cadastro: { ...d.cadastro, [campo]: valor } }));

  const aoToken = useCallback((t: string) => setToken(t), []);

  // Ao anexar/remover uma imagem, guarda o arquivo e apaga o aviso vermelho daquele campo
  const aoFoto = useCallback((b: Blob | null) => {
    setFoto(b);
    if (b) setErrosCampo((e) => ({ ...e, foto: undefined }));
  }, []);
  const aoFrente = useCallback((b: Blob | null) => {
    setFrente(b);
    if (b) setErrosCampo((e) => ({ ...e, frente: undefined }));
  }, []);
  const aoVerso = useCallback((b: Blob | null) => {
    setVerso(b);
    if (b) setErrosCampo((e) => ({ ...e, verso: undefined }));
  }, []);
  const erroCpf = problemaDoCpf(dados.cpf, cpfTocado);

  // Preenche o endereço pelo CEP (ViaCEP); se falhar, a pessoa digita
  async function aoSairDoCep() {
    const cep = dados.cadastro.cep;
    setAvisoCep(null);
    if (!/^\d{8}$/.test(cep)) return;
    setBuscandoCep(true);
    const r = await buscarEnderecoPorCep(cep);
    setBuscandoCep(false);
    if (r.tipo === "ok") {
      setDados((d) => ({
        ...d,
        cidade: r.endereco.cidade || d.cidade,
        bairro: r.endereco.bairro || d.bairro,
        cadastro: {
          ...d.cadastro,
          endereco: r.endereco.endereco || d.cadastro.endereco,
          complemento: d.cadastro.complemento || r.endereco.complemento,
          uf: r.endereco.uf || d.cadastro.uf,
        },
      }));
    } else {
      setAvisoCep(r.tipo === "nao_encontrado" ? "CEP não encontrado. Digite o endereço." : "Não consegui consultar o CEP agora. Digite o endereço.");
    }
  }

  async function aoEnviar(e: FormEvent) {
    e.preventDefault();
    if (enviando) return;
    const hoje = hojeIso();

    // Confere primeiro o que costuma ser esquecido (imagens e CPF) e mostra o aviso junto de cada campo
    const faltas: { foto?: string; frente?: string; verso?: string } = {};
    if (!foto) faltas.foto = "Falta a sua fotografia. Tire uma foto ou escolha da galeria.";
    if (!frente) faltas.frente = "Falta a foto da frente do documento.";
    if (!verso) faltas.verso = "Falta a foto do verso do documento.";
    setErrosCampo(faltas);
    setCpfTocado(true);
    const cpfProblema = problemaDoCpf(dados.cpf, true);
    const primeiro = faltas.foto ? "campo-foto" : cpfProblema ? "cpf" : faltas.frente ? "campo-frente" : faltas.verso ? "campo-verso" : null;
    if (primeiro) {
      setErro("Corrija os campos marcados em vermelho.");
      irParaCampo(primeiro);
      return;
    }

    const problema = validarEnvioPublico(dados, {
      cargo,
      temFoto: foto !== null,
      temDocumentoFrente: frente !== null,
      temDocumentoVerso: verso !== null,
      hoje,
    });
    if (problema) return setErro(problema);
    if (token === "") return setErro("Aguarde a verificação de segurança e tente de novo.");
    if (!foto || !frente || !verso) return;

    setErro(null);
    setEnviando(true);
    try {
      await enviarCadastroPublico(montarCargaPublica(dados, { cargo, hoje }), { foto, frente, verso }, token);
      setEnviado(true);
    } catch (ex) {
      setErro(ex instanceof Error ? ex.message : "Não foi possível enviar o cadastro.");
      setToken(""); // o token vale uma só vez: pede uma nova verificação
      setReiniciarTurnstile((n) => n + 1);
    } finally {
      setEnviando(false);
    }
  }

  if (enviado) {
    return (
      <div role="status" className="rounded-2xl border border-emerald-200 bg-emerald-50 p-6 text-center">
        <CheckCircle2 className="mx-auto h-10 w-10 text-emerald-600" aria-hidden="true" />
        <p className="mt-3 text-base font-medium text-emerald-900">{MENSAGEM_ENVIO_RECEBIDO}</p>
      </div>
    );
  }

  const cad = dados.cadastro;
  const exigeCartao = cargoExigeCartao(cargo);
  const bloqueado = enviando;

  return (
    <form onSubmit={(ev) => void aoEnviar(ev)} className="space-y-8" noValidate>
      {/* Campo-armadilha: invisível para pessoas; robôs costumam preencher. Não remova. */}
      <div aria-hidden="true" className="absolute -left-[9999px] h-0 w-0 overflow-hidden">
        <label htmlFor="site">Site</label>
        <input id="site" type="text" tabIndex={-1} autoComplete="off" value={dados.site} onChange={(e) => mudar("site", e.target.value)} />
      </div>

      <Secao titulo="Fotografia">
        <div id="campo-foto" className="space-y-2">
          <CampoFoto nome={dados.nome || "você"} obrigatoria onChange={aoFoto} disabled={bloqueado} />
          <Anexada ok={foto !== null} texto="Fotografia anexada" />
          <ErroCampo id="erro-foto" mensagem={errosCampo.foto} />
        </div>
      </Secao>

      <Secao titulo="Identificação">
        <Campo id="nome" rotulo="Nome completo" obrigatorio>
          <input id="nome" type="text" autoComplete="name" maxLength={120} value={dados.nome} onChange={(e) => mudar("nome", e.target.value)} disabled={bloqueado} className={classeInput} placeholder="Ex: João da Silva" />
        </Campo>
        <div className="grid gap-3 sm:grid-cols-2">
          <Campo id="cpf" rotulo="CPF" obrigatorio>
            <input id="cpf" type="text" inputMode="numeric" autoComplete="off" value={dados.cpf} onChange={(e) => mudar("cpf", formatarCpfParcial(e.target.value))} onBlur={() => setCpfTocado(true)} aria-invalid={erroCpf ? true : undefined} aria-describedby={erroCpf ? "erro-cpf" : undefined} disabled={bloqueado} className={`${classeInput}${erroCpf ? " border-red-500" : ""}`} placeholder="000.000.000-00" maxLength={14} />
            <ErroCampo id="erro-cpf" mensagem={erroCpf} />
          </Campo>
          <Campo id="nascimento" rotulo="Data de nascimento" obrigatorio>
            <input id="nascimento" type="date" autoComplete="bday" max={hojeIso()} value={dados.dataNascimento} onChange={(e) => mudar("dataNascimento", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <Campo id="estado_civil" rotulo="Estado civil" obrigatorio>
            <select id="estado_civil" value={cad.estado_civil} onChange={(e) => mudarCad("estado_civil", e.target.value)} disabled={bloqueado} className={classeInput}>
              <option value="">Selecione</option>
              {ESTADOS_CIVIS.map((v) => <option key={v} value={v}>{v}</option>)}
            </select>
          </Campo>
          <Campo id="sexo" rotulo="Sexo" obrigatorio>
            <select id="sexo" value={cad.sexo} onChange={(e) => mudarCad("sexo", e.target.value)} disabled={bloqueado} className={classeInput}>
              <option value="">Selecione</option>
              {SEXOS.map((v) => <option key={v} value={v}>{v}</option>)}
            </select>
          </Campo>
        </div>
      </Secao>

      {menor && (
        <Secao titulo="Responsável (menor de 18 anos)">
          <Campo id="resp-nome" rotulo="Nome do responsável" obrigatorio>
            <input id="resp-nome" type="text" maxLength={120} value={dados.responsavelNome} onChange={(e) => mudar("responsavelNome", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <Campo id="resp-tel" rotulo="Telefone do responsável (com DDD)" obrigatorio>
            <input id="resp-tel" type="tel" inputMode="numeric" value={dados.responsavelTelefone} onChange={(e) => mudar("responsavelTelefone", formatarWhatsapp(e.target.value))} disabled={bloqueado} className={classeInput} />
          </Campo>
          <label className="flex items-start gap-2 text-sm text-slate-700">
            <input type="checkbox" checked={dados.aceiteResponsavel} onChange={(e) => mudar("aceiteResponsavel", e.target.checked)} disabled={bloqueado} className="mt-0.5" />
            <span>Eu sou o responsável e concordo com este cadastro e com o aviso de privacidade.</span>
          </label>
        </Secao>
      )}

      <Secao titulo="Casa de Oração e cargo">
        <Campo id="casa" rotulo="Casa de Oração" obrigatorio dica="Digite e escolha na lista. Se a sua casa não existir na lista, digite o nome dela mesmo assim.">
          <SeletorCasaPublico id="casa" valor={dados.casaOracaoId} onChange={(casaId, nome) => setDados((d) => ({ ...d, casaOracaoId: casaId, casaNome: nome }))} casas={opcoes.casas} disabled={bloqueado} />
        </Campo>
        <Campo id="cargo" rotulo="Cargo" obrigatorio>
          <select
            id="cargo"
            value={dados.cargoId}
            onChange={(e) => setDados((d) => ({ ...d, cargoId: e.target.value, categoria: "", instrumentoId: "" }))}
            disabled={bloqueado}
            className={classeInput}
          >
            <option value="">Selecione o cargo</option>
            {cargos.map((c) => <option key={c.id} value={c.id}>{c.nome}</option>)}
          </select>
        </Campo>
        {tipoCategoria && (
          <Campo id="categoria" rotulo="Categoria" obrigatorio>
            <select id="categoria" value={dados.categoria} onChange={(e) => mudar("categoria", e.target.value)} disabled={bloqueado} className={classeInput}>
              <option value="">Selecione a categoria</option>
              {CATEGORIAS.map((c) => <option key={c.valor} value={c.valor}>{c[tipoCategoria === "organista" ? "organista" : "musico"]}</option>)}
            </select>
          </Campo>
        )}
        {cargo?.permite_instrumento && (
          <>
            <Campo id="instrumento" rotulo="Instrumento" obrigatorio>
              <SeletorInstrumento id="instrumento" valor={dados.instrumentoId} onChange={(v) => mudar("instrumentoId", v)} instrumentos={instrumentos} familias={opcoes.familias} obrigatorio disabled={bloqueado} className={classeInput} />
            </Campo>
            <FamiliaAutomatica instrumentoId={dados.instrumentoId} instrumentos={instrumentos} familias={opcoes.familias} />
          </>
        )}
      </Secao>

      <Secao titulo="Dados religiosos (consentimento específico)">
        <div className="grid gap-3 sm:grid-cols-2">
          <Campo id="batizado" rotulo="É batizado(a)?" obrigatorio>
            <select id="batizado" value={cad.batizado} onChange={(e) => mudarCad("batizado", e.target.value as SimNao)} disabled={bloqueado} className={classeInput}>
              <option value="">Selecione</option>
              <option value="sim">Sim</option>
              <option value="nao">Não</option>
            </select>
          </Campo>
          {cad.batizado === "sim" && (
            <Campo id="data_batismo" rotulo="Data do batismo" obrigatorio>
              <input id="data_batismo" type="date" value={cad.data_batismo} onChange={(e) => mudarCad("data_batismo", e.target.value)} disabled={bloqueado} className={classeInput} />
            </Campo>
          )}
        </div>
        <Campo id="selado" rotulo="É selado(a)?" obrigatorio>
          <select id="selado" value={cad.selado} onChange={(e) => mudarCad("selado", e.target.value as SimNao)} disabled={bloqueado} className={classeInput}>
            <option value="">Selecione</option>
            <option value="sim">Sim</option>
            <option value="nao">Não</option>
          </select>
        </Campo>
      </Secao>

      <Secao titulo="Contato">
        <div className="grid grid-cols-3 gap-3">
          {/* Telefone e WhatsApp: o estado guarda SÓ OS NÚMEROS (a validação exige isso); o traço/parênteses são só a exibição. */}
          <Campo id="ddd" rotulo="DDD" obrigatorio>
            <input id="ddd" type="tel" inputMode="numeric" maxLength={2} value={cad.ddd} onChange={(e) => mudarCad("ddd", somenteDigitos(e.target.value, 2))} disabled={bloqueado} className={classeInput} />
          </Campo>
          <div className="col-span-2">
            <Campo id="telefone" rotulo="Telefone" obrigatorio>
              <input id="telefone" type="tel" inputMode="numeric" value={formatarTelefone(cad.telefone)} onChange={(e) => mudarCad("telefone", somenteDigitos(e.target.value, 9))} disabled={bloqueado} className={classeInput} />
            </Campo>
          </div>
        </div>
        <Campo id="tem_whatsapp" rotulo="O telefone tem WhatsApp?" obrigatorio>
          <select id="tem_whatsapp" value={cad.tem_whatsapp} onChange={(e) => mudarCad("tem_whatsapp", e.target.value as SimNao)} disabled={bloqueado} className={classeInput}>
            <option value="">Selecione</option>
            <option value="sim">Sim</option>
            <option value="nao">Não</option>
          </select>
        </Campo>
        {cad.tem_whatsapp === "sim" && (
          <Campo id="whatsapp" rotulo="WhatsApp (com DDD)" dica="Deixe vazio se for o mesmo número do telefone.">
            <input id="whatsapp" type="tel" inputMode="numeric" value={formatarWhatsapp(cad.whatsapp)} onChange={(e) => mudarCad("whatsapp", somenteDigitos(e.target.value, 11))} disabled={bloqueado} className={classeInput} />
          </Campo>
        )}
        <Campo id="email" rotulo="E-mail">
          <input id="email" type="email" autoComplete="email" maxLength={120} value={cad.email} onChange={(e) => mudarCad("email", e.target.value)} disabled={bloqueado} className={classeInput} />
        </Campo>
      </Secao>

      <Secao titulo="Endereço">
        <Campo id="cep" rotulo="CEP" obrigatorio dica={buscandoCep ? "Consultando o CEP..." : (avisoCep ?? undefined)}>
          <input id="cep" type="text" inputMode="numeric" autoComplete="postal-code" value={formatarCep(cad.cep)} onChange={(e) => mudarCad("cep", somenteDigitos(e.target.value, 8))} onBlur={() => void aoSairDoCep()} disabled={bloqueado} className={classeInput} />
        </Campo>
        <Campo id="endereco" rotulo="Endereço" obrigatorio>
          <input id="endereco" type="text" autoComplete="street-address" maxLength={150} value={cad.endereco} onChange={(e) => mudarCad("endereco", e.target.value)} disabled={bloqueado} className={classeInput} />
        </Campo>
        <div className="grid grid-cols-2 gap-3">
          <Campo id="numero" rotulo="Número" obrigatorio>
            <input id="numero" type="text" maxLength={20} value={cad.numero} onChange={(e) => mudarCad("numero", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <Campo id="complemento" rotulo="Complemento">
            <input id="complemento" type="text" maxLength={80} value={cad.complemento} onChange={(e) => mudarCad("complemento", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
        </div>
        <div className="grid gap-3 sm:grid-cols-3">
          <Campo id="bairro" rotulo="Bairro" obrigatorio>
            <input id="bairro" type="text" maxLength={80} value={dados.bairro} onChange={(e) => mudar("bairro", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <Campo id="cidade" rotulo="Cidade" obrigatorio>
            <input id="cidade" type="text" maxLength={80} value={dados.cidade} onChange={(e) => mudar("cidade", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <Campo id="uf" rotulo="UF" obrigatorio>
            <select id="uf" value={cad.uf} onChange={(e) => mudarCad("uf", e.target.value)} disabled={bloqueado} className={classeInput}>
              <option value="">UF</option>
              {UFS.map((u) => <option key={u} value={u}>{u}</option>)}
            </select>
          </Campo>
        </div>
      </Secao>

      {exigeCartao && (
        <Secao titulo="Cartão de identificação">
          <Campo id="cartao_numero" rotulo="Número do cartão" obrigatorio>
            <input id="cartao_numero" type="text" autoComplete="off" maxLength={40} value={cad.cartao_numero} onChange={(e) => mudarCad("cartao_numero", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <div className="grid grid-cols-2 gap-3">
            <Campo id="cartao_emissao" rotulo="Emissão">
              <input id="cartao_emissao" type="date" value={cad.cartao_emissao} onChange={(e) => mudarCad("cartao_emissao", e.target.value)} disabled={bloqueado} className={classeInput} />
            </Campo>
            <Campo id="cartao_validade" rotulo="Validade" obrigatorio>
              <input id="cartao_validade" type="date" value={cad.cartao_validade} onChange={(e) => mudarCad("cartao_validade", e.target.value)} disabled={bloqueado} className={classeInput} />
            </Campo>
          </div>
        </Secao>
      )}

      <Secao titulo="Documento de identificação">
        <p className="text-xs text-slate-500">Anexe uma foto da frente e uma do verso (RG ou CNH). Os arquivos ficam em armazenamento privado.</p>
        <div id="campo-frente" className="space-y-2">
          <CampoDocumento id="pub-doc-frente" rotulo="Frente do documento" obrigatorio onChange={aoFrente} disabled={bloqueado} />
          <Anexada ok={frente !== null} texto="Frente anexada" />
          <ErroCampo id="erro-frente" mensagem={errosCampo.frente} />
        </div>
        <div id="campo-verso" className="space-y-2">
          <CampoDocumento id="pub-doc-verso" rotulo="Verso do documento" obrigatorio onChange={aoVerso} disabled={bloqueado} />
          <Anexada ok={verso !== null} texto="Verso anexado" />
          <ErroCampo id="erro-verso" mensagem={errosCampo.verso} />
        </div>
      </Secao>

      <Secao titulo="Aviso de privacidade (LGPD)">
        <div className="max-h-64 space-y-3 overflow-y-auto rounded-lg border border-slate-200 bg-slate-50 p-3 text-sm text-slate-700">
          {itens.map((item) => (
            <div key={item.titulo}>
              <p className="font-semibold">{item.titulo}</p>
              <p>{item.texto}</p>
            </div>
          ))}
        </div>
        <label className="flex items-start gap-2 text-sm text-slate-800">
          <input type="checkbox" checked={dados.aceitePrivacidade} onChange={(e) => mudar("aceitePrivacidade", e.target.checked)} disabled={bloqueado} className="mt-0.5" />
          <span>Li e concordo com o aviso de privacidade, inclusive com o uso dos dados sobre batismo e selamento.</span>
        </label>
      </Secao>

      <Turnstile onToken={aoToken} reiniciar={reiniciarTurnstile} />

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <button
        type="submit"
        disabled={enviando}
        className="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-brand-600 px-4 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-60"
      >
        <Send className="h-4 w-4" aria-hidden="true" />
        {enviando ? "Enviando..." : "Enviar cadastro"}
      </button>
    </form>
  );
}
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
  if "$@" > /tmp/p9aj5-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p9aj5-passo.out
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
echo "Pronto: recarregue /cadastro e teste o telefone."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
