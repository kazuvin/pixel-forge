import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

async function source(path) {
  return readFile(new URL(path, root), "utf8");
}

test("every stable Japanese and English route is statically authored", async () => {
  const routes = [
    "src/pages/index.astro",
    "src/pages/ja/support.astro",
    "src/pages/ja/privacy.astro",
    "src/pages/ja/terms.astro",
    "src/pages/en/support.astro",
    "src/pages/en/privacy.astro",
    "src/pages/en/terms.astro",
    "src/pages/404.astro",
  ];

  for (const route of routes) {
    assert.match(await source(route), /LegalPage|SupportPage|LandingPage|NotFoundPage/);
  }
});

test("Astro and Workers are configured for static assets only", async () => {
  const astro = await source("astro.config.mjs");
  const wrangler = await source("wrangler.jsonc");

  assert.match(astro, /output:\s*["']static["']/);
  assert.doesNotMatch(astro, /adapter|cloudflare/);
  assert.match(wrangler, /"directory"\s*:\s*"\.\/dist"/);
  assert.match(wrangler, /"not_found_handling"\s*:\s*"404-page"/);
  assert.doesNotMatch(wrangler, /"main"\s*:/);
});

test("security headers and privacy disclosures cover the static support site", async () => {
  const headers = await source("public/_headers");
  const privacy = await source("src/content/copy.ts");

  assert.match(headers, /Content-Security-Policy:/);
  assert.match(headers, /X-Content-Type-Options:\s*nosniff/);
  assert.match(headers, /Referrer-Policy:/);
  assert.match(privacy, /Google Forms/);
  assert.match(privacy, /ローカル/);
});
