import { NextResponse } from "next/server";
import { z } from "zod";

import { getCurrentAccountState } from "@/lib/auth/current-account";
import { GroupMediaError, normalizeGroupImage } from "@/lib/media/group-media";
import { createAdminSupabaseClient } from "@/lib/supabase/admin";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const runtime = "nodejs";

const targetSchema = z.object({ groupId: z.uuid(), kind: z.enum(["avatar", "cover"]) }).strict();
const noStore = { "Cache-Control": "private, no-store" };

export async function POST(request: Request) {
  try {
    const supabase = await createServerSupabaseClient();
    const account = await getCurrentAccountState(supabase);
    if (account.kind === "anonymous") return NextResponse.json({ error: "unauthenticated" }, { status: 401, headers: noStore });
    if (account.kind !== "active" || !account.onboardingCompleted) return NextResponse.json({ error: "forbidden" }, { status: 403, headers: noStore });
    const form = await request.formData();
    const parsed = targetSchema.safeParse({ groupId: form.get("groupId"), kind: form.get("kind") });
    const file = form.get("file");
    if (!parsed.success || !(file instanceof File)) return NextResponse.json({ error: "validation_error" }, { status: 400, headers: noStore });
    const normalized = await normalizeGroupImage(new Uint8Array(await file.arrayBuffer()), parsed.data.kind);
    const { data: attempts, error: authorizeError } = await supabase.rpc("authorize_group_media_upload", {
      target_group_id: parsed.data.groupId,
      media_kind: parsed.data.kind,
      requested_content_hash: normalized.hash,
      requested_size_bytes: normalized.bytes.byteLength,
    });
    const attempt = attempts?.[0];
    if (authorizeError || !attempt) return NextResponse.json({ error: "forbidden" }, { status: 403, headers: noStore });
    const admin = createAdminSupabaseClient();
    const bucket = admin.storage.from("group-media");
    const { error: uploadError } = await bucket.upload(attempt.object_path, normalized.bytes, { contentType: normalized.contentType, cacheControl: "60", upsert: true });
    if (uploadError) {
      await supabase.rpc("fail_group_media_upload", { target_upload_id: attempt.upload_id });
      return NextResponse.json({ error: "temporary_error" }, { status: 503, headers: noStore });
    }
    const { error: finalizeError } = await supabase.rpc("finalize_group_media_upload", { target_upload_id: attempt.upload_id });
    if (finalizeError) {
      await bucket.remove([attempt.object_path]);
      await supabase.rpc("fail_group_media_upload", { target_upload_id: attempt.upload_id });
      return NextResponse.json({ error: "state_changed" }, { status: 409, headers: noStore });
    }
    return NextResponse.json({ ok: true }, { headers: noStore });
  } catch (error) {
    const status = error instanceof GroupMediaError ? 400 : 503;
    return NextResponse.json({ error: error instanceof GroupMediaError ? error.code : "temporary_error" }, { status, headers: noStore });
  }
}

export async function GET(request: Request) {
  try {
    const parsed = targetSchema.safeParse(Object.fromEntries(new URL(request.url).searchParams));
    if (!parsed.success) return NextResponse.json({ error: "validation_error" }, { status: 400, headers: noStore });
    const supabase = await createServerSupabaseClient();
    const { data: path, error } = await supabase.rpc("get_group_media_path", { target_group_id: parsed.data.groupId, media_kind: parsed.data.kind });
    if (error || !path) return NextResponse.json({ error: "not_found" }, { status: 404, headers: noStore });
    const admin = createAdminSupabaseClient();
    const { data, error: signError } = await admin.storage.from("group-media").createSignedUrl(path, 60);
    if (signError || !data) return NextResponse.json({ error: "temporary_error" }, { status: 503, headers: noStore });
    return NextResponse.json({ url: data.signedUrl }, { headers: noStore });
  } catch {
    return NextResponse.json({ error: "temporary_error" }, { status: 503, headers: noStore });
  }
}
