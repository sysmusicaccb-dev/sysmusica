/**
 * SysMúsica — Estado de erro (UI base) com botão opcional "Tentar novamente".
 * Mostre mensagens simples ao usuário; o detalhe técnico fica no console.
 */
interface ErrorStateProps {
  titulo: string;
  mensagem: string;
  onTentarNovamente?: () => void;
}

export default function ErrorState({ titulo, mensagem, onTentarNovamente }: ErrorStateProps) {
  return (
    <div role="alert" className="rounded-2xl border border-red-200 bg-red-50 p-6">
      <p className="font-semibold text-red-800">{titulo}</p>
      <p className="mt-1 text-sm text-red-700">{mensagem}</p>
      {onTentarNovamente && (
        <button
          type="button"
          onClick={onTentarNovamente}
          className="mt-4 rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-red-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-red-300"
        >
          Tentar novamente
        </button>
      )}
    </div>
  );
}
