import type { NextConfig } from "next";

// Quem o navegador pode carregar/contatar. Turnstile = "não sou robô" do formulário público; Supabase = banco, login e
// arquivos (fotos/documentos por link temporário); ViaCEP = consulta de endereço pelo CEP no cadastro.
// 'unsafe-inline' nos scripts e estilos é necessário porque o Next.js e o tema escuro usam trechos embutidos.
const POLITICA_CSP = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline' https://challenges.cloudflare.com",
  "style-src 'self' 'unsafe-inline'",
  // https: porque a logomarca dos relatórios pode ser um endereço https qualquer (imagem não executa código)
  "img-src 'self' data: blob: https:",
  "font-src 'self' data:",
  "connect-src 'self' https://*.supabase.co wss://*.supabase.co https://viacep.com.br",
  "frame-src https://challenges.cloudflare.com",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "frame-ancestors 'self'",
].join("; ");

const nextConfig: NextConfig = {
  /* config options here */
  cacheComponents: true,
  // Cabeçalhos de segurança em todas as páginas (auditoria). Não mexa sem testar: o formulário público usa o
  // Cloudflare Turnstile. A Content-Security-Policy está VALENDO (bloqueia o que não está na lista POLITICA_CSP).
  // Se alguma tela nova precisar de um endereço externo, acrescente-o na lista; para só observar sem bloquear, troque
  // a chave abaixo por "Content-Security-Policy-Report-Only".
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains" }, // só HTTPS
          { key: "X-Content-Type-Options", value: "nosniff" }, // o navegador não "adivinha" tipos de arquivo
          { key: "X-Frame-Options", value: "SAMEORIGIN" }, // ninguém embute o sistema em outro site
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" }, // não vaza endereços internos
          { key: "Permissions-Policy", value: "camera=(self), microphone=(), geolocation=(), payment=()" },
          { key: "Content-Security-Policy", value: POLITICA_CSP },
        ],
      },
    ];
  },
  partialPrefetching: true,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
