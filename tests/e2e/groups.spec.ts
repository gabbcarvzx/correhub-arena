import { expect, test, type BrowserContext } from "@playwright/test";

import {
  authenticatedContext, completeLocalProfile, createLocalGroup, createLocalIdentity,
  expireLocalOwnerTransfer, getLocalGroupBySlug, getLocalGroupRelation, localGroupRpc, removeLocalGroups,
  removeLocalIdentity, setLocalAccountStatus, setLocalPlatformRole, tryDirectGroupMediaUpload,
  type LocalIdentity,
} from "./support/local-auth";

test.describe.configure({ mode: "serial" });
const identities: LocalIdentity[] = [];
let owner: LocalIdentity, reviewer: LocalIdentity, selfReviewer: LocalIdentity, runner: LocalIdentity, candidate: LocalIdentity, blocked: LocalIdentity, suspended: LocalIdentity;
let requestSlug: string, requestId: string, openSlug: string, openId: string;
const fixture = async (label: string) => { const identity = await createLocalIdentity(`groups-${label}`); identities.push(identity); await completeLocalProfile(identity,{ username:`g4_${label}_${identity.id.slice(0,8)}`.slice(0,30),fullName:`Runner ${label}` }); return identity; };
const close = async (context: BrowserContext) => context.close();

test.beforeAll(async () => {
  owner=await fixture("owner"); reviewer=await fixture("reviewer"); selfReviewer=await fixture("self"); runner=await fixture("runner"); candidate=await fixture("candidate"); blocked=await fixture("blocked"); suspended=await fixture("suspended");
  setLocalPlatformRole(reviewer,"platform_admin"); setLocalPlatformRole(selfReviewer,"platform_admin");
});
test.afterAll(async () => { let firstError: unknown=null; try { await removeLocalGroups(identities); } catch(error){firstError=error;} for(const identity of identities.reverse()){try{await removeLocalIdentity(identity);}catch(error){firstError??=error;}} if(firstError)throw firstError; });

test("runner requests a pending group and an independent admin approves it", async ({ browser }) => {
  requestSlug=`gate4-${owner.id.slice(0,8)}`;
  const ownerContext=await authenticatedContext(browser,owner), page=await ownerContext.newPage();
  await page.goto("/grupos/solicitar"); await page.getByLabel("Nome do grupo").fill("Passos do Capibaribe"); await page.getByLabel("Endereço do grupo").fill(requestSlug); await page.getByLabel("Descrição").fill("Comunidade local para correr com segurança e constância."); await page.getByLabel("Com aprovação").check(); await page.getByRole("button",{name:"Enviar para análise"}).click();
  await expect(page).toHaveURL(/\/grupos\/meus/); await expect(page.getByText("Em análise")).toBeVisible();
  const requested=await getLocalGroupBySlug(requestSlug); requestId=requested.id; expect(requested.status).toBe("pending"); expect(await getLocalGroupRelation(requestId,owner.id)).toMatchObject({role:"owner",status:"pending"}); await close(ownerContext);
  const adminContext=await authenticatedContext(browser,reviewer), review=await adminContext.newPage(); await review.goto(`/admin/grupos/${requestId}`); await review.getByRole("button",{name:"Aprovar grupo"}).click(); await expect(review.getByText(/decisão foi registrada/i)).toBeVisible(); expect((await getLocalGroupBySlug(requestSlug)).status).toBe("approved"); await close(adminContext);
});

test("a platform admin cannot review their own request", async ({ browser }) => {
  const own=await createLocalGroup(selfReviewer,{ slug:`self-${selfReviewer.id.slice(0,8)}`,joinPolicy:"open" });
  const context=await authenticatedContext(browser,selfReviewer),page=await context.newPage(); await page.goto(`/admin/grupos/${own.id}`); await expect(page.getByText(/Outra pessoa administradora/)).toBeVisible(); await expect(page.getByRole("button",{name:"Aprovar grupo"})).toHaveCount(0); await close(context);
});

test("open join is immediate and remains separate from follow", async ({ browser }) => {
  const made=await createLocalGroup(owner,{slug:`open-${owner.id.slice(0,8)}`,joinPolicy:"open"}); openId=made.id;openSlug=made.slug; await localGroupRpc(reviewer,"approve_group_request",{target_group_id:openId});
  const context=await authenticatedContext(browser,runner),page=await context.newPage(); await page.goto(`/grupos/${openSlug}`); await page.getByRole("button",{name:"Entrar no grupo"}).click(); await expect(page.getByText("Você entrou no grupo.")).toBeVisible(); expect(await getLocalGroupRelation(openId,runner.id)).toMatchObject({role:"member",status:"active"}); await page.getByRole("button",{name:"Seguir grupo"}).click(); await expect(page.getByRole("button",{name:"Seguindo grupo"})).toBeVisible(); await page.reload(); await expect(page.getByRole("button",{name:"Seguindo grupo"})).toBeVisible(); await page.getByRole("button",{name:"Seguindo grupo"}).click(); expect(await getLocalGroupRelation(openId,runner.id)).toMatchObject({status:"active"}); await close(context);
});

test("approval-required join, hierarchy and ownership transfer use real RPC and UI", async ({ browser }) => {
  const candidateContext=await authenticatedContext(browser,candidate),candidatePage=await candidateContext.newPage(); await candidatePage.goto(`/grupos/${requestSlug}`); await candidatePage.getByRole("button",{name:"Pedir para entrar"}).click(); await expect(candidatePage.getByText("Pedido enviado para análise.")).toBeVisible(); expect(await getLocalGroupRelation(requestId,candidate.id)).toMatchObject({status:"pending"}); await close(candidateContext);
  const ownerContext=await authenticatedContext(browser,owner),members=await ownerContext.newPage(); await members.goto(`/grupos/${requestSlug}/membros`); await members.getByRole("button",{name:/Aprovar Runner candidate/}).click(); await expect.poll(()=>getLocalGroupRelation(requestId,candidate.id)).toMatchObject({status:"active"}); await members.getByRole("button",{name:/Promover Runner candidate/}).click(); await members.getByRole("button",{name:"Confirmar promoção"}).click(); await expect.poll(()=>getLocalGroupRelation(requestId,candidate.id)).toMatchObject({role:"admin"});
  const escalation=await localGroupRpc(candidate,"promote_group_admin",{target_group_id:requestId,target_user_id:owner.id},{allowError:true}); expect(escalation.error).toBeTruthy(); await members.reload(); await members.getByRole("button",{name:/Rebaixar Runner candidate/}).click(); await members.getByRole("button",{name:"Confirmar rebaixamento"}).click(); await expect.poll(()=>getLocalGroupRelation(requestId,candidate.id)).toMatchObject({role:"member"}); await members.reload(); await members.getByRole("button",{name:/Promover Runner candidate/}).click(); await members.getByRole("button",{name:"Confirmar promoção"}).click();
  await members.goto(`/grupos/${requestSlug}/transferencia`); await members.getByLabel("Nova pessoa responsável").selectOption(candidate.id); await members.getByRole("button",{name:"Iniciar transferência"}).click(); await members.getByRole("button",{name:"Enviar convite"}).click(); await close(ownerContext);
  const recipientContext=await authenticatedContext(browser,candidate),transfer=await recipientContext.newPage(); await transfer.goto(`/grupos/${requestSlug}/transferencia`); await transfer.getByRole("button",{name:"Aceitar responsabilidade"}).click(); await transfer.getByRole("alertdialog").getByRole("button",{name:"Aceitar responsabilidade"}).click(); await expect.poll(()=>getLocalGroupRelation(requestId,candidate.id)).toMatchObject({role:"owner",status:"active"}); await close(recipientContext);
  const newOwnerContext=await authenticatedContext(browser,candidate),newOwnerPage=await newOwnerContext.newPage(); await newOwnerPage.goto(`/grupos/${requestSlug}/transferencia`); await newOwnerPage.getByLabel("Nova pessoa responsável").selectOption(owner.id); await newOwnerPage.getByRole("button",{name:"Iniciar transferência"}).click(); await newOwnerPage.getByRole("button",{name:"Enviar convite"}).click(); expireLocalOwnerTransfer(requestId); await close(newOwnerContext); const oldOwnerContext=await authenticatedContext(browser,owner),expiredPage=await oldOwnerContext.newPage(); await expiredPage.goto(`/grupos/${requestSlug}/transferencia`); await expect(expiredPage.getByText("Transferência expirada")).toBeVisible(); await close(oldOwnerContext);
});

test("blocked and suspended users cannot mutate with still-valid sessions", async ({ browser }) => {
  await localGroupRpc(blocked,"join_group",{target_group_id:requestId}); await localGroupRpc(candidate,"block_group_member",{target_group_id:requestId,target_user_id:blocked.id}); expect(await getLocalGroupRelation(requestId,blocked.id)).toMatchObject({status:"blocked"}); const retry=await localGroupRpc(blocked,"join_group",{target_group_id:requestId},{allowError:true}); expect(retry.error).toBeTruthy();
  setLocalAccountStatus(suspended,"suspended"); const denied=await localGroupRpc(suspended,"join_group",{target_group_id:openId},{allowError:true}); expect(denied.error).toBeTruthy(); const context=await authenticatedContext(browser,suspended),page=await context.newPage(); await page.goto("/grupos/meus"); await expect(page).toHaveURL(/account-unavailable/); await close(context);
});

test("group media accepts a valid owner image and denies invalid or direct uploads", async ({ browser }) => {
  const mediaGroup=await createLocalGroup(candidate,{slug:`media-${candidate.id.slice(0,8)}`,joinPolicy:"open"}); await localGroupRpc(reviewer,"approve_group_request",{target_group_id:mediaGroup.id});
  const context=await authenticatedContext(browser,candidate),page=await context.newPage(); await page.goto(`/grupos/${mediaGroup.slug}/configuracoes`); const valid=Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=","base64"); await page.getByLabel("Avatar").setInputFiles({name:"avatar.png",mimeType:"image/png",buffer:valid}); await page.getByRole("button",{name:"Enviar imagem"}).first().click(); await expect(page.getByRole("status")).toHaveText("Imagem atualizada."); await page.getByLabel("Capa").setInputFiles({name:"invalid.txt",mimeType:"text/plain",buffer:Buffer.from("not an image")}); await page.getByRole("button",{name:"Enviar imagem"}).nth(1).click(); await expect(page.getByRole("status")).toContainText("JPEG, PNG ou WebP"); const bypass=await tryDirectGroupMediaUpload(runner,mediaGroup.id); expect(bypass.error).toBeTruthy(); await close(context);
});

test("group and admin surfaces remain responsive", async ({ browser },testInfo) => {
  const context=await authenticatedContext(browser,reviewer),page=await context.newPage(); for(const width of [360,390,430,768,1024,1440]){await page.setViewportSize({width,height:900});await page.goto("/admin/grupos");await expect(page.getByRole("heading",{name:"Solicitações de grupos"})).toBeVisible();expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);if(width===390||width===1440)await page.screenshot({path:testInfo.outputPath(`admin-${width}.png`),fullPage:true});} await close(context);
});
