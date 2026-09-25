with launch_city as (
insert into public.cities
  (id, name, country_code, state_code, slug, timezone, is_active)
values
  (
    '10000000-0000-4000-8000-000000000001',
    'São Lourenço da Mata',
    'BR',
    'PE',
    'sao-lourenco-da-mata',
    'America/Recife',
    true
  )
on conflict (id) do update set
  name = excluded.name,
  country_code = excluded.country_code,
  state_code = excluded.state_code,
  slug = excluded.slug,
  timezone = excluded.timezone,
  is_active = excluded.is_active
returning id
)

insert into public.app_settings (id, launch_city_id)
values (
  '10000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000001'
)
on conflict (id) do update set
  launch_city_id = excluded.launch_city_id;
