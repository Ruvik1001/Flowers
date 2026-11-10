# Collaboration Guide

This is a monorepo for the Flowers shop management system.

## Repository layout

- `backend/` — API and server-side domain (backend team)
- `frontend/` — client application (frontend collaborators)
- Root docs: `README.md`, `README_RU.md`, `COLLAB.md`, `COLLAB_RU.md`

## Mandatory long-lived Git branches

Collaborators **must** use this branch model:

| Branch | Purpose |
|---|---|
| `master` | Stable integration branch |
| `backend` | Backend integration line |
| `frontend` | Frontend integration line |

### Workflow

1. Backend features branch from `backend` (example: `backend/feat-supplies`).
2. Frontend features branch from `frontend` (example: `frontend/feat-sales-ui`).
3. Merge feature branches back into `backend` or `frontend` respectively.
4. Promote tested changes into `master` by agreement (PR/review).

Do not push feature work directly to `master` unless explicitly agreed.

## Backend documentation rules (for API consumers)

- After every commit that affects the frontend contract, add/update API docs.
- Doc file mask: `xx_id_desc.md` (`xx` = ordinal, `id` = commit identifier, `desc` = short description).
- Docs are written **only after** the commit exists.
- Keep Postman collection in sync.
- Required sections in each API doc file:
  - Title
  - Short file description
  - Endpoint description
  - Endpoint name
  - Accepted headers (+ required flag)
  - Accepted fields/params (+ required flag)
  - Accepted body (+ required flag)
  - Request and response examples
  - Expected error codes and error messages

## Shared engineering rules

- Real environment files are never committed; only `.env.example`.
- All runtime settings come from environment variables.
- Requests must be logged and traced (MonitoringPLTG on the server).
- Backend test coverage target: ≥ 90%.
- Before starting a new feature, re-read architecture documentation.
- Keep `README.md` (English) and `README_RU.md` (Russian) up to date.

## Contacts / ownership

- Backend ownership: backend team (this repository `backend/` line)
- Frontend ownership: frontend collaborators (`frontend/` line)

Update this file when collaboration process changes.
