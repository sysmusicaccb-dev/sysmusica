"use client";

/**
 * Sysmusica — Detalhe de um cadastro enviado pelo link público (dentro do painel lateral).
 * Mostra a foto e o documento (endereços temporários), os dados e, nas ATUALIZAÇÕES, a comparação campo a campo
 * com o cadastro atual do membro. Aprovar e Recusar só aparecem para quem tem cadastros.aprovar.
 */
import { useEffect, useState } from "react";
import { AlertTriangle, Check, ExternalLink, X } from "lucide-react";
import Badge from "@/components/ui/Badge";
import Button from "@/components/ui/Button";
import Skeleton from "@/components/ui/Skeleton";
import { listarOrganizacaoParaSelecao } from "@/modules/organizacao/services/organizacao";
import { arquivosDoCadastro } from "../services/cadastrosPendentes";
import {
  ROTULO_STATUS,
  ROTULO_TIPO,
  VARIANTE_STATUS,
  compararComAtual,
  formatarData,
  formatarDataHora,
  quantosMudaram,
} from "../regras";
import type { ArquivosDoCadastro, DetalheCadastro } from "../tipos";

/** Imagem sem usar <img> (mesmo padrão dos campos de foto) e com link para abrir em tamanho real. */
function Imagem({ url, rotulo, alto }: { url: string | null | undefined; rotulo: string; alto: string }) {
  if (!url) {
    return (
      <div className={`flex ${alto} w-full items-center justify-center rounded-lg bg-slate-100 px-2 text-center text-xs text-slate-500`}>
        {rotulo}: indisponível
      </div>
    );
  }
  return (
    <a href={url} target="_blank" rel="noopener noreferrer" className="block" title={`Abrir ${rotulo} em tamanho real`}>
      <div role="img" aria-label={rotulo} style={{ backgroundImage: `url(${url})` }} className={`${alto} w-full rounded-lg bg-slate-100 bg-contain bg-center bg-no-repeat`} />
      <span className="mt-1 inline-flex items-center gap-1 text-xs text-brand-700">
        {rotulo} <ExternalLink className="h-3 w-3" aria-hidden="true" />
      </span>
    </a>
  );
}

interface Props {
  detalhe: DetalheCadastro;
  podeAprovar: boolean;
  ocupado: boolean;
  /** `casaId`: preenchido quando o pedido veio com uma Casa de Oração digitada e quem aprova escolheu a correta. */
  onAprovar: (casaId?: string) => void;
  onRecusar: () => void;
}

export default function DetalheDoCadastro({ detalhe, podeAprovar, ocupado, onAprovar, onRecusar }: Props) {
  const [arquivos, setArquivos] = useState<ArquivosDoCadastro | null>(null);
  const [erroArquivos, setErroArquivos] = useState<string | null>(null);

  // Pedido com Casa de Oração DIGITADA (não estava na lista): quem aprova escolhe a casa cadastrada correta
  const semCasa = detalhe.casa_oracao_id === null;
  const [casas, setCasas] = useState<{ id: string; nome: string }[] | null>(null);
  const [erroCasas, setErroCasas] = useState<string | null>(null);
  const [casaId, setCasaId] = useState("");
  useEffect(() => {
    let ativo = true;
    if (!semCasa || detalhe.status !== "PENDENTE") return;
    // Só as casas que quem aprova enxerga (o banco aplica a abrangência)
    listarOrganizacaoParaSelecao()
      .then((nos) => {
        if (!ativo) return;
        const lista = nos
          .filter((no) => String(no.nivel) === "CASA_ORACAO")
          .map((no) => ({ id: no.id, nome: no.nome }))
          .sort((a, b) => a.nome.localeCompare(b.nome, "pt-BR"));
        setCasas(lista);
      })
      .catch(() => ativo && setErroCasas("Não foi possível carregar a lista de Casas de Oração."));
    return () => {
      ativo = false;
    };
  }, [semCasa, detalhe.status]);

  // Busca os endereços temporários das imagens quando o detalhe abre
  useEffect(() => {
    let ativo = true;
    if (!detalhe.arquivos_disponiveis) return;
    arquivosDoCadastro(detalhe.id)
      .then((r) => ativo && setArquivos(r))
      .catch((e: unknown) => ativo && setErroArquivos(e instanceof Error ? e.message : "Não foi possível carregar as imagens."));
    return () => {
      ativo = false;
    };
  }, [detalhe.id, detalhe.arquivos_disponiveis]);

  const linhas = compararComAtual(detalhe);
  const atualizacao = detalhe.tipo === "ATUALIZACAO";
  const mudancas = quantosMudaram(linhas);
  const pendente = detalhe.status === "PENDENTE";

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-2">
        <Badge variante={VARIANTE_STATUS[detalhe.status]}>{ROTULO_STATUS[detalhe.status]}</Badge>
        <Badge variante="neutro">{ROTULO_TIPO[detalhe.tipo]}</Badge>
        {detalhe.menor && <Badge variante="marca">Menor de idade</Badge>}
      </div>

      {detalhe.cpf_conflito && (
        <p role="alert" className="flex gap-2 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
          Já existe um membro com este CPF, mas com outra data de nascimento. Confira com a pessoa antes de decidir: este
          pedido não pode ser aprovado como novo cadastro enquanto o CPF existir.
        </p>
      )}
      {semCasa && detalhe.status === "PENDENTE" && (
        <section className="space-y-2 rounded-lg border border-amber-300 bg-amber-50 px-3 py-3 text-sm text-amber-950">
          <p role="alert">
            <strong>Casa de Oração não cadastrada.</strong> A pessoa digitou: “{detalhe.casa_nome_informada ?? detalhe.casa_nome ?? "—"}”.
            Escolha abaixo a casa correta. Se ela ainda não existe, cadastre-a antes em <strong>Organização</strong> e volte aqui.
          </p>
          {erroCasas ? (
            <p className="text-red-700">{erroCasas}</p>
          ) : !casas ? (
            <Skeleton className="h-9" />
          ) : (
            <select
              aria-label="Casa de Oração correta"
              value={casaId}
              onChange={(e) => setCasaId(e.target.value)}
              disabled={ocupado}
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 [color-scheme:light]"
            >
              <option value="">Selecione a Casa de Oração</option>
              {casas.map((c) => (
                <option key={c.id} value={c.id}>{c.nome}</option>
              ))}
            </select>
          )}
        </section>
      )}
      {detalhe.outros_pendentes > 0 && (
        <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900">
          Há {detalhe.outros_pendentes} outro(s) pedido(s) pendente(s) com este CPF. Aprove só um e recuse os demais.
        </p>
      )}
      {detalhe.status === "REJEITADO" && detalhe.motivo_rejeicao && (
        <p className="rounded-lg bg-slate-100 px-3 py-2 text-sm text-slate-800">
          <strong>Motivo da recusa:</strong> {detalhe.motivo_rejeicao}
        </p>
      )}
      {atualizacao && (
        <p className="rounded-lg bg-brand-50 px-3 py-2 text-sm text-slate-800">
          Esta pessoa já tem cadastro. Ao aprovar, os dados abaixo <strong>substituem</strong> os atuais
          {mudancas > 0 ? ` (${mudancas} campo(s) diferente(s), em destaque)` : " (nenhum campo mudou)"}.
        </p>
      )}

      {/* Fotografia e documento */}
      {detalhe.arquivos_disponiveis ? (
        erroArquivos ? (
          <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erroArquivos}</p>
        ) : !arquivos ? (
          <Skeleton className="h-40" />
        ) : !arquivos.disponivel ? (
          <p className="text-sm text-slate-500">As imagens deste cadastro não estão mais disponíveis.</p>
        ) : (
          <div className="grid grid-cols-3 gap-3">
            <Imagem url={arquivos.foto} rotulo="Fotografia" alto="h-40" />
            <Imagem url={arquivos.frente} rotulo="Documento (frente)" alto="h-40" />
            <Imagem url={arquivos.verso} rotulo="Documento (verso)" alto="h-40" />
            {!arquivos.documentos_liberados && (
              <p className="col-span-3 text-xs text-slate-500">O documento só aparece para quem tem a permissão CPF.</p>
            )}
          </div>
        )
      ) : (
        <p className="text-sm text-slate-500">As imagens não estão mais guardadas (aprovadas ou apagadas pela limpeza automática).</p>
      )}

      {/* Dados pessoais */}
      <section>
        <h3 className="mb-2 border-b border-slate-200 pb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">Identificação</h3>
        <dl className="grid grid-cols-[8rem_1fr] gap-x-3 gap-y-1 text-sm">
          <dt className="text-slate-500">Nome</dt>
          <dd className="font-medium text-slate-900">{detalhe.nome ?? "(removido)"}</dd>
          <dt className="text-slate-500">CPF</dt>
          <dd className="tabular-nums text-slate-900">{detalhe.cpf ?? "—"}</dd>
          <dt className="text-slate-500">Nascimento</dt>
          <dd className="text-slate-900">{formatarData(detalhe.data_nascimento)}</dd>
          <dt className="text-slate-500">Enviado em</dt>
          <dd className="text-slate-900">{formatarDataHora(detalhe.criado_em)}</dd>
          <dt className="text-slate-500">Aceite LGPD</dt>
          <dd className="text-slate-900">versão {detalhe.aviso_versao}, em {formatarDataHora(detalhe.aceite_em)}</dd>
        </dl>
      </section>

      {detalhe.menor && (
        <section>
          <h3 className="mb-2 border-b border-slate-200 pb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">Responsável</h3>
          <dl className="grid grid-cols-[8rem_1fr] gap-x-3 gap-y-1 text-sm">
            <dt className="text-slate-500">Nome</dt>
            <dd className="text-slate-900">{detalhe.responsavel_nome ?? "—"}</dd>
            <dt className="text-slate-500">Telefone</dt>
            <dd className="tabular-nums text-slate-900">{detalhe.responsavel_telefone ?? "—"}</dd>
          </dl>
        </section>
      )}

      <section>
        <h3 className="mb-2 border-b border-slate-200 pb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
          {atualizacao ? "Hoje × pedido" : "Dados do cadastro"}
        </h3>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="text-left text-xs uppercase tracking-wide text-slate-500">
                <th scope="col" className="py-1 pr-3 font-semibold">Campo</th>
                {atualizacao && <th scope="col" className="py-1 pr-3 font-semibold">Hoje</th>}
                <th scope="col" className="py-1 font-semibold">{atualizacao ? "Pedido" : "Informado"}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {linhas.map((l) => (
                <tr key={l.chave} className={l.mudou ? "bg-amber-50" : undefined}>
                  <th scope="row" className="py-1.5 pr-3 text-left font-normal text-slate-500">{l.rotulo}</th>
                  {atualizacao && <td className="py-1.5 pr-3 text-slate-700">{l.atual}</td>}
                  <td className={"py-1.5 " + (l.mudou ? "font-semibold text-slate-900" : "text-slate-800")}>{l.novo}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {pendente && podeAprovar && (
        <div className="flex flex-wrap gap-2 border-t border-slate-200 pt-4">
          <Button icone={Check} onClick={() => onAprovar(semCasa ? casaId : undefined)} disabled={ocupado || (detalhe.cpf_conflito && !atualizacao) || (semCasa && casaId === "")}>
            Aprovar
          </Button>
          <Button variante="perigo" icone={X} onClick={onRecusar} disabled={ocupado}>
            Recusar
          </Button>
        </div>
      )}
    </div>
  );
}
