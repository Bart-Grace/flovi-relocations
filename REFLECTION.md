# Reflection — Flovi AI Build Challenge

> **Status: in progress.** Parts 1–4 are drafted at T+188 from `docs/DECISIONS.md` and `git log` only —
> nothing here is written from memory. Part 5 is written by hand at the end.
> Section 0 below was written **before the clock started**, because it records a decision made before it.

---

## 0. Stack decision — and the case against it

The brief suggests Supabase and permits deviation "with good reason". I considered writing a small
PHP or Node API instead and rejected it. The reasoning, recorded before the build so it cannot be
reconstructed favourably afterwards:

**What a custom API would have cost.** Three things, none of them the CRUD:

1. **OAuth session handling, written twice.** `supabase-js` and `supabase_flutter` both restore the
   session from local storage on refresh, auto-refresh the token, and expose an auth-state stream.
   With a custom backend that is server-side code exchange, my own JWT issuance, a refresh endpoint,
   and then the client half implemented independently in TypeScript and in Dart. The plan budgets
   8 minutes for web OAuth and 7 for the Flutter shell plus auth gate.
2. **Realtime.** The brief requires "real-time or near-real-time data sync between the two apps".
   PHP has no first-class answer: WebSockets mean a separate long-lived process alongside PHP-FPM,
   SSE occupies a worker per connected client. The realistic landing point is a 5-second poll — which
   is already this plan's *fallback* for a failed socket (`plan.md` §8, T+165). I would have started
   at the contingency.
3. **A second deployment axis.** Vercel does not run PHP as a first-class runtime, so the backend
   needs its own host and its own database, plus CORS across three origins, inside a 4-hour budget
   whose hard requirement is "both apps live on the internet".

**Why that settled it.** None of the five scored rows in the brief is backend architecture. The
scored rows are prompting quality, product judgment, debugging mindset, delivery, and reflection.
A hand-rolled API buys nothing on any of them and spends minutes against the one hard constraint.
Supabase was not chosen because it is architecturally superior — it was chosen because it collapses
auth, database, realtime and backend hosting into a single dashboard.

**When I would not choose it.** Supabase's model has the client talking straight to Postgres through
PostgREST, so the entire authorization boundary lives in RLS policies — and RLS failures are
*silent*. A policy that filters a row out produces HTTP 200 with an empty array, not a 403. The
plan budgets 30 minutes for that specific confusion (`plan.md` §6, trap 10) and it is the single
most expensive non-realtime trap on the list. On a system with a team and a six-month horizon I
would take the API layer specifically so that authorization failures are loud.

**What the pushback actually produced.** Not a stack change — a standing rule, adopted before any
client code existed: **every mutation ends with `.select()`, and an empty result is an error, never
a success.** It appears as a constraint in prompts 07 and 08 in the prompt log. That is the cheap
mitigation for the one property of this stack I distrust.

---

## 1. Two things I would do identically

_Pending — drafted at T+188 from `docs/DECISIONS.md` and `git log`. Each claim carries a number,
a filename, a sha, or a verbatim quote._

---

## 2. Three specific failures

_Pending. Each entry carries elapsed cost in minutes and how it was diagnosed. At least one is a
failure where I was the problem, not the tool._

---

## 3. Where AI actively got in the way

_Pending — named as failure modes, not as anecdotes._

---

## 4. What is still shaky and unfixed

_Pending. At least one thing here is still broken at submission time._

---

## 5. What this says about how software development is changing

_Written by hand. Stub._
