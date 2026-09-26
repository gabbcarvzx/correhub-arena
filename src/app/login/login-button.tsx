"use client";

import { useState } from "react";

import { buildAuthCallbackUrl } from "@/lib/auth/origin";
import { sanitizeInternalReturnTo } from "@/lib/auth/return-to";
import { createBrowserSupabaseClient } from "@/lib/supabase/client";

type LoginButtonProps = {
  returnTo?: string;
};

export function LoginButton({ returnTo = "/" }: LoginButtonProps) {
  const [pending, setPending] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function continueWithGoogle() {
    if (pending) {
      return;
    }

    setPending(true);
    setErrorMessage(null);

    try {
      const supabase = createBrowserSupabaseClient();
      const { error } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: {
          redirectTo: buildAuthCallbackUrl(sanitizeInternalReturnTo(returnTo)),
          scopes: "openid email profile",
        },
      });

      if (error) {
        throw error;
      }
    } catch {
      setPending(false);
      setErrorMessage("Não foi possível iniciar o acesso. Tente novamente.");
    }
  }

  return (
    <div className="mt-8">
      <button
        className="inline-flex min-h-12 w-full items-center justify-center rounded-full bg-primary px-6 py-3 font-bold text-on-primary transition-colors hover:bg-primary-hover disabled:cursor-not-allowed disabled:bg-disabled"
        disabled={pending}
        onClick={continueWithGoogle}
        type="button"
      >
        Continuar com Google
      </button>
      {pending ? (
        <p className="mt-3 text-sm text-muted" role="status">
          Abrindo o Google…
        </p>
      ) : null}
      {errorMessage ? (
        <p className="mt-3 text-sm text-destructive" role="alert">
          {errorMessage}
        </p>
      ) : null}
    </div>
  );
}
