"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { useRouter } from "next/navigation";

import { requestGroup, resubmitGroup, updateGroup } from "@/lib/groups/actions";
import { groupRequestSchema, type GroupRequestInput } from "@/lib/validations/group";

type City = { id: string; name: string; state_code: string };
type EditContext = { groupId: string; wasRejected: boolean; slugLocked?: boolean };
const control = "mt-2 min-h-12 w-full rounded-xl border border-border bg-surface px-4 py-3 outline-none transition focus:border-focus";
const slugify = (value: string) => value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 100);

export function GroupRequestForm({ cities, initialValues, edit, cancelHref = "/grupos/meus" }: { cities: City[]; initialValues?: GroupRequestInput; edit?: EditContext; cancelHref?: string }) {
  const router = useRouter();
  const [slugEdited, setSlugEdited] = useState(Boolean(initialValues));
  const [message, setMessage] = useState<string | null>(null);
  const { register, handleSubmit, setValue, formState: { errors, isSubmitting } } = useForm<GroupRequestInput>({
    resolver: zodResolver(groupRequestSchema),
    defaultValues: initialValues ?? { name: "", slug: "", description: "", city_id: cities[0]?.id ?? "", group_type: "community", join_policy: "open" },
  });
  const nameField = register("name");
  const slugField = register("slug");
  const submit = handleSubmit(async (rawValues) => {
    const values = edit?.slugLocked && initialValues ? { ...rawValues, slug: initialValues.slug } : rawValues;
    setMessage(null);
    if (edit) {
      const saved = await updateGroup({ ...values, groupId: edit.groupId });
      if (!saved.ok) { setMessage(saved.message); return; }
      if (edit.wasRejected) {
        const resubmitted = await resubmitGroup({ groupId: edit.groupId });
        if (!resubmitted.ok) { setMessage(resubmitted.message); return; }
      }
      router.push(cancelHref); return;
    }
    const result = await requestGroup(values);
    if (!result.ok) { setMessage(result.message); return; }
    router.push(cancelHref);
  });
  const error = (id: string, value?: string) => value ? <p className="mt-1 text-sm text-destructive" id={id}>{value}</p> : null;
  return <form className="mt-8 grid gap-6" noValidate onSubmit={submit}>
    <div><label className="font-bold" htmlFor="group-name">Nome do grupo</label><input {...nameField} aria-describedby={errors.name ? "group-name-error" : undefined} aria-invalid={Boolean(errors.name)} className={control} id="group-name" onChange={(event) => { nameField.onChange(event); if (!slugEdited) setValue("slug", slugify(event.target.value), { shouldValidate: true }); }} />{error("group-name-error", errors.name?.message)}</div>
    <div><label className="font-bold" htmlFor="group-slug">Endereço do grupo</label><div className="mt-2 flex min-h-12 items-center rounded-xl border border-border bg-surface focus-within:border-focus"><span className="pl-4 text-muted" aria-hidden="true">/grupos/</span><input {...slugField} aria-describedby="group-slug-help" className="min-h-11 min-w-0 flex-1 bg-transparent px-1 pr-4 outline-none disabled:cursor-not-allowed disabled:text-muted" disabled={edit?.slugLocked} id="group-slug" onChange={(event) => { setSlugEdited(true); slugField.onChange(event); }} /></div><p className="mt-1 text-sm text-muted" id="group-slug-help">{edit?.slugLocked ? "O endereço permanece estável depois da aprovação." : "Use letras, números e hífens. Você pode ajustar antes de enviar."}</p>{error("group-slug-error", errors.slug?.message)}</div>
    <div><label className="font-bold" htmlFor="group-description">Descrição</label><textarea {...register("description")} aria-invalid={Boolean(errors.description)} className={`${control} min-h-32 resize-y`} id="group-description" maxLength={2000} />{error("group-description-error", errors.description?.message)}</div>
    <div className="grid gap-5 sm:grid-cols-2"><div><label className="font-bold" htmlFor="group-city">Cidade</label><select {...register("city_id")} className={control} id="group-city">{cities.map((city) => <option key={city.id} value={city.id}>{city.name} — {city.state_code}</option>)}</select></div><div><label className="font-bold" htmlFor="group-type">Tipo de grupo</label><select {...register("group_type")} className={control} id="group-type"><option value="community">Comunidade de corrida</option><option value="professional">Equipe profissional</option></select></div></div>
    <fieldset><legend className="font-bold">Como as pessoas entram</legend><div className="mt-3 grid gap-3 sm:grid-cols-2"><div className="flex min-h-14 items-start gap-3 border-l-4 border-primary bg-surface px-4 py-3"><input aria-describedby="join-open-help" className="mt-1 size-5 accent-primary" id="join-open" type="radio" value="open" {...register("join_policy")} /><span><label className="block font-bold" htmlFor="join-open">Entrada livre</label><span className="text-sm text-muted" id="join-open-help">A pessoa entra assim que solicitar.</span></span></div><div className="flex min-h-14 items-start gap-3 border-l-4 border-border bg-surface px-4 py-3"><input aria-describedby="join-approval-help" className="mt-1 size-5 accent-primary" id="join-approval" type="radio" value="approval_required" {...register("join_policy")} /><span><label className="block font-bold" htmlFor="join-approval">Com aprovação</label><span className="text-sm text-muted" id="join-approval-help">A gestão analisa cada pedido.</span></span></div></div></fieldset>
    {message ? <p className="border-l-4 border-destructive pl-4 text-sm text-destructive" role="alert">{message}</p> : null}
    <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end"><button className="min-h-11 px-5 font-bold text-muted" type="button" onClick={() => router.push(cancelHref)}>Cancelar</button><button className="min-h-12 rounded-full bg-primary px-7 py-3 font-black text-on-primary hover:bg-primary-hover disabled:cursor-not-allowed disabled:bg-disabled" disabled={isSubmitting} type="submit">{isSubmitting ? "Enviando…" : edit?.wasRejected ? "Salvar e reenviar" : edit ? "Salvar alterações" : "Enviar para análise"}</button></div>
  </form>;
}
