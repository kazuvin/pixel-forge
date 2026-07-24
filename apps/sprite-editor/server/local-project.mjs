import { spawn } from "node:child_process";
import { createReadStream } from "node:fs";
import {
  access,
  mkdtemp,
  readFile,
  rename,
  rm,
  unlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

const DEFAULTS = {
  manifest: "examples/sprites/rock-golem/rock-golem.sprite.json",
  source: "examples/sprites/rock-golem/rock-golem.parts.png",
  output: "examples/sprites/rock-golem/output",
};

const JSON_BODY_LIMIT = 2 * 1024 * 1024;

export function resolveInsideRepository(repositoryRoot, value, label) {
  const resolved = path.resolve(repositoryRoot, value);
  const relative = path.relative(repositoryRoot, resolved);
  if (
    relative === "" ||
    relative === ".." ||
    relative.startsWith(`..${path.sep}`) ||
    path.isAbsolute(relative)
  ) {
    throw new Error(`${label} must stay inside the repository`);
  }
  return resolved;
}

export function parseProjectArguments(argumentsList, repositoryRoot) {
  const values = { ...DEFAULTS };
  const optionNames = {
    "--manifest": "manifest",
    "--source": "source",
    "--output": "output",
  };

  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (argument === "--") {
      continue;
    }
    const key = optionNames[argument];
    if (!key) {
      throw new Error(`unknown option ${argument}`);
    }
    const value = argumentsList[index + 1];
    if (!value || value.startsWith("--")) {
      throw new Error(`${argument} requires a path`);
    }
    values[key] = value;
    index += 1;
  }

  return {
    repositoryRoot,
    manifestPath: resolveInsideRepository(
      repositoryRoot,
      values.manifest,
      "manifest",
    ),
    sourcePath: resolveInsideRepository(repositoryRoot, values.source, "source"),
    outputPath: resolveInsideRepository(repositoryRoot, values.output, "output"),
  };
}

export async function verifyProjectFiles(project) {
  await access(project.manifestPath);
  await access(project.sourcePath);
}

export async function readProject(project) {
  const manifest = JSON.parse(await readFile(project.manifestPath, "utf8"));
  return {
    manifest,
    paths: {
      manifest: path.relative(project.repositoryRoot, project.manifestPath),
      source: path.relative(project.repositoryRoot, project.sourcePath),
      output: path.relative(project.repositoryRoot, project.outputPath),
    },
    revision: Date.now().toString(),
  };
}

function runPixelCli(project, manifestPath, outputPath) {
  const argumentsList = [
    "run",
    "-q",
    "-p",
    "pixel-cli",
    "--",
    "sprite",
    "build",
    manifestPath,
    "--source",
    project.sourcePath,
    "--output",
    outputPath,
  ];

  return new Promise((resolve, reject) => {
    const child = spawn("cargo", argumentsList, {
      cwd: project.repositoryRoot,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) {
        resolve([stdout.trim(), stderr.trim()].filter(Boolean).join("\n"));
        return;
      }
      reject(
        new Error(
          [stderr.trim(), stdout.trim(), `pixel-cli exited with ${code}`]
            .filter(Boolean)
            .join("\n"),
        ),
      );
    });
  });
}

export async function buildProject(project) {
  return runPixelCli(project, project.manifestPath, project.outputPath);
}

export async function saveAndBuildProject(project, manifest) {
  const serialized = `${JSON.stringify(manifest, null, 2)}\n`;
  const temporaryRoot = await mkdtemp(
    path.join(tmpdir(), "pixel-forge-sprite-editor-"),
  );
  const temporaryManifest = path.join(temporaryRoot, "candidate.sprite.json");
  const temporaryOutput = path.join(temporaryRoot, "output");
  const siblingTemporary = `${project.manifestPath}.sprite-editor-${process.pid}.tmp`;

  try {
    await writeFile(temporaryManifest, serialized, "utf8");
    await runPixelCli(project, temporaryManifest, temporaryOutput);
    await writeFile(siblingTemporary, serialized, "utf8");
    await rename(siblingTemporary, project.manifestPath);
    const log = await runPixelCli(
      project,
      project.manifestPath,
      project.outputPath,
    );
    return { log, revision: Date.now().toString() };
  } finally {
    await unlink(siblingTemporary).catch(() => {});
    await rm(temporaryRoot, { recursive: true, force: true });
  }
}

async function readJsonBody(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > JSON_BODY_LIMIT) {
      throw new Error("request body is too large");
    }
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function sendJson(response, statusCode, value) {
  response.statusCode = statusCode;
  response.setHeader("Content-Type", "application/json; charset=utf-8");
  response.setHeader("Cache-Control", "no-store");
  response.end(JSON.stringify(value));
}

async function sendPng(response, filePath) {
  await access(filePath);
  response.statusCode = 200;
  response.setHeader("Content-Type", "image/png");
  response.setHeader("Cache-Control", "no-store");
  createReadStream(filePath).pipe(response);
}

export function createLocalSpriteApi(project) {
  return {
    name: "pixel-forge-local-sprite-api",
    configureServer(server) {
      server.middlewares.use(async (request, response, next) => {
        const requestUrl = new URL(request.url ?? "/", "http://127.0.0.1");
        if (!requestUrl.pathname.startsWith("/api/")) {
          next();
          return;
        }

        try {
          if (
            request.method === "GET" &&
            requestUrl.pathname === "/api/project"
          ) {
            sendJson(response, 200, await readProject(project));
            return;
          }

          if (
            request.method === "POST" &&
            requestUrl.pathname === "/api/save"
          ) {
            const body = await readJsonBody(request);
            if (!body || typeof body !== "object" || !body.manifest) {
              throw new Error("manifest is required");
            }
            const result = await saveAndBuildProject(project, body.manifest);
            sendJson(response, 200, result);
            return;
          }

          const partMatch = requestUrl.pathname.match(
            /^\/api\/parts\/([a-z0-9_-]+)\.png$/i,
          );
          if (request.method === "GET" && partMatch) {
            const projectData = await readProject(project);
            const knownPart = projectData.manifest.parts.some(
              (part) => part.id === partMatch[1],
            );
            if (!knownPart) {
              sendJson(response, 404, { error: "part was not found" });
              return;
            }
            await sendPng(
              response,
              path.join(project.outputPath, "parts", `${partMatch[1]}.png`),
            );
            return;
          }

          sendJson(response, 404, { error: "local API route was not found" });
        } catch (error) {
          sendJson(response, 400, {
            error: error instanceof Error ? error.message : String(error),
          });
        }
      });
    },
  };
}
