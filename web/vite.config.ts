import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// base relativo ('./'): il sito funziona sia in locale sia servito da
// https://USERNAME.github.io/NOME_REPO/ senza dover conoscere il nome del repo.
export default defineConfig({
  base: "./",
  plugins: [react()],
});
