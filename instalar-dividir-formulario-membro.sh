#!/usr/bin/env bash
# =============================================================================
# SysMúsica — ORGANIZAÇÃO: divide o formulário de membro (1.110 linhas) em seções menores
#
#  Não precisa de SQL. O formulário continua igual para quem usa: o texto de cada seção foi só MOVIDO para arquivos
#  próprios em src/modules/membros/components/formulario/. src/components/FormularioMembro.tsx fica com o estado e o salvar.
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-dividir-formulario-membro-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-dividir-formulario-membro.sh
# Log:  /tmp/instalar-dividir-formulario-membro.log
# =============================================================================

LOG=/tmp/instalar-dividir-formulario-membro.log
BKP=/tmp/bkp-dividir-formulario-membro-$(date +%Y%m%d-%H%M%S)
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
EDITS = [
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    'src/modules/membros/components/formulario/SecaoCargo.tsx': r'''/**
 * SysMúsica — Formulário de membro, seção: Casa de Oração, cargo, status do cargo, instrumento, batismo e selamento.
 * Trecho movido de src/components/FormularioMembro.tsx sem mudar o comportamento; o estado e as regras de salvar
 * continuam lá, e esta seção só recebe os valores e as funções de que precisa.
 */
import SeletorInstrumento, { FamiliaAutomatica } from "@/modules/instrumentos/components/SeletorInstrumento";
import SeletorCasaOracao from "@/modules/organizacao/components/SeletorCasaOracao";
import { CATEGORIAS, cargoUsaCategoria } from "@/modules/painel/regras";
import { cargoSomenteOrgao, cargosDoCadastro, instrumentosDoCargo, type CadastroMusical, type SimNao } from "@/modules/membros/cadastroMusical";
import type { Cargo, Familia, Instrumento } from "@/types/database";
import { Campo, Secao, classeInput, rotuloSimNao, hojeLocal, type MudarCadastro } from "./campos";

interface SecaoCargoProps {
  completo: boolean;
  salvando: boolean;
  casaOracaoId: string;
  setCasaOracaoId: (valor: string) => void;
  setCongregacao: (valor: string) => void;
  cargoId: string;
  trocarCargo: (novoCargoId: string) => void;
  cargosDisponiveis: ReturnType<typeof cargosDoCadastro>;
  tipoCategoria: ReturnType<typeof cargoUsaCategoria>;
  categoria: string;
  setCategoria: (valor: string) => void;
  cargoSelecionado: Cargo | undefined;
  permiteInstrumento: boolean;
  instrumentoObrigatorio: boolean;
  somenteOrgao: ReturnType<typeof cargoSomenteOrgao>;
  instrumentosDisponiveis: ReturnType<typeof instrumentosDoCargo>;
  instrumentoId: string;
  setInstrumentoId: (valor: string) => void;
  instrumentos: Instrumento[];
  familias: Familia[];
  cadastro: CadastroMusical;
  mudar: MudarCadastro;
  escolherBatizado: (valor: SimNao) => void;
}

export default function SecaoCargo({
  completo,
  salvando,
  casaOracaoId,
  setCasaOracaoId,
  setCongregacao,
  cargoId,
  trocarCargo,
  cargosDisponiveis,
  tipoCategoria,
  categoria,
  setCategoria,
  cargoSelecionado,
  permiteInstrumento,
  instrumentoObrigatorio,
  somenteOrgao,
  instrumentosDisponiveis,
  instrumentoId,
  setInstrumentoId,
  instrumentos,
  familias,
  cadastro,
  mudar,
  escolherBatizado,
}: SecaoCargoProps) {
  // Data máxima dos campos de data = hoje (AAAA-MM-DD, no fuso local)
  const hoje = hojeLocal();
  return (
    <>
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
              obrigatorio={instrumentoObrigatorio}
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
                disabled={salvando || (somenteOrgao && instrumentosDisponiveis.length === 1)}
                className={classeInput}
              />
            </Campo>

            <FamiliaAutomatica instrumentoId={instrumentoId} instrumentos={instrumentos} familias={familias} />
          </>
        )}

        <div className="grid grid-cols-2 gap-3">
          <Campo id="batizado" rotulo="Batizado(a)?" obrigatorio={completo}>
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
    </>
  );
}
''',
    'src/modules/membros/components/formulario/SecaoCartao.tsx': r'''/**
 * SysMúsica — Formulário de membro, seção: Cartão de identificação (só para os cargos marcados em cargos.exige_cartao).
 * Trecho movido de src/components/FormularioMembro.tsx sem mudar o comportamento; o estado e as regras de salvar
 * continuam lá, e esta seção só recebe os valores e as funções de que precisa.
 */
import type { CadastroMusical } from "@/modules/membros/cadastroMusical";
import { Campo, Secao, classeInput, type MudarCadastro } from "./campos";

interface SecaoCartaoProps {
  exigeCartao: boolean;
  salvando: boolean;
  cadastro: CadastroMusical;
  mudar: MudarCadastro;
}

export default function SecaoCartao({
  exigeCartao,
  salvando,
  cadastro,
  mudar,
}: SecaoCartaoProps) {
  return (
    <>
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
    </>
  );
}
''',
    'src/modules/membros/components/formulario/SecaoContato.tsx': r'''/**
 * SysMúsica — Formulário de membro, seção: Contato: telefone, WhatsApp e e-mail.
 * Trecho movido de src/components/FormularioMembro.tsx sem mudar o comportamento; o estado e as regras de salvar
 * continuam lá, e esta seção só recebe os valores e as funções de que precisa.
 */
import { formatarTelefone, formatarWhatsapp, somenteDigitos, type CadastroMusical, type SimNao } from "@/modules/membros/cadastroMusical";
import { Campo, Secao, classeInput, rotuloSimNao, type MudarCadastro } from "./campos";

interface SecaoContatoProps {
  completo: boolean;
  salvando: boolean;
  cadastro: CadastroMusical;
  mudar: MudarCadastro;
  escolherWhatsapp: (valor: SimNao) => void;
}

export default function SecaoContato({
  completo,
  salvando,
  cadastro,
  mudar,
  escolherWhatsapp,
}: SecaoContatoProps) {
  return (
    <>
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
    </>
  );
}
''',
    'src/modules/membros/components/formulario/SecaoDocumento.tsx': r'''/**
 * SysMúsica — Formulário de membro, seção: Documento de identificação (frente e verso; armazenamento privado).
 * Trecho movido de src/components/FormularioMembro.tsx sem mudar o comportamento; o estado e as regras de salvar
 * continuam lá, e esta seção só recebe os valores e as funções de que precisa.
 */
import CampoDocumento from "@/modules/membros/components/CampoDocumento";
import type { CadastroMusical } from "@/modules/membros/cadastroMusical";
import { Secao } from "./campos";

interface SecaoDocumentoProps {
  completo: boolean;
  salvando: boolean;
  podeDocumento: boolean;
  cadastro: CadastroMusical;
  setDocFrente: (imagem: Blob | null) => void;
  setDocVerso: (imagem: Blob | null) => void;
}

export default function SecaoDocumento({
  completo,
  salvando,
  podeDocumento,
  cadastro,
  setDocFrente,
  setDocVerso,
}: SecaoDocumentoProps) {
  return (
    <>
      {/* ---------- Documento de identificação (frente e verso; armazenamento privado) ---------- */}
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
    </>
  );
}
''',
    'src/modules/membros/components/formulario/SecaoEndereco.tsx': r'''/**
 * SysMúsica — Formulário de membro, seção: Endereço: CEP (consulta online), rua, cidade e bairro.
 * Trecho movido de src/components/FormularioMembro.tsx sem mudar o comportamento; o estado e as regras de salvar
 * continuam lá, e esta seção só recebe os valores e as funções de que precisa.
 */
import { UFS, formatarCep, type CadastroMusical } from "@/modules/membros/cadastroMusical";
import { textoDoStatusCep, type StatusCep } from "./cep";
import type { SugestoesLocalidade } from "./tipos";
import { Campo, Secao, classeInput, type MudarCadastro } from "./campos";

interface SecaoEnderecoProps {
  completo: boolean;
  salvando: boolean;
  cadastro: CadastroMusical;
  mudar: MudarCadastro;
  statusCep: StatusCep;
  mudarCep: (valor: string) => Promise<void>;
  cidade: string;
  setCidade: (valor: string) => void;
  bairro: string;
  setBairro: (valor: string) => void;
  sugestoes: SugestoesLocalidade;
}

export default function SecaoEndereco({
  completo,
  salvando,
  cadastro,
  mudar,
  statusCep,
  mudarCep,
  cidade,
  setCidade,
  bairro,
  setBairro,
  sugestoes,
}: SecaoEnderecoProps) {
  return (
    <>
      {/* ---------- Endereço ---------- */}
      <Secao titulo="Endereço">
        <div className="grid grid-cols-2 gap-3">
          <Campo id="cep" rotulo="CEP" obrigatorio={completo} dica={textoDoStatusCep(statusCep)}>
            <input
              id="cep"
              type="text"
              inputMode="numeric"
              autoComplete="off"
              value={formatarCep(cadastro.cep)}
              onChange={(e) => void mudarCep(e.target.value)}
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
    </>
  );
}
''',
    'src/modules/membros/components/formulario/SecaoFotografia.tsx': r'''/**
 * SysMúsica — Formulário de membro, seção: Fotografia do membro (obrigatória no cadastro novo; na edição só troca/remove quem tem a permissão).
 * Trecho movido de src/components/FormularioMembro.tsx sem mudar o comportamento; o estado e as regras de salvar
 * continuam lá, e esta seção só recebe os valores e as funções de que precisa.
 */
import FotoMembro from "@/modules/membros/components/FotoMembro";
import CampoFoto from "@/modules/membros/components/CampoFoto";
import type { MembroPublico } from "@/types/database";

interface SecaoFotografiaProps {
  editando: boolean;
  podeFoto: boolean;
  nome: string;
  membro: MembroPublico | null;
  salvando: boolean;
  setFoto: (foto: Blob | null) => void;
  confirmandoRemocaoFoto: boolean;
  setConfirmandoRemocaoFoto: (valor: boolean) => void;
  removerFotoAtual: () => Promise<void>;
}

export default function SecaoFotografia({
  editando,
  podeFoto,
  nome,
  membro,
  salvando,
  setFoto,
  confirmandoRemocaoFoto,
  setConfirmandoRemocaoFoto,
  removerFotoAtual,
}: SecaoFotografiaProps) {
  return (
    <>
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
    </>
  );
}
''',
    'src/modules/membros/components/formulario/SecaoIdentificacao.tsx': r'''/**
 * SysMúsica — Formulário de membro, seção: Identificação: nome, CPF, nascimento, estado civil e sexo.
 * Trecho movido de src/components/FormularioMembro.tsx sem mudar o comportamento; o estado e as regras de salvar
 * continuam lá, e esta seção só recebe os valores e as funções de que precisa.
 */
import { formatarCpf } from "@/lib/cpf";
import { ESTADOS_CIVIS, SEXOS, type CadastroMusical } from "@/modules/membros/cadastroMusical";
import { Campo, Secao, classeInput, rotuloSimNao, hojeLocal, type MudarCadastro } from "./campos";

interface SecaoIdentificacaoProps {
  editando: boolean;
  podeCpf: boolean;
  completo: boolean;
  nome: string;
  setNome: (valor: string) => void;
  cpf: string;
  setCpf: (valor: string) => void;
  dataNascimento: string;
  setDataNascimento: (valor: string) => void;
  salvando: boolean;
  cadastro: CadastroMusical;
  mudar: MudarCadastro;
}

export default function SecaoIdentificacao({
  editando,
  podeCpf,
  completo,
  nome,
  setNome,
  cpf,
  setCpf,
  dataNascimento,
  setDataNascimento,
  salvando,
  cadastro,
  mudar,
}: SecaoIdentificacaoProps) {
  // Data máxima dos campos de data = hoje (AAAA-MM-DD, no fuso local)
  const hoje = hojeLocal();
  return (
    <>
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
            obrigatorio={completo}
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

        {/* Sem a permissão CPF não dá para preencher o CPF obrigatório de um cadastro novo */}
        {!podeCpf && !editando && (
          <p role="alert" className="rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
            O CPF é obrigatório no cadastro e o seu perfil não tem a permissão CPF. Peça a um administrador para liberá-la
            em Administração &gt; Grupos de acesso.
          </p>
        )}

        <Campo id="data_nascimento" rotulo="Data de nascimento" obrigatorio={completo}>
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
          <Campo id="estado_civil" rotulo="Estado civil" obrigatorio={completo}>
            <select
              id="estado_civil"
              value={cadastro.estado_civil}
              onChange={(e) => mudar("estado_civil", e.target.value)}
              disabled={salvando}
              className={classeInput}
            >
              <option value="">{rotuloSimNao(completo)}</option>
              {ESTADOS_CIVIS.map((item) => (
                <option key={item} value={item}>
                  {item}
                </option>
              ))}
            </select>
          </Campo>
          <Campo id="sexo" rotulo="Sexo" obrigatorio={completo}>
            <select
              id="sexo"
              value={cadastro.sexo}
              onChange={(e) => mudar("sexo", e.target.value)}
              disabled={salvando}
              className={classeInput}
            >
              <option value="">{rotuloSimNao(completo)}</option>
              {SEXOS.map((item) => (
                <option key={item} value={item}>
                  {item}
                </option>
              ))}
            </select>
          </Campo>
        </div>
      </Secao>
    </>
  );
}
''',
    'src/modules/membros/components/formulario/SecaoOutras.tsx': r'''/**
 * SysMúsica — Formulário de membro, seção: Observação e situação cadastral (a situação só aparece na edição).
 * Trecho movido de src/components/FormularioMembro.tsx sem mudar o comportamento; o estado e as regras de salvar
 * continuam lá, e esta seção só recebe os valores e as funções de que precisa.
 */
import type { CadastroMusical } from "@/modules/membros/cadastroMusical";
import { Campo, Secao, classeInput, type MudarCadastro } from "./campos";

interface SecaoOutrasProps {
  editando: boolean;
  salvando: boolean;
  cadastro: CadastroMusical;
  mudar: MudarCadastro;
  status: string;
  setStatus: (valor: string) => void;
}

export default function SecaoOutras({
  editando,
  salvando,
  cadastro,
  mudar,
  status,
  setStatus,
}: SecaoOutrasProps) {
  return (
    <>
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
    </>
  );
}
''',
    'src/modules/membros/components/formulario/campos.tsx': r'''"use client";

/**
 * SysMúsica — Peças comuns do formulário de membro: estilo dos campos, bloco com título (Secao) e campo com rótulo (Campo).
 */
import type { ReactNode } from "react";
import type { CadastroMusical } from "@/modules/membros/cadastroMusical";

// Classe compartilhada pelos campos (mesma identidade visual dos demais módulos).
// [color-scheme:light] mantém o ícone do seletor de data visível mesmo com o navegador em tema escuro.
export const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60 " +
  "[color-scheme:light]";

/** Função que muda um campo dos dados pessoais (a mesma usada pelo formulário). */
export type MudarCadastro = <K extends keyof CadastroMusical>(campo: K, valor: CadastroMusical[K]) => void;

/** Texto do primeiro item de uma lista Sim/Não ou de escolha: "Selecione" quando o campo é obrigatório. */
export function rotuloSimNao(obrigatorio: boolean): string {
  return obrigatorio ? "Selecione" : "—";
}

/** Data de hoje no formato AAAA-MM-DD, no fuso local (limite máximo dos campos de data). */
export function hojeLocal(): string {
  return new Date().toLocaleDateString("sv-SE");
}

/** Bloco do formulário com título (agrupa os campos por assunto). */
export function Secao({ titulo, children }: { titulo: string; children: ReactNode }) {
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
export function Campo({
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
}
''',
    'src/modules/membros/components/formulario/cep.test.ts': r'''import { describe, expect, it } from "vitest";
import { textoDoStatusCep } from "./cep";

describe("textoDoStatusCep", () => {
  it("não mostra nada quando não há consulta em andamento", () => {
    expect(textoDoStatusCep("")).toBeUndefined();
  });

  it("explica cada situação da consulta do CEP", () => {
    expect(textoDoStatusCep("buscando")).toMatch(/Buscando/);
    expect(textoDoStatusCep("encontrado")).toMatch(/preenchido/);
    expect(textoDoStatusCep("nao_encontrado")).toMatch(/não encontrado/);
    expect(textoDoStatusCep("indisponivel")).toMatch(/Não foi possível/);
  });
});
''',
    'src/modules/membros/components/formulario/cep.ts': r'''/**
 * SysMúsica — Andamento da consulta de endereço pelo CEP (ViaCEP) e o texto que o formulário mostra para cada situação.
 */
/** Andamento da consulta de endereço pelo CEP ("" = nada a mostrar). */
export type StatusCep = "" | "buscando" | "encontrado" | "nao_encontrado" | "indisponivel";

export function textoDoStatusCep(status: StatusCep): string | undefined {
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
''',
    'src/modules/membros/components/formulario/tipos.ts': r'''/** SysMúsica — Tipos do formulário de membro. */

/** Listas de sugestões para os campos de localidade. */
export interface SugestoesLocalidade {
  congregacoes: string[];
  cidades: string[];
  bairros: string[];
}
''',
}


# Arquivos a REMOVER: só são apagados se o conteúdo for idêntico ao esperado (cópia fica no backup)
REMOVER = {}


# Arquivos SUBSTITUÍDOS por inteiro: só troca se o original tiver o hash (sha256, fim de linha normalizado) esperado
SUBST = {
    'src/components/FormularioMembro.tsx': {'sha': '7155605d0cc7bfddf49e2b1bee23c28fcc8a87d09cce1af0df559c4fa1b75088', 'novo': r'''"use client";

/**
 * SysMúsica — Formulário de membro (cadastro e edição) — conteúdo do painel lateral.
 * membro = null -> cadastrar; preenchido -> editar (inclui o status Ativo/Inativo).
 *
 * Casa de Oração: lista agrupada por Região › Setor (cadastrada em Organização). O nome da congregação sai da casa de oração.
 * Cidade e bairro: texto com sugestões dos valores já cadastrados.
 * CPF: só aparece para quem tem a permissão membros.cpf (o banco também confere). É opcional,
 *      validado pelos dígitos verificadores e não pode repetir entre os membros.
 *
 * CADASTRO MUSICAL (migração 0038): além dos dados de "membros", o formulário coleta os dados pessoais
 *      (estado civil, sexo, batismo, selado, telefone/WhatsApp, e-mail, endereço, cartão de identificação,
 *      apresentado por, observação), gravados na tabela protegida membros_cadastro pelas funções do banco
 *      (services/cadastroMusical.ts). As regras e validações ficam em modules/membros/cadastroMusical.ts.
 *  - Só os cargos do cadastro aparecem na lista (o cargo atual do membro é mantido na edição).
 *  - Cargos com cartão de identificação (cargos.exige_cartao) mostram os campos do cartão.
 *  - "Status do cargo" (Oficializado / Culto Oficial / RJM) é o campo Categoria; outros cargos são Oficializado.
 *  - Os campos obrigatórios (*) valem no cadastro novo e em quem já tem o cadastro preenchido.
 *
 * MIGRAÇÃO 0040: no cadastro completo também são obrigatórios CPF, data de nascimento, estado civil, sexo, instrumento
 *      (nos cargos que usam instrumento), Batizado (Sim/Não; sendo Sim, a data do batismo) e a frente e o verso do
 *      documento de identificação (armazenamento privado). Organista, Examinadora, Instrutor e Instrutora só aceitam
 *      o instrumento Órgão (cargos.somente_orgao). Ao digitar o CEP, o endereço é consultado online (ViaCEP).
 *
 * Instrumento: lista suspensa agrupada por família, igual em todo o sistema (só instrumentos cadastrados).
 *  - O campo só aparece para cargos com permite_instrumento = true.
 *  - É OBRIGATÓRIO nos cargos que exigem instrumento (o Músico); o banco também recusa sem ele.
 *  - A FAMÍLIA é automática e somente leitura (vem do cadastro do instrumento). Instrumento novo e
 *    correção de família: tela Instrumentos e famílias.
 *
 * ORGANIZAÇÃO: as seções visuais ficam em src/modules/membros/components/formulario/ (uma por assunto). Este arquivo
 * guarda o estado, as regras de salvar e a montagem das seções.
 */
import { useRef, useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { formatarCpf, limparCpf, validarCpf } from "@/lib/cpf";
import { validarInstrumentoDoCargo } from "@/modules/instrumentos/selecao";
import { atualizarMembro, criarMembro } from "@/modules/membros/services/membros";
import { cargoUsaCategoria, validarCategoria } from "@/modules/painel/regras";
import { descartarFoto, enviarFoto, removerFoto, subirFotoNova } from "@/modules/membros/services/fotos";
import { buscarEnderecoPorCep } from "@/modules/membros/services/cep";
import { descartarDocumentos, subirDocumento } from "@/modules/membros/services/documentos";
import {
  CADASTRO_VAZIO,
  cargoExigeCartao,
  cargoSomenteOrgao,
  cargosDoCadastro,
  instrumentosDoCargo,
  somenteDigitos,
  temAlgumDado,
  validarCadastro,
  type CadastroMusical,
  type SimNao,
} from "@/modules/membros/cadastroMusical";
import { salvarCadastroMusical } from "@/modules/membros/services/cadastroMusical";
import type { Cargo, Familia, Instrumento, MembroPublico } from "@/types/database";
import type { StatusCep } from "@/modules/membros/components/formulario/cep";
import type { SugestoesLocalidade } from "@/modules/membros/components/formulario/tipos";
import SecaoFotografia from "@/modules/membros/components/formulario/SecaoFotografia";
import SecaoIdentificacao from "@/modules/membros/components/formulario/SecaoIdentificacao";
import SecaoCargo from "@/modules/membros/components/formulario/SecaoCargo";
import SecaoCartao from "@/modules/membros/components/formulario/SecaoCartao";
import SecaoDocumento from "@/modules/membros/components/formulario/SecaoDocumento";
import SecaoContato from "@/modules/membros/components/formulario/SecaoContato";
import SecaoEndereco from "@/modules/membros/components/formulario/SecaoEndereco";
import SecaoOutras from "@/modules/membros/components/formulario/SecaoOutras";

// Os outros arquivos continuam importando o tipo daqui
export type { SugestoesLocalidade };

interface FormularioMembroProps {
  membro: MembroPublico | null; // null = cadastrar; preenchido = editar
  cpfInicial: string | null; // CPF completo (só na edição e só para quem tem membros.cpf)
  cadastroInicial: CadastroMusical | null; // dados pessoais já gravados (só na edição; null = ainda sem cadastro)
  podeCpf: boolean; // permissão membros.cpf
  podeFoto: boolean; // permissão membros.foto (trocar a fotografia de um membro já cadastrado)
  podeDocumento: boolean; // permissão membros.cpf (ver o documento de identificação já anexado)
  cargos: Cargo[];
  instrumentos: Instrumento[];
  familias: Familia[];
  sugestoes: SugestoesLocalidade;
  carregando: boolean;
  erro: string | null;
  /** Chamado após salvar com sucesso, com a mensagem para o aviso da tela. */
  onSalvo: (mensagem: string) => void | Promise<void>;
}

export default function FormularioMembro({
  membro,
  cpfInicial,
  cadastroInicial,
  podeCpf,
  podeFoto,
  podeDocumento,
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
  const [casaOracaoId, setCasaOracaoId] = useState(membro?.casa_oracao_id ?? ""); // a casa de oração define o nome da congregação
  const [cidade, setCidade] = useState(membro?.cidade ?? "");
  const [bairro, setBairro] = useState(membro?.bairro ?? "");
  const [cpf, setCpf] = useState(cpfInicial ? formatarCpf(cpfInicial) : "");
  const [cargoId, setCargoId] = useState(membro?.cargo_id ?? "");
  const [dataNascimento, setDataNascimento] = useState(membro?.data_nascimento ?? ""); // "AAAA-MM-DD"
  const [instrumentoId, setInstrumentoId] = useState(membro?.instrumento_id ?? "");
  const [categoria, setCategoria] = useState(membro?.categoria ?? ""); // Oficializado, Culto Oficial ou RJM
  const [status, setStatus] = useState(membro?.status ?? "Ativo");
  const [foto, setFoto] = useState<Blob | null>(null); // foto nova já preparada (obrigatória no cadastro novo)
  const [docFrente, setDocFrente] = useState<Blob | null>(null); // imagem nova da frente do documento
  const [docVerso, setDocVerso] = useState<Blob | null>(null); // imagem nova do verso do documento
  const [statusCep, setStatusCep] = useState<StatusCep>(""); // andamento da consulta do endereço pelo CEP
  const ultimoCepConsultado = useRef(""); // evita consultar o mesmo CEP de novo e descarta resposta atrasada
  const [cadastro, setCadastro] = useState<CadastroMusical>(cadastroInicial ?? CADASTRO_VAZIO); // dados pessoais
  const [confirmandoRemocaoFoto, setConfirmandoRemocaoFoto] = useState(false);
  const [salvando, setSalvando] = useState(false);
  const [erroForm, setErroForm] = useState<string | null>(null);

  // Cargos do Cadastro Musical (Ancião, Diácono, Cooperadores e Secretário da Música não têm mais cadastro;
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
  // Cargo travado no Órgão (Organista, Examinadora, Instrutor, Instrutora): só os instrumentos Órgão aparecem
  const somenteOrgao = cargoSomenteOrgao(cargoSelecionado);
  const instrumentosDisponiveis = instrumentosDoCargo(instrumentos, somenteOrgao);
  // O instrumento é obrigatório nos cargos que o usam, no cadastro completo (e sempre nos cargos que exigem)
  const instrumentoObrigatorio = permiteInstrumento && (exigeInstrumento || completo);

  // Ao trocar de cargo, limpa o instrumento se o novo cargo não usar instrumento
  function trocarCargo(novoCargoId: string) {
    setCargoId(novoCargoId);
    const novoCargo = cargos.find((cargo) => cargo.id === novoCargoId);
    if (!novoCargo?.permite_instrumento) {
      setInstrumentoId("");
    } else if (cargoSomenteOrgao(novoCargo)) {
      // Cargo travado no Órgão: escolhe o Órgão sozinho (se só houver um) e tira um instrumento que não seja Órgão
      const orgaos = instrumentosDoCargo(instrumentos, true);
      setInstrumentoId((atual) => (orgaos.some((item) => item.id === atual) ? atual : orgaos.length === 1 ? orgaos[0].id : ""));
    }
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

  // "Batizado? Não" apaga a data do batismo (só quem é batizado tem data)
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

    // Cargo travado no Órgão: o instrumento precisa ser um dos Órgãos (o banco confere de novo)
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
      } else {
        // Cadastro novo: o identificador é gerado aqui para a foto subir para a pasta do próprio membro
        // antes do cadastro; o banco confere o arquivo e recusa o cadastro sem foto.
        const novoId = crypto.randomUUID();
        const caminho = await subirFotoNova(novoId, foto as Blob);
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
          await criarMembro({
            ...dados,
            id: novoId,
            foto_path: caminho,
            ...(podeCpf && cpfDigitos ? { cpf: cpfDigitos } : {}),
          });
        } catch (e) {
          await descartarFoto(caminho); // o cadastro falhou: não deixa a foto solta
          await descartarDocumentos(docsNovos);
          throw e;
        }
        try {
          await salvarCadastroMusical(novoId, cadastroNovo);
        } catch (e) {
          // O membro já existe: fecha o formulário (evita cadastrar duas vezes) e avisa o que faltou
          const motivo = e instanceof Error ? e.message : "erro desconhecido";
          await descartarDocumentos(docsNovos); // os documentos precisarão ser anexados de novo na edição
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

  return (
    <form onSubmit={salvar} className="space-y-6">
      {/* ---------- Fotografia ---------- */}
      <SecaoFotografia
        editando={editando}
        podeFoto={podeFoto}
        nome={nome}
        membro={membro}
        salvando={salvando}
        setFoto={setFoto}
        confirmandoRemocaoFoto={confirmandoRemocaoFoto}
        setConfirmandoRemocaoFoto={setConfirmandoRemocaoFoto}
        removerFotoAtual={removerFotoAtual}
      />

      {/* ---------- Identificação ---------- */}
      <SecaoIdentificacao
        editando={editando}
        podeCpf={podeCpf}
        completo={completo}
        nome={nome}
        setNome={setNome}
        cpf={cpf}
        setCpf={setCpf}
        dataNascimento={dataNascimento}
        setDataNascimento={setDataNascimento}
        salvando={salvando}
        cadastro={cadastro}
        mudar={mudar}
      />

      {/* ---------- Vínculo e função ---------- */}
      <SecaoCargo
        completo={completo}
        salvando={salvando}
        casaOracaoId={casaOracaoId}
        setCasaOracaoId={setCasaOracaoId}
        setCongregacao={setCongregacao}
        cargoId={cargoId}
        trocarCargo={trocarCargo}
        cargosDisponiveis={cargosDisponiveis}
        tipoCategoria={tipoCategoria}
        categoria={categoria}
        setCategoria={setCategoria}
        cargoSelecionado={cargoSelecionado}
        permiteInstrumento={permiteInstrumento}
        instrumentoObrigatorio={instrumentoObrigatorio}
        somenteOrgao={somenteOrgao}
        instrumentosDisponiveis={instrumentosDisponiveis}
        instrumentoId={instrumentoId}
        setInstrumentoId={setInstrumentoId}
        instrumentos={instrumentos}
        familias={familias}
        cadastro={cadastro}
        mudar={mudar}
        escolherBatizado={escolherBatizado}
      />

      {/* ---------- Cartão de identificação ---------- */}
      <SecaoCartao
        exigeCartao={exigeCartao}
        salvando={salvando}
        cadastro={cadastro}
        mudar={mudar}
      />

      {/* ---------- Documento de identificação ---------- */}
      <SecaoDocumento
        completo={completo}
        salvando={salvando}
        podeDocumento={podeDocumento}
        cadastro={cadastro}
        setDocFrente={setDocFrente}
        setDocVerso={setDocVerso}
      />

      {/* ---------- Contato ---------- */}
      <SecaoContato
        completo={completo}
        salvando={salvando}
        cadastro={cadastro}
        mudar={mudar}
        escolherWhatsapp={escolherWhatsapp}
      />

      {/* ---------- Endereço ---------- */}
      <SecaoEndereco
        completo={completo}
        salvando={salvando}
        cadastro={cadastro}
        mudar={mudar}
        statusCep={statusCep}
        mudarCep={mudarCep}
        cidade={cidade}
        setCidade={setCidade}
        bairro={bairro}
        setBairro={setBairro}
        sugestoes={sugestoes}
      />

      {/* ---------- Observação e situação ---------- */}
      <SecaoOutras
        editando={editando}
        salvando={salvando}
        cadastro={cadastro}
        mudar={mudar}
        status={status}
        setStatus={setStatus}
      />

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
  if "$@" > /tmp/divform-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/divform-passo.out
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
echo "Pronto. Confira o formulário de membro (cadastrar e editar) antes do git push."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
