---
name: dev-note
description: Write a plain-language note about the most recent fix for customer service staff, who relay it to live customers. Explains what customers experienced, what was wrong, what changed, whether it is live yet, and what to tell customers. Scans uncommitted work or the last commit. Use when asked for a dev note, a fix writeup, a support note, a handover note, or what to tell customers about a fix.
metadata:
  short-description: Explain the latest fix in plain language for customer service
---

# Dev Note

Write a note about the most recent fix for **customer service employees**. They
are not developers. They will read it, then explain it to live customers (school
staff, parents, students) by chat, phone, or email. Every sentence in the main
body has to make sense to someone who has never seen the code.

A developer appendix at the bottom keeps the technical detail for engineers.

## Scope selection

Decide what to document before writing anything.

1. If the invocation names a target (a commit SHA, a range such as `dev...HEAD`,
   a branch, or a path), document exactly that.
2. Otherwise run `git status --porcelain`. If source files are modified, staged,
   or untracked, document that uncommitted work.
3. Otherwise document `HEAD`.

Ignore lock files, build artifacts, `vendor/`, caches, and editor noise when
deciding whether the tree is dirty. State the resolved scope in the note's
appendix so developers know what was inspected.

## Gathering evidence

Read the real diff. Never infer a fix from file names or commit subjects.

- Uncommitted: `git status --porcelain`, `git diff`, `git diff --staged`, and
  the contents of relevant untracked files.
- Commit: `git show --stat <ref>`, then `git show <ref>`.
- Range: `git log --oneline <range>` and `git diff <range>`.

Read enough surrounding code to understand the mechanism. Then work out the
customer's side of it, which the diff never states directly:

- **What screen, report, button, or message did the customer see?** Open the
  Blade views, JavaScript, and route names the change touches and use the
  labels customers actually read (menu names, page titles, column headings,
  error text). Never use controller, class, table, or route names.
- **Who hits this?** Role (cashier, registrar, teacher, parent, student),
  school level or program, and the conditions that trigger it.
- **What did it look like when it went wrong?** A wrong total, a missing row,
  an error message, a page that would not load, a payment that did not show.
- **Is it live?** Check, do not assume:
  - uncommitted or unpushed: not released;
  - committed on a feature branch: not released;
  - `git branch -r --contains <sha>` lists the production branch: merged for
    release, but git cannot prove the server was updated. Say "merged for
    release" and note that deployment itself was not confirmed.
  - Never write "live" or "fixed for customers" unless deployment was confirmed.
- **Does anyone have to do anything afterward?** For example refresh the page,
  re-run a report, wait for the next automatic update, or nothing. Check for
  scheduled jobs, caches, and data that the fix does not repair on its own.
  A fix that stops new mistakes may leave existing wrong records in place, and
  customer service must know that.

Collect verification evidence that exists (tests, command output from this
session). Do not run the full test suite unless asked.

## Writing the note

Write to `docs/dev-notes/<YYYY-MM-DD>-<slug>.md`, creating the directory if
needed. The slug is three to five lowercase words naming the problem the way a
customer would. If a note for the same fix and date exists, update it.

Use this structure exactly:

```markdown
# <Title a customer would recognize>

**Status:** <Not released yet | Merged for release, deployment not confirmed | Live>
**Date:** <YYYY-MM-DD>

## In short
<Two or three sentences: what was wrong, what we did, and whether customers
will notice a difference.>

## What customers experienced
<What they saw, in their words. Who it affected and when. Include the exact
wording of any error message.>

## What was wrong
<The cause, in everyday language. One short paragraph. An analogy is welcome if
it is accurate.>

## What we changed
<What the system does differently now, described from the customer's side.>

## What customers will notice
<Before and after, concretely. If nothing visible changes, say so plainly.>

## What to tell customers
<A short message in plain, friendly wording that agents can send as written.
Honest about status: do not say "fixed" if it is not live.>

## If a customer still has the problem
<What to ask for and collect (which screen, which account or student ID, the
time it happened, a screenshot, the exact message) and who to escalate to.>

## What people need to do
<Steps for customers or staff, or "Nothing. No action needed.">

---

## For developers
<Scope inspected and branch. Root cause with `path/file.php:123` references.
What changed and why. Tests and commands with real results. Follow-ups,
migrations, cache clears, deploy steps.>
```

Omit **What people need to do** only if it would say nothing useful; keep
**If a customer still has the problem** always.

## Plain-language rules

Apply these to everything above the divider.

- **No code vocabulary.** Do not use file names, function or class names, SQL,
  table or column names, route paths, branch names, or words such as cache,
  query, null, endpoint, middleware, race condition, migration, queue, payload,
  regression. If a concept matters, describe what it does instead: "the system
  kept an old copy of the numbers" rather than "stale cache".
- **Use the product's own words.** If the screen says "Student Fees Report",
  write that, in the same capitalization, not "the report generator".
- **Short sentences, active voice,** about an eighth-grade reading level. Put the
  most important fact first in each section.
- **Concrete over abstract.** Say "the total on the dashboard was about 142,000
  pesos lower than the report" instead of "figures were inconsistent". Use real
  magnitudes when the work recorded them. Round sensibly.
- **Honest and calm.** Describe what went wrong without blaming people or
  minimizing the effect. Do not promise dates, refunds, or outcomes the code
  does not support. If a customer's money, grades, or records were affected,
  say precisely what was and was not corrected.
- **Say what you do not know.** If the customer impact cannot be determined from
  the code, write that and name who can confirm, instead of guessing.
- **Internal-only changes.** If the change is a refactor, test, or tooling with
  no customer-visible effect, say "Customers will not notice any change" in
  **In short**, keep the rest brief, and do not invent a customer story.
- **Privacy.** Never include student, parent, employee, or payment details,
  credentials, tokens, or `.env` values. Describe the shape of the problem
  ("a handful of first-year college accounts") instead of naming people.
- **Define unavoidable terms** once, in plain words, the first time they appear.

## Accuracy rules

- Report only what the diff, the code, and recorded command output support. Do
  not invent a cause or a customer symptom that merely fits.
- If the diff does not reveal why the change was made or who it affects, ask the
  user instead of guessing.
- The developer appendix may be technical, but must stay factual and brief.
- Do not commit, push, or amend anything. Writing the note file is the only
  change this skill makes to the working tree.

## Before you finish

Reread everything above the divider as a customer service agent on their first
day. For each sentence ask: could they say this to a customer without a
developer translating? Rewrite any sentence that fails. Confirm the **Status**
line matches what you actually verified about release.

## Reporting back

Print the note's path, then three lines: what customers experienced, what was
fixed, and whether it is live. Do not paste the full note.
