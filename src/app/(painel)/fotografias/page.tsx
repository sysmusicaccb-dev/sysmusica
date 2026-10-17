"use client";

/**
 * SysMúsica — Página /fotografias: cadastro, troca e remoção da fotografia dos membros.
 * A foto é reduzida no navegador (800 px, JPEG) e guardada em armazenamento privado. A fotografia
 * aparece para a portaria na hora de conferir a identidade (leitura do QR Code ou busca pelo nome).
 */
import { useCallback, useEffect, useState } from "react";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import GaleriaFotos from "@/modules/membros/components/GaleriaFotos";
import { prepararFoto } from "@/modules/membros/fotoImagem";
import {
  enviarFoto,
  listarMembrosParaFoto,
  removerFoto,
  urlsDasFotos,
  type MembroFoto,
} from "@/modules/membros/services/fotos";

export default function FotografiasPage() {
  const [membros, setMembros] = useState<MembroFoto[]>([]);
  const [urls, setUrls] = useState<Record<string, string>>({});
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [ocupadoId, setOcupadoId] = useState<string | null>(null);
  const [erroAcao, setErroAcao] = useState<string | null>(null);
  const [alvoRemocao, setAlvoRemocao] = useState<MembroFoto | null>(null);
  const [removendo, setRemovendo] = useState(false);
  const [aviso, setAviso] = useState<string | null>(null);

  // Busca os membros e as URLs temporárias das fotos já cadastradas
  const carregar = useCallback(async () => {
    try {
      const lista = await listarMembrosParaFoto();
      const mapa = await urlsDasFotos(lista.flatMap((membro) => (membro.foto_path ? [membro.foto_path] : [])));
      setMembros(lista);
      setUrls(mapa);
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar as fotografias:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar os membros.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga ao abrir a página
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona). Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  function tentarNovamente() {
    setCarregando(true);
    void carregar();
  }

  // Foto escolhida: reduz, envia, vincula ao membro e recarrega a lista
  async function aoEscolherArquivo(membro: MembroFoto, arquivo: File) {
    setOcupadoId(membro.id);
    setErroAcao(null);
    try {
      const imagem = await prepararFoto(arquivo);
      await enviarFoto(membro.id, imagem);
      await carregar();
      setAviso(`Fotografia de ${membro.nome} atualizada.`);
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível salvar a fotografia.");
    } finally {
      setOcupadoId(null);
    }
  }

  async function confirmarRemocao() {
    if (!alvoRemocao) return;
    setRemovendo(true);
    setErroAcao(null);
    try {
      await removerFoto(alvoRemocao.id);
      await carregar();
      setAviso(`Fotografia de ${alvoRemocao.nome} removida.`);
      setAlvoRemocao(null);
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível remover a fotografia.");
      setAlvoRemocao(null);
    } finally {
      setRemovendo(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Fotografias"
          descricao="Cadastre a fotografia dos membros: ela aparece para a portaria na conferência de identidade."
        />

        {erroAcao && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroAcao}
          </p>
        )}

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando membros...</span>
            <Skeleton className="h-14 rounded-2xl" />
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-16" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar os membros." mensagem={erro} onTentarNovamente={tentarNovamente} />
        ) : (
          <GaleriaFotos
            membros={membros}
            urls={urls}
            ocupadoId={ocupadoId}
            onEscolherArquivo={(membro, arquivo) => void aoEscolherArquivo(membro, arquivo)}
            onRemover={setAlvoRemocao}
          />
        )}
      </div>

      <ConfirmDialog
        aberto={alvoRemocao !== null}
        titulo="Remover fotografia?"
        mensagem={
          <p>
            A fotografia de <strong>{alvoRemocao?.nome}</strong> será apagada. Na portaria, ele aparecerá sem
            foto até que uma nova seja cadastrada.
          </p>
        }
        textoConfirmar="Remover"
        processando={removendo}
        onConfirmar={() => void confirmarRemocao()}
        onCancelar={() => setAlvoRemocao(null)}
      />

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
