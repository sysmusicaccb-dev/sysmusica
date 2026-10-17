"use client";

/**
 * SysMúsica — Página /membros: listagem em tabela (largura total) com busca e filtros.
 * O botão "Novo membro" abre o formulário de cadastro em um painel lateral.
 * Busca cargos, instrumentos, famílias e membros de uma vez e distribui os dados.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import { supabase } from "@/lib/supabase";
import {
  COLUNAS_MEMBRO_PUBLICO,
  type Cargo,
  type Familia,
  type Instrumento,
  type MembroPublico,
} from "@/types/database";
import Button from "@/components/ui/Button";
import Drawer from "@/components/ui/Drawer";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import FormularioMembro from "@/components/FormularioMembro";
import ListaMembros from "@/components/ListaMembros";

export default function MembrosPage() {
  const { pode } = useSessao();
  const [cargos, setCargos] = useState<Cargo[]>([]);
  const [instrumentos, setInstrumentos] = useState<Instrumento[]>([]);
  const [familias, setFamilias] = useState<Familia[]>([]);
  const [membros, setMembros] = useState<MembroPublico[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [painelAberto, setPainelAberto] = useState(false);
  const [aviso, setAviso] = useState<string | null>(null);

  // Busca as quatro tabelas em paralelo
  const buscarDados = useCallback(async () => {
    try {
      const [resCargos, resInstrumentos, resMembros, resFamilias] = await Promise.all([
        supabase.from("cargos").select("*").order("nome", { ascending: true }),
        supabase.from("instrumentos").select("*").order("nome", { ascending: true }),
        // Lista explícita de colunas: select("*") falharia por causa do qr_secret (protegido)
        supabase
          .from("membros")
          .select(COLUNAS_MEMBRO_PUBLICO)
          .order("nome", { ascending: true }),
        supabase.from("familias").select("*").order("nome", { ascending: true }),
      ]);

      // Se qualquer uma das consultas falhar, trata como erro único
      const erroBanco =
        resCargos.error ?? resInstrumentos.error ?? resMembros.error ?? resFamilias.error;
      if (erroBanco) throw new Error(erroBanco.message);

      setCargos((resCargos.data ?? []) as Cargo[]);
      setInstrumentos((resInstrumentos.data ?? []) as Instrumento[]);
      setFamilias((resFamilias.data ?? []) as Familia[]);
      // Cast duplo: com lista de colunas, o cliente (sem tipagem gerada) não infere a linha
      setMembros((resMembros.data ?? []) as unknown as MembroPublico[]);
      setErro(null);
    } catch (e) {
      // O detalhe técnico vai só para o console; a tela mostra uma mensagem simples
      console.error("Falha ao carregar membros:", e);
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

  // Depois de salvar: recarrega a lista, fecha o painel e mostra o aviso de sucesso
  async function aoCadastrar(mensagem: string) {
    await buscarDados();
    setPainelAberto(false);
    setAviso(mensagem);
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Membros"
          descricao={`Cadastre e acompanhe os membros do SysMúsica.${
            !carregando && !erro ? ` ${membros.length} cadastrado(s).` : ""
          }`}
          acoes={
            pode("membros.criar") ? (
              <Button icone={Plus} onClick={() => setPainelAberto(true)} disabled={carregando || !!erro}>
                Novo membro
              </Button>
            ) : undefined
          }
        />

        <ListaMembros
          membros={membros}
          cargos={cargos}
          instrumentos={instrumentos}
          familias={familias}
          carregando={carregando}
          erro={erro}
          onTentarNovamente={tentarNovamente}
        />
      </div>

      <Drawer
        aberto={painelAberto}
        onFechar={() => setPainelAberto(false)}
        titulo="Novo membro"
        descricao="Preencha os dados para cadastrar."
      >
        <FormularioMembro
          cargos={cargos}
          instrumentos={instrumentos}
          familias={familias}
          carregando={carregando}
          erro={erro}
          onMembroAdicionado={aoCadastrar}
        />
      </Drawer>

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
