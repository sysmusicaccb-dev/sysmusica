"use client";

/**
 * SysMúsica — Opções da página do relatório: título, orientação (retrato é o padrão), margens, o que
 * aparece no cabeçalho e no rodapé, linhas de assinatura e o ajuste à página.
 *  - Automático: a letra diminui conforme o número de colunas, para a tabela caber na largura.
 *  - Manual: você escolhe o zoom (%) e o tamanho da letra (pt).
 */
import { ESCALA_MAX, ESCALA_MIN, FONTE_MAX, FONTE_MIN, ITENS_CABECALHO, ITENS_RODAPE, MARGENS } from "../regras";
import type { ItemCabecalho, ItemRodape, MargemPagina, OpcoesPagina } from "../tipos";

interface OpcoesDaPaginaProps {
  valores: OpcoesPagina;
  onChange: (novos: OpcoesPagina) => void;
  /** Itens do cabeçalho que fazem sentido para o tipo de relatório escolhido. */
  itensCabecalho: ItemCabecalho[];
}

const classeCampo =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200";

const classeCaixa = "h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300";
const classeRadio = "h-4 w-4 border-slate-300 text-brand-600 focus:ring-brand-300";

const ROTULO_MARGEM: Record<MargemPagina, string> = {
  estreita: `Estreita (${MARGENS.estreita} mm)`,
  normal: `Normal (${MARGENS.normal} mm)`,
  larga: `Larga (${MARGENS.larga} mm)`,
};

export default function OpcoesDaPagina({ valores, onChange, itensCabecalho }: OpcoesDaPaginaProps) {
  const mudar = (parcial: Partial<OpcoesPagina>) => onChange({ ...valores, ...parcial });

  const alternarCabecalho = (id: ItemCabecalho) =>
    mudar({ cabecalho: { ...valores.cabecalho, [id]: !valores.cabecalho[id] } });
  const alternarRodape = (id: ItemRodape) =>
    mudar({ rodapeMarcado: { ...valores.rodapeMarcado, [id]: !valores.rodapeMarcado[id] } });

  return (
    <div className="space-y-6">
      {/* Título */}
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="space-y-1.5">
          <label htmlFor="pag-titulo" className="text-xs font-medium text-slate-600">
            Título do relatório
          </label>
          <input
            id="pag-titulo"
            type="text"
            maxLength={120}
            value={valores.titulo}
            onChange={(e) => mudar({ titulo: e.target.value })}
            className={classeCampo}
          />
        </div>
        <div className="space-y-1.5">
          <label htmlFor="pag-subtitulo" className="text-xs font-medium text-slate-600">
            Subtítulo <span className="font-normal text-slate-400">(opcional)</span>
          </label>
          <input
            id="pag-subtitulo"
            type="text"
            maxLength={160}
            value={valores.subtitulo}
            onChange={(e) => mudar({ subtitulo: e.target.value })}
            className={classeCampo}
          />
        </div>
      </div>

      {/* Orientação e margens */}
      <div className="grid gap-6 sm:grid-cols-2">
        <fieldset className="space-y-2">
          <legend className="text-xs font-medium text-slate-600">Orientação da página</legend>
          <div className="flex flex-wrap gap-4 text-sm text-slate-700">
            <label className="flex items-center gap-2">
              <input
                type="radio"
                name="pag-orientacao"
                checked={valores.orientacao === "retrato"}
                onChange={() => mudar({ orientacao: "retrato" })}
                className={classeRadio}
              />
              Retrato (em pé)
            </label>
            <label className="flex items-center gap-2">
              <input
                type="radio"
                name="pag-orientacao"
                checked={valores.orientacao === "paisagem"}
                onChange={() => mudar({ orientacao: "paisagem" })}
                className={classeRadio}
              />
              Paisagem (deitada)
            </label>
          </div>
        </fieldset>

        <div className="space-y-1.5">
          <label htmlFor="pag-margem" className="text-xs font-medium text-slate-600">
            Margens da página
          </label>
          <select
            id="pag-margem"
            value={valores.margem}
            onChange={(e) => mudar({ margem: e.target.value as MargemPagina })}
            className={classeCampo}
          >
            {(Object.keys(ROTULO_MARGEM) as MargemPagina[]).map((margem) => (
              <option key={margem} value={margem}>
                {ROTULO_MARGEM[margem]}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Cabeçalho */}
      <fieldset className="space-y-2">
        <legend className="text-xs font-medium text-slate-600">O que aparece no cabeçalho</legend>
        <ul className="grid gap-2 sm:grid-cols-2">
          {ITENS_CABECALHO.filter((item) => itensCabecalho.includes(item.id)).map((item) => (
            <li key={item.id}>
              <label className="flex items-center gap-2 text-sm text-slate-700">
                <input
                  type="checkbox"
                  checked={valores.cabecalho[item.id]}
                  onChange={() => alternarCabecalho(item.id)}
                  className={classeCaixa}
                />
                {item.rotulo}
              </label>
            </li>
          ))}
        </ul>
      </fieldset>

      {/* Rodapé */}
      <fieldset className="space-y-3">
        <legend className="text-xs font-medium text-slate-600">O que aparece no rodapé</legend>
        <ul className="grid gap-2 sm:grid-cols-2">
          {ITENS_RODAPE.map((item) => (
            <li key={item.id}>
              <label className="flex items-center gap-2 text-sm text-slate-700">
                <input
                  type="checkbox"
                  checked={valores.rodapeMarcado[item.id]}
                  onChange={() => alternarRodape(item.id)}
                  className={classeCaixa}
                />
                {item.rotulo}
              </label>
            </li>
          ))}
        </ul>
        <div className="space-y-1.5">
          <label htmlFor="pag-rodape" className="text-xs font-medium text-slate-600">
            Texto livre no rodapé <span className="font-normal text-slate-400">(opcional)</span>
          </label>
          <input
            id="pag-rodape"
            type="text"
            maxLength={160}
            value={valores.rodape}
            onChange={(e) => mudar({ rodape: e.target.value })}
            className={classeCampo}
          />
        </div>
      </fieldset>

      {/* Assinaturas */}
      <fieldset className="space-y-2">
        <legend className="text-xs font-medium text-slate-600">Assinaturas</legend>
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={valores.assinaturas}
            onChange={() => mudar({ assinaturas: !valores.assinaturas })}
            className={classeCaixa}
          />
          Incluir linhas de assinatura no fim do relatório
        </label>
        {valores.assinaturas && (
          <div className="space-y-1.5">
            <label htmlFor="pag-assinaturas" className="text-xs font-medium text-slate-600">
              Nomes das linhas, separados por vírgula (até 4)
            </label>
            <input
              id="pag-assinaturas"
              type="text"
              maxLength={200}
              value={valores.nomesAssinaturas}
              onChange={(e) => mudar({ nomesAssinaturas: e.target.value })}
              placeholder="Ex: Responsável, Secretário da Música"
              className={classeCampo}
            />
          </div>
        )}
      </fieldset>

      {/* Ajuste à página */}
      <fieldset className="space-y-2">
        <legend className="text-xs font-medium text-slate-600">Ajuste à página</legend>
        <div className="flex flex-wrap gap-4 text-sm text-slate-700">
          <label className="flex items-center gap-2">
            <input
              type="radio"
              name="pag-ajuste"
              checked={valores.ajuste === "automatico"}
              onChange={() => mudar({ ajuste: "automatico" })}
              className={classeRadio}
            />
            Automático (cabe na largura da página)
          </label>
          <label className="flex items-center gap-2">
            <input
              type="radio"
              name="pag-ajuste"
              checked={valores.ajuste === "manual"}
              onChange={() => mudar({ ajuste: "manual" })}
              className={classeRadio}
            />
            Manual
          </label>
        </div>

        {valores.ajuste === "manual" && (
          <div className="grid gap-4 pt-2 sm:grid-cols-2">
            <div className="space-y-1.5">
              <label htmlFor="pag-escala" className="text-xs font-medium text-slate-600">
                Zoom (%) — de {ESCALA_MIN} a {ESCALA_MAX}
              </label>
              <input
                id="pag-escala"
                type="text"
                inputMode="decimal"
                value={valores.escala}
                onChange={(e) => mudar({ escala: e.target.value })}
                className={classeCampo}
              />
            </div>
            <div className="space-y-1.5">
              <label htmlFor="pag-fonte" className="text-xs font-medium text-slate-600">
                Tamanho da letra (pt) — de {FONTE_MIN} a {FONTE_MAX}
              </label>
              <input
                id="pag-fonte"
                type="text"
                inputMode="decimal"
                value={valores.fonte}
                onChange={(e) => mudar({ fonte: e.target.value })}
                className={classeCampo}
              />
            </div>
          </div>
        )}
      </fieldset>
    </div>
  );
}
