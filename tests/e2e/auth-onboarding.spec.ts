import { expect, test, type BrowserContext } from "@playwright/test";

import {
  authenticatedContext,
  applyRevokedRefreshState,
  createLocalIdentity,
  removeLocalIdentity,
  setLocalAccountStatus,
  type LocalIdentity,
} from "./support/local-auth";

test.describe.configure({ mode: "serial" });

const identities: LocalIdentity[] = [];

async function fixture(label: string) {
  const identity = await createLocalIdentity(label);
  identities.push(identity);
  return identity;
}

async function close(context: BrowserContext) {
  await context.close();
}

test.afterAll(async () => {
  for (const identity of identities.reverse()) {
    await removeLocalIdentity(identity);
  }
});

test("visitor is sent to Google login from protected onboarding", async ({ page }) => {
  await page.goto("/onboarding?returnTo=%2F");
  await expect(page).toHaveURL(/\/login/);
  await expect(page.getByRole("button", { name: "Continuar com Google" })).toBeVisible();
});

test("incomplete account sees database cities and a responsive onboarding form", async ({ browser }) => {
  const identity = await fixture("incomplete");
  const context = await authenticatedContext(browser, identity);
  const page = await context.newPage();

  for (const width of [360, 390, 430, 768, 1024, 1440]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/onboarding");
    await expect(page.getByRole("heading", { name: "Complete seu perfil" })).toBeVisible();
    await expect(page.getByRole("option", { name: "São Lourenço da Mata — PE" })).toHaveCount(1);
    await expect(page.getByLabel("Cidade")).toHaveValue("10000000-0000-4000-8000-000000000001");
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  }

  await expect(page.getByRole("textbox", { name: "Nome", exact: true })).toHaveValue(
    "Corredor incomplete",
  );
  await expect(page.getByLabel("Perfil privado")).not.toBeChecked();
  await close(context);
});

test("onboarding completes once, survives reload and keeps values under database authority", async ({ browser }) => {
  const identity = await fixture("complete");
  const context = await authenticatedContext(browser, identity);
  const page = await context.newPage();
  const username = `runner_${identity.id.slice(0, 8)}`;

  await page.goto("/onboarding?returnTo=%2F");
  await page.getByLabel("Nome de usuário").fill(username);
  await page.getByLabel("Nível de corrida").selectOption("intermediate");
  await page.getByLabel("Distância preferida").selectOption("5k_to_10k");
  await page.getByLabel("Pace aproximado (opcional)").fill("6:30");
  await page.getByRole("button", { name: "Concluir cadastro" }).click();
  await expect(page).toHaveURL("http://localhost:3000/");
  await expect(page.getByRole("link", { name: "Sair" })).toBeVisible();

  await page.reload();
  await expect(page.getByRole("link", { name: "Sair" })).toBeVisible();
  await page.goto("/onboarding");
  await expect(page).toHaveURL("http://localhost:3000/");
  await close(context);
});

test("logout remains effective after reload and across two tabs", async ({ browser }) => {
  const identity = await fixture("logout");
  const context = await authenticatedContext(browser, identity);
  const first = await context.newPage();
  const second = await context.newPage();

  await first.goto("/");
  await second.goto("/");
  await first.goto("/logout");
  await first.getByRole("button", { name: "Sair da conta" }).click();
  await expect(first).toHaveURL("http://localhost:3000/");

  await first.reload();
  await second.reload();
  await expect(first.getByRole("link", { name: "Entrar com Google" })).toBeVisible();
  await expect(second.getByRole("link", { name: "Entrar com Google" })).toBeVisible();
  await close(context);
});

test("suspended account is blocked even with an existing session", async ({ browser }) => {
  const identity = await fixture("suspended");
  setLocalAccountStatus(identity, "suspended");
  const context = await authenticatedContext(browser, identity);
  const page = await context.newPage();

  await page.goto("/onboarding");
  await expect(page).toHaveURL(/\/account-unavailable$/);
  await expect(page.getByRole("heading", { name: "Conta indisponível" })).toBeVisible();
  await close(context);
});

test("revoked refresh state fails closed without exposing private content", async ({ browser }) => {
  const identity = await fixture("revoked");
  const context = await authenticatedContext(browser, identity);
  await applyRevokedRefreshState(context, identity);
  const page = await context.newPage();

  await page.goto("/onboarding");
  await expect(page).not.toHaveURL(/\/onboarding$/);
  await expect(page.locator("body")).not.toContainText("Complete seu perfil");
  await close(context);
});

test("Google handoff uses only the configured OAuth authorize endpoint", async ({ page }) => {
  let authorizeUrl = "";
  await page.route("**/auth/v1/authorize**", async (route) => {
    authorizeUrl = route.request().url();
    await route.fulfill({ status: 302, headers: { location: "https://accounts.google.com/o/oauth2/v2/auth" } });
  });
  await page.route("https://accounts.google.com/**", (route) =>
    route.fulfill({ status: 200, contentType: "text/html", body: "Google OAuth boundary" }),
  );

  await page.goto("/login?returnTo=%2F");
  await page.getByRole("button", { name: "Continuar com Google" }).click({ noWaitAfter: true });
  await expect.poll(() => authorizeUrl).toContain("provider=google");
  expect(authorizeUrl).toContain("redirect_to=http%3A%2F%2Flocalhost%3A3000%2Fauth%2Fcallback");
  expect(authorizeUrl).not.toMatch(/service_role|client_secret|access_token/i);
});
