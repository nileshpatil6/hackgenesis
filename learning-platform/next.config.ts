import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // pdf-parse pulls in pdfjs-dist, which loads its worker and font data at
  // runtime. Bundling it makes those lookups fail and every PDF silently
  // extracts to an empty string, which leaves RAG with nothing to retrieve.
  serverExternalPackages: ["pdf-parse", "pdfjs-dist", "mammoth"],
};

export default nextConfig;
