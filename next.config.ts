import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  cacheComponents: true,
  // Cabeçalhos de segurança em todas as páginas (auditoria). Não mexa sem testar: o formulário público usa o
  // Cloudflare Turnstile, então ainda NÃO há Content-Security-Policy (fica para uma etapa própria).
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
