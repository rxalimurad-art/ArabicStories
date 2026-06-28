# Daily Checklist — PWA

A calm, mobile-first daily checklist for **Deen & Arabic**, **Projects**, and **Growth**.
Installable to your home screen, works **offline**, and saves to a **cloud database**
(Cloud Firestore) so your progress syncs across devices. Each day starts fresh; all history is
kept so streaks and a weekly view work.

- **React + TypeScript + Vite**, installable PWA via `vite-plugin-pwa`
- **Cloud persistence** in **Cloud Firestore** with IndexedDB offline caching — works offline
  and syncs automatically when back online
- Per-task **streaks**, a **7-day consistency grid**, and a per-day **note** on every task
- Plain CSS, warm-dark theme
- All persistence is isolated behind a tiny `storage.ts` seam (a local-only Dexie/IndexedDB
  implementation is also included as a drop-in alternative)

> **Auth model:** no login — everyone who opens the URL shares **one** checklist, stored in a
> single `checklist_entries` collection. Firestore rules make only that collection public; keep
> the URL private. To make it per-account later, see the seam section below.

## Run locally

```bash
npm install
npm run dev          # http://localhost:5173
```

## Build

```bash
npm run build        # type-checks, then outputs static site to dist/
npm run preview      # serve the production build locally
```

The build in `dist/` is a plain static site — host it anywhere.

## Deploy

### Firebase Hosting (used for the live link)
From the repo root (where `firebase.json` lives):

```bash
cd checklist-pwa && npm install && npm run build && cd ..
firebase deploy --only hosting:checklist
```

The hosting target `checklist` points at `checklist-pwa/dist`.

### Vercel
- Import the repo, set **Root Directory** to `checklist-pwa`.
- Framework preset: **Vite**. Build: `npm run build`, Output: `dist`. Deploy.

### Netlify
- New site from Git. **Base directory** `checklist-pwa`, **Build** `npm run build`,
  **Publish** `checklist-pwa/dist`.

### GitHub Pages
Pages serves from a sub-path, so set Vite's base to the repo name and deploy `dist`:

```bash
# vite.config.ts → defineConfig({ base: '/<repo>/', ... })
npm run build
npx gh-pages -d dist        # or push dist/ to a gh-pages branch
```

> PWAs require **HTTPS** (all the hosts above provide it). The service worker and offline
> caching only activate on the deployed HTTPS site (or `localhost`).

## How it works

- **Data model** — one `entries` row per `(taskKey, date)`:
  `{ taskKey, date: 'YYYY-MM-DD', done, note }`. Streaks and the 7-day grid are **derived**
  from this table, never stored separately.
- **Today** is the device's **local** calendar day (Lahore / UTC+5 for the author). A new day
  shows everything unchecked while preserving prior days; the app re-checks the date on focus.
- **Tasks** are data-driven in [`src/config/tasks.ts`](src/config/tasks.ts) — add, rename, or
  reorder freely. Keep a task's `key` stable once it has history.

## The storage seam (and adding accounts later)

The UI talks **only** to the `Storage` interface in
[`src/lib/storage.ts`](src/lib/storage.ts):

```ts
interface Storage {
  getEntry(taskKey, date): Promise<Entry | undefined>;
  setEntry(entry): Promise<void>;
  getRange(taskKey, fromDate, toDate): Promise<Entry[]>;
  getDay(date): Promise<Entry[]>;
}
```

Two implementations ship:

- **`firestoreStorage`** ([`src/lib/firestoreStorage.ts`](src/lib/firestoreStorage.ts)) — **active.**
  Cloud Firestore, single shared `checklist_entries` collection, with offline IndexedDB caching
  configured in [`src/lib/firebase.ts`](src/lib/firebase.ts).
- **`dexieStorage`** — local-only IndexedDB, no network. Drop-in alternative.

`export const storage = …` is the entire switch.

**To make it per-account (real cross-device, private sync)** without touching the UI:

1. Add Firebase Auth (e.g. Google sign-in) and move docs under `users/{uid}/entries`.
2. Tighten the Firestore rule to `allow read, write: if request.auth.uid == uid`.
3. Update the doc paths in `firestoreStorage.ts` to include the uid.

Because streaks and the grid are derived from `getRange`/`getDay`, nothing else changes.
