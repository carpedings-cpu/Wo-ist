-- Wo ist's? · Autorin: Diana Ziegler
-- Projekt: wo-ist (uvvqgwbshdtwlveopgvn), Region eu-central-1.
-- Gemeinsame Liste ohne Anmeldung: Jeder, der die App öffnet, liest und schreibt
-- dieselben Einträge. Bewusst so gewählt für einen Zwei-Personen-Haushalt.

create table if not exists public.haushalt_eintraege (
  id text primary key,
  gegenstand text not null default '',
  ort text not null default '',
  originalsatz text not null default '',
  foto_pfad text,
  erstellt timestamptz not null default now(),
  verlauf jsonb not null default '[]'::jsonb,
  geaendert timestamptz not null default now(),
  geloescht boolean not null default false
);

alter table public.haushalt_eintraege enable row level security;

create policy "App liest Einträge" on public.haushalt_eintraege
  for select to anon, authenticated using (true);
create policy "App legt Einträge an" on public.haushalt_eintraege
  for insert to anon, authenticated with check (true);
create policy "App ändert Einträge" on public.haushalt_eintraege
  for update to anon, authenticated using (true) with check (true);

insert into storage.buckets (id, name, public)
values ('haushalt-fotos', 'haushalt-fotos', false)
on conflict (id) do nothing;

create policy "App liest Fotos" on storage.objects
  for select to anon, authenticated using (bucket_id = 'haushalt-fotos');
create policy "App lädt Fotos hoch" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'haushalt-fotos');
create policy "App ersetzt Fotos" on storage.objects
  for update to anon, authenticated using (bucket_id = 'haushalt-fotos');
create policy "App entfernt Fotos" on storage.objects
  for delete to anon, authenticated using (bucket_id = 'haushalt-fotos');
