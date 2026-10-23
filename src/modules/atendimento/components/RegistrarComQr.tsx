"use client";

/**
 * Sysmusica — Registrar Presença com QR Code (conteúdo do popup da tela Registrar Presença).
 * Lê o QR Code do membro pela câmera (ou busca pelo nome), abre a conferência (foto e dados) e registra a entrada.
 * Ao registrar, avisa a tela (onRegistrado) e ela fecha o popup. A regra é a mesma da tela Portaria:
 * o banco confere de novo a portaria, a janela de atendimento, a abrangência e a permissão.
 */
import { useEffect, useState } from "react";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { pareceQrSysMusica } from "../regras";
import { valoresDaEntrada } from "../regrasEntrada";
import { buscarMembroPorQr, recarregarCartao, registrarEntrada } from "../services/atendimento";
import { infoEntrada } from "../services/entrada";
import type { CartaoMembro, OrigemEntrada } from "../tipos";
import type { EscolhaToca, InfoEntrada, OpcoesEntrada } from "../tiposEntrada";
import BuscaPorNome from "./BuscaPorNome";
import CartaoConferencia from "./CartaoConferencia";
import LeitorQr from "./LeitorQr";

interface RegistrarComQrProps {
  portariaId: string;
  opcoes: OpcoesEntrada | null; // instrumentos para a pergunta "Vai tocar?"
  onRegistrado: (mensagem: string) => void | Promise<void>;
}

export default function RegistrarComQr({ portariaId, opcoes, onRegistrado }: RegistrarComQrProps) {
  const { pode } = useSessao();
  const [cartao, setCartao] = useState<{ membro: CartaoMembro; origem: OrigemEntrada } | null>(null);
  const [info, setInfo] = useState<InfoEntrada | null>(null); // como o membro conferido será contado
  const [escolha, setEscolha] = useState<EscolhaToca>({ toca: null, instrumentoId: "" });
  const [consultando, setConsultando] = useState(false);
  const [registrando, setRegistrando] = useState(false);
  const [erroCartao, setErroCartao] = useState<string | null>(null);
  const [erroLeitura, setErroLeitura] = useState<string | null>(null);

  // O aviso de leitura some sozinho depois de alguns segundos
  useEffect(() => {
    if (!erroLeitura) return;
    const temporizador = setTimeout(() => setErroLeitura(null), 5000);
    return () => clearTimeout(temporizador);
  }, [erroLeitura]);

  // Abre a conferência: antes, consulta se a pessoa precisa responder "Vai tocar?"
  async function abrirCartao(membro: CartaoMembro, origem: OrigemEntrada) {
    try {
      setInfo(await infoEntrada(portariaId, membro.membro_id));
      setEscolha({ toca: null, instrumentoId: "" });
      setErroCartao(null);
      setCartao({ membro, origem });
    } catch (e) {
      setErroLeitura(e instanceof Error ? e.message : "Não foi possível abrir a conferência.");
    }
  }

  // QR Code lido: consulta o membro e abre a conferência
  async function aoLerQr(texto: string) {
    if (cartao || consultando) return;
    setErroLeitura(null);
    if (!pareceQrSysMusica(texto)) {
      setErroLeitura("Este QR Code não é do Sysmusica.");
      return;
    }
    setConsultando(true);
    try {
      const membro = await buscarMembroPorQr(portariaId, texto);
      await abrirCartao(membro, "QR");
    } catch (e) {
      setErroLeitura(e instanceof Error ? e.message : "Não foi possível ler o QR Code.");
    } finally {
      setConsultando(false);
    }
  }

  // Foto tirada na conferência: recarrega os dados do cartão
  async function aoSalvarFotoNoCartao() {
    if (!cartao) return;
    const atualizado = await recarregarCartao(portariaId, cartao.membro.membro_id);
    setCartao({ membro: atualizado, origem: cartao.origem });
  }

  async function confirmar() {
    if (!cartao || registrando) return;
    setRegistrando(true);
    setErroCartao(null);
    try {
      const valores = valoresDaEntrada(info, escolha);
      await registrarEntrada(portariaId, cartao.membro.membro_id, cartao.origem, valores.toca, valores.instrumentoId);
      const nome = cartao.membro.nome;
      setCartao(null);
      await onRegistrado(`Presença registrada: ${nome}`); // a tela fecha o popup
    } catch (e) {
      setErroCartao(e instanceof Error ? e.message : "Não foi possível registrar a entrada.");
    } finally {
      setRegistrando(false);
    }
  }

  return (
    <div className="space-y-4">
      <LeitorQr ativo={!cartao && !consultando} onLeitura={(texto) => void aoLerQr(texto)} />

      {(erroLeitura || consultando) && (
        <p
          role={erroLeitura ? "alert" : "status"}
          className={"rounded-lg px-3 py-2 text-sm " + (erroLeitura ? "bg-red-50 text-red-700" : "bg-slate-50 text-slate-600")}
        >
          {erroLeitura ?? "Consultando o QR Code..."}
        </p>
      )}

      {/* Sem câmera ou sem QR: busca pelo nome, como na tela Portaria */}
      <BuscaPorNome portariaId={portariaId} desabilitado={cartao !== null} onEscolher={(membro) => void abrirCartao(membro, "MANUAL")} />

      {cartao && (
        <CartaoConferencia
          // A chave reinicia a caixa "conferi a identidade" a cada membro
          key={cartao.membro.membro_id}
          membro={cartao.membro}
          origem={cartao.origem}
          registrando={registrando}
          erro={erroCartao}
          onConfirmar={() => void confirmar()}
          onCancelar={() => setCartao(null)}
          podeFoto={pode("membros.foto")}
          onFotoSalva={aoSalvarFotoNoCartao}
          info={info}
          instrumentos={opcoes?.instrumentos ?? []}
          escolha={escolha}
          onEscolha={setEscolha}
        />
      )}
    </div>
  );
}
