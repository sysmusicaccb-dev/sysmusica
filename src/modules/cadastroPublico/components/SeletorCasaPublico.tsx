"use client";

/**
 * Sysmusica — Casa de Oração no formulário público: UM campo com sugestões.
 * A pessoa começa a digitar e aparece, na hora, a lista das Casas de Oração cadastradas que combinam (por nome ou pelo
 * caminho RRM › RA › ADM › Setor). Clicar numa sugestão (ou setas + Enter) escolhe a casa.
 * Se a casa NÃO existe na lista, a pessoa simplesmente termina de digitar o nome: o formulário avisa que ela não está
 * cadastrada, mas deixa enviar. O pedido vai para "Cadastros pendentes" e a secretaria escolhe (ou cadastra) a casa correta.
 * A lista vem inteira de uma vez da função pública opcoes_cadastro_publico (só nome e caminho na organização), então a busca
 * é instantânea e não consulta o banco a cada letra.
 */
import { useId, useMemo, useState, type KeyboardEvent } from "react";
import type { CasaPublica } from "../regras";
import { classeInput } from "./Campos";

/** Quantas sugestões aparecem de uma vez (o resto some até a pessoa digitar mais). */
const MAXIMO_SUGESTOES = 30;
/** Só avisa "casa não cadastrada" depois de algumas letras (evita avisar enquanto a pessoa ainda começa a digitar). */
const LETRAS_PARA_AVISAR = 3;

function semAcento(texto: string): string {
  return texto.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/\s+/g, " ").trim();
}

function caminho(casa: CasaPublica): string {
  return [casa.rrm, casa.ra, casa.adm, casa.setor].filter((parte): parte is string => !!parte).join(" › ");
}

interface Props {
  id: string;
  /** Id da casa escolhida na lista ("" = nenhuma). */
  valor: string;
  /** Chamado a cada mudança: `casaId` preenchido quando escolheu da lista; vazio quando é um nome digitado. */
  onChange: (casaId: string, nomeDigitado: string) => void;
  casas: CasaPublica[];
  disabled?: boolean;
}

export default function SeletorCasaPublico({ id, valor, onChange, casas, disabled }: Props) {
  const idLista = useId();
  const [texto, setTexto] = useState("");
  const [aberto, setAberto] = useState(false);
  const [destaque, setDestaque] = useState(0);

  const termo = semAcento(texto);
  // Com uma casa escolhida, ao abrir a lista mostra todas; sem escolha, filtra pelo que foi digitado
  const encontradas = useMemo(() => {
    const filtro = valor ? "" : termo;
    if (filtro === "") return casas;
    return casas.filter((c) => semAcento(`${c.nome} ${caminho(c)}`).includes(filtro));
  }, [termo, valor, casas]);
  const sugestoes = encontradas.slice(0, MAXIMO_SUGESTOES);
  const naoCadastrada = !valor && termo.length >= LETRAS_PARA_AVISAR && encontradas.length === 0;

  function escolher(casa: CasaPublica) {
    setTexto(casa.nome);
    onChange(casa.id, "");
    setAberto(false);
  }

  function aoDigitar(novo: string) {
    setTexto(novo);
    onChange("", novo); // mudou o texto: vale o que está escrito (a escolha anterior deixa de valer)
    setAberto(true);
    setDestaque(0);
  }

  // Ao sair do campo: se o que foi digitado é exatamente o nome de UMA casa da lista, escolhe essa casa
  function aoSair() {
    setAberto(false);
    if (valor || termo === "") return;
    const iguais = casas.filter((c) => semAcento(c.nome) === termo);
    if (iguais.length === 1) escolher(iguais[0]);
  }

  function aoTeclar(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setAberto(true);
      setDestaque((d) => Math.min(d + 1, sugestoes.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setDestaque((d) => Math.max(d - 1, 0));
    } else if (e.key === "Enter" && aberto && sugestoes[destaque]) {
      e.preventDefault(); // não envia o formulário: só escolhe a casa
      escolher(sugestoes[destaque]);
    } else if (e.key === "Escape") {
      setAberto(false);
    }
  }

  return (
    <div className="relative space-y-1">
      <input
        id={id}
        type="text"
        role="combobox"
        aria-expanded={aberto}
        aria-controls={idLista}
        aria-autocomplete="list"
        autoComplete="off"
        maxLength={120}
        value={texto}
        disabled={disabled}
        placeholder="Comece a digitar o nome da Casa de Oração"
        onChange={(e) => aoDigitar(e.target.value)}
        onFocus={() => setAberto(true)}
        onBlur={aoSair}
        onKeyDown={aoTeclar}
        className={classeInput}
      />

      {aberto && sugestoes.length > 0 && (
        <ul
          id={idLista}
          role="listbox"
          className="absolute z-20 mt-1 max-h-64 w-full overflow-y-auto rounded-lg border border-slate-300 bg-white py-1 text-sm shadow-lg"
        >
          {sugestoes.map((casa, i) => (
            <li
              key={casa.id}
              role="option"
              aria-selected={casa.id === valor}
              // mouseDown (e não click): acontece ANTES de o campo perder o foco e fechar a lista
              onMouseDown={(e) => {
                e.preventDefault();
                escolher(casa);
              }}
              onMouseEnter={() => setDestaque(i)}
              className={`cursor-pointer px-3 py-2 ${i === destaque ? "bg-brand-50" : ""} ${casa.id === valor ? "font-semibold" : ""}`}
            >
              <span className="block text-slate-900">{casa.nome}</span>
              {caminho(casa) && <span className="block text-xs text-slate-500">{caminho(casa)}</span>}
            </li>
          ))}
          {encontradas.length > MAXIMO_SUGESTOES && (
            <li className="px-3 py-2 text-xs text-slate-500">
              Mostrando {MAXIMO_SUGESTOES} de {encontradas.length}. Digite mais letras para refinar.
            </li>
          )}
        </ul>
      )}

      {valor && <p className="text-xs font-medium text-emerald-700">Casa de Oração escolhida na lista.</p>}
      {naoCadastrada && (
        <p role="status" className="rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-900">
          Não encontramos esta Casa de Oração na lista. Você pode continuar: o nome digitado será enviado e a secretaria vai
          conferir e cadastrar a casa. Se foi erro de digitação, corrija o nome acima.
        </p>
      )}
    </div>
  );
}
