"use client";

/**
 * SysMúsica — Página /eventos: listagem em tabela (largura total), do evento mais recente
 * para o mais antigo. O botão "Novo evento" abre o formulário em um painel lateral.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import { supabase } from "@/lib/supabase";
import type { Evento } from "@/types/database";
import Button from "@/components/ui/Button";
import Drawer from "@/components/ui/Drawer";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import FormularioEvento from "@/components/FormularioEvento";
import ListaEventos from "@/components/ListaEventos";

export default function EventosPage() {
  const [eventos, setEventos] = useState<Evento[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [painelAberto, setPainelAberto] = useState(false);
  const [aviso, setAviso] = useState<string | null>(null);

  // Busca todos os eventos, do mais recente para o mais antigo
  const buscarEventos = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from("eventos")
        .select("*")
        .order("data_evento", { ascending: false });

      if (error) throw new Error(error.message);

      setEventos((data ?? []) as Evento[]);
      setErro(null);
    } catch (e) {
      // O detalhe técnico vai só para o console; a tela mostra uma mensagem simples
      console.error("Falha ao carregar eventos:", e);
      setErro("Não foi possível carregar os eventos. Verifique a conexão e tente novamente.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga ao abrir a página
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga inicial. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void buscarEventos();
  }, [buscarEventos]);

  // Botão "Tentar novamente": volta ao estado de loading e busca de novo
  function tentarNovamente() {
    setCarregando(true);
    void buscarEventos();
  }

  // Depois de salvar: recarrega a lista, fecha o painel e mostra o aviso de sucesso
  async function aoCadastrar(mensagem: string) {
    await buscarEventos();
    setPainelAberto(false);
    setAviso(mensagem);
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Eventos"
          descricao={`Cadastre e acompanhe os ensaios e cultos do SysMúsica.${
            !carregando && !erro ? ` ${eventos.length} cadastrado(s).` : ""
          }`}
          acoes={
            <Button icone={Plus} onClick={() => setPainelAberto(true)} disabled={carregando || !!erro}>
              Novo evento
            </Button>
          }
        />

        <ListaEventos
          eventos={eventos}
          carregando={carregando}
          erro={erro}
          onTentarNovamente={tentarNovamente}
        />
      </div>

      <Drawer
        aberto={painelAberto}
        onFechar={() => setPainelAberto(false)}
        titulo="Novo evento"
        descricao="Preencha os dados para cadastrar."
      >
        <FormularioEvento onEventoAdicionado={aoCadastrar} />
      </Drawer>

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
