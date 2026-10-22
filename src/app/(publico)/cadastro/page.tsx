"use client";

/**
 * Sysmusica — Página pública /cadastro: Cadastro Musical sem login.
 * Carrega as opções (cargos, instrumentos, Casas de Oração) por uma função pública do banco e mostra o formulário.
 */
import { useEffect, useState } from "react";
import FormularioPublico from "@/modules/cadastroPublico/components/FormularioPublico";
import { carregarOpcoes } from "@/modules/cadastroPublico/services/envio";
import type { OpcoesCadastroPublico } from "@/modules/cadastroPublico/regras";

export default function CadastroPublicoPage() {
  const [opcoes, setOpcoes] = useState<OpcoesCadastroPublico | null>(null);
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    let ativo = true;
    carregarOpcoes()
      .then((o) => ativo && setOpcoes(o))
      .catch((e: unknown) => ativo && setErro(e instanceof Error ? e.message : "Não foi possível carregar o formulário."));
    return () => {
      ativo = false;
    };
  }, []);

  return (
    <main className="mx-auto max-w-2xl px-4 py-8 sm:px-6">
      <h1 className="text-2xl font-semibold">Cadastro Musical</h1>
      <p className="mt-1 mb-6 text-sm text-slate-600">
        Preencha seus dados. Depois do envio, a secretaria analisa o cadastro. Campos com * são obrigatórios.
      </p>
      {erro && <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erro}</p>}
      {!erro && !opcoes && <p className="text-sm text-slate-500">Carregando o formulário...</p>}
      {opcoes && <FormularioPublico opcoes={opcoes} />}
    </main>
  );
}
