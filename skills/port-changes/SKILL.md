---
name: port-changes
description: Port the uncommitted working-tree changes of the current repository into one or more sibling repositories under D:\laragon\www. Lets the user pick several targets, then for each one, in turn, brings its feature/fix branch up to date with the latest base branch, applies the change (patch first, by-hand port where the code has drifted), commits only the ported change even when the target is already dirty, and pushes after the user confirms. Use when asked to port, carry over, copy, or apply current changes to another repo or school system.
metadata:
  short-description: Safely port working-tree changes to sibling repos' feature/fix
---

# Port Changes

Carry the current repo's uncommitted changes into one or more sibling repos
under `D:\laragon\www`, on each one's `feature/fix` branch, without disturbing
anything the user already has in progress there. Siblings share history but have drifted:
port the **behavior**, not just the bytes.

Exact commands for each step are in `references/git-recipes.md`. Read it before
you start. Use Git Bash for the recipes (on PowerShell, `bash -c '...'`).

## 1. Capture the source change (read-only)

The source is the repo the session is working in. Never modify it.

- Snapshot staged + unstaged + untracked (not ignored) changes against `HEAD`
  as one binary patch (recipe **R1**). Save it, plus a name-status list, in a
  temp folder outside both repos.
- Leave out `vendor/`, `node_modules/`, `storage/`, `bootstrap/cache/`,
  `public/build/`, other build output, and every `.env*`. Lock files
  (`composer.lock`, `package-lock.json`) are listed but not ported unless asked.
- Stop if nothing is left.
- Read the whole diff and write yourself a short summary of what it does and
  why: which screen or flow, which data, which new methods, routes, views,
  migrations, config keys, or JS it depends on. The by-hand port relies on this.

## 2. Pick the targets (one or more)

If the invocation names repos, use them. Otherwise list git repos directly in
`D:\laragon\www` (recipe **R2**), skipping the source, non-git folders, and
names containing `Copy`, `scratch`, or `tmp`. Show a **numbered** table, most
relevant first: how many of the changed paths exist there, repo, current
branch, number of dirty files, base branch, whether `feature/fix` exists.

Ask the user to pick **any number** of them:
- Claude Code: AskUserQuestion with `multiSelect: true`, offering the top four
  by relevance; tell them to use "Other" to type more numbers or names from the
  table (`3, 7, 12` or `es_pcc es_mda`).
- Codex: ask them to reply with numbers or names.

Repeat the final list back (in the order given) before touching anything.
Drop, and say why, any target that has no `origin`, is the source, or has a
merge, rebase, cherry-pick, or revert in progress.

## Run steps 3–7 for each target, one at a time

Finish one target completely (including its push decision) before starting
the next. Each target gets its own temp folder and fresh variables (R2). The
source patch from step 1 is reused as is; never re-capture between targets.

When a target stops on a problem (conflict, overlap, refused switch, failed
check), ask: **skip this repo and continue**, or **stop here**. A skipped
target keeps whatever state step 3 left it in; say exactly what that is
(branch, any merge already done, any stash) so the user can pick it up later.
Never let one target's problem change what happens in another.

## 3. Prepare the target

1. `git fetch origin --prune`. Find the base branch from the remote's HEAD
   (recipe **R3**): usually `dev`, `main`, or `master`.
2. Record the starting state: branch, `HEAD`, `git status --porcelain`, any
   staged changes, and `git stash list` count. Show the dirty files to the user
   and say they will be left uncommitted.
3. Get onto `feature/fix` (recipe **R4**). Uncommitted work comes along and stays
   uncommitted. If git refuses because it would overwrite that work, stop and
   offer: abort, or a labeled stash (`port-changes: <source> <timestamp>`) that
   you pop back at the end.
4. Bring `feature/fix` up to date without rewriting history (recipe **R5**):
   merge `origin/feature/fix`, then `origin/<base>`. Fast-forward when possible,
   otherwise a normal merge commit. If git refuses because of dirty or staged
   files, or the merge conflicts, stop and ask. Resolve conflicts only with the
   user's agreement.
5. Take the **pre-port snapshot** of the working tree as a tree object
   (recipe **R6**). Everything after this point is the port.

## 4. Port

For each changed file, in dependency order (migrations and config, models,
services, controllers, routes, views, JS):

- **Clean in the target:** `git apply --3way` for that file. Conflict markers
  mean drift: resolve by hand, keeping the target's own code.
- **Already dirty in the target:** plain `git apply` for that file (no `--3way`,
  it needs a clean index). Never overwrite the user's edits.
- **Patch fails, file missing, or the surrounding code differs:** port by hand.
  Read the source change and the target file, find where the same behavior
  lives in the target (it may have a different name or place), and re-create
  it. Keep target-specific branding, school names, permissions, routes,
  reports, and workflows.
- **Not applicable** (the feature doesn't exist in the target): skip and say why.

Mark each file `patched`, `hand-ported`, or `skipped (reason)`. Then follow the
change's dependencies: every new method, route, view, migration, config key,
JS function, or permission it uses must exist in the target or be ported too.

## 5. Check

- `php -l` every changed PHP file. Check Blade directives and JS syntax.
- If routes changed and the app boots, `php artisan route:list --path=<prefix>`
  (read-only; never run migrations, seeders, or anything that writes data).
- Diff the post-port tree against the pre-port snapshot (recipe **R7**): every
  source change is accounted for, nothing unrelated changed, no secrets, no
  `.env` values, no hard-coded source-school names.
- Flag, don't run: new migrations, composer/npm changes, config or route cache
  clears, scheduled jobs.

## 6. Commit only the port

Build the commit from `HEAD` plus the port patch alone, using a temporary index
(recipe **R8**), so the user's existing staged and unstaged work stays out. If
the port patch won't apply to `HEAD` because it overlaps lines the user had
already changed, stop and ask: the user decides whether to commit those
together or separate them.

Message: `Port <short summary> from <source-repo>`, then a body listing each
file with patched / hand-ported / skipped and any follow-up. If the repo has
active hooks (recipe **R8** shows how to check), run them before committing;
never bypass them.

## 7. Confirm, then push

Show the user: target (and `n of N`), branch, base, commit SHA and message,
the file table, check results, warnings (migrations, dependencies, caches), and
the dirty work left untouched. Ask before pushing: **push**, **don't push**, or
**push this and the remaining targets without asking** (only offered when more
targets follow; the summary for each is still shown, and any problem still
stops and asks).

On yes (recipe **R9**):
1. Fetch again. If `origin/<base>` or `origin/feature/fix` moved, merge again
   under the same rules and re-run step 5.
2. `git push origin feature/fix` (`-u` if the branch is new on origin).
3. Pop the stash if step 3 made one. If it conflicts, leave the stash in place
   and tell the user.

On no: leave the commit local and say how to undo it (`git reset --soft HEAD~1`
is the user's call, not yours).

## Rules

- Never modify the source repo.
- Never commit, stage permanently, or discard the target's pre-existing work.
- Never `reset --hard`, `clean`, `checkout -- .`, `restore`, force push, rebase a
  pushed branch, or skip hooks.
- Never port `.env*`, credentials, or real student, parent, employee, or payment
  data.
- Only `feature/fix`. No pull request unless asked.
- Targets are handled strictly one after another, never in parallel.
- If a step's outcome is unclear, stop and report the exact git output.

## Finish

A table with one row per chosen target: repo, result (pushed SHA / committed,
not pushed / skipped / not reached), files patched / hand-ported / skipped,
follow-ups the user must do, and anything left in a stash or uncommitted. If
the run stopped early, list the targets that were not reached so the user can
re-run with just those.
