---
name: dev-note
description: Write a developer note that explains the most recent fix - the problem, the root cause, the change, and the verification - by scanning uncommitted work or the last commit in the current repository. Use when asked for a dev note, a fix writeup, a handover note, or an explanation of what was just fixed and why.
metadata:
  short-description: Document the latest fix as a problem/root-cause/fix/verification note
---

# Dev Note

Produce a short, factual developer note describing the most recent fix in the
current repository. The note explains what broke, why it broke, what was changed,
and what proves the change works. It is written for a developer who did not make
the change and has no session context.

## Scope selection

Determine the subject before writing anything.

1. If the invocation names a target (a commit SHA, a range such as `dev...HEAD`,
   a branch, or a path), document exactly that.
2. Otherwise run `git status --porcelain`. If the working tree has modified,
   staged, or untracked source files, document that uncommitted work.
3. Otherwise document `HEAD`.

State the resolved scope in the note's header line so the reader knows what was
inspected. Do not silently widen the scope. Ignore lock files, build artifacts,
`vendor/`, caches, and editor noise when deciding whether the tree is dirty, but
mention them in the note if they were genuinely part of the fix.

## Gathering evidence

Read the actual diff; never infer a fix from file names or commit subjects.

- Uncommitted scope: `git status --porcelain`, `git diff`, `git diff --staged`,
  and the contents of relevant untracked files.
- Commit scope: `git show --stat <ref>` then `git show <ref>`.
- Range scope: `git log --oneline <range>` and `git diff <range>`.

Then read enough surrounding code to understand the mechanism. For each changed
hunk, identify the function or block it sits in and what calls it. If the diff
alone does not explain why the old code was wrong, open the file and trace the
path. Use `git log -L` or `git blame` on the changed lines when the history
clarifies the original intent.

Collect verification evidence that already exists: new or modified tests, test
output from the session, commands that were run, and any migration or script that
has to be executed. Do not run the project's full test suite unless asked.

## Writing the note

Write to `docs/dev-notes/<YYYY-MM-DD>-<slug>.md`, creating the directory if
needed. The slug is three to five lowercase words naming the fix, not the module.
If a note for the same fix already exists for the same date, update it instead of
creating a second file.

Use this structure:

```markdown
# <Fix title>

<One line: scope inspected, date, branch.>

## Problem

## Root cause

## The fix

## Verification

## Follow-ups
```

Section rules:

- **Problem** - the observable symptom, in the terms the reporter would use: the
  wrong number, the failing request, the error text, who hit it and where. State
  the trigger conditions. If the symptom was intermittent or data-dependent, say
  what made it appear.
- **Root cause** - the actual mechanism, not a restatement of the symptom. Name
  the responsible code as `path/to/file.php:123`. Explain why the old code was
  wrong in the case that failed and right, or merely untested, in the cases that
  passed. If several causes compounded, order them by what has to be understood
  first.
- **The fix** - what changed and why that resolves the root cause. Group by
  concern rather than walking the diff file by file. Reference each touched file
  with line numbers. Call out behavior that intentionally did not change, and any
  guard, default, or backward-compatibility decision a reviewer might question.
- **Verification** - what proves it. Name the tests, the commands with their real
  output summary, and the manual checks. Record pass and failure counts as
  observed. If something was not verified, write that it was not verified and
  why; never imply coverage that does not exist.
- **Follow-ups** - known gaps, deferred work, required deploy steps, migrations,
  cache clears, or configuration. Omit the section when there are none.

## Accuracy rules

- Report only what the diff, the code, and the recorded command output support.
  Never invent a root cause that fits the symptom but is not visible in the code.
- If the diff does not reveal why the change was made, say so and ask, rather
  than guessing a plausible rationale.
- Prefer prose in full sentences; use bullets for genuine lists such as touched
  files or follow-ups. No filler, no praise of the fix, no summary of the note
  inside the note.
- Keep the note under roughly 500 words unless the change is large. Length should
  track the complexity of the mechanism, not the size of the diff.
- Do not include credentials, tokens, `.env` values, personal data, or raw
  student, payroll, or payment records. Describe the shape of the data instead.
- Do not commit, push, or amend anything. Writing the note file is the only
  change this skill makes to the working tree.

## Reporting back

End by printing the note's path and a two or three sentence summary covering the
root cause and the fix, so the note does not have to be opened to know what
happened.
