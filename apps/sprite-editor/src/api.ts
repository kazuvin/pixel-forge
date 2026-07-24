import type { ProjectPayload, SpriteManifest } from "./types";

async function readResponse<T>(response: Response): Promise<T> {
  const payload = (await response.json()) as T & { error?: string };
  if (!response.ok) {
    throw new Error(payload.error ?? `request failed with ${response.status}`);
  }
  return payload;
}

export async function loadProject(): Promise<ProjectPayload> {
  const response = await fetch("/api/project", { cache: "no-store" });
  return readResponse<ProjectPayload>(response);
}

export async function saveProject(
  manifest: SpriteManifest,
): Promise<{ log: string; revision: string }> {
  const response = await fetch("/api/save", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ manifest }),
  });
  return readResponse<{ log: string; revision: string }>(response);
}

export function partImageUrl(id: string, revision: string): string {
  return `/api/parts/${encodeURIComponent(id)}.png?revision=${encodeURIComponent(revision)}`;
}
