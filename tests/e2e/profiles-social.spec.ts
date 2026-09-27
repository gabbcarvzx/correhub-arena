import { expect, test, type BrowserContext } from "@playwright/test";

import {
  attemptCrossUserProfileUpdate,
  authenticatedContext,
  completeLocalProfile,
  createLocalIdentity,
  removeLocalIdentity,
  setLocalAccountStatus,
  type LocalIdentity,
} from "./support/local-auth";

test.describe.configure({ mode: "serial" });

const identities: LocalIdentity[] = [];
let runnerA: LocalIdentity;
let runnerB: LocalIdentity;
let privateRunner: LocalIdentity;
let suspendedRunner: LocalIdentity;
let incompleteRunner: LocalIdentity;
let usernameA: string;
let usernameB: string;
let privateUsername: string;
let suspendedUsername: string;
let incompleteUsername: string;

async function fixture(label: string) {
  const identity = await createLocalIdentity(label);
  identities.push(identity);
  return identity;
}

async function close(context: BrowserContext) {
  await context.close();
}

test.beforeAll(async () => {
  runnerA = await fixture("social-a");
  runnerB = await fixture("social-b");
  privateRunner = await fixture("social-private");
  suspendedRunner = await fixture("social-suspended");
  incompleteRunner = await fixture("social-incomplete");
  usernameA = `runner_a_${runnerA.id.slice(0, 8)}`;
  usernameB = `runner_b_${runnerB.id.slice(0, 8)}`;
  privateUsername = `private_${privateRunner.id.slice(0, 8)}`;
  suspendedUsername = `suspended_${suspendedRunner.id.slice(0, 8)}`;
  incompleteUsername = `incomplete_${incompleteRunner.id.slice(0, 8)}`;
  await completeLocalProfile(runnerA, { username: usernameA, fullName: "Runner A", bio: "Bio A" });
  await completeLocalProfile(runnerB, { username: usernameB, fullName: "Runner B", bio: "Bio pública B" });
  await completeLocalProfile(privateRunner, { username: privateUsername, fullName: "Runner Private", bio: "Segredo privado", isPrivate: true });
  await completeLocalProfile(suspendedRunner, { username: suspendedUsername, fullName: "Runner Suspended" });
  setLocalAccountStatus(suspendedRunner, "suspended");
  // The incomplete identity deliberately keeps the trigger-created empty profile.
  expect(incompleteUsername).toContain("incomplete_");
});

test.afterAll(async () => {
  for (const identity of identities.reverse()) await removeLocalIdentity(identity);
});

test("visitor sees a public profile and only minimal private identity", async ({ page }) => {
  await page.goto(`/u/${usernameB}`);
  await expect(page.getByRole("heading", { name: "Runner B" })).toBeVisible();
  await expect(page.getByText("Bio pública B")).toBeVisible();
  await page.goto(`/u/${privateUsername}`);
  await expect(page.getByText("Perfil privado")).toBeVisible();
  await expect(page.getByText("Segredo privado")).toHaveCount(0);
  await expect(page.getByText(/São Lourenço/)).toHaveCount(0);
  await expect(page.getByText(/min\/km/)).toHaveCount(0);
  await expect(page.getByRole("link", { name: /seguidores|seguindo/i })).toHaveCount(0);
});

test("follow and unfollow persist after reload", async ({ browser }) => {
  const context = await authenticatedContext(browser, runnerA);
  const page = await context.newPage();
  await page.goto(`/u/${usernameB}`);
  await page.getByRole("button", { name: "Seguir" }).click();
  await expect(page.getByRole("button", { name: "Seguindo" })).toBeVisible();
  await page.reload();
  await expect(page.getByRole("button", { name: "Seguindo" })).toBeVisible();
  await page.getByRole("button", { name: "Seguindo" }).click();
  await expect(page.getByRole("button", { name: "Seguir" })).toBeVisible();
  await page.reload();
  await expect(page.getByRole("button", { name: "Seguir" })).toBeVisible();
  await close(context);
});

test("following a private runner never unlocks private fields or graph", async ({ browser }) => {
  const context = await authenticatedContext(browser, runnerA);
  const page = await context.newPage();
  await page.goto(`/u/${privateUsername}`);
  for (const hidden of ["Segredo privado", "São Lourenço da Mata", "6:30 min/km"]) {
    await expect(page.getByText(hidden)).toHaveCount(0);
  }
  await page.getByRole("button", { name: "Seguir" }).click();
  await expect(page.getByRole("button", { name: "Seguindo" })).toBeVisible();
  await page.reload();
  await expect(page.getByText("Perfil privado")).toBeVisible();
  for (const hidden of ["Segredo privado", "São Lourenço da Mata", "6:30 min/km"]) {
    await expect(page.getByText(hidden)).toHaveCount(0);
  }
  await expect(page.getByRole("link", { name: /seguidores|seguindo/i })).toHaveCount(0);
  await close(context);
});

test("discovery includes only public active complete runners", async ({ page }) => {
  await page.goto("/people");
  await expect(page.getByText("Runner B")).toBeVisible();
  await expect(page.getByText("Runner Private")).toHaveCount(0);
  await expect(page.getByText("Runner Suspended")).toHaveCount(0);
  await expect(page.getByText(incompleteUsername)).toHaveCount(0);
  await expect(page.getByRole("option", { name: "São Lourenço da Mata — PE" })).toHaveCount(1);
});

test("profile editing keeps UUID relations and cross-user updates are denied", async ({ browser }) => {
  const context = await authenticatedContext(browser, runnerA);
  const page = await context.newPage();
  await page.goto("/settings/profile");
  const newUsername = `updated_${runnerA.id.slice(0, 8)}`;
  await page.getByLabel("Nome de usuário").fill(newUsername);
  await page.getByLabel("Bio (opcional)").fill("Bio atualizada A");
  await page.getByLabel("Perfil privado").check();
  await page.getByRole("button", { name: "Salvar perfil" }).click();
  await expect(page.getByRole("status")).toHaveText("Perfil salvo.");
  await page.goto(`/u/${newUsername}`);
  await expect(page.getByRole("heading", { name: "Runner A" })).toBeVisible();
  await page.goto(`/u/${usernameA}`);
  await expect(page).toHaveURL(new RegExp(`/u/${usernameA}$`));
  await expect(page.getByRole("heading", { name: /404|not found/i })).toBeVisible();
  usernameA = newUsername;
  const crossUser = await attemptCrossUserProfileUpdate(runnerA, runnerB.id);
  expect(crossUser.error).toBeNull();
  expect(crossUser.data).toEqual([]);
  await close(context);
});

test("profile, settings and discovery have no horizontal overflow at approved widths", async ({ browser, page }) => {
  const context = await authenticatedContext(browser, runnerA);
  const ownPage = await context.newPage();
  for (const width of [360, 390, 430, 768, 1024, 1440]) {
    for (const [targetPage, route] of [[page, `/u/${usernameB}`], [page, "/people"], [ownPage, "/settings/profile"]] as const) {
      await targetPage.setViewportSize({ width, height: 900 });
      await targetPage.goto(route);
      expect(await targetPage.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    }
  }
  await close(context);
});
