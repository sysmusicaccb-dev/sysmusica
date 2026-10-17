/**
 * SysMúsica — Painel de gráficos do dashboard (componente de apresentação).
 * Recebe os dados prontos de buscarDadosGraficos e organiza os cartões em grade responsiva.
 */
import Card from "@/components/ui/Card";
import GraficoBarras from "@/components/charts/GraficoBarras";
import GraficoColunasEmpilhadas, {
  type ColunaEmpilhada,
} from "@/components/charts/GraficoColunasEmpilhadas";
import GraficoRosca from "@/components/charts/GraficoRosca";
import type { DadosGraficos } from "../services/graficos";

// Legenda do gráfico de frequência (as mesmas cores dos segmentos abaixo)
const LEGENDA_FREQUENCIA = [
  { rotulo: "Presente", corFundo: "bg-emerald-500" },
  { rotulo: "Ausente", corFundo: "bg-red-500" },
  { rotulo: "Justificado", corFundo: "bg-amber-500" },
];

export default function PainelGraficos({ dados }: { dados: DadosGraficos }) {
  // Uma coluna por evento, com um trecho empilhado para cada status
  const colunas: ColunaEmpilhada[] = dados.frequencia.map((evento) => ({
    rotulo: evento.rotulo,
    titulo: `${evento.rotulo}: ${evento.presentes} presente(s), ${evento.ausentes} ausente(s), ${evento.justificados} justificado(s)`,
    segmentos: [
      { rotulo: "Presente", valor: evento.presentes, corFundo: "bg-emerald-500" },
      { rotulo: "Ausente", valor: evento.ausentes, corFundo: "bg-red-500" },
      { rotulo: "Justificado", valor: evento.justificados, corFundo: "bg-amber-500" },
    ],
  }));

  const descricaoFrequencia =
    dados.frequenciaMedia !== null
      ? `Frequência média: ${dados.frequenciaMedia}% nos últimos ${dados.frequencia.length} evento(s).`
      : "Registros de presença dos últimos eventos realizados.";

  return (
    <div className="space-y-6">
      <div className="grid gap-6 lg:grid-cols-3">
        <Card
          className="lg:col-span-2"
          titulo="Frequência nos últimos eventos"
          descricao={descricaoFrequencia}
        >
          <GraficoColunasEmpilhadas
            colunas={colunas}
            legenda={LEGENDA_FREQUENCIA}
            vazio="Ainda não há presenças registradas em eventos realizados."
          />
        </Card>
        <Card titulo="Presenças por status" descricao="Todos os registros de presença.">
          <GraficoRosca
            dados={dados.presencasPorStatus}
            rotuloCentro="registros"
            vazio="Nenhuma presença registrada ainda."
          />
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card titulo="Membros por cargo" descricao="Distribuição dos membros pelos cargos.">
          <GraficoBarras dados={dados.porCargo} vazio="Nenhum membro cadastrado ainda." />
        </Card>
        <Card
          titulo="Membros por família de instrumento"
          descricao="A família vem do instrumento de cada membro."
        >
          <GraficoRosca
            dados={dados.porFamilia}
            rotuloCentro="membros"
            vazio="Nenhum membro cadastrado ainda."
          />
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card titulo="Instrumentos mais usados" descricao="Quantidade de membros por instrumento.">
          <GraficoBarras
            dados={dados.porInstrumento}
            vazio="Nenhum membro com instrumento cadastrado."
          />
        </Card>
        <Card titulo="Membros por congregação" descricao="As congregações com mais membros.">
          <GraficoBarras dados={dados.porCongregacao} vazio="Nenhum membro cadastrado ainda." />
        </Card>
      </div>
    </div>
  );
}
