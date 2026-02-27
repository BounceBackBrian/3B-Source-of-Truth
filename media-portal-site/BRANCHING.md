# Branching Strategy

## Protected Flow
- `dev`: integration/staging branch for daily work.
- `main`: production release branch.

## Standard Workflow
1. Create a feature branch from `dev`.
2. Open a PR into `dev`.
3. CI (`lint`, `typecheck`, `build`) must pass.
4. Merge `dev` into `main` only for approved releases.

## Naming Convention
- `feature/<short-description>`
- `fix/<short-description>`
- `chore/<short-description>`

## Rules
- Do not push directly to `main`.
- Keep PRs small and focused.
- Require governance checklist completion in PR template.
