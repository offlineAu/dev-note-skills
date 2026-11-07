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

Conflicts are resolved, not reasons to stop (see **Resolving conflicts**).
When a target still stops (a conflict that needs the user's decision and they
can't give one, a failed check, an unexpected git error), ask: **skip this repo and continue**, or **stop here**. A skipped
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
   uncommitted. If git refuses because it would overwrite that work, set aside
   only the colliding files (**Resolving conflicts → D**) and switch again.
4. Bring `feature/fix` up to date without rewriting history (recipe **R5**):
   merge `origin/feature/fix`, then `origin/<base>`. Fast-forward when possible,
   otherwise a normal merge commit. If the merge would conflict, or the repo
   has staged changes, do the merge in a side worktree and resolve it there
   (**Resolving conflicts → A**). If git refuses because the update touches
   files the user has uncommitted edits in, use **→ D**.
5. Take the **pre-port snapshot** of the working tree as a tree object
   (recipe **R6**). Everything after this point is the port.

## 4. Port

For each changed file, in dependency order (migrations and config, models,
services, controllers, routes, views, JS):

- **Clean in the target:** `git apply --3way` for that file. Conflict markers
  mean drift: resolve them (**Resolving conflicts → B**).
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
the port patch won't apply to `HEAD` for some files because the port touches
lines the user had already changed, build the committed version of those files
separately (**Resolving conflicts → C**).

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
   under the same rules (including **A** and **D**) and re-run step 5.
2. `git push origin feature/fix` (`-u` if the branch is new on origin). If it
   is rejected because the remote moved, go back to 1. Never force.
3. Pop the stash if step 3 made one. If it conflicts, resolve it
   (**Resolving conflicts → D**).

On no: leave the commit local and say how to undo it (`git reset --soft HEAD~1`
is the user's call, not yours).

## Resolving conflicts

Resolve conflicts yourself; don't stop just because one appeared. The user's
uncommitted work must never be inside a conflict you are resolving, which is
why merges happen in a side worktree (A) and the user's edits are set aside
first when they collide (D).

### How to decide each conflicted hunk

1. Look at all three versions: the common ancestor, ours, and theirs
   (`git show :1:<path>`, `:2:`, `:3:`), and run `git log --oneline -5 <side>
   -- <path>` on each side to learn **why** it changed. Read the surrounding
   code, not just the hunk.
2. Both sides added different things (methods, routes, imports, menu items,
   array entries, CSS rules): keep both, in a sensible order, without
   duplicates.
3. Both sides changed the same lines:
   - In a merge from the base branch or `origin/feature/fix` (A): take the
     incoming fix, then re-apply what `feature/fix` was doing on top if it is
     still needed.
   - In a port (B, C): keep the target's version and add the source's
     behavior into it.
   - Either way, target-specific code always survives: school names, branding,
     logos, permissions, report layouts, school-specific workflows.
4. One side deleted or renamed what the other changed: find where the code
   went (`git log --follow`, search for the function name) and put the change
   there. If it is truly gone, ask.
5. Lock files (`composer.lock`, `package-lock.json`): never hand-merge. Take
   the incoming version in A, flag `composer install` / `npm install`.
6. **Ask the user instead of guessing** when the two sides want different
   behavior (not just different code), or the conflict is in a migration,
   grade or money calculation, permission check, or config value. Show both
   versions in a few lines and your proposal.

### After resolving

- No conflict markers remain (`git diff --check`, plus a search for
  `<<<<<<<`, `=======`, `>>>>>>>` at line start in the resolved files).
- `php -l` each resolved PHP file; check Blade and JS still parse.
- Write one line per file for the summary: what each side did and what you
  kept. These lines go into the commit message and the step 7 summary.

### A. Updating feature/fix (recipe **R10**)

Create a temporary detached worktree from `HEAD` under the target's temp
folder, run the merge there, resolve, `git add` only the resolved paths, and
commit the merge. Back in the live folder, `git merge --ff-only` to that commit,
then remove the temp worktree. The user's dirty and staged files never take
part. To give up, just remove the temp worktree: nothing in the live folder
changed.

### B. Port conflicts in clean files

`git apply --3way` left markers in the live file. Ours = the target, theirs =
the source change. Resolve in place with the rules above, then continue.

### C. Port overlaps the user's uncommitted lines (recipe **R11**)

The live file now holds the user's edits **and** the port, which is correct for
the working tree. For the commit, build a second version: the target's `HEAD`
copy with **only** the port applied by hand, and put that into the temporary
commit index. Show the user both: what will be committed, and what stays as
their uncommitted change afterwards (`git diff HEAD -- <path>` after the
commit should be exactly their own edits).

### D. The user's uncommitted edits collide (recipe **R12**)

Happens when switching branch, fast-forwarding, or popping the stash would
touch files the user has edited. Stash **only those files** with a labeled
message, do the operation, then pop. If the pop conflicts: ours = the updated
branch, theirs = the user's work. Keep both; the user's edits win on the same
lines unless that would undo the update or the port, then ask. Unstage the
resolved files so they are uncommitted again, exactly as before. Drop the
stash only after the files are verified; if anything is unclear, keep the
stash and say so.

## Rules

- Never modify the source repo.
- Never commit, stage permanently, or discard the target's pre-existing work.
- Never `reset --hard`, `clean`, `checkout -- .`, `restore`, force push, rebase a
  pushed branch, or skip hooks. (Force-removing the skill's own temporary
  worktree is fine; it holds nothing of the user's.)
- Never resolve a conflict with a blanket `--ours` / `--theirs` / `-X` on a
  whole merge; decide each hunk.
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
