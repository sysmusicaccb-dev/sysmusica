cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-destinos-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/modules/auditoria/regras.ts" "src/modules/backup/components/AbasBackup.tsx" "src/modules/backup/server/operacoes.ts")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  rm -rf "src/app/api/backup/destinos" "src/app/(painel)/administracao/backup/destinos"
  rm -f supabase/migrations/0022_backup_destinos.sql src/modules/backup/destinos.ts src/modules/backup/destinos.test.ts \
        src/modules/backup/assinatura.ts src/modules/backup/assinatura.test.ts \
        src/modules/backup/server/destinos.ts src/modules/backup/services/destinosApi.ts
  echo ">>> REVERTIDO. Me mande o log: /tmp/destinos-instalar.log"
}

echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, sys
NOVOS = {
  'supabase/migrations/0022_backup_destinos.sql': r"""-- =====================================================================
-- SysMúsica — Migração 0022: destinos do backup (hoje: "Servidor local" por túnel da Cloudflare)
--   * Tabela backup_destinos: uma linha por tipo de destino, com o endereço, os segredos CRIPTOGRAFADOS pela
--     aplicação (Client ID, Client Secret e chave de assinatura), se o envio automático está ligado e o resultado
--     do último envio. Ninguém (anon/authenticated) lê a tabela: só o servidor do sistema, com a chave secreta.
-- Requer a migração 0020. Idempotente, uma única transação.
-- Ao final, a migração TESTA que um tipo inválido é recusado e que anon/authenticated não têm acesso:
-- se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regclass('public.backup_arquivos') is null then
    raise exception 'Aplique primeiro a migração 0020 (backup).';
  end if;
end $$;

create table if not exists public.backup_destinos (
  id                    uuid primary key default gen_random_uuid(),
  tipo                  text not null unique check (tipo in ('servidor_local')),
  ativo                 boolean not null default false,
  endereco              text,
  config_cifrado        text,
  ultimo_envio_em       timestamptz,
  ultimo_envio_situacao text check (ultimo_envio_situacao in ('ok', 'falhou')),
  ultimo_envio_detalhe  text,
  atualizado_em         timestamptz not null default now(),
  atualizado_por        uuid
);

alter table public.backup_destinos enable row level security;
revoke all on public.backup_destinos from anon, authenticated;

-- VERIFICAÇÃO DE SEGURANÇA: se qualquer teste falhar, a migração INTEIRA é desfeita.
do $$
declare
  v_bloqueou boolean := false;
begin
  -- 1) um tipo inválido precisa ser recusado
  begin
    insert into public.backup_destinos (tipo) values ('xyz');
    raise exception 'sysmusica_sem_bloqueio';
  exception when others then
    if sqlstate = '23514' then
      v_bloqueou := true;
    elsif sqlerrm <> 'sysmusica_sem_bloqueio' then
      raise exception 'Verificação falhou (teste do tipo): %', sqlerrm;
    end if;
  end;
  if not v_bloqueou then
    raise exception 'Verificação falhou: o banco aceitou um tipo de destino inválido. Nada foi alterado.';
  end if;

  -- 2) usuários comuns não podem ler nem gravar a tabela
  if has_table_privilege('anon', 'public.backup_destinos', 'select')
     or has_table_privilege('authenticated', 'public.backup_destinos', 'select')
     or has_table_privilege('anon', 'public.backup_destinos', 'insert')
     or has_table_privilege('authenticated', 'public.backup_destinos', 'insert') then
    raise exception 'Verificação falhou: anon/authenticated ainda têm acesso a backup_destinos. Nada foi alterado.';
  end if;

  -- 3) a proteção por linha (RLS) precisa estar ligada
  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'backup_destinos' and c.relrowsecurity
  ) then
    raise exception 'Verificação falhou: a proteção por linha (RLS) não está ligada. Nada foi alterado.';
  end if;
end $$;

commit;
""",
  'src/modules/backup/destinos.ts': r"""/**
 * SysMúsica — Destinos do Backup: regras puras (sem acesso a banco nem a rede), compartilhadas entre a tela e o
 * servidor. Hoje existe um destino: o "Servidor local", um receptor que roda no Windows Server da casa do
 * administrador e é alcançado por um túnel da Cloudflare (sem porta aberta no roteador). O OneDrive desse servidor
 * sincroniza a pasta de destino; o sistema NÃO enxerga o OneDrive, só confirma que o servidor recebeu o arquivo.
 */

export type TipoDestino = "servidor_local";

/** Como o destino volta para a tela: segredos só aparecem mascarados ("…abcd"). */
export interface DestinoPublico {
  tipo: TipoDestino;
  configurado: boolean; // endereço, Client ID, Client Secret e chave de assinatura preenchidos
  ativo: boolean; // envio automático depois de cada backup verificado
  endereco: string;
  client_id_final: string;
  client_secret_final: string;
  chave_final: string;
  ultimo_envio_em: string | null;
  ultimo_envio_situacao: "ok" | "falhou" | null;
  ultimo_envio_detalhe: string | null;
  aviso_segredos: string | null; // preenchido quando os segredos salvos não abrem com a BACKUP_CHAVE atual
}

/** O que a tela envia ao salvar. Campo de segredo em branco = manter o valor salvo. */
export interface EntradaDestino {
  ativo: boolean;
  endereco: string;
  client_id: string;
  client_secret: string;
  chave_assinatura: string;
}

/** Quais segredos já existem salvos (para aceitar campo em branco). */
export interface SegredosSalvos {
  clientId: boolean;
  clientSecret: boolean;
  assinatura: boolean;
}

export interface ResultadoCopia {
  estado: "enviado" | "ja_existia" | "erro" | "desligado";
  detalhe?: string;
}

export const MIN_SEGREDO = 16;

export function formularioInicialDestino(destino: DestinoPublico): EntradaDestino {
  return { ativo: destino.ativo, endereco: destino.endereco, client_id: "", client_secret: "", chave_assinatura: "" };
}

/** Tira espaços e barras do final: "https://x.com.br/ " vira "https://x.com.br". */
export function normalizarEndereco(texto: string): string {
  return texto.trim().replace(/\/+$/, "");
}

/** Só aceita https com domínio (sem usuário, senha, caminho, parâmetros ou âncora). */
export function enderecoValido(texto: string): boolean {
  let url: URL;
  try {
    url = new URL(texto);
  } catch {
    return false;
  }
  return (
    url.protocol === "https:" &&
    url.hostname.includes(".") &&
    url.username === "" &&
    url.password === "" &&
    url.search === "" &&
    url.hash === "" &&
    url.pathname === "/"
  );
}

/** Devolve a mensagem de erro (para a tela) ou null se a entrada está boa. */
export function validarEntradaDestino(entrada: EntradaDestino, salvos: SegredosSalvos): string | null {
  const endereco = normalizarEndereco(entrada.endereco);
  const clientId = entrada.client_id.trim();
  const segredo = entrada.client_secret.trim();
  const assinatura = entrada.chave_assinatura.trim();

  if (endereco !== "" && !enderecoValido(endereco)) {
    return "O endereço precisa começar com https:// e ter só o domínio, por exemplo https://bkp.seudominio.com.br";
  }
  if (clientId !== "" && clientId.length < 8) {
    return "O Client ID parece curto demais. Copie-o inteiro do painel da Cloudflare.";
  }
  if (segredo !== "" && segredo.length < MIN_SEGREDO) {
    return "O Client Secret parece curto demais. Copie-o inteiro (ele só aparece uma vez no painel da Cloudflare).";
  }
  if (assinatura !== "" && assinatura.length < MIN_SEGREDO) {
    return `A chave de assinatura precisa ter pelo menos ${MIN_SEGREDO} caracteres. Copie-a inteira do arquivo segredo.txt do servidor.`;
  }

  if (entrada.ativo) {
    if (endereco === "") return "Informe o endereço do servidor para ligar o envio automático.";
    if (clientId === "" && !salvos.clientId) return "Informe o Client ID para ligar o envio automático.";
    if (segredo === "" && !salvos.clientSecret) return "Informe o Client Secret para ligar o envio automático.";
    if (assinatura === "" && !salvos.assinatura) return "Informe a chave de assinatura para ligar o envio automático.";
  }
  return null;
}

/** Lê o corpo recebido pela rota; devolve null se o formato estiver errado. */
export function lerEntradaDestino(valor: unknown): EntradaDestino | null {
  if (valor === null || typeof valor !== "object" || Array.isArray(valor)) return null;
  const o = valor as Record<string, unknown>;
  const texto = (campo: unknown, max: number): string | null =>
    typeof campo === "string" && campo.length <= max ? campo : null;

  const endereco = texto(o.endereco, 300);
  const clientId = texto(o.client_id, 300);
  const clientSecret = texto(o.client_secret, 600);
  const assinatura = texto(o.chave_assinatura, 600);
  if (typeof o.ativo !== "boolean" || endereco === null || clientId === null || clientSecret === null || assinatura === null) {
    return null;
  }
  return { ativo: o.ativo, endereco, client_id: clientId, client_secret: clientSecret, chave_assinatura: assinatura };
}

/** Padrão que o receptor do servidor aceita para o nome do arquivo. */
export const NOME_REMOTO_VALIDO = /^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$/;

/** Nome do arquivo no servidor: só o final do caminho, com caracteres seguros (o sufixo único é preservado). */
export function nomeRemoto(caminho: string): string {
  const base = (caminho.split("/").pop() ?? "").replace(/[^A-Za-z0-9._-]/g, "-");
  const nome = (base.length > 120 ? base.slice(-120) : base).replace(/^[^A-Za-z0-9]+/, "");
  return nome === "" ? "backup.sysbk" : nome;
}

/** Linha que entra no aviso de sucesso do backup (nulo = destino desligado, nada a dizer). */
export function linhaDoAviso(resultado: ResultadoCopia): string | null {
  switch (resultado.estado) {
    case "enviado":
      return "Cópia no servidor local: enviada e conferida (a impressão digital confere). A sincronização com o OneDrive é feita pelo próprio servidor.";
    case "ja_existia":
      return "Cópia no servidor local: o arquivo já estava lá.";
    case "erro":
      return `Cópia no servidor local: FALHOU (${resultado.detalhe ?? "motivo desconhecido"}). O backup continua válido no sistema.`;
    default:
      return null;
  }
}
""",
  'src/modules/backup/destinos.test.ts': r"""import { describe, expect, it } from "vitest";
import {
  enderecoValido,
  lerEntradaDestino,
  linhaDoAviso,
  NOME_REMOTO_VALIDO,
  nomeRemoto,
  normalizarEndereco,
  validarEntradaDestino,
  type EntradaDestino,
} from "./destinos";

const nada = { clientId: false, clientSecret: false, assinatura: false };
const tudo = { clientId: true, clientSecret: true, assinatura: true };
const entrada = (parcial: Partial<EntradaDestino> = {}): EntradaDestino => ({
  ativo: false,
  endereco: "",
  client_id: "",
  client_secret: "",
  chave_assinatura: "",
  ...parcial,
});

describe("endereço", () => {
  it("normaliza espaços e barras finais", () => {
    expect(normalizarEndereco("  https://bkp.exemplo.com.br/// ")).toBe("https://bkp.exemplo.com.br");
  });
  it("aceita só https com domínio e sem caminho", () => {
    expect(enderecoValido("https://bkp-sysmusicaccb.2atelecom.net.br")).toBe(true);
    expect(enderecoValido("http://bkp.exemplo.com.br")).toBe(false);
    expect(enderecoValido("https://localhost")).toBe(false);
    expect(enderecoValido("https://usuario:senha@bkp.exemplo.com.br")).toBe(false);
    expect(enderecoValido("https://bkp.exemplo.com.br/caminho")).toBe(false);
    expect(enderecoValido("https://bkp.exemplo.com.br?x=1")).toBe(false);
    expect(enderecoValido("isto não é um endereço")).toBe(false);
  });
});

describe("validarEntradaDestino", () => {
  it("aceita formulário vazio desligado", () => {
    expect(validarEntradaDestino(entrada(), nada)).toBeNull();
  });
  it("recusa endereço ruim, mesmo desligado", () => {
    expect(validarEntradaDestino(entrada({ endereco: "http://x.com.br" }), nada)).toMatch(/https/);
  });
  it("recusa segredos curtos demais", () => {
    expect(validarEntradaDestino(entrada({ client_id: "abc" }), nada)).toMatch(/Client ID/);
    expect(validarEntradaDestino(entrada({ client_secret: "curto" }), nada)).toMatch(/Client Secret/);
    expect(validarEntradaDestino(entrada({ chave_assinatura: "curta" }), nada)).toMatch(/chave de assinatura/);
  });
  it("para ligar exige tudo, contando o que já está salvo", () => {
    const ligado = entrada({ ativo: true, endereco: "https://bkp.exemplo.com.br" });
    expect(validarEntradaDestino(ligado, nada)).toMatch(/Client ID/);
    expect(validarEntradaDestino({ ...ligado, client_id: "12345678.access" }, nada)).toMatch(/Client Secret/);
    expect(
      validarEntradaDestino({ ...ligado, client_id: "12345678.access", client_secret: "x".repeat(20) }, nada)
    ).toMatch(/chave de assinatura/);
    expect(validarEntradaDestino(ligado, tudo)).toBeNull(); // campos em branco mantêm o que está salvo
  });
  it("para ligar exige o endereço", () => {
    expect(validarEntradaDestino(entrada({ ativo: true }), tudo)).toMatch(/endereço/);
  });
});

describe("lerEntradaDestino", () => {
  it("lê um corpo válido e recusa formatos errados", () => {
    const ok = { ativo: true, endereco: "https://a.b.com", client_id: "", client_secret: "", chave_assinatura: "" };
    expect(lerEntradaDestino(ok)).toEqual(ok);
    expect(lerEntradaDestino(null)).toBeNull();
    expect(lerEntradaDestino([])).toBeNull();
    expect(lerEntradaDestino({ ...ok, ativo: "sim" })).toBeNull();
    expect(lerEntradaDestino({ ...ok, endereco: 5 })).toBeNull();
    expect(lerEntradaDestino({ ...ok, client_secret: "x".repeat(601) })).toBeNull();
  });
});

describe("nomeRemoto", () => {
  it("usa só o final do caminho e caracteres seguros", () => {
    expect(nomeRemoto("2026/10/manual-20261018-abc.sysbk")).toBe("manual-20261018-abc.sysbk");
    expect(nomeRemoto("pasta/arquivo com espaço.sysbk")).toBe("arquivo-com-espa-o.sysbk");
  });
  it("sempre gera um nome que o receptor aceita", () => {
    for (const caminho of ["../../etc/passwd", "...", "-x", "a/b/" + "z".repeat(300), "", "ç/ç"]) {
      expect(nomeRemoto(caminho)).toMatch(NOME_REMOTO_VALIDO);
    }
    expect(nomeRemoto("a/" + "z".repeat(300) + "-fim")).toMatch(/-fim$/); // o final (sufixo único) é preservado
  });
});

describe("linhaDoAviso", () => {
  it("descreve cada resultado", () => {
    expect(linhaDoAviso({ estado: "enviado" })).toMatch(/enviada e conferida/);
    expect(linhaDoAviso({ estado: "ja_existia" })).toMatch(/já estava/);
    expect(linhaDoAviso({ estado: "erro", detalhe: "túnel fora" })).toMatch(/FALHOU \(túnel fora\)/);
    expect(linhaDoAviso({ estado: "desligado" })).toBeNull();
  });
});
""",
  'src/modules/backup/assinatura.ts': r"""/**
 * SysMúsica — Assinatura dos envios ao servidor local (só roda no SERVIDOR do sistema).
 * O receptor do Windows Server confere esta mesma conta: HMAC-SHA256, chave = texto da chave de assinatura (UTF-8),
 * mensagem = "timestamp \n nome-do-arquivo \n sha256". Quem não tem a chave não consegue enviar nem repetir um envio
 * antigo (o receptor aceita no máximo 5 minutos de diferença no relógio e nunca sobrescreve um arquivo).
 */
import { createHmac } from "node:crypto";

export function assinarEnvio(chaveAssinatura: string, timestamp: string, nome: string, sha256: string): string {
  return createHmac("sha256", Buffer.from(chaveAssinatura, "utf8"))
    .update(`${timestamp}\n${nome}\n${sha256}`, "utf8")
    .digest("hex");
}
""",
  'src/modules/backup/assinatura.test.ts': r"""import { describe, expect, it } from "vitest";
import { assinarEnvio } from "./assinatura";

describe("assinarEnvio", () => {
  it("gera a assinatura esperada (mesma conta do receptor do servidor)", () => {
    expect(assinarEnvio("segredo-de-teste-1234567890", "1760000000", "manual-2026.sysbk", "a".repeat(64))).toBe(
      "621224994a7bed36ab669d52e782f52b4123f74e28f626d3227c85e8aefe8cb5"
    );
  });

  it("muda se qualquer parte mudar", () => {
    const base = assinarEnvio("segredo-de-teste-1234567890", "1760000000", "a.sysbk", "b".repeat(64));
    expect(assinarEnvio("outra-chave-de-teste-123456", "1760000000", "a.sysbk", "b".repeat(64))).not.toBe(base);
    expect(assinarEnvio("segredo-de-teste-1234567890", "1760000001", "a.sysbk", "b".repeat(64))).not.toBe(base);
    expect(assinarEnvio("segredo-de-teste-1234567890", "1760000000", "b.sysbk", "b".repeat(64))).not.toBe(base);
    expect(assinarEnvio("segredo-de-teste-1234567890", "1760000000", "a.sysbk", "c".repeat(64))).not.toBe(base);
  });
});
""",
  'src/modules/backup/server/destinos.ts': r"""/**
 * SysMúsica — Destino "Servidor local" do Backup, no servidor do sistema: salvar a configuração, testar a conexão e
 * enviar o arquivo (já criptografado) pelo túnel da Cloudflare até o receptor do Windows Server.
 *
 * SEGURANÇA, em três camadas:
 *  1) Cloudflare Access: só quem tem o token de serviço (Client ID + Client Secret) chega ao receptor.
 *  2) Assinatura HMAC com horário (assinatura.ts): sem a chave de assinatura, o receptor recusa e não aceita repetição.
 *  3) O arquivo já viaja criptografado com a BACKUP_CHAVE e o receptor devolve o SHA-256, que o sistema confere.
 * Client ID, Client Secret e chave de assinatura ficam criptografados no banco (BACKUP_CHAVE) e nunca voltam inteiros
 * para a tela. Nada aqui derruba o backup: uma falha na cópia vira aviso, e o backup continua válido no sistema.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { assinarEnvio } from "../assinatura";
import { abrirSegredo, cifrarSegredo, lerChave, mascararSegredo, sha256Hex } from "../cripto";
import {
  linhaDoAviso,
  nomeRemoto,
  normalizarEndereco,
  validarEntradaDestino,
  type DestinoPublico,
  type EntradaDestino,
  type ResultadoCopia,
  type TipoDestino,
} from "../destinos";
import { dataHoraSalvador } from "../regras";
import type { UsuarioAutenticado } from "./autorizacao";
import { clienteAdmin } from "./clienteAdmin";
import { ErroBackup } from "./erros";
import { notificar } from "./notificar";

const BUCKET = "backups";
const TIPO: TipoDestino = "servidor_local";
const COLUNAS = "ativo, endereco, config_cifrado, ultimo_envio_em, ultimo_envio_situacao, ultimo_envio_detalhe";

interface LinhaDestino {
  ativo: boolean;
  endereco: string | null;
  config_cifrado: string | null;
  ultimo_envio_em: string | null;
  ultimo_envio_situacao: "ok" | "falhou" | null;
  ultimo_envio_detalhe: string | null;
}

// Segredos já abertos. "assinatura" é a chave de assinatura (não confundir com a BACKUP_CHAVE).
interface Segredos {
  client_id: string;
  client_secret: string;
  assinatura: string;
  ilegivel: boolean; // os dados salvos não abriram com a BACKUP_CHAVE atual
}

interface ConfigDestino {
  endereco: string;
  clientId: string;
  clientSecret: string;
  assinatura: string;
}

function chaveDoAmbiente(): Buffer {
  try {
    return lerChave(process.env.BACKUP_CHAVE);
  } catch (e) {
    throw new ErroBackup(500, e instanceof Error ? e.message : "A chave dos backups não está configurada.");
  }
}

const texto = (valor: unknown): string => (typeof valor === "string" ? valor : "");

// Mensagem de erro sem nenhum segredo dentro
function mensagemSegura(erro: unknown, segredos: string[]): string {
  let mensagem = erro instanceof Error ? erro.message : "erro desconhecido";
  for (const segredo of segredos) {
    if (segredo.length >= 4) mensagem = mensagem.split(segredo).join("***");
  }
  return mensagem.slice(0, 300);
}

async function lerLinha(admin: SupabaseClient): Promise<LinhaDestino | null> {
  const { data, error } = await admin.from("backup_destinos").select(COLUNAS).eq("tipo", TIPO).maybeSingle();
  if (error) throw new ErroBackup(500, "Não foi possível ler a configuração do destino. A migração 0022 foi aplicada?");
  return (data as unknown as LinhaDestino | null) ?? null;
}

function lerSegredos(linha: LinhaDestino | null, chave: Buffer): Segredos {
  const vazio: Segredos = { client_id: "", client_secret: "", assinatura: "", ilegivel: false };
  if (!linha?.config_cifrado) return vazio;
  try {
    const bruto: unknown = JSON.parse(abrirSegredo(linha.config_cifrado, chave));
    if (bruto === null || typeof bruto !== "object" || Array.isArray(bruto)) return { ...vazio, ilegivel: true };
    const o = bruto as Record<string, unknown>;
    return { client_id: texto(o.client_id), client_secret: texto(o.client_secret), assinatura: texto(o.assinatura), ilegivel: false };
  } catch {
    return { ...vazio, ilegivel: true };
  }
}

// Configuração completa e pronta para usar (nulo = incompleta ou ilegível)
function configCompleta(linha: LinhaDestino | null, segredos: Segredos): ConfigDestino | null {
  if (!linha?.endereco || !segredos.client_id || !segredos.client_secret || !segredos.assinatura) return null;
  return { endereco: linha.endereco, clientId: segredos.client_id, clientSecret: segredos.client_secret, assinatura: segredos.assinatura };
}

// Registra na Auditoria; uma falha aqui nunca derruba a operação
async function auditar(
  admin: SupabaseClient,
  usuarioId: string | null,
  acao: string,
  entidadeId: string | null,
  detalhes: Record<string, unknown>
): Promise<void> {
  const { error } = await admin
    .from("auditoria")
    .insert({ usuario_id: usuarioId, acao, entidade: "backup", entidade_id: entidadeId, detalhes });
  if (error) console.error("Falha ao registrar a auditoria do destino do backup:", error.message);
}

// ---------- Ler e salvar ----------

export async function lerDestinoPublico(): Promise<DestinoPublico> {
  const admin = clienteAdmin();
  const linha = await lerLinha(admin);
  const segredos = lerSegredos(linha, chaveDoAmbiente());
  return {
    tipo: TIPO,
    configurado: configCompleta(linha, segredos) !== null,
    ativo: linha?.ativo ?? false,
    endereco: linha?.endereco ?? "",
    client_id_final: segredos.client_id ? mascararSegredo(segredos.client_id) : "",
    client_secret_final: segredos.client_secret ? mascararSegredo(segredos.client_secret) : "",
    chave_final: segredos.assinatura ? mascararSegredo(segredos.assinatura) : "",
    ultimo_envio_em: linha?.ultimo_envio_em ?? null,
    ultimo_envio_situacao: linha?.ultimo_envio_situacao ?? null,
    ultimo_envio_detalhe: linha?.ultimo_envio_detalhe ?? null,
    aviso_segredos: segredos.ilegivel
      ? "Os dados salvos deste destino não abrem com a BACKUP_CHAVE atual. Preencha os três campos secretos de novo e salve."
      : null,
  };
}

export async function salvarDestino(entrada: EntradaDestino, usuario: UsuarioAutenticado): Promise<DestinoPublico> {
  const admin = clienteAdmin();
  const chave = chaveDoAmbiente();
  const linha = await lerLinha(admin);
  const atuais = lerSegredos(linha, chave);

  const erro = validarEntradaDestino(entrada, {
    clientId: atuais.client_id !== "",
    clientSecret: atuais.client_secret !== "",
    assinatura: atuais.assinatura !== "",
  });
  if (erro) throw new ErroBackup(400, erro);

  const endereco = normalizarEndereco(entrada.endereco);
  const novos = {
    client_id: entrada.client_id.trim() || atuais.client_id,
    client_secret: entrada.client_secret.trim() || atuais.client_secret,
    assinatura: entrada.chave_assinatura.trim() || atuais.assinatura,
  };

  // Só os NOMES dos campos que mudaram vão para a Auditoria (nunca os valores)
  const alterados: string[] = [];
  if (entrada.ativo !== (linha?.ativo ?? false)) alterados.push("envio_automatico");
  if (endereco !== (linha?.endereco ?? "")) alterados.push("endereco");
  if (entrada.client_id.trim() !== "") alterados.push("client_id");
  if (entrada.client_secret.trim() !== "") alterados.push("client_secret");
  if (entrada.chave_assinatura.trim() !== "") alterados.push("chave_assinatura");

  const { error } = await admin.from("backup_destinos").upsert(
    {
      tipo: TIPO,
      ativo: entrada.ativo,
      endereco: endereco === "" ? null : endereco,
      config_cifrado: cifrarSegredo(JSON.stringify(novos), chave),
      atualizado_em: new Date().toISOString(),
      atualizado_por: usuario.id,
    },
    { onConflict: "tipo" }
  );
  if (error) throw new ErroBackup(500, "Não foi possível salvar o destino do backup.");

  if (alterados.length > 0) await auditar(admin, usuario.id, "backup_destino_alterado", null, { destino: TIPO, alterados });
  return lerDestinoPublico();
}

// ---------- Conversa com o receptor ----------

interface RespostaServidor {
  status: number;
  ok: boolean;
  json: Record<string, unknown> | null;
}

async function chamar(
  config: ConfigDestino,
  metodo: "GET" | "PUT",
  caminho: string,
  opcoes: { headers?: Record<string, string>; corpo?: BodyInit; limiteMs: number }
): Promise<RespostaServidor> {
  let resposta: Response;
  try {
    resposta = await fetch(`${config.endereco}${caminho}`, {
      method: metodo,
      headers: {
        "CF-Access-Client-Id": config.clientId,
        "CF-Access-Client-Secret": config.clientSecret,
        ...opcoes.headers,
      },
      body: opcoes.corpo,
      redirect: "manual", // um redirecionamento é a Cloudflare pedindo login: tratamos como acesso recusado
      cache: "no-store",
      signal: AbortSignal.timeout(opcoes.limiteMs),
    });
  } catch (e) {
    throw new Error(
      `não foi possível falar com o servidor (${mensagemSegura(e, [config.clientId, config.clientSecret, config.assinatura])})`
    );
  }
  const tipo = resposta.headers.get("content-type") ?? "";
  const json = tipo.includes("json") ? ((await resposta.json().catch(() => null)) as Record<string, unknown> | null) : null;
  return { status: resposta.status, ok: resposta.ok, json };
}

// Traduz a resposta de erro em uma frase que o administrador entende
function explicar(resposta: RespostaServidor): string {
  const erro = typeof resposta.json?.erro === "string" ? resposta.json.erro : null;
  if (erro === "assinatura") {
    return "o servidor recusou a assinatura: a chave de assinatura salva aqui é diferente da que está no arquivo segredo.txt do servidor";
  }
  if (erro === "timestamp") return "o relógio do servidor está diferente do relógio do sistema (mais de 5 minutos de diferença)";
  if (erro === "sha256 diferente") return "o arquivo chegou diferente do enviado (conexão instável); tente de novo";
  if (erro) return `o servidor respondeu: ${erro}`;
  if (resposta.status === 302 || resposta.status === 401 || resposta.status === 403) {
    return "a Cloudflare recusou o acesso: confira o Client ID, o Client Secret e se a política do aplicativo aceita o token de serviço";
  }
  if ([502, 503, 504, 530].includes(resposta.status)) {
    return "o túnel ou o receptor não está respondendo (servidor desligado, túnel desconectado ou receptor parado)";
  }
  if (resposta.status === 413) return "o arquivo é grande demais para passar pelo túnel";
  return `resposta inesperada do servidor (código ${resposta.status})`;
}

// Envia um arquivo assinado e confere a impressão digital devolvida
async function enviarArquivo(config: ConfigDestino, nome: string, dados: Buffer, sha256: string): Promise<"enviado" | "ja_existia"> {
  const horario = String(Math.floor(Date.now() / 1000));
  const resposta = await chamar(config, "PUT", `/backup/${encodeURIComponent(nome)}`, {
    headers: {
      "Content-Type": "application/octet-stream",
      "X-Sys-Timestamp": horario,
      "X-Sys-Sha256": sha256,
      "X-Sys-Assinatura": assinarEnvio(config.assinatura, horario, nome, sha256),
    },
    corpo: new Uint8Array(dados),
    limiteMs: 40_000,
  });

  if (resposta.status === 409) return "ja_existia"; // o receptor nunca sobrescreve
  if (!resposta.ok || resposta.json?.ok !== true) throw new Error(explicar(resposta));
  if (resposta.json.sha256 !== sha256 || Number(resposta.json.bytes) !== dados.length) {
    throw new Error("o servidor confirmou um arquivo diferente do enviado (a impressão digital não confere)");
  }
  return "enviado";
}

// ---------- Testar ----------

/** Testa a configuração JÁ SALVA: alcança o receptor e envia um arquivo pequeno de teste, assinado. */
export async function testarDestino(usuario: UsuarioAutenticado): Promise<{ detalhe: string }> {
  const admin = clienteAdmin();
  const linha = await lerLinha(admin);
  const config = configCompleta(linha, lerSegredos(linha, chaveDoAmbiente()));
  if (!config) throw new ErroBackup(400, "Salve o endereço, o Client ID, o Client Secret e a chave de assinatura antes de testar.");
  const segredos = [config.clientId, config.clientSecret, config.assinatura];

  try {
    const saude = await chamar(config, "GET", "/saude", { limiteMs: 15_000 });
    if (!saude.ok || saude.json?.ok !== true) throw new Error(explicar(saude));

    const nome = `teste-conexao-${Math.floor(Date.now() / 1000)}.txt`;
    const conteudo = Buffer.from(`Teste de conexão do SysMúsica em ${dataHoraSalvador(new Date())}\n`, "utf8");
    await enviarArquivo(config, nome, conteudo, sha256Hex(conteudo));
    await auditar(admin, usuario.id, "backup_destino_testado", null, { destino: TIPO, resultado: "ok" });
    return {
      detalhe: `Conexão confirmada: o servidor aceitou e gravou o arquivo de teste ${nome}. Você pode apagá-lo da pasta BACKUPS.`,
    };
  } catch (e) {
    await auditar(admin, usuario.id, "backup_destino_testado", null, { destino: TIPO, resultado: "falhou" });
    throw new ErroBackup(502, `O teste falhou: ${mensagemSegura(e, segredos)}`);
  }
}

// ---------- Copiar um backup ----------

// Copia um backup para o servidor, grava o resultado (backup, destino e Auditoria) e avisa se falhar. Nunca lança erro.
async function executarCopia(
  admin: SupabaseClient,
  id: string,
  usuarioId: string | null,
  origem: "automatico" | "manual",
  config: ConfigDestino
): Promise<ResultadoCopia> {
  let resultado: ResultadoCopia;
  let destinosAtuais: Record<string, boolean> | null = null;
  try {
    const { data } = await admin.from("backup_arquivos").select("situacao, caminho, sha256, destinos").eq("id", id).maybeSingle();
    const linha = data as { situacao: string; caminho: string | null; sha256: string | null; destinos: Record<string, boolean> | null } | null;
    if (!linha || linha.situacao !== "ok" || !linha.caminho || !linha.sha256) {
      throw new Error("este backup não tem um arquivo válido para copiar");
    }
    destinosAtuais = linha.destinos ?? {};

    const baixado = await admin.storage.from(BUCKET).download(linha.caminho);
    if (baixado.error || !baixado.data) throw new Error("não foi possível ler o arquivo do backup no armazenamento");
    const arquivo = Buffer.from(await baixado.data.arrayBuffer());
    if (sha256Hex(arquivo) !== linha.sha256) {
      throw new Error("o arquivo guardado no sistema não confere com a impressão digital registrada");
    }

    resultado = { estado: await enviarArquivo(config, nomeRemoto(linha.caminho), arquivo, linha.sha256) };
  } catch (e) {
    resultado = { estado: "erro", detalhe: mensagemSegura(e, [config.clientId, config.clientSecret, config.assinatura]) };
  }

  const deu = resultado.estado === "enviado" || resultado.estado === "ja_existia";
  if (destinosAtuais !== null) {
    const { error } = await admin.from("backup_arquivos").update({ destinos: { ...destinosAtuais, [TIPO]: deu } }).eq("id", id);
    if (error) console.error("Falha ao gravar o destino do backup:", error.message);
  }
  const { error } = await admin
    .from("backup_destinos")
    .update({
      ultimo_envio_em: new Date().toISOString(),
      ultimo_envio_situacao: deu ? "ok" : "falhou",
      ultimo_envio_detalhe: deu ? null : (resultado.detalhe ?? null),
    })
    .eq("tipo", TIPO);
  if (error) console.error("Falha ao gravar o último envio do destino:", error.message);

  await auditar(admin, usuarioId, "backup_copiado_destino", id, {
    destino: TIPO,
    origem,
    resultado: resultado.estado,
    ...(deu ? {} : { motivo: resultado.detalhe ?? null }),
  });

  if (!deu) {
    await notificar("falha", {
      assunto: "SysMúsica: a cópia do backup para o servidor local falhou",
      texto:
        `Quando: ${dataHoraSalvador(new Date())}\n` +
        `O backup foi feito, mas não foi copiado para o servidor local.\nMotivo: ${resultado.detalhe ?? "desconhecido"}\n` +
        `O arquivo continua guardado e válido no sistema. Resolva o problema e use "Enviar o backup mais recente agora" na aba Destinos.`,
    });
  }
  return resultado;
}

/**
 * Cópia automática, chamada logo depois de um backup verificado. Se o envio automático está desligado devolve
 * "desligado". NUNCA lança erro (nem se a migração 0022 ainda não foi aplicada): o backup não pode falhar por isso.
 */
export async function enviarAutomatico(admin: SupabaseClient, id: string): Promise<ResultadoCopia> {
  try {
    const linha = await lerLinha(admin);
    if (!linha?.ativo) return { estado: "desligado" };
    const config = configCompleta(linha, lerSegredos(linha, chaveDoAmbiente()));
    if (!config) {
      const resultado: ResultadoCopia = {
        estado: "erro",
        detalhe: "o envio automático está ligado, mas a configuração está incompleta ou não abre com a chave atual",
      };
      await notificar("falha", {
        assunto: "SysMúsica: a cópia do backup para o servidor local falhou",
        texto: `Motivo: ${resultado.detalhe}.\nO backup continua válido no sistema. Confira a aba Destinos.`,
      });
      return resultado;
    }
    return await executarCopia(admin, id, null, "automatico", config);
  } catch (e) {
    console.error("Falha na cópia automática do backup:", e);
    return { estado: "desligado" };
  }
}

/** Botão "Enviar o backup mais recente agora" (funciona mesmo com o envio automático desligado). */
export async function enviarMaisRecente(usuario: UsuarioAutenticado): Promise<{ detalhe: string }> {
  const admin = clienteAdmin();
  const linha = await lerLinha(admin);
  const config = configCompleta(linha, lerSegredos(linha, chaveDoAmbiente()));
  if (!config) throw new ErroBackup(400, "Salve o endereço, o Client ID, o Client Secret e a chave de assinatura antes de enviar.");

  const { data } = await admin
    .from("backup_arquivos")
    .select("id")
    .eq("situacao", "ok")
    .order("criado_em", { ascending: false })
    .limit(1)
    .maybeSingle();
  const id = (data as { id: string } | null)?.id;
  if (!id) throw new ErroBackup(400, "Ainda não existe nenhum backup para enviar. Faça um backup primeiro.");

  const resultado = await executarCopia(admin, id, usuario.id, "manual", config);
  if (resultado.estado === "erro") throw new ErroBackup(502, `Não foi possível enviar: ${resultado.detalhe ?? "motivo desconhecido"}`);
  return {
    detalhe:
      resultado.estado === "ja_existia"
        ? "O backup mais recente já estava no servidor local."
        : "Backup mais recente copiado para o servidor local e conferido. O OneDrive do servidor sincroniza em seguida.",
  };
}

/** Acrescenta ao aviso de sucesso do backup uma linha dizendo como ficou a cópia no servidor local. */
export function acrescentarCopia(
  copia: ResultadoCopia | null,
  mensagem: { assunto: string; texto: string }
): { assunto: string; texto: string } {
  const linha = copia ? linhaDoAviso(copia) : null;
  return linha ? { ...mensagem, texto: `${mensagem.texto}\n\n${linha}` } : mensagem;
}
""",
  'src/modules/backup/services/destinosApi.ts': r"""/**
 * SysMúsica — Chamadas do navegador às rotas /api/backup/destinos. Cada chamada leva o token do login (o servidor
 * confere a sessão e a permissão). Client Secret e chave de assinatura só trafegam daqui para o servidor, ao salvar;
 * nada secreto volta na resposta.
 */
import { supabase } from "@/lib/supabase";
import type { DestinoPublico, EntradaDestino } from "../destinos";

async function chamar<T>(caminho: string, metodo: "GET" | "POST" | "PUT", corpo?: unknown): Promise<T> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error("Sua sessão expirou. Entre de novo.");

  const resposta = await fetch(caminho, {
    method: metodo,
    headers: { Authorization: `Bearer ${token}`, ...(corpo !== undefined ? { "Content-Type": "application/json" } : {}) },
    body: corpo !== undefined ? JSON.stringify(corpo) : undefined,
    cache: "no-store",
  });
  const json = (await resposta.json().catch(() => null)) as { erro?: string } | null;
  if (!resposta.ok) throw new Error(json?.erro ?? "Não foi possível concluir a operação.");
  return json as T;
}

export async function obterDestino(): Promise<DestinoPublico> {
  return (await chamar<{ destino: DestinoPublico }>("/api/backup/destinos", "GET")).destino;
}

export async function salvarDestino(entrada: EntradaDestino): Promise<DestinoPublico> {
  return (await chamar<{ destino: DestinoPublico }>("/api/backup/destinos", "PUT", entrada)).destino;
}

export function testarDestino(): Promise<{ detalhe: string }> {
  return chamar<{ detalhe: string }>("/api/backup/destinos/testar", "POST");
}

export function enviarMaisRecente(): Promise<{ detalhe: string }> {
  return chamar<{ detalhe: string }>("/api/backup/destinos/enviar", "POST");
}
""",
  'src/app/api/backup/destinos/route.ts': r"""/**
 * SysMúsica — Rotas /api/backup/destinos: GET lê o destino (segredos só mascarados); PUT salva.
 * Só o Administrador entra (backup.configurar, conferida no banco a cada chamada).
 * Não usamos "runtime" nem "dynamic": o projeto usa cacheComponents, que não aceita essas opções.
 */
import type { NextRequest } from "next/server";
import { lerEntradaDestino } from "@/modules/backup/destinos";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { lerDestinoPublico, salvarDestino } from "@/modules/backup/server/destinos";
import { ErroBackup } from "@/modules/backup/server/erros";
import { responder } from "@/modules/backup/server/rota";

export async function GET(request: NextRequest) {
  return responder(async () => {
    await autenticar(request, "backup.configurar");
    return { destino: await lerDestinoPublico() };
  });
}

export async function PUT(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.configurar");
    const entrada = lerEntradaDestino(await request.json().catch(() => null));
    if (!entrada) throw new ErroBackup(400, "Os dados enviados estão em um formato inválido.");
    return { destino: await salvarDestino(entrada, usuario) };
  });
}
""",
  'src/app/api/backup/destinos/testar/route.ts': r"""/** SysMúsica — POST /api/backup/destinos/testar: testa o destino JÁ SALVO (alcança o receptor e envia um arquivo de teste). */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { testarDestino } from "@/modules/backup/server/destinos";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 60;

export async function POST(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.configurar");
    return await testarDestino(usuario);
  });
}
""",
  'src/app/api/backup/destinos/enviar/route.ts': r"""/** SysMúsica — POST /api/backup/destinos/enviar: copia o backup mais recente para o servidor local agora. */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { enviarMaisRecente } from "@/modules/backup/server/destinos";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 60;

export async function POST(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.criar");
    return await enviarMaisRecente(usuario);
  });
}
""",
  'src/app/(painel)/administracao/backup/destinos/page.tsx': r""""use client";

/**
 * SysMúsica — Página /administracao/backup/destinos (só o Administrador): para onde vai a cópia dos backups.
 * Cada destino é um cartão que se abre ao clicar (evita poluir a tela). Hoje o único ativo é o "Servidor local",
 * alcançado por um túnel da Cloudflare. Segredos só são enviados ao servidor ao salvar, ficam criptografados e
 * nunca voltam para a tela. Campo secreto em branco = manter o valor atual. Os botões usam a configuração JÁ SALVA.
 */
import { useCallback, useEffect, useState, type ReactNode } from "react";
import ErrorState from "@/components/ui/ErrorState";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import AbasBackup from "@/modules/backup/components/AbasBackup";
import { formularioInicialDestino, type DestinoPublico, type EntradaDestino } from "@/modules/backup/destinos";
import { dataHoraSalvador } from "@/modules/backup/regras";
import { enviarMaisRecente, obterDestino, salvarDestino, testarDestino } from "@/modules/backup/services/destinosApi";

const classeCampo =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm placeholder:text-slate-400 " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60";
const classeBotao =
  "inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium " +
  "text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";
const classeBotaoPrimario =
  "inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm " +
  "transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-60";
const classeCaixa = "h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300";

function Campo({ id, rotulo, dica, children }: { id: string; rotulo: string; dica?: string; children: ReactNode }) {
  return (
    <div className="space-y-1.5">
      <label htmlFor={id} className="text-xs font-medium text-slate-600">
        {rotulo}
      </label>
      {children}
      {dica && <p className="text-xs text-slate-500">{dica}</p>}
    </div>
  );
}

function Selo({ cor, children }: { cor: "verde" | "cinza" | "ambar"; children: ReactNode }) {
  const classes = {
    verde: "bg-emerald-50 text-emerald-700",
    cinza: "bg-slate-100 text-slate-600",
    ambar: "bg-amber-50 text-amber-700",
  }[cor];
  return <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${classes}`}>{children}</span>;
}

// Destinos que ainda não existem: aparecem desabilitados para o administrador saber o que vem por aí
const EM_BREVE: { titulo: string; texto: string }[] = [
  {
    titulo: "OneDrive (API da Microsoft)",
    texto: "Indisponível nesta organização: exige autorização do administrador do Microsoft 365. O OneDrive já é alcançado pelo Servidor local.",
  },
  { titulo: "FTP / SFTP", texto: "Envio para um servidor de arquivos próprio ou contratado." },
  { titulo: "Google Drive", texto: "Envio para uma pasta do Google Drive." },
  { titulo: "Armazenamento S3 (Cloudflare R2, Backblaze B2)", texto: "Cópia em nuvem de baixo custo, independente do servidor da casa." },
];

export default function DestinosBackupPage() {
  const [destino, setDestino] = useState<DestinoPublico | null>(null);
  const [form, setForm] = useState<EntradaDestino | null>(null);
  const [alterado, setAlterado] = useState(false); // há mudanças ainda não salvas
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [ocupado, setOcupado] = useState<string | null>(null);
  const [erroAcao, setErroAcao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  const [aberto, setAberto] = useState(true);

  const carregar = useCallback(async () => {
    try {
      const dados = await obterDestino();
      setDestino(dados);
      setForm(formularioInicialDestino(dados));
      setAlterado(false);
      setErro(null);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível carregar o destino.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona). Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  function mudar(parcial: Partial<EntradaDestino>) {
    setForm((atual) => (atual ? { ...atual, ...parcial } : atual));
    setAlterado(true);
  }

  // Roda uma ação mostrando "ocupado" e trata o erro; a mensagem devolvida vira o aviso da tela
  async function executar(chave: string, tarefa: () => Promise<string | void>) {
    if (ocupado) return; // evita dois cliques seguidos
    setOcupado(chave);
    setErroAcao(null);
    setAviso(null);
    try {
      const mensagem = await tarefa();
      if (mensagem) setAviso(mensagem);
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível concluir a operação.");
    } finally {
      setOcupado(null);
    }
  }

  function aoSalvar() {
    if (!form) return;
    void executar("salvar", async () => {
      const novo = await salvarDestino(form);
      setDestino(novo);
      setForm(formularioInicialDestino(novo)); // os campos secretos voltam em branco
      setAlterado(false);
      return "Destino salvo. Use \"Testar conexão\" para conferir.";
    });
  }

  function aoTestar() {
    void executar("testar", async () => (await testarDestino()).detalhe);
  }

  function aoEnviar() {
    void executar("enviar", async () => {
      const resposta = await enviarMaisRecente();
      await carregar(); // atualiza o "último envio"
      return resposta.detalhe;
    });
  }

  const desabilitado = ocupado !== null;
  const acoesBloqueadas = desabilitado || alterado || !destino?.configurado;

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Backup"
          descricao="Para onde vai a cópia dos backups, além do armazenamento do sistema. Somente o Administrador tem acesso."
          acoes={
            <button type="button" className={classeBotaoPrimario} onClick={aoSalvar} disabled={desabilitado || !alterado || !form}>
              {ocupado === "salvar" ? "Salvando..." : "Salvar destino"}
            </button>
          }
        />

        <AbasBackup />

        {erroAcao && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroAcao}
          </p>
        )}
        {aviso && (
          <p role="status" className="mb-4 rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
            {aviso}
          </p>
        )}

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando o destino...</span>
            {[0, 1].map((i) => (
              <Skeleton key={i} className="h-24" />
            ))}
          </div>
        ) : erro || !destino || !form ? (
          <ErrorState
            titulo="Não foi possível carregar o destino."
            mensagem={erro ?? "Tente novamente."}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar();
            }}
          />
        ) : (
          <div className="space-y-4">
            {destino.aviso_segredos && (
              <p role="alert" className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
                {destino.aviso_segredos}
              </p>
            )}
            {alterado && (
              <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
                Há mudanças não salvas. Salve antes de usar os botões de teste e de envio, que usam o destino salvo.
              </p>
            )}

            {/* Cartão: Servidor local */}
            <section className="rounded-2xl border border-slate-200 bg-white shadow-sm">
              <button
                type="button"
                onClick={() => setAberto((valor) => !valor)}
                aria-expanded={aberto}
                aria-controls="cartao-servidor-local"
                className="flex w-full flex-wrap items-center justify-between gap-2 rounded-2xl px-5 py-4 text-left"
              >
                <span>
                  <span className="block text-sm font-semibold text-slate-900">Servidor local (túnel Cloudflare)</span>
                  <span className="block text-xs text-slate-500">
                    Copia o backup, já criptografado, para o servidor de casa. O OneDrive dele leva o arquivo para a nuvem.
                  </span>
                </span>
                <span className="flex items-center gap-2">
                  {!destino.configurado ? <Selo cor="cinza">Não configurado</Selo> : destino.ativo ? <Selo cor="verde">Envio automático ligado</Selo> : <Selo cor="ambar">Envio automático desligado</Selo>}
                  <span aria-hidden="true" className="text-slate-400">
                    {aberto ? "▲" : "▼"}
                  </span>
                </span>
              </button>

              {aberto && (
                <div id="cartao-servidor-local" className="space-y-4 border-t border-slate-100 px-5 py-4">
                  <label className="flex items-center gap-2 text-sm text-slate-700">
                    <input type="checkbox" className={classeCaixa} checked={form.ativo} onChange={(e) => mudar({ ativo: e.target.checked })} />
                    Enviar automaticamente depois de cada backup verificado
                  </label>

                  <Campo id="ds-endereco" rotulo="Endereço do servidor" dica="O endereço do túnel, começando com https:// e sem barra no final.">
                    <input
                      id="ds-endereco"
                      type="text"
                      autoComplete="off"
                      value={form.endereco}
                      onChange={(e) => mudar({ endereco: e.target.value })}
                      placeholder="https://bkp-sysmusicaccb.2atelecom.net.br"
                      className={classeCampo}
                    />
                  </Campo>

                  <div className="grid gap-4 sm:grid-cols-2">
                    <Campo
                      id="ds-client-id"
                      rotulo="Client ID (token de serviço da Cloudflare)"
                      dica={destino.client_id_final ? `Configurado (${destino.client_id_final}). Deixe em branco para manter.` : undefined}
                    >
                      <input
                        id="ds-client-id"
                        type="password"
                        autoComplete="new-password"
                        value={form.client_id}
                        onChange={(e) => mudar({ client_id: e.target.value })}
                        placeholder={destino.client_id_final ? "••••••••••••" : "xxxxxxxx.access"}
                        className={classeCampo}
                      />
                    </Campo>
                    <Campo
                      id="ds-client-secret"
                      rotulo="Client Secret"
                      dica={destino.client_secret_final ? `Configurado (${destino.client_secret_final}). Deixe em branco para manter.` : undefined}
                    >
                      <input
                        id="ds-client-secret"
                        type="password"
                        autoComplete="new-password"
                        value={form.client_secret}
                        onChange={(e) => mudar({ client_secret: e.target.value })}
                        placeholder={destino.client_secret_final ? "••••••••••••" : ""}
                        className={classeCampo}
                      />
                    </Campo>
                  </div>

                  <Campo
                    id="ds-chave"
                    rotulo="Chave de assinatura"
                    dica={
                      destino.chave_final
                        ? `Configurada (${destino.chave_final}). Deixe em branco para manter.`
                        : "Está no servidor, no arquivo C:\\SysMusicaReceptor\\segredo.txt. Copie o texto inteiro."
                    }
                  >
                    <input
                      id="ds-chave"
                      type="password"
                      autoComplete="new-password"
                      value={form.chave_assinatura}
                      onChange={(e) => mudar({ chave_assinatura: e.target.value })}
                      placeholder={destino.chave_final ? "••••••••••••" : ""}
                      className={classeCampo}
                    />
                  </Campo>

                  <div className="flex flex-wrap gap-2">
                    <button type="button" className={classeBotao} onClick={aoTestar} disabled={acoesBloqueadas}>
                      {ocupado === "testar" ? "Testando..." : "Testar conexão"}
                    </button>
                    <button type="button" className={classeBotao} onClick={aoEnviar} disabled={acoesBloqueadas}>
                      {ocupado === "enviar" ? "Enviando..." : "Enviar o backup mais recente agora"}
                    </button>
                  </div>

                  <p className="text-xs text-slate-500">
                    {destino.ultimo_envio_em
                      ? destino.ultimo_envio_situacao === "ok"
                        ? `Último envio: ${dataHoraSalvador(new Date(destino.ultimo_envio_em))}, concluído e conferido.`
                        : `Último envio: ${dataHoraSalvador(new Date(destino.ultimo_envio_em))}, FALHOU${destino.ultimo_envio_detalhe ? ` (${destino.ultimo_envio_detalhe})` : ""}.`
                      : "Nenhum envio feito ainda."}
                  </p>
                  <p className="text-xs text-slate-500">
                    O sistema confirma que o servidor recebeu o arquivo íntegro. A sincronização com o OneDrive é feita pelo próprio servidor e não é vista daqui.
                  </p>
                </div>
              )}
            </section>

            {/* Destinos futuros */}
            {EM_BREVE.map((item) => (
              <section key={item.titulo} className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-dashed border-slate-200 bg-slate-50 px-5 py-4 opacity-80">
                <span>
                  <span className="block text-sm font-semibold text-slate-700">{item.titulo}</span>
                  <span className="block text-xs text-slate-500">{item.texto}</span>
                </span>
                <Selo cor="cinza">Em breve</Selo>
              </section>
            ))}
          </div>
        )}
      </div>
    </main>
  );
}
""",
}

# 1) nada existente pode ser sobrescrito
for caminho in NOVOS:
    if os.path.exists(caminho):
        print("ERRO: já existe", caminho); sys.exit(1)

def trocar(arquivo, antigo, novo):
    s = open(arquivo, encoding="utf-8").read()
    if s.count(antigo) != 1:
        print("ERRO: trecho esperado não encontrado (ou repetido) em", arquivo); sys.exit(1)
    return s.replace(antigo, novo)

# 2) edições nos arquivos existentes (trocas exatas, conferidas antes de gravar qualquer coisa)
ed = {}
ed["src/modules/auditoria/regras.ts"] = trocar("src/modules/auditoria/regras.ts",
  '  backup_aviso_testado: "Testou os avisos do backup",\n',
  '  backup_aviso_testado: "Testou os avisos do backup",\n'
  '  backup_destino_alterado: "Alterou o destino do backup",\n'
  '  backup_destino_testado: "Testou o destino do backup",\n'
  '  backup_copiado_destino: "Copiou o backup para o servidor local",\n')
ed["src/modules/backup/components/AbasBackup.tsx"] = trocar("src/modules/backup/components/AbasBackup.tsx",
  '  { href: "/administracao/backup/notificacoes", rotulo: "Notificações", permissao: "backup.configurar" },\n',
  '  { href: "/administracao/backup/notificacoes", rotulo: "Notificações", permissao: "backup.configurar" },\n'
  '  { href: "/administracao/backup/destinos", rotulo: "Destinos", permissao: "backup.configurar" },\n')
op = "src/modules/backup/server/operacoes.ts"
s = trocar(op, 'import { clienteAdmin } from "./clienteAdmin";\nimport { ErroBackup } from "./erros";\n',
  'import { clienteAdmin } from "./clienteAdmin";\nimport { acrescentarCopia, enviarAutomatico } from "./destinos";\nimport { ErroBackup } from "./erros";\n')
s2 = s.replace('  const avisos = final.verificacao.ok\n    ? await notificar(\n        "sucesso",\n        mensagemSucesso({',
  '  // Cópia automática para o servidor local: só depois de o backup passar na verificação. Nunca derruba o backup.\n'
  '  const copia = final.verificacao.ok ? await enviarAutomatico(admin, final.id) : null;\n\n'
  '  const avisos = final.verificacao.ok\n    ? await notificar(\n        "sucesso",\n        acrescentarCopia(copia, mensagemSucesso({')
assert s2.count("acrescentarCopia(copia, mensagemSucesso({") == 1 and s2 != s, "trecho do aviso de sucesso não encontrado"
s3 = s2.replace('          refeito,\n        })\n      )\n    : await notificar(', '          refeito,\n        }))\n      )\n    : await notificar(')
assert s3 != s2 and s3.count("        }))\n      )\n    : await notificar(") == 1, "fim do aviso de sucesso não encontrado"
ed[op] = s3

# 3) grava (só chega aqui se todas as conferências passaram)
for caminho, conteudo in NOVOS.items():
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    open(caminho, "w", encoding="utf-8").write(conteudo)
for caminho, conteudo in ed.items():
    open(caminho, "w", encoding="utf-8").write(conteudo)

# 4) layout da nova página: cópia do layout das Notificações (só o nome muda)
origem = "src/app/(painel)/administracao/backup/notificacoes/layout.tsx"
destino = "src/app/(painel)/administracao/backup/destinos/layout.tsx"
lay = open(origem, encoding="utf-8").read().replace("Notificações", "Destinos").replace("notificacoes", "destinos")
open(destino, "w", encoding="utf-8").write(lay)
print("Arquivos gravados:", len(NOVOS) + 1, "novos,", len(ed), "alterados.")

PYSCRIPT
[ $? -eq 0 ] || { reverter; exit 1; }

echo; echo "=== 2) Parando o servidor de teste e limpando o cache ==="
pkill -f "next dev" 2>/dev/null; pkill -f next-server 2>/dev/null; pkill -f "next/dist" 2>/dev/null; sleep 2
for i in 1 2 3 4 5; do rm -rf .next 2>/dev/null; [ -d .next ] || break; sleep 1; done

echo; echo "=== 3) Conferência de tipos ==="
npx tsc --noEmit || { reverter; exit 1; }
echo; echo "=== 4) Testes automáticos ==="
npx vitest run src/modules/backup || { reverter; exit 1; }
echo; echo "=== 5) Lint dos arquivos novos e alterados ==="
npx eslint "${ALT[@]}" src/modules/backup/destinos.ts src/modules/backup/assinatura.ts src/modules/backup/server/destinos.ts \
  src/modules/backup/services/destinosApi.ts "src/app/(painel)/administracao/backup/destinos" src/app/api/backup/destinos || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== TUDO CERTO: arquivos instalados e conferidos ==="
git status --short
) 2>&1 | tee /tmp/destinos-instalar.log
