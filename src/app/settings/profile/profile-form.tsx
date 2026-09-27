"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useState } from "react";
import { useForm } from "react-hook-form";

import {
  DISTANCE_LABELS,
  PREFERRED_DISTANCES,
  RUNNING_LEVEL_LABELS,
  RUNNING_LEVELS,
  profileEditSchema,
  type ProfileFormInput,
} from "@/lib/validations/profile";

import { updateProfile } from "./actions";

type CityOption = { id: string; name: string; state_code: string };
const inputClass =
  "mt-2 min-h-12 w-full rounded-xl border border-border bg-surface px-4 py-3 text-foreground outline-none focus:border-focus";

function FieldError({ id, message }: { id: string; message?: string }) {
  return message ? <span className="mt-1 block text-sm text-destructive" id={id}>{message}</span> : null;
}

export function ProfileForm({
  cities,
  initialValues,
}: {
  cities: CityOption[];
  initialValues: ProfileFormInput;
}) {
  const [message, setMessage] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<ProfileFormInput>({
    resolver: zodResolver(profileEditSchema, undefined, { raw: true }),
    defaultValues: initialValues,
  });

  const submit = handleSubmit(async (values) => {
    setMessage(null);
    const result = await updateProfile(values);
    if (!result.ok) {
      setMessage(result.message);
      for (const [field, fieldMessage] of Object.entries(result.fieldErrors ?? {})) {
        setError(field as keyof ProfileFormInput, { type: "server", message: fieldMessage });
      }
      return;
    }
    setMessage("Perfil salvo.");
  });

  return (
    <form className="mt-8 grid gap-5" noValidate onSubmit={submit}>
      <div>
        <label className="font-semibold" htmlFor="username">Nome de usuário</label>
        <input id="username" aria-invalid={Boolean(errors.username)} aria-describedby={errors.username ? "username-error" : undefined} autoCapitalize="none" autoComplete="username" className={inputClass} {...register("username")} />
        <FieldError id="username-error" message={errors.username?.message} />
      </div>
      <div>
        <label className="font-semibold" htmlFor="full_name">Nome</label>
        <input id="full_name" aria-invalid={Boolean(errors.full_name)} aria-describedby={errors.full_name ? "full-name-error" : undefined} autoComplete="name" className={inputClass} {...register("full_name")} />
        <FieldError id="full-name-error" message={errors.full_name?.message} />
      </div>
      <div>
        <label className="font-semibold" htmlFor="city_id">Cidade</label>
        <select id="city_id" aria-invalid={Boolean(errors.city_id)} aria-describedby={errors.city_id ? "city-error" : undefined} className={inputClass} {...register("city_id")}>
          {cities.map((city) => <option key={city.id} value={city.id}>{city.name} — {city.state_code}</option>)}
        </select>
        <FieldError id="city-error" message={errors.city_id?.message} />
      </div>
      <div>
        <label className="font-semibold" htmlFor="running_level">Nível de corrida</label>
        <select id="running_level" className={inputClass} {...register("running_level")}>
          {RUNNING_LEVELS.map((level) => <option key={level} value={level}>{RUNNING_LEVEL_LABELS[level]}</option>)}
        </select>
      </div>
      <div>
        <label className="font-semibold" htmlFor="preferred_distance">Distância preferida</label>
        <select id="preferred_distance" className={inputClass} {...register("preferred_distance")}>
          {PREFERRED_DISTANCES.map((distance) => <option key={distance} value={distance}>{DISTANCE_LABELS[distance]}</option>)}
        </select>
      </div>
      <div>
        <label className="font-semibold" htmlFor="bio">Bio (opcional)</label>
        <textarea id="bio" aria-invalid={Boolean(errors.bio)} aria-describedby={errors.bio ? "bio-error" : undefined} className={`${inputClass} min-h-24 resize-y`} maxLength={300} {...register("bio")} />
        <FieldError id="bio-error" message={errors.bio?.message} />
      </div>
      <div>
        <label className="font-semibold" htmlFor="pace">Pace aproximado (opcional)</label>
        <input id="pace" aria-invalid={Boolean(errors.pace)} aria-describedby={errors.pace ? "pace-help pace-error" : "pace-help"} className={inputClass} inputMode="numeric" placeholder="6:30" {...register("pace")} />
        <span className="mt-1 block text-sm text-muted" id="pace-help">Use minutos:segundos por km.</span>
        <FieldError id="pace-error" message={errors.pace?.message} />
      </div>
      <div>
        <label className="flex min-h-11 items-center gap-3 font-semibold">
          <input aria-describedby="privacy-help" className="size-5 accent-primary" type="checkbox" {...register("is_private")} />
          Perfil privado
        </label>
        <p className="mt-1 text-sm text-muted" id="privacy-help">Ao tornar o perfil privado, posts pessoais públicos também ficam privados. Torná-lo público depois não republica esses posts.</p>
      </div>
      {message ? <p className="text-sm text-muted" role="status">{message}</p> : null}
      <button className="min-h-12 rounded-full bg-primary px-6 py-3 font-bold text-on-primary hover:bg-primary-hover disabled:cursor-not-allowed disabled:bg-disabled" disabled={isSubmitting} type="submit">
        {isSubmitting ? "Salvando…" : "Salvar perfil"}
      </button>
    </form>
  );
}
