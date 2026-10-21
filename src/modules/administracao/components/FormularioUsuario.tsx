"use client";

/**
 * SysMúsica — Formulário de usuário (novo ou edição).
 * usuario = null -> criar conta (nome, e-mail, senha e grupos); preenchido -> editar nome e grupos.
 * O usuário pode ter VÁRIOS grupos: as permissões dos grupos marcados se somam. O e-mail não muda
 * depois de criado. Senha de conta existente: use "Redefinir senha".
 * A criação passa pelo servidor (precisa da chave secreta); a edição usa uma função do banco que
 * grava nome, situação e todos os grupos de uma vez (tudo ou nada).
 */
import { useEffect, useState, type FormEvent } from "react";
import { Eye, EyeOff } from "lucide-react";
import Button from "@/components/ui/Button";
import { alternarGrupo, validarGruposEscolhidos } from "../gruposDoUsuario";
import { SENHA_MINIMA, validarNome, validarSenha } from "../regras";
import {
  criarUsuario,
  listarGruposDosUsuarios,
  listarUsuarios,
  salvarUsuarioComGrupos,
} from "../services/acesso";
import type { GrupoAcesso, UsuarioSistema } from "../tipos";

interface FormularioUsuarioProps {
  usuario: UsuarioSistema | null;
  grupos: GrupoAcesso[];
  meuId: string | null;
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:opacity-70";

const classeBotaoSecundario =
  "rounded-lg border border-slate-300 bg-white px-2.5 py-1 text-xs font-medium text-slate-700 " +
  "transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioUsuario({ usuario, grupos, meuId, onSalvo }: FormularioUsuarioProps) {
  const editando = usuario !== null;

  const [nome, setNome] = useState(usuario?.nome ?? "");
  const [email, setEmail] = useState(usuario?.email ?? "");
  const [senha, setSenha] = useState("");
  const [confirmacao, setConfirmacao] = useState("");
  const [mostrarSenha, setMostrarSenha] = useState(false);
  // Grupos marcados (ids). Na edição começa pelo grupo principal e, logo em seguida, carrega todos os grupos do usuário.
  const [gruposEscolhidos, setGruposEscolhidos] = useState<string[]>(usuario?.grupo_id ? [usuario.grupo_id] : []);
  const [carregandoGrupos, setCarregandoGrupos] = useState(editando);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

   
  useEffect(() => {
    if (!usuario) return;
    let cancelado = false;
    void listarGruposDosUsuarios()
      .then((mapa) => {
        if (cancelado) return;
        const lista = mapa[usuario.id];
        if (lista && lista.length > 0) setGruposEscolhidos(lista);
        setCarregandoGrupos(false);
      })
      .catch(() => {
        // Sem a lista completa, o formulário segue com o grupo principal e avisa ao salvar se algo falhar
        if (!cancelado) setCarregandoGrupos(false);
      });
    return () => {
      cancelado = true;
    };
  }, [usuario]);
   

  // Só grupos ativos podem ser escolhidos (e os que o usuário já tem, mesmo inativos, continuam visíveis)
  const gruposDisponiveis = grupos.filter((grupo) => grupo.ativo || gruposEscolhidos.includes(grupo.id));

  function marcarTodos() {
    setGruposEscolhidos(grupos.filter((grupo) => grupo.ativo).map((grupo) => grupo.id));
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando || carregandoGrupos) return; // evita envio duplicado
    setErro(null);

    const erroNome = validarNome(nome);
    if (erroNome) return setErro(erroNome);
    const erroGrupos = validarGruposEscolhidos(gruposEscolhidos);
    if (erroGrupos) return setErro(erroGrupos);

    if (!editando) {
      const erroSenha = validarSenha(senha);
      if (erroSenha) return setErro(erroSenha);
      if (senha !== confirmacao) return setErro("A confirmação da senha não confere.");
    }

    setSalvando(true);
    try {
      if (usuario) {
        await salvarUsuarioComGrupos({
          id: usuario.id,
          nome: nome.trim(),
          grupos: gruposEscolhidos,
          ativo: usuario.ativo,
        });
        await onSalvo(`Usuário "${nome.trim()}" atualizado.`);
      } else {
        // A conta nasce com o primeiro grupo; se houver mais, eles são aplicados em seguida
        await criarUsuario({ nome: nome.trim(), email, senha, grupoId: gruposEscolhidos[0] });

        if (gruposEscolhidos.length > 1) {
          try {
            const lista = await listarUsuarios();
            const novo = lista.find((item) => item.email.toLowerCase() === email.trim().toLowerCase());
            if (!novo) throw new Error("Usuário criado não encontrado.");
            await salvarUsuarioComGrupos({
              id: novo.id,
              nome: nome.trim(),
              grupos: gruposEscolhidos,
              ativo: true,
            });
          } catch {
            await onSalvo(
              `Usuário "${nome.trim()}" criado só com o primeiro grupo. Edite o usuário para marcar os demais.`
            );
            return;
          }
        }
        await onSalvo(`Usuário "${nome.trim()}" criado. Informe a senha a ele por um canal seguro.`);
      }
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar o usuário.");
    } finally {
      setSalvando(false);
    }
  }

  if (gruposDisponiveis.length === 0) {
    return (
      <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
        Não há grupos ativos. Crie um grupo em Administração &gt; Grupos e permissões antes de
        cadastrar usuários.
      </p>
    );
  }

  const bloqueado = salvando || carregandoGrupos;

  return (
    <form onSubmit={salvar} className="space-y-5">
      {editando && usuario.id === meuId && (
        <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
          Você está editando a sua própria conta. Mudar os seus grupos pode remover o seu acesso a
          algumas telas.
        </p>
      )}

      <div className="space-y-1.5">
        <label htmlFor="nome-usuario" className="text-sm font-medium text-slate-700">
          Nome
        </label>
        <input
          id="nome-usuario"
          type="text"
          required
          maxLength={80}
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Maria da Silva"
          className={classeInput}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="email-usuario" className="text-sm font-medium text-slate-700">
          E-mail (usado no login)
        </label>
        <input
          id="email-usuario"
          type="email"
          required
          maxLength={254}
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          disabled={salvando || editando}
          placeholder="maria@exemplo.com"
          className={classeInput}
        />
      </div>

      {!editando && (
        <>
          <div className="space-y-1.5">
            <label htmlFor="senha-usuario" className="text-sm font-medium text-slate-700">
              Senha inicial
            </label>
            <div className="relative">
              <input
                id="senha-usuario"
                type={mostrarSenha ? "text" : "password"}
                required
                autoComplete="new-password"
                value={senha}
                onChange={(e) => setSenha(e.target.value)}
                disabled={salvando}
                className={`${classeInput} pr-10`}
              />
              <button
                type="button"
                onClick={() => setMostrarSenha((atual) => !atual)}
                aria-label={mostrarSenha ? "Ocultar senha" : "Mostrar senha"}
                className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-slate-500 transition hover:text-slate-900"
              >
                {mostrarSenha ? (
                  <EyeOff className="h-4 w-4" aria-hidden="true" />
                ) : (
                  <Eye className="h-4 w-4" aria-hidden="true" />
                )}
              </button>
            </div>
            <p className="text-xs text-slate-500">
              Mínimo de {SENHA_MINIMA} caracteres, misturando letras e números.
            </p>
          </div>

          <div className="space-y-1.5">
            <label htmlFor="confirmacao-usuario" className="text-sm font-medium text-slate-700">
              Confirmar a senha
            </label>
            <input
              id="confirmacao-usuario"
              type={mostrarSenha ? "text" : "password"}
              required
              autoComplete="new-password"
              value={confirmacao}
              onChange={(e) => setConfirmacao(e.target.value)}
              disabled={salvando}
              className={classeInput}
            />
          </div>
        </>
      )}

      <fieldset className="space-y-2">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <legend className="text-sm font-medium text-slate-700">Grupos de acesso</legend>
          <div className="flex gap-2">
            <button type="button" onClick={marcarTodos} disabled={bloqueado} className={classeBotaoSecundario}>
              Marcar todos
            </button>
            <button
              type="button"
              onClick={() => setGruposEscolhidos([])}
              disabled={bloqueado || gruposEscolhidos.length === 0}
              className={classeBotaoSecundario}
            >
              Limpar
            </button>
          </div>
        </div>

        {carregandoGrupos ? (
          <p className="text-sm text-slate-500">Carregando os grupos do usuário...</p>
        ) : (
          <ul className="max-h-72 space-y-2 overflow-y-auto rounded-lg border border-slate-200 p-3">
            {gruposDisponiveis.map((grupo) => (
              <li key={grupo.id}>
                <label className="flex items-start gap-2 text-sm text-slate-700">
                  <input
                    type="checkbox"
                    checked={gruposEscolhidos.includes(grupo.id)}
                    onChange={() => setGruposEscolhidos((atuais) => alternarGrupo(atuais, grupo.id))}
                    disabled={salvando}
                    className="mt-0.5 h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300"
                  />
                  <span className="min-w-0">
                    <span className="font-medium text-slate-900">
                      {grupo.nome}
                      {grupo.ativo ? "" : " (inativo)"}
                    </span>
                    {grupo.descricao && <span className="block text-xs text-slate-500">{grupo.descricao}</span>}
                  </span>
                </label>
              </li>
            ))}
          </ul>
        )}
        <p className="text-xs text-slate-500">
          As permissões dos grupos marcados se somam. Marque quantos forem necessários.
        </p>
      </fieldset>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={bloqueado} className="w-full">
        {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Criar usuário"}
      </Button>
    </form>
  );
}
