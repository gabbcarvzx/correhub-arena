"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/lib/supabase/server";

export async function logoutAction(): Promise<void> {
  try {
    const supabase = await createServerSupabaseClient();
    await supabase.auth.signOut({ scope: "local" });
  } finally {
    revalidatePath("/", "layout");
    redirect("/");
  }
}
