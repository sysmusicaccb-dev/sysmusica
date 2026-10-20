"use client";

/**
 * SysMúsica — Opções do relatório de presença: o que aparece na folha antes de gerar.
 * Por padrão vai o mínimo (logomarca, título, evento, local e total). A escolha fica guardada neste navegador.
 */
import { useState } from "react";
import Button from "@/components/ui/Button";
import { OPCOES_PADRAO, type OpcoesRelatorioPresenca } from "../presencaPortaria";

interface FormularioRelatorioPresencaProps {
  opcoesIniciais: OpcoesRelatorioPresenca;
  gerando: boolean;
  erro: string | null;
  onGerar: (opcoes: OpcoesRelatorioPresenca) => void;
}

type Grupo = { titulo: string; itens: { chave: keyof OpcoesRelatorioPresenca; rotulo: string }[] };

const GRUPOS: Grupo[] = [
  {
    titulo: "No cabeçalho (além do título e da data)",
    itens: [
      { chave: "local", rotulo: "Local e cidade" },
      { chave: "total", rotulo: "Total de presentes" },
      { chave: "casaOracao", rotulo: "Casa de Oração do evento" },
      { chave: "regiaoSetor", rotulo: "Região › Setor" },
      { chave: "semCadastro", rotulo: "Quantidade de entradas sem cadastro" },
      { chave: "resumo", rotulo: "Resumo: Ministério, Músicos e Organistas" },
      { chave: "familias", rotulo: "Instrumentos por família (quem toca)" },
      { chave: "portaria", rotulo: "Situação da portaria (quem aprovou e quando)" },
    ],
  },
  {
    titulo: "Colunas da lista (número e nome sempre aparecem)",
    itens: [
      { chave: "colCargo", rotulo: "Cargo" },
      { chave: "colInstrumento", rotulo: "Instrumento" },
      { chave: "colOrigem", rotulo: "Casa de Oração de origem" },
      { chave: "colEntrada", rotulo: "Hora de entrada" },
    ],
  },
  {
    titulo: "Folha",
    itens: [
      { chave: "logoCcb", rotulo: "Logomarca da CCB no topo" },
      { chave: "assinaturas", rotulo: "Linhas de assinatura no fim" },
      { chave: "emitidoEm", rotulo: "Data e hora da emissão no rodapé" },
      { chave: "emitidoPor", rotulo: "Nome de quem emitiu no rodapé" },
      { chave: "paginacao", rotulo: "Numeração das páginas" },
    ],
  },
];

export default function FormularioRelatorioPresenca({
  opcoesIniciais,
  gerando,
  erro,
  onGerar,
}: FormularioRelatorioPresencaProps) {
  const [opcoes, setOpcoes] = useState<OpcoesRelatorioPresenca>(opcoesIniciais);

  function alternar(chave: keyof OpcoesRelatorioPresenca) {
    setOpcoes((atual) => ({ ...atual, [chave]: !atual[chave] }));
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        onGerar(opcoes);
      }}
      className="space-y-5"
    >
      {GRUPOS.map((grupo) => (
        <fieldset key={grupo.titulo} className="space-y-2">
          <legend className="mb-1 text-sm font-semibold text-slate-800">{grupo.titulo}</legend>
          {grupo.itens.map((item) => (
            <label key={item.chave} className="flex cursor-pointer items-center gap-2 text-sm text-slate-700">
              <input
                type="checkbox"
                checked={opcoes[item.chave]}
                onChange={() => alternar(item.chave)}
                disabled={gerando}
                className="h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-500"
              />
              {item.rotulo}
            </label>
          ))}
        </fieldset>
      ))}

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <div className="space-y-2">
        <Button type="submit" disabled={gerando} className="w-full">
          {gerando ? "Gerando..." : "Gerar relatório"}
        </Button>
        <button
          type="button"
          onClick={() => setOpcoes({ ...OPCOES_PADRAO })}
          disabled={gerando}
          className="w-full text-sm font-medium text-slate-600 hover:underline disabled:opacity-60"
        >
          Voltar ao padrão (mínimo)
        </button>
        <p className="text-xs text-slate-500">A sua escolha fica guardada neste navegador para os próximos relatórios.</p>
      </div>
    </form>
  );
}
