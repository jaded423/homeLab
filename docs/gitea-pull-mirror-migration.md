# Gitea Pull-Mirror Migration Plan

**Status:** planned 2026-07-02, execution starts next session. **Goal:** stop juggling
per-repo multi-push. Flip Gitea backup from **push-mirror** (each `git push` fans out to
GitHub + Gitea) to **pull-mirror** (single `git push` → GitHub only; Gitea auto-pulls
from GitHub on a schedule). Keeps 3-2-1 (local + GitHub offsite + Gitea homelab).

---

## Current state (starting point — don't redo)

- **Gitea:** `192.168.68.101` (VM101). SSH `:2223`, API `:3001`. Token at
  `~/scripts/config/gitea_token`. Personal namespace = `jaded/`.
- **Model today = push-mirror.** Origins carry GitHub + Gitea push URLs; `git push` hits both.
- **Already on Gitea (push-mirror, `jaded/`):** the long-standing jaded423 repos (coa,
  odooReports, scripts, zshConfig, nvimConfig, terminalConfig, gsuite, mcp, leadscout,
  odooModules, elevatedOdoo, ABM, daxOrder, …) **plus 9 wired 2026-07-02**: photoEditor,
  b2bScraper, coaDax, daxCrawler, geoTracker, point4, unibrain, vault, elevatedWeb.
- **photoEditor specifics:** origin = `jaded423/photoEditor` (push), `elevated` remote =
  `Elevated-Trading-LLC/photoEditor` **fork** with push **disabled** (`DISABLED_use_github_fork_sync`,
  fetch kept). Fork syncs via GitHub. Branch = `main`.
- **NOT backed yet:** `point4pi` (origin `point4project/point4pi` — Cody's org, Joshua authored;
  back up in its own Gitea org, not `jaded/`).
- **Reachability gotcha:** Gitea only reachable when **Twingate up** (or TS shared-tail
  personalnet→worknet → tower ProxyJump → VM101). Pushes over TG were **flaky 2026-07-02** —
  first-push-after-create failed repeatedly; needed retry-until-`ls-remote`-confirms.

## Prerequisites (BLOCKERS — get before executing)

1. **GitHub PAT, `repo` read scope**, covering `jaded423` + orgs (`Elevated-Trading-LLC`,
   `point4project`, `Dax-Distro`). Fine-grained read-only preferred. `gh auth token` can
   bootstrap but rotates — a dedicated PAT won't die under the mirrors. **Needed because
   private repos require `auth_token` in the Gitea mirror config.**
2. **Decision:** uniform pull-mirror for everything, OR keep ABM/elevatedWeb on instant
   push-mirror while hot. (User: keep their **namespace** in `jaded/` for now regardless —
   re-home to `elevated/` only when stable, same rule as photoEditor.)

## Steps

1. **Inventory.** `gh repo list jaded423 --limit 300 --json name,isPrivate` + same per org.
   List Gitea repos via API. Map: mirrored vs not, push-type vs mirror-type.
2. **Create Gitea orgs** matching GitHub: `elevated`, `point4project`, `dax`. (Namespace
   moves for existing `jaded/` repos deferred; only NEW org backups like point4pi go
   straight to their org.)
3. **Convert each push-mirror → pull-mirror.** Per repo:
   - GitHub is source of truth — confirm GitHub has latest first.
   - Delete the regular Gitea repo, recreate via Migrate API:
     `POST /api/v1/repos/migrate` with `{clone_addr:"https://github.com/<owner>/<name>.git",
     repo_name, repo_owner:"jaded"|<org>, mirror:true, mirror_interval:"8h0m0s",
     private:true, service:"github", auth_token:"<PAT>"}`.
   - **Test on ONE repo first** — newer Gitea can add a pull-mirror to an existing repo via
     Settings (no delete); if API supports it, prefer that (non-destructive).
4. **Strip multi-push** from every origin: `git remote set-url --delete --push origin <gitea-url>`
   → back to single GitHub push. (Pull-mirrors are READ-ONLY in Gitea and reject pushes, so
   the two models can't coexist — this step is mandatory, not optional.)
5. **Discovery cron** (Mac or VM101, daily): `gh repo list` across jaded423 + orgs → for any
   repo with no Gitea mirror, create one via Migrate API. Idempotent, logged. **This is the
   real "stop remembering" win — new repos self-enroll.**
6. **Update `push-all` skill** (`~/.claude/skills/push-all/SKILL.md`): drop the "auto-add
   Gitea push URL" logic → replace with "ensure a Gitea pull-mirror exists (create via
   Migrate if missing)."
7. **point4pi** → Gitea `point4project` org as a pull-mirror.

## Verify

- Manual sync trigger: `POST /api/v1/repos/{owner}/{repo}/mirror-sync` then
  `git ls-remote <gitea-url>` HEAD == GitHub HEAD.
- Origins: `git remote get-url --push --all origin` = 1 URL (GitHub), no `2223`.
- End-to-end: push a commit to GitHub, trigger/await mirror-sync, confirm Gitea caught it.
- Discovery cron dry-run lists missing mirrors correctly, then creates them.

## Gotchas

- **Twingate up** required for Gitea from Mac; TS shared-tail path is the fallback.
- Flaky TG pushes 2026-07-02 → always **verify by `ls-remote`**, retry, don't trust push exit alone.
- Deleting Gitea repos to recreate = destructive; safe because GitHub is source, but double-check.

## Deferred (not now)

- Re-home ABM + elevatedWeb `jaded/` → `elevated/` (still heavily worked; move when stable).
