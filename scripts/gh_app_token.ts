#!/usr/bin/env bun
// Mints a short-lived GitHub App installation access token for mmio-claude-agent.
//
// Needs MMIO_GH_APP_ID, MMIO_GH_APP_INSTALLATION_ID, and MMIO_GH_APP_PRIVATE_KEY_PATH
// (path to the App's downloaded .pem) set in the environment — see docs/runbooks/ for
// how to get these three values from the GitHub dashboard. Namespaced with an MMIO_
// prefix because ~/.claude/.env already holds a second GitHub App's credentials
// (schoolshopla-claude-agent) under the unprefixed GH_APP_* names — reusing those names
// here would silently collide. Prints the token to stdout so it can be captured
// directly: `TOKEN=$(bun scripts/gh_app_token.ts)`.
import { readFile } from "node:fs/promises";
import { createSign } from "node:crypto";

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) {
    console.error(`Missing required env var: ${name}`);
    process.exit(1);
  }
  return v;
}

function base64url(input: Buffer | string): string {
  return Buffer.from(input).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function signJwt(appId: string, privateKeyPem: string): string {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  // Backdate iat by 60s to tolerate clock drift between this host and GitHub's, per
  // GitHub's own App-auth docs. exp capped at 10 minutes, the API's hard max.
  const payload = { iat: now - 60, exp: now + 9 * 60, iss: appId };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = createSign("RSA-SHA256").update(signingInput).end().sign(privateKeyPem);
  return `${signingInput}.${base64url(signature)}`;
}

async function main() {
  const appId = requireEnv("MMIO_GH_APP_ID");
  const installationId = requireEnv("MMIO_GH_APP_INSTALLATION_ID");
  const privateKeyPath = requireEnv("MMIO_GH_APP_PRIVATE_KEY_PATH");
  const privateKeyPem = await readFile(privateKeyPath, "utf8");

  const jwt = signJwt(appId, privateKeyPem);

  const res = await fetch(`https://api.github.com/app/installations/${installationId}/access_tokens`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${jwt}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
    },
  });

  if (!res.ok) {
    console.error(`GitHub API error ${res.status}: ${await res.text()}`);
    process.exit(1);
  }

  const body = (await res.json()) as { token: string; expires_at: string };
  console.error(`Installation token expires at ${body.expires_at}`);
  console.log(body.token);
}

main();
