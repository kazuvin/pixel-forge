import path from "node:path";
import { fileURLToPath } from "node:url";

import react from "@vitejs/plugin-react";
import { createServer } from "vite";

import {
  buildProject,
  createLocalSpriteApi,
  parseProjectArguments,
  verifyProjectFiles,
} from "./server/local-project.mjs";

const applicationRoot = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(applicationRoot, "../..");
const project = parseProjectArguments(process.argv.slice(2), repositoryRoot);

await verifyProjectFiles(project);
const buildLog = await buildProject(project);

const server = await createServer({
  configFile: false,
  root: applicationRoot,
  appType: "spa",
  clearScreen: false,
  plugins: [react(), createLocalSpriteApi(project)],
  server: {
    host: "127.0.0.1",
    port: 4317,
    strictPort: false,
  },
});

await server.listen();
console.log(buildLog);
console.log("Sprite Rig Editor is local-only and bound to 127.0.0.1.");
server.printUrls();
