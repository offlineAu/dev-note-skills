# Git recipes for port-changes

Git Bash syntax. Needs git 2.38+ (`merge-tree --write-tree`, `git hook run`).
Set these once and reuse them in every recipe:

```bash
SRC=$(git rev-parse --show-toplevel)          # run inside the source repo
SRCNAME=$(basename "$SRC")
WORK=<a new empty folder outside both repos>  # e.g. the session scratchpad
mkdir -p "$WORK"
EXCL=(':(exclude)vendor' ':(exclude)node_modules' ':(exclude)storage'
      ':(exclude)bootstrap/cache' ':(exclude)public/build'
      ':(exclude,glob)**/.env*')
```

Every snapshot below uses a **temporary index** (`GIT_INDEX_FILE`), so the
user's real index is never changed. `git add` into a temporary index does write
blob objects into `.git/objects`; that is harmless and is not a change to the
work.

## R1. Capture the source change

```bash
export GIT_INDEX_FILE="$WORK/src.idx"; rm -f "$GIT_INDEX_FILE"
git -C "$SRC" read-tree HEAD
git -C "$SRC" add -A -- . "${EXCL[@]}"
git -C "$SRC" diff --cached --binary HEAD -- . "${EXCL[@]}"            > "$WORK/source.patch"
git -C "$SRC" diff --cached --name-status -M HEAD -- . "${EXCL[@]}"   > "$WORK/source.files"
unset GIT_INDEX_FILE
[ -s "$WORK/source.patch" ] || echo "NOTHING TO PORT"
grep -E '(composer|package)-lock\.json|composer\.lock|yarn\.lock' "$WORK/source.files"  # list, don't port unless asked
```

## R2. List candidate targets

Reads local state only (no fetch). Runs 8 repos at a time; the first run after
a reboot can still take a minute or two while the disk warms up.

```bash
cut -f2 "$WORK/source.files" > "$WORK/paths.txt"   # first path of each entry
row() {   # $1 = repo dir; prints one tab-separated row
  local r=${1%/} n br dirty base ff hits total
  n=$(basename "$r"); total=$(wc -l < "$WORK/paths.txt")
  br=$(git -C "$r" branch --show-current)
  dirty=$(git -C "$r" status --porcelain | wc -l)
  base=$(git -C "$r" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); base=${base#origin/}
  if git -C "$r" show-ref -q refs/heads/feature/fix refs/remotes/origin/feature/fix; then ff=yes; else ff=no; fi
  hits=$(git -C "$r" ls-tree -r --name-only HEAD 2>/dev/null | grep -Fxc -f "$WORK/paths.txt")
  printf '%s\t%s\t%s\tdirty=%s\tbase=%s\tfeature/fix=%s\n' \
    "$hits/$total paths" "$n" "${br:-DETACHED}" "$dirty" "${base:-?}" "$ff"
}
export -f row; export WORK
for d in /d/laragon/www/*/; do
  r=${d%/}; n=$(basename "$r")
  [ -d "$r/.git" ] || continue
  [ "$r" -ef "$SRC" ] && continue
  case "$n" in *Copy*|*scratch*|*tmp*) continue;; esac
  printf '%s\0' "$r"
done | xargs -0 -P 8 -I{} bash -c 'row "$1"' _ {} \
  | sort -t$'\t' -k1,1nr -k2,2 | cat -n > "$WORK/targets.txt"
cat "$WORK/targets.txt"
```

Show this numbered list to the user. They answer with numbers or names
(`3, 7, 12` or `es_pcc es_mda`); keep the chosen repos in that order.

Start of **each** target: fresh variables, its own temp folder, and refuse it
if it is busy:

```bash
T=/d/laragon/www/<target>; cd "$T"
TW="$WORK/$(basename "$T")"; mkdir -p "$TW"
unset base START_BRANCH START_HEAD STAGED STASH_SHA PRE POST OLD NEW TREE IDX NEW_BRANCH
git remote get-url origin >/dev/null || echo "NO ORIGIN"
for f in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD REBASE_HEAD rebase-merge rebase-apply; do
  [ -e "$(git rev-parse --git-path "$f")" ] && echo "BUSY: $f"
done
```

## R3. Base branch

```bash
git fetch origin --prune
base=$(git ls-remote --symref origin HEAD | sed -n 's#^ref: refs/heads/\(.*\)\tHEAD$#\1#p')
[ -n "$base" ] || { base=$(git symbolic-ref --short refs/remotes/origin/HEAD); base=${base#origin/}; }
git rev-parse -q --verify "origin/$base" || echo "BASE NOT FOUND: ask the user"
```

Record the starting state:

```bash
START_BRANCH=$(git branch --show-current); START_HEAD=$(git rev-parse HEAD)
git status --porcelain > "$TW/start.status"
git diff --cached --quiet && STAGED=no || STAGED=yes
```

## R4. Get onto feature/fix

```bash
if   [ "$(git branch --show-current)" = feature/fix ]; then :
elif git show-ref -q --verify refs/heads/feature/fix;          then git switch feature/fix
elif git show-ref -q --verify refs/remotes/origin/feature/fix; then git switch -c feature/fix --track origin/feature/fix
else                                                               git switch -c feature/fix --no-track "origin/$base"
fi
```

If `git switch` refuses ("would be overwritten"), nothing changed. Set aside
only the files it names (R12), switch, and pop them back at the end (R9).

## R5. Update feature/fix (no history rewrite)

Run for `origin/feature/fix` (if it exists) and then `origin/$base`:

```bash
up() {   # $1 = remote ref
  git merge-base --is-ancestor "$1" HEAD && { echo "up to date with $1"; return 0; }
  if git merge-base --is-ancestor HEAD "$1"; then
    git merge --ff-only "$1" || { echo "COLLIDES WITH UNCOMMITTED EDITS: R12, then retry"; return 1; }
  else
    side_merge "$1"                             # R10: real merges never happen in the live folder
  fi
}
git show-ref -q --verify refs/remotes/origin/feature/fix && up origin/feature/fix
up "origin/$base"
```

Return code 2 from `side_merge` = conflicts to resolve in the side worktree
(R10). Run `up` for `origin/$base` only after `origin/feature/fix` is done.

## R6. Pre-port snapshot

```bash
snap() {   # prints a tree id for the whole working tree, real index untouched
  local idx="$TW/tgt.$1.idx"; rm -f "$idx"
  GIT_INDEX_FILE="$idx" git read-tree HEAD &&
  GIT_INDEX_FILE="$idx" git add -A -- . "${EXCL[@]}" &&
  GIT_INDEX_FILE="$idx" git write-tree
}
PRE=$(snap pre)
git status --porcelain > "$TW/pre.status"   # files already dirty = user's work
```

Applying the patch (step 4 of SKILL.md), one file at a time:

```bash
p=<path>
if grep -q " $p\$" "$TW/pre.status"; then        # already dirty: working tree only
  git apply --check --include="$p" "$WORK/source.patch" && git apply --include="$p" "$WORK/source.patch"
else                                               # clean: 3-way (may leave conflict markers)
  git apply --3way --include="$p" "$WORK/source.patch"
fi
```

For renames, include both old and new paths. Anything that fails: port by hand.

## R7. Port patch and review

```bash
POST=$(snap post)
git diff --stat --find-renames "$PRE" "$POST"
git diff --binary "$PRE" "$POST" > "$TW/port.patch"
git diff --name-status -M "$PRE" "$POST"     # compare with $WORK/source.files
git diff "$PRE" "$POST" | grep -nE '^\+.*(APP_KEY|PASSWORD|SECRET|TOKEN|DB_)' # must be empty or explained
```

## R8. Commit only the port

Check hooks first:

```bash
hooks=$(git config core.hooksPath || git rev-parse --git-path hooks)
ls "$hooks" 2>/dev/null | grep -v '\.sample$'   # any output = active hooks
```

Write the message to `$TW/msg.txt`, then:

```bash
IDX="$TW/commit.idx"; rm -f "$IDX"
OLD=$(git rev-parse HEAD)
GIT_INDEX_FILE="$IDX" git read-tree "$OLD"
# files whose port hunks overlap the user's uncommitted lines (handled by R11)
: > "$TW/overlap.txt"
git diff --name-only --no-renames "$PRE" "$POST" | while IFS= read -r p; do
  git diff --binary "$PRE" "$POST" -- "$p" > "$TW/one.patch"
  GIT_INDEX_FILE="$IDX" git apply --cached --check --binary "$TW/one.patch" 2>/dev/null || echo "$p" >> "$TW/overlap.txt"
done
ex=(); while IFS= read -r p; do ex+=(--exclude="$p"); done < "$TW/overlap.txt"
GIT_INDEX_FILE="$IDX" git apply --cached --binary "${ex[@]}" "$TW/port.patch" || exit 1
cat "$TW/overlap.txt"        # non-empty: run R11 for each path before going on
GIT_INDEX_FILE="$IDX" git hook run --ignore-missing pre-commit || exit 1
git hook run --ignore-missing commit-msg -- "$TW/msg.txt"   || exit 1
TREE=$(GIT_INDEX_FILE="$IDX" git write-tree)
NEW=$(git commit-tree "$TREE" -p "$OLD" -F "$TW/msg.txt")
git update-ref -m "port-changes from $SRCNAME" refs/heads/feature/fix "$NEW" "$OLD"
# point the real index at the new commit for ported paths only (-r: never run a bare reset)
git diff -z --name-only --no-renames "$PRE" "$POST" | xargs -0 -r git reset -q --
```

Verify: `git show --stat HEAD` lists only ported files, and `git status
--porcelain` lists only files from `$TW/start.status` (the user's own work).
If a ported path had staged changes before, `git reset` unstaged them (content
kept in the working tree); tell the user.

## R9. Push

After the user says yes:

```bash
git fetch origin --prune
NEW_BRANCH=no; git show-ref -q --verify refs/remotes/origin/feature/fix || NEW_BRANCH=yes
# re-run R5 (up ...). If it merged anything, re-run the checks before pushing.
if [ "$NEW_BRANCH" = yes ]; then git push -u origin feature/fix; else git push origin feature/fix; fi
```

Rejected as non-fast-forward: fetch, R5 again, push again. Never `--force`.

Restore anything set aside with R12 (pop and, if needed, resolve as R12 shows).

## R10. Merge in a side worktree (Resolving conflicts → A)

The merge runs in a temporary detached worktree. The live folder only ever
fast-forwards to the finished merge commit, so the user's dirty and staged
files never take part.

```bash
side_merge() {   # $1 = ref to merge into feature/fix
  MW="$TW/merge"
  [ -e "$MW" ] && git worktree remove --force "$MW"
  git worktree add -q --detach "$MW" HEAD || return 1
  if git -C "$MW" merge --no-edit -m "Merge $1 into feature/fix" "$1"; then
    finish_side_merge
  else
    echo "CONFLICTS in $MW:"; git -C "$MW" diff --name-only --diff-filter=U
    return 2
  fi
}
finish_side_merge() {
  git -C "$MW" diff --name-only --diff-filter=U | grep -q . && { echo "STILL UNRESOLVED"; return 1; }
  git -C "$MW" rev-parse -q --verify MERGE_HEAD >/dev/null && git -C "$MW" commit -q --no-edit
  M=$(git -C "$MW" rev-parse HEAD)
  git merge --ff-only "$M" || { echo "COLLIDES WITH UNCOMMITTED EDITS: R12, then: git merge --ff-only $M; git worktree remove --force \"$MW\""; return 1; }
  git worktree remove --force "$MW"
}
```

Resolving inside `$MW`, per conflicted path `p`:

```bash
cd "$MW"
git show ":1:$p"   # common ancestor
git show ":2:$p"   # ours   = feature/fix
git show ":3:$p"   # theirs = the ref being merged
git log --oneline -5 HEAD -- "$p"; git log --oneline -5 MERGE_HEAD -- "$p"
# edit "$MW/$p" following "How to decide each conflicted hunk", then:
git diff --check -- "$p"; grep -nE '^(<<<<<<<|=======|>>>>>>>)' -- "$p"   # both must be empty
php -l "$p"        # PHP files
git add -- "$p"    # only the resolved path, never -A
cd "$T"
```

Lock files: `git -C "$MW" checkout --theirs -- composer.lock && git -C "$MW" add composer.lock`
(this is the one place a whole-file side is taken), then flag `composer install`.

When every path is resolved: `finish_side_merge`. Add the per-file resolution
lines to the merge commit (`git -C "$MW" commit --amend` before
`finish_side_merge` is fine: nothing is pushed yet). To give up instead:
`git -C "$MW" merge --abort; git worktree remove --force "$MW"`; the live folder
is unchanged.

## R11. Commit version of an overlapping file (Resolving conflicts → C)

For each path in `$TW/overlap.txt`, after R8 applied the rest:

```bash
cv="$TW/commitver/$p"; mkdir -p "$(dirname "$cv")"
git show "HEAD:$p" > "$cv"                  # target as committed, without the user's edits
git diff "$PRE" "$POST" -- "$p"             # the port, as made in the live file
# edit "$cv": apply ONLY the port change, by hand
mode=$(git ls-tree HEAD -- "$p" | cut -d' ' -f1)
blob=$(git hash-object -w --path="$p" "$cv")
GIT_INDEX_FILE="$IDX" git update-index --cacheinfo "${mode:-100644},$blob,$p"
GIT_INDEX_FILE="$IDX" git diff --cached "$OLD" -- "$p"   # must show the port and nothing else
```

Then continue R8 (hooks, `write-tree`, `commit-tree`). After the commit,
`git diff HEAD -- "$p"` must show only the user's own edits; show it to them.

## R12. Set aside colliding edits (Resolving conflicts → D)

Collect the paths git refused on (it prints them indented with a tab), stash
only those, redo the operation:

```bash
git switch feature/fix 2>&1 | sed -n 's/^\t//p' > "$TW/collide.txt"   # or the failing merge --ff-only
mapfile -t C < "$TW/collide.txt"
# GUARD: with no paths, `stash push --` stashes EVERYTHING and `reset --` unstages
# everything. An empty list means git refused for another reason (e.g. diverged
# branches: use R10). Stop here.
[ ${#C[@]} -gt 0 ] || { echo "NO COLLIDING PATHS: not an R12 case"; cat "$TW/collide.txt"; return 1 2>/dev/null || exit 1; }
git stash push -u -m "port-changes: $SRCNAME $(date +%Y%m%d-%H%M%S) set-aside" -- "${C[@]}"
STASH_SHA=$(git rev-parse stash@{0})
# ... redo the switch / fast-forward ...
```

Bring them back (now, or at the end of R9 if the port should land first):

```bash
ref=$(git stash list --format='%gd %H' | awk -v h="$STASH_SHA" '$2==h{print $1}')
git stash pop "$ref"            # success: done, the stash is dropped
```

If the pop conflicts, the stash is kept and files have markers
(`Updated upstream` = the branch, `Stashed changes` = the user's work):

```bash
git diff --name-only --diff-filter=U        # resolve each file in place, then:
[ ${#C[@]} -gt 0 ] || exit 1                # same guard: never run the lines below without paths
grep -nE '^(<<<<<<<|=======|>>>>>>>)' -- "${C[@]}"   # must be empty
git reset -q -- "${C[@]}"                   # back to uncommitted and unstaged, like before
git stash show -p "$ref" | head -50         # compare: every user edit is present
git stash drop "$ref"                       # only after that check
```

Staged edits come back unstaged; tell the user which ones.
