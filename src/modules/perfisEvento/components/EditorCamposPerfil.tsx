"use client";

/**
 * Sysmusica — Editor dos campos da tela Dados do Ensaio para um perfil de evento.
 * Cada cartão é um bloco da tela (Quem atendeu, Hino de abertura, Palavra exortada, Encarregados, Hinos executados)
 * com a chave liga/desliga e as opções. Embaixo, uma prévia em frases do que a tela vai mostrar.
 * O componente só edita a configuração (onChange); quem salva é o formulário do perfil.
 */
import type { ReactNode } from "react";
import { cn } from "@/lib/cn";
import { CARGOS_ENCARREGADO, ROTULO_MODO_ABERTURA, descreverConfig, type ConfigEnsaio, type ModoAbertura } from "@/modules/ensaio/perfilConfig";
import { CARGOS_ATENDE, MAXIMO_ENCARREGADOS, PALAVRA_MAXIMA } from "@/modules/ensaio/regras";
import EditorCamposExtras from "./EditorCamposExtras";

interface EditorCamposPerfilProps {
  config: ConfigEnsaio;
  onChange: (config: ConfigEnsaio) => void;
  disabled?: boolean;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";
const MODOS: ModoAbertura[] = ["pergunta", "obrigatorio", "nao_usa"];

/** Chave liga/desliga (mesmo visual dos Status das outras telas). */
function Chave({ ligada, rotulo, onClick, disabled }: { ligada: boolean; rotulo: string; onClick: () => void; disabled?: boolean }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={ligada}
      aria-label={rotulo}
      disabled={disabled}
      onClick={onClick}
      className={cn(
        "relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:opacity-50",
        ligada ? "bg-emerald-500" : "bg-slate-300"
      )}
    >
      <span className={cn("inline-block h-5 w-5 transform rounded-full bg-white shadow transition", ligada ? "translate-x-5" : "translate-x-0.5")} />
    </button>
  );
}

/** Cartão de um bloco: título, chave opcional e as opções (que só aparecem com o bloco ligado). */
function Cartao({
  titulo,
  ligado,
  onLigar,
  disabled,
  children,
}: {
  titulo: string;
  ligado?: boolean;
  onLigar?: () => void;
  disabled?: boolean;
  children?: ReactNode;
}) {
  const aberto = ligado !== false;
  return (
    <section className="rounded-xl border border-slate-200 bg-white">
      <header className="flex items-center justify-between gap-3 border-b border-slate-200 bg-slate-50 px-4 py-2.5">
        <h3 className="text-sm font-semibold text-slate-900">{titulo}</h3>
        {onLigar && <Chave ligada={ligado === true} rotulo={`Usar ${titulo}`} onClick={onLigar} disabled={disabled} />}
      </header>
      {aberto && children && <div className="space-y-3 p-4">{children}</div>}
    </section>
  );
}

/** Marca/desmarca um valor de uma lista, sem deixar a lista ficar vazia. */
function alternarItem<T extends string>(lista: T[], item: T, ordem: readonly T[]): T[] {
  const novo = lista.includes(item) ? lista.filter((x) => x !== item) : [...lista, item];
  if (novo.length === 0) return lista;
  return ordem.filter((x) => novo.includes(x));
}

export default function EditorCamposPerfil({ config, onChange, disabled }: EditorCamposPerfilProps) {
  const qa = config.quem_atendeu;
  const pa = config.palavra;
  const en = config.encarregados;
  const ordemAtende = CARGOS_ATENDE.map((c) => c.codigo);
  const ordemEnc = CARGOS_ENCARREGADO.map((c) => c.codigo);

  return (
    <div className="space-y-3">
      <Cartao titulo="Quem atendeu" ligado={qa.ativo} disabled={disabled} onLigar={() => onChange({ ...config, quem_atendeu: { ...qa, ativo: !qa.ativo } })}>
        <div className="space-y-1.5">
          <label htmlFor="perfil-titulo-qa" className="text-xs font-semibold text-slate-700">Título do cartão</label>
          <input id="perfil-titulo-qa" type="text" maxLength={60} value={qa.titulo} disabled={disabled} className={classeInput}
            onChange={(e) => onChange({ ...config, quem_atendeu: { ...qa, titulo: e.target.value } })} />
        </div>
        <div className="space-y-1.5">
          <label htmlFor="perfil-rotulo-nome" className="text-xs font-semibold text-slate-700">Rótulo do campo de nome</label>
          <input id="perfil-rotulo-nome" type="text" maxLength={60} value={qa.rotulo_nome} disabled={disabled} className={classeInput}
            onChange={(e) => onChange({ ...config, quem_atendeu: { ...qa, rotulo_nome: e.target.value } })} />
        </div>
        <fieldset className="space-y-1.5">
          <legend className="text-xs font-semibold text-slate-700">Cargos que podem ter atendido</legend>
          {CARGOS_ATENDE.map((c) => (
            <label key={c.codigo} className="flex items-center gap-2 text-sm text-slate-800">
              <input type="checkbox" checked={qa.cargos.includes(c.codigo)} disabled={disabled} className="h-4 w-4"
                onChange={() => onChange({ ...config, quem_atendeu: { ...qa, cargos: alternarItem(qa.cargos, c.codigo, ordemAtende) } })} />
              {c.rotulo}
            </label>
          ))}
          <p className="text-xs text-slate-500">Com um cargo só, a tela já vem com ele escolhido (sem a lista).</p>
        </fieldset>
      </Cartao>

      <Cartao titulo="Hino de abertura">
        <fieldset className="space-y-1.5">
          <legend className="sr-only">Como funciona o hino de abertura</legend>
          {MODOS.map((modo) => (
            <label key={modo} className="flex items-center gap-2 text-sm text-slate-800">
              <input type="radio" name="perfil-modo-abertura" checked={config.hino_abertura.modo === modo} disabled={disabled} className="h-4 w-4"
                onChange={() => onChange({ ...config, hino_abertura: { modo } })} />
              {ROTULO_MODO_ABERTURA[modo]}
            </label>
          ))}
          <p className="text-xs text-slate-500">O campo aparece embaixo do nome de quem atendeu, no mesmo cartão.</p>
        </fieldset>
      </Cartao>

      <Cartao titulo="Palavra exortada" ligado={pa.ativo} disabled={disabled} onLigar={() => onChange({ ...config, palavra: { ...pa, ativo: !pa.ativo } })}>
        <label className="flex items-center gap-2 text-sm text-slate-800">
          <input type="checkbox" checked={pa.obrigatoria} disabled={disabled} className="h-4 w-4"
            onChange={() => onChange({ ...config, palavra: { ...pa, obrigatoria: !pa.obrigatoria } })} />
          Preenchimento obrigatório
        </label>
        <div className="space-y-1.5">
          <label htmlFor="perfil-limite-palavra" className="text-xs font-semibold text-slate-700">Limite de caracteres (até {PALAVRA_MAXIMA})</label>
          <input id="perfil-limite-palavra" type="number" min={1} max={PALAVRA_MAXIMA} value={pa.limite} disabled={disabled} className={cn(classeInput, "w-32")}
            onChange={(e) => onChange({ ...config, palavra: { ...pa, limite: Math.min(PALAVRA_MAXIMA, Math.max(1, Math.trunc(Number(e.target.value)) || 1)) } })} />
        </div>
      </Cartao>

      <Cartao titulo="Encarregados" ligado={en.ativo} disabled={disabled} onLigar={() => onChange({ ...config, encarregados: { ...en, ativo: !en.ativo } })}>
        <fieldset className="space-y-1.5">
          <legend className="text-xs font-semibold text-slate-700">Cargos permitidos</legend>
          {CARGOS_ENCARREGADO.map((c) => (
            <label key={c.codigo} className="flex items-center gap-2 text-sm text-slate-800">
              <input type="checkbox" checked={en.cargos.includes(c.codigo)} disabled={disabled} className="h-4 w-4"
                onChange={() => onChange({ ...config, encarregados: { ...en, cargos: alternarItem(en.cargos, c.codigo, ordemEnc) } })} />
              {c.rotulo}
            </label>
          ))}
          <p className="text-xs text-slate-500">Com mais de um cargo, cada encarregado tem a sua lista de cargo na tela.</p>
        </fieldset>
        <div className="flex flex-wrap gap-4">
          <div className="space-y-1.5">
            <label htmlFor="perfil-enc-min" className="text-xs font-semibold text-slate-700">Mínimo</label>
            <select id="perfil-enc-min" value={en.minimo} disabled={disabled} className={cn(classeInput, "w-24")}
              onChange={(e) => onChange({ ...config, encarregados: { ...en, minimo: Number(e.target.value) } })}>
              {Array.from({ length: en.maximo + 1 }, (_, i) => i).map((n) => (<option key={n} value={n}>{n}</option>))}
            </select>
          </div>
          <div className="space-y-1.5">
            <label htmlFor="perfil-enc-max" className="text-xs font-semibold text-slate-700">Máximo</label>
            <select id="perfil-enc-max" value={en.maximo} disabled={disabled} className={cn(classeInput, "w-24")}
              onChange={(e) => { const maximo = Number(e.target.value); onChange({ ...config, encarregados: { ...en, maximo, minimo: Math.min(en.minimo, maximo) } }); }}>
              {Array.from({ length: MAXIMO_ENCARREGADOS }, (_, i) => i + 1).map((n) => (<option key={n} value={n}>{n}</option>))}
            </select>
          </div>
        </div>
        <label className="flex items-center gap-2 text-sm text-slate-800">
          <input type="checkbox" checked={en.cidade_uf} disabled={disabled} className="h-4 w-4"
            onChange={() => onChange({ ...config, encarregados: { ...en, cidade_uf: !en.cidade_uf } })} />
          Pedir a Cidade-UF de cada encarregado
        </label>
      </Cartao>

      <Cartao titulo="Hinos executados" ligado={config.hinos_executados.ativo} disabled={disabled}
        onLigar={() => onChange({ ...config, hinos_executados: { ativo: !config.hinos_executados.ativo } })} />

      <EditorCamposExtras config={config} onChange={onChange} disabled={disabled} />

      <section aria-label="Como a tela vai ficar" className="rounded-xl border border-brand-100 bg-brand-50 p-4">
        <h3 className="text-sm font-semibold text-slate-900">Como a tela Dados do Ensaio vai ficar</h3>
        <ul className="mt-2 list-disc space-y-0.5 pl-5 text-sm text-slate-700">
          {descreverConfig(config).map((linha) => (<li key={linha}>{linha}</li>))}
        </ul>
      </section>
    </div>
  );
}
