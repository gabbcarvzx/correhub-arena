"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useState } from "react";
import { useForm } from "react-hook-form";

import {
  DISTANCE_LABELS,
  PREFERRED_DISTANCES,
  RUNNING_LEVEL_LABELS,
  RUNNING_LEVELS,
  onboardingSchema,
  type OnboardingFormInput,
} from "@/lib/validations/onboarding";

import { completeOnboarding } from "./actions";

type CityOption = { id: string; name: string; state_code: string };

type OnboardingFormProps = {
  cities: CityOption[];
  launchCityId: string;
  initialFullName: string;
  returnTo: string;
};

function FieldError({ id, message }: { id: string; message?: string }) {
  return message ? (
    <span className="mt-1 block text-sm text-destructive" id={id}>
      {message}
    </span>
  ) : null;
}

function describedBy(error: unknown, helpId?: string) {
  return [helpId, error ? `${helpId?.replace(/-help$/, "") ?? "field"}-error` : null]
    .filter(Boolean)
    .join(" ") || undefined;
}

const inputClass =
  "mt-2 min-h-12 w-full rounded-xl border border-border bg-surface px-4 py-3 text-foreground outline-none focus:border-focus";

export function OnboardingForm({
  cities,
  launchCityId,
  initialFullName,
  returnTo,
}: OnboardingFormProps) {
  const [serverMessage, setServerMessage] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<OnboardingFormInput>({
    resolver: zodResolver(onboardingSchema, undefined, { raw: true }),
    defaultValues: {
      username: "",
      full_name: initialFullName,
      city_id: launchCityId,
      running_level: "beginner",
      preferred_distance: "up_to_5k",
      bio: "",
      pace: "",
      is_private: false,
    },
  });

  const submit = handleSubmit(async (values) => {
    setServerMessage(null);
    const result = await completeOnboarding(values, returnTo);
    if (!result.ok) {
      setServerMessage(result.message);
      Object.entries(result.fieldErrors ?? {}).forEach(([field, message]) => {
        setError(field as keyof OnboardingFormInput, { type: "server", message });
      });
    }
  });

  return (
    <form className="mt-8 grid gap-5" noValidate onSubmit={submit}>
      <div>
        <label className="font-semibold" htmlFor="username">Nome de usuário</label>
        <input
          id="username"
          aria-describedby={errors.username ? "username-error" : undefined}
          aria-invalid={Boolean(errors.username)}
          autoCapitalize="none"
          autoComplete="username"
          className={inputClass}
          {...register("username")}
        />
        <FieldError id="username-error" message={errors.username?.message} />
      </div>

      <div>
        <label className="font-semibold" htmlFor="full_name">Nome</label>
        <input
          id="full_name"
          aria-describedby={errors.full_name ? "full-name-error" : undefined}
          aria-invalid={Boolean(errors.full_name)}
          autoComplete="name"
          className={inputClass}
          {...register("full_name")}
        />
        <FieldError id="full-name-error" message={errors.full_name?.message} />
      </div>

      <div>
        <label className="font-semibold" htmlFor="city_id">Cidade</label>
        <select
          id="city_id"
          aria-describedby={errors.city_id ? "city-error" : undefined}
          aria-invalid={Boolean(errors.city_id)}
          className={inputClass}
          {...register("city_id")}
        >
          {cities.map((city) => (
            <option key={city.id} value={city.id}>
              {city.name} — {city.state_code}
            </option>
          ))}
        </select>
        <FieldError id="city-error" message={errors.city_id?.message} />
      </div>

      <div>
        <label className="font-semibold" htmlFor="running_level">Nível de corrida</label>
        <select
          id="running_level"
          aria-describedby={errors.running_level ? "running-level-error" : undefined}
          aria-invalid={Boolean(errors.running_level)}
          className={inputClass}
          {...register("running_level")}
        >
          {RUNNING_LEVELS.map((level) => (
            <option key={level} value={level}>
              {RUNNING_LEVEL_LABELS[level]}
            </option>
          ))}
        </select>
        <FieldError id="running-level-error" message={errors.running_level?.message} />
      </div>

      <div>
        <label className="font-semibold" htmlFor="preferred_distance">Distância preferida</label>
        <select
          id="preferred_distance"
          aria-describedby={errors.preferred_distance ? "preferred-distance-error" : undefined}
          aria-invalid={Boolean(errors.preferred_distance)}
          className={inputClass}
          {...register("preferred_distance")}
        >
          {PREFERRED_DISTANCES.map((distance) => (
            <option key={distance} value={distance}>
              {DISTANCE_LABELS[distance]}
            </option>
          ))}
        </select>
        <FieldError id="preferred-distance-error" message={errors.preferred_distance?.message} />
      </div>

      <div>
        <label className="font-semibold" htmlFor="bio">Bio (opcional)</label>
        <textarea
          id="bio"
          aria-describedby={errors.bio ? "bio-error" : undefined}
          aria-invalid={Boolean(errors.bio)}
          className={`${inputClass} min-h-24 resize-y`}
          maxLength={300}
          {...register("bio")}
        />
        <FieldError id="bio-error" message={errors.bio?.message} />
      </div>

      <div>
        <label className="font-semibold" htmlFor="pace">Pace aproximado (opcional)</label>
        <input
          id="pace"
          aria-describedby={describedBy(errors.pace, "pace-help")}
          aria-invalid={Boolean(errors.pace)}
          className={inputClass}
          inputMode="numeric"
          placeholder="6:30"
          {...register("pace")}
        />
        <span className="mt-1 block text-sm text-muted" id="pace-help">
          Use minutos:segundos por km.
        </span>
        <FieldError id="pace-error" message={errors.pace?.message} />
      </div>

      <div>
        <label className="flex min-h-11 items-center gap-3 font-semibold">
          <input
            aria-describedby="privacy-help"
            className="size-5 accent-primary"
            type="checkbox"
            {...register("is_private")}
          />
          Perfil privado
        </label>
        <p className="mt-1 text-sm text-muted" id="privacy-help">
          Seu perfil é público por padrão. Perfis privados não liberam conteúdo completo para terceiros.
        </p>
      </div>

      {serverMessage ? (
        <p className="text-sm text-destructive" role="alert">
          {serverMessage}
        </p>
      ) : null}

      <button
        className="min-h-12 rounded-full bg-primary px-6 py-3 font-bold text-on-primary transition-colors hover:bg-primary-hover disabled:cursor-not-allowed disabled:bg-disabled"
        disabled={isSubmitting}
        type="submit"
      >
        {isSubmitting ? "Salvando…" : "Concluir cadastro"}
      </button>
    </form>
  );
}
