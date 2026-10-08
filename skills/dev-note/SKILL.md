---
name: dev-note
description: Write a clear plain-language note about the most recent fix for customer service staff, who relay it to live customers. Explains what customers saw, why it happened in the backend, what we changed, whether it is live, and what to tell them. Scans uncommitted work or the last commit. Use when asked for a dev note, a fix writeup, a support note, or what to tell customers about a fix.
metadata:
  short-description: Plain-language note on what broke, why, and how it was fixed
---

# Dev Note

Write a note about the most recent fix for customer service staff. They are not
developers, but they need to understand **what happened, why it happened, and
what we did**, well enough to answer a customer's follow-up questions without
asking a developer. They will explain it to live customers.

## Find the fix

1. If the invocation names a target (commit SHA, range like `dev...HEAD`, branch,
   or path), use it.
2. Otherwise, if `git status --porcelain` shows changed source files, use the
   uncommitted work.
3. Otherwise use `HEAD`.

Ignore lock files, caches, `vendor/`, and build output. Read the real diff
(`git diff`, `git diff --staged`, `git show <ref>`) and trace the surrounding
code until you can explain the mechanism. Do not guess from file names or commit
subjects. Use `git log -L` or `git blame` on the changed lines when history
explains why the old code existed.

Then work out what the diff does not say:

- What did the customer see go wrong? Use the words on the screen (page titles,
  button and column labels, error text) found in the views and JavaScript.
- Who was affected (cashier, registrar, teacher, parent, student), and under what
  conditions did it happen?
- **How did the backend produce the problem?** Follow the data from the screen
  back to where it comes from: what the system saves, what it calculates, what
  it reuses, and where two parts disagreed or one step was skipped.
- Is it live? Uncommitted, unpushed, or on a feature branch means **Not
  released yet**. In the production branch (`git branch -r --contains <sha>`)
  means **Merged for release**, since git cannot prove the server was updated.
  Write **Live** only if deployment was confirmed.
- Does anyone have to do something afterward? Say so if old wrong records are
  not repaired by the fix.

## Write the note

Save to `docs/dev-notes/<YYYY-MM-DD>-<slug>.md` (create the folder if needed;
update the file if the same fix and date already has one). Use this shape:

```markdown
# <Title a customer would recognize>

**Status:** <Not released yet | Merged for release | Live>

## What happened
<What customers saw, who it affected, and when it showed up. Quote any error
message exactly. Include real numbers if the work recorded them.>

## Why it happened
<The backend cause, explained step by step in plain words: what the system does
normally, what went differently this time, and how that produced what the
customer saw. Name the part of the system (for example "the saved dashboard
totals" or "the nightly update") and, the first time, add the technical name in
parentheses. Use an everyday analogy if it is accurate. Say why it was not
caught earlier if the code shows why.>

## What we changed
<What the system does differently now, and why that stops the problem. Say what
did not change, and whether old wrong records are fixed or still need action.>

## What to tell customers
"<A short message agents can send as written. Honest about status.>"

## If it still happens
<What to collect (screen, account or student ID, time, exact message,
screenshot) and who to escalate to.>

<sub>Dev: <Files with line numbers, the exact cause, tests and commands with
results, follow-ups and deploy steps.></sub>
```

## Rules

- **Length.** About 200 to 350 words above the Dev line. Enough to explain the
  cause properly; no padding. Simple fixes can be shorter.
- **Explain the cause, don't just name it.** "Why it happened" must answer how
  the problem was produced, not restate the symptom. Walk the chain: normal
  behavior, what broke it, the visible result.
- **Plain words first.** Backend ideas are welcome when explained in a clause.
  Avoid file names, function names, SQL, and table names above the Dev line.
  Use the product's own screen names exactly.
- **Concrete.** Prefer "the dashboard total was about 142,000 pesos lower than
  the report" over "figures were inconsistent", when the work recorded the number.
- **Honest.** Do not say "fixed" for anything not live. Do not promise dates or
  refunds. If the effect on customers or the cause is unclear, say so and name
  who can confirm. Never invent a cause that merely fits the symptom.
- **No customer change.** For refactors or tooling, say "Customers will not
  notice any change," then briefly explain what was improved and why.
- **Private.** No student, parent, employee, or payment details, credentials, or
  `.env` values. Describe the shape of the data instead.
- Do not commit, push, or amend. Writing the note is the only change you make.

## Before you finish

Reread everything above the Dev line as a new customer service agent. Could they
explain **why** this happened to a customer without a developer translating?
If not, add the missing step or simplify the wording.

## Finish

Print the note's path and its three facts in one line each: what customers saw,
why it happened, whether it is live. Do not paste the whole note.
