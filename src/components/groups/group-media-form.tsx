"use client";

import { useState } from "react";

export function GroupMediaForm({ groupId }: { groupId: string }) {
  const [message, setMessage] = useState<string | null>(null); const [pending, setPending] = useState(false);
  async function upload(form: FormData) {
    setPending(true); setMessage(null); form.set("groupId", groupId);
    try {
      const response = await fetch("/api/group-media", { method: "POST", body: form });
      setMessage(response.ok ? "Imagem atualizada." : response.status === 400 ? "Escolha uma imagem JPEG, PNG ou WebP dentro do limite." : "Não foi possível atualizar a imagem agora.");
    } catch { setMessage("Não foi possível atualizar a imagem agora."); }
    setPending(false);
  }
  return <section className="border-t border-border pt-8" aria-labelledby="group-media-title"><h2 className="text-2xl font-black" id="group-media-title">Imagens do grupo</h2><p className="mt-2 max-w-2xl text-muted">Envie JPEG, PNG ou WebP. O CorreHub converte e armazena a mídia de forma privada.</p><div className="mt-5 grid gap-5 sm:grid-cols-2">{(["avatar", "cover"] as const).map(kind => <form action={upload} className="border-l-4 border-border pl-4" key={kind}><input name="kind" type="hidden" value={kind} /><label className="block font-bold" htmlFor={`group-media-${kind}`}>{kind === "avatar" ? "Avatar" : "Capa"}</label><input accept="image/jpeg,image/png,image/webp" className="mt-2 block w-full text-sm" disabled={pending} id={`group-media-${kind}`} name="file" required type="file" /><button className="mt-3 min-h-11 rounded-full border border-border px-4 font-bold disabled:text-disabled" disabled={pending} type="submit">{pending ? "Enviando…" : "Enviar imagem"}</button></form>)}</div>{message ? <p className="mt-4 font-semibold" role="status">{message}</p> : null}</section>;
}
