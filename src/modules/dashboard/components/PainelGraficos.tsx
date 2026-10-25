/**
 * Sysmusica — Painel de gráficos do dashboard (componente de apresentação).
 * Recebe os dados prontos de buscarDadosGraficos e organiza os cartões em grade responsiva.
 */
import type { ReactNode } from "react";
import { BarChart3, Building2, Guitar, Music, PieChart, Users } from "lucide-react";
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

interface PainelGraficosProps {
  dados: DadosGraficos;
  proximosEventos?: ReactNode; // vai no fim da 2ª linha
  atalhos?: ReactNode; // vai no fim da 3ª linha
}

export default function PainelGraficos({ dados, proximosEventos, atalhos }: PainelGraficosProps) {
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

  // As colunas das linhas 2 e 3 têm as mesmas proporções, como no desenho
  const linhaDeTres = "grid gap-4 lg:grid-cols-[1.35fr_1.2fr_1fr]";

  return (
    <div className="space-y-4">
      <div className="grid gap-4 lg:grid-cols-[1.1fr_1fr]">
        <Card
          icone={BarChart3}
          titulo="Frequência nos últimos eventos"
          descricao={descricaoFrequencia}
        >
          <GraficoColunasEmpilhadas
            colunas={colunas}
            legenda={LEGENDA_FREQUENCIA}
            vazio="Ainda não há presenças registradas em eventos realizados."
          />
        </Card>
        <Card icone={PieChart} titulo="Presenças por status" descricao="Todos os registros de presença.">
          <GraficoRosca
            dados={dados.presencasPorStatus}
            rotuloCentro="registros"
            vazio="Nenhuma presença registrada ainda."
          />
        </Card>
      </div>

      <div className={linhaDeTres}>
        <Card icone={Users} titulo="Membros por cargo" descricao="Distribuição dos membros pelos cargos.">
          <GraficoBarras dados={dados.porCargo} vazio="Nenhum membro cadastrado ainda." />
        </Card>
        <Card
          icone={Music}
          titulo="Membros por família de instrumento"
          descricao="A família vem do instrumento de cada membro."
        >
          <GraficoRosca
            dados={dados.porFamilia}
            rotuloCentro="membros"
            vazio="Nenhum membro cadastrado ainda."
          />
        </Card>
        {proximosEventos}
      </div>

      <div className={linhaDeTres}>
        <Card icone={Guitar} titulo="Instrumentos mais usados" descricao="Quantidade de membros por instrumento.">
          <GraficoBarras
            dados={dados.porInstrumento}
            vazio="Nenhum membro com instrumento cadastrado."
          />
        </Card>
        <Card icone={Building2} titulo="Membros por Casa de Oração" descricao="As Casas de Oração com mais membros.">
          <GraficoBarras dados={dados.porCongregacao} vazio="Nenhum membro cadastrado ainda." />
        </Card>
        {atalhos}
      </div>
    </div>
  );
}
