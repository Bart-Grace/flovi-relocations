# Developer Case Assignment

**Flovi AI Build Challenge — 4-Hour Sprint**

## Overview

Build and ship two connected apps in under 4 hours — entirely AI-generated, zero lines of code written manually. Your job is to be an exceptional AI engineer: clear thinking, precise prompting, fast iteration.

The apps simulate a core Flovi workflow: a dispatcher creates and manages relocation requests, and a driver sees and books available gigs.

## What to build

### App 1 — Dispatcher web app (Vue.js)

A modern, polished Vue 3 frontend with:

- Google OAuth login
- Create a new relocation request (origin, destination, date, notes)
- List all requests with status indicators
- Edit and update existing requests

### App 2 — Driver mobile app (Flutter)

A clean Flutter app with:

- Google OAuth login
- Browse available (unbooked) relocation gigs
- One-tap booking with confirmation
- View your booked gigs

### Backend

Choose whatever suits the task best — Firebase, Supabase, or a lightweight Node/Express API. It needs to support real-time or near-real-time data sync between the two apps.

## Constraints

| Rule | Detail |
| --- | --- |
| No manual code | Zero lines of code written by hand. Every file is AI-generated. |
| Time limit | 4 hours from start to published URLs |
| Delivery | Both apps live and accessible on the internet |
| Code | Repository publicly visible (GitHub, GitLab, etc.) |
| Design | Modern and polished — not a tutorial app |

## Deliverables

Bring to your presentation:

1. **Live URLs** — working web app and either a hosted Flutter web build or instructions to run the APK
2. **Public repo** — clean commit history showing how the project evolved
3. **Prompt log** — a written or recorded trace of your key prompts: what you asked, what came back, what you changed and why
4. **5-minute walkthrough** — demo both apps end to end as if showing a real customer
5. **Reflection** — what worked, what broke, where AI got in the way

## Presentation questions to prepare for

- Walk us through your prompting strategy. How did you break the problem down?
- Where did the AI produce something wrong or incomplete? How did you catch it?
- If you had another hour, what would you improve first?
- What does this experience tell you about how software development is changing?

## Evaluation criteria

We're not grading the code — we're grading you as an AI-powered engineer.

| Area | What we look for |
| --- | --- |
| Prompting quality | Clear, structured, iterative — not a wall of text on the first try |
| Product judgment | Does the UX make sense? Did you push back on anything the AI suggested? |
| Debugging mindset | How did you diagnose and fix problems without touching the code directly? |
| Delivery | Did it ship? Does it work? Is it polished? |
| Reflection | Honest, specific — not "AI is amazing" |

## Suggested tech stack (you may deviate with good reason)

- **Frontend:** Vue 3 + Vite + Tailwind CSS
- **Mobile:** Flutter 3
- **Backend/DB:** Supabase (handles auth, database, and real-time out of the box)
- **Hosting:** Vercel or Netlify (web), Flutter web build for mobile demo
- **AI tools:** Cursor, Claude, Copilot — your choice, use what makes you fastest

## Submission

Send your live URLs and repo link to [hiring contact] at least 1 hour before your presentation slot. Be ready to share your screen and walk through both apps live.

Questions? Reach out. Good luck — we're rooting for you.
