"use client";

/**
 * SysMúsica — Página /presencas: histórico de presenças agrupado por evento (largura total).
 * O botão "Registrar presenças" abre o formulário de lançamento em um painel lateral.
 * Busca eventos, membros, presenças e instrumentos de uma só vez e distribui os dados.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import { supabase } from "@/lib/supabase";
import {
  COLUNAS_MEMBRO_PUBLICO,
  type Evento,
  type Instrumento,
  type MembroPublico,
  type Presenca,
} from "@/types/database";
import Button from "@/components/ui/Button";
import Drawer from "@/components/ui/Drawer";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import FormularioPresenca from "@/components/FormularioPresenca";
import ListaPresencas from "@/components/ListaPresencas";

export default function PortariaPage() {
  const { pode } = useSessao();
  const [eventos, setEventos] = useState<Evento[]>([]);
  const [membros, setMembros] = useState<MembroPublico[]>([]);
  const [instrumentos, setInstrumentos] = useState<Instrumento[]>([]);
  const [presencas, setPresencas] = useState<Presenca[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [painelAberto, setPainelAberto] = useState(false);
  const [aviso, setAviso] = useState<string | null>(null);

  // Busca as quatro tabelas em paralelo
  const buscarDados = useCallback(async () => {
    try {
      const [resEventos, resMembros, resPresencas, resInstrumentos] = await Promise.all([
        supabase.from("eventos").select("*").order("data_evento", { ascending: false }),
        // Lista explícita de colunas: select("*") falharia por causa do qr_secret (protegido)
        supabase
          .from("membros")
          .select(COLUNAS_MEMBRO_PUBLICO)
          .order("nome", { ascending: true }),
        supabase.from("presencas").select("*"),
        supabase.from("instrumentos").select("*"),
      ]);

      // Se qualquer uma das consultas falhar, trata como erro único
      const erroBanco =
        resEventos.error ?? resMembros.error ?? resPresencas.error ?? resInstrumentos.error;
      if (erroBanco) throw new Error(erroBanco.message);

      setEventos((resEventos.data ?? []) as Evento[]);
      // Cast duplo: com lista de colunas, o cliente (sem tipagem gerada) não infere a linha
      setMembros((resMembros.data ?? []) as unknown as MembroPublico[]);
      setPresencas((resPresencas.data ?? []) as Presenca[]);
      setInstrumentos((resInstrumentos.data ?? []) as Instrumento[]);
      setErro(null);
    } catch (e) {
      // O detalhe técnico vai só para o console; a tela mostra uma mensagem simples
      console.error("Falha ao carregar presenças:", e);
      setErro("Não foi possível carregar os dados. Verifique a conexão e tente novamente.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga ao abrir a página
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga inicial. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void buscarDados();
  }, [buscarDados]);

  // Botão "Tentar novamente": volta ao estado de loading e busca de novo
  function tentarNovamente() {
    setCarregando(true);
    void buscarDados();
  }

  // Depois de salvar: recarrega os dados, fecha o painel e mostra o aviso de sucesso
  async function aoRegistrar(mensagem: string) {
    await buscarDados();
    setPainelAberto(false);
    setAviso(mensagem);
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Portaria"
          descricao={`Controle de entrada dos membros nos eventos.${
            !carregando && !erro ? ` ${presencas.length} registro(s).` : ""
          }`}
          acoes={
            pode("portaria.registrar") ? (
              <Button icone={Plus} onClick={() => setPainelAberto(true)} disabled={carregando || !!erro}>
                Registrar presenças
              </Button>
            ) : undefined
          }
        />

        <ListaPresencas
          presencas={presencas}
          membros={membros}
          instrumentos={instrumentos}
          eventos={eventos}
          carregando={carregando}
          erro={erro}
          onTentarNovamente={tentarNovamente}
        />
      </div>

      <Drawer
        aberto={painelAberto}
        onFechar={() => setPainelAberto(false)}
        titulo="Registrar presenças"
        descricao="Escolha o evento e marque cada membro."
      >
        <FormularioPresenca
          eventos={eventos}
          membros={membros}
          instrumentos={instrumentos}
          presencas={presencas}
          carregando={carregando}
          erro={erro}
          onPresencaAdicionada={aoRegistrar}
        />
      </Drawer>

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
