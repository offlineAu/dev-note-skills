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

If `git switch` refuses ("would be overwritten"), nothing changed. Ask the user;
on "stash":

```bash
git stash push -u -m "port-changes: $SRCNAME $(date +%Y%m%d-%H%M%S)"
STASH_SHA=$(git rev-parse stash@{0})     # pop this exact entry later (R9)
```

then repeat R4.

## R5. Update feature/fix (no history rewrite)

Run for `origin/feature/fix` (if it exists) and then `origin/$base`:

```bash
up() {   # $1 = remote ref
  git merge-base --is-ancestor "$1" HEAD && { echo "up to date with $1"; return 0; }
  if git merge-base --is-ancestor HEAD "$1"; then
    git merge --ff-only "$1"                    # refuses, unchanged, if it would touch dirty files
  else
    git diff --cached --quiet || { echo "STAGED CHANGES: a real merge would sweep them in; ask"; return 1; }
    git merge-tree --write-tree HEAD "$1" >/dev/null || { echo "MERGE WOULD CONFLICT with $1; ask"; return 1; }
    git merge --no-edit "$1"                    # refuses, unchanged, if it would touch dirty files
  fi
}
git show-ref -q --verify refs/remotes/origin/feature/fix && up origin/feature/fix
up "origin/$base"
```

Any non-zero result: stop and show the user the output. Do not resolve
conflicts or retry with other flags on your own.

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
GIT_INDEX_FILE="$IDX" git apply --cached --binary "$TW/port.patch" \
  || { echo "PORT OVERLAPS PRE-EXISTING EDITS: ask"; exit 1; }
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

Restore a stash made in R4:

```bash
ref=$(git stash list --format='%gd %H' | awk -v h="$STASH_SHA" '$2==h{print $1}')
[ -n "$ref" ] && git stash pop "$ref"   # on conflict the stash is kept: tell the user
```
