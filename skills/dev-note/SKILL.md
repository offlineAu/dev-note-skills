---
name: dev-note
description: Write a short, plain-language note about the most recent fix for customer service staff, who relay it to live customers. Says what customers saw, what we fixed, whether it is live, and what to tell them. Scans uncommitted work or the last commit. Use when asked for a dev note, a fix writeup, a support note, or what to tell customers about a fix.
metadata:
  short-description: Short plain-language note on the latest fix for customer service
---

# Dev Note

Write a **short** note about the most recent fix for customer service staff. They
are not developers. They read it, then explain it to live customers. If a
sentence needs a developer to translate it, rewrite it.

## Find the fix

1. If the invocation names a target (commit SHA, range like `dev...HEAD`, branch,
   or path), use it.
2. Otherwise, if `git status --porcelain` shows changed source files, use the
   uncommitted work.
3. Otherwise use `HEAD`.

Ignore lock files, caches, `vendor/`, and build output. Read the real diff
(`git diff`, `git diff --staged`, `git show <ref>`) and enough surrounding code
to understand it. Do not guess from file names or commit subjects.

Then work out what the diff does not say:

- What did the customer see go wrong? Use the words on the screen (page titles,
  button and column labels, error text) found in the views and JavaScript.
- Who was affected (cashier, registrar, teacher, parent, student)?
- Is it live? Uncommitted, unpushed, or on a feature branch means **Not
  released yet**. In the production branch (`git branch -r --contains <sha>`)
  means **Merged for release**, since git cannot prove the server was updated.
  Write **Live** only if deployment was confirmed.
- Does anyone have to do something afterward? Say so if old wrong records are
  not repaired by the fix.

## Write the note

Save to `docs/dev-notes/<YYYY-MM-DD>-<slug>.md` (create the folder if needed;
update the file if the same fix and date already has one). Use exactly this
shape:

```markdown
# <Title a customer would recognize>

**Status:** <Not released yet | Merged for release | Live>

**What happened:** <1-2 sentences. What customers saw and who it affected.>

**What we fixed:** <1-2 sentences. What is different now, in plain words.>

**What to tell customers:** "<A short message agents can send as written.>"

**If it still happens:** <One line: what to collect, and who to escalate to.>

<sub>Dev: <one or two lines: files with line numbers, the cause, and tests run.></sub>
```

## Rules

- **Short.** The whole note above the Dev line is under 120 words. No extra
  sections, no headings beyond the title.
- **Plain.** No file names, code terms, or jargon such as cache, query, null,
  endpoint, or migration. Describe what the system does instead. Use the
  product's own screen names exactly.
- **Concrete.** Prefer "the dashboard total was about 142,000 pesos lower than
  the report" over "figures were inconsistent", when the work recorded the number.
- **Honest.** Do not say "fixed" for anything not live. Do not promise dates or
  refunds. If the effect on customers is unclear, say so and name who can confirm.
- **No customer change.** For refactors or tooling, write "Customers will not
  notice any change." and keep the rest to one line each.
- **Private.** No student, parent, employee, or payment details, credentials, or
  `.env` values.
- Do not commit, push, or amend. Writing the note is the only change you make.

## Finish

Print the note's path and its three facts in one line each: what customers saw,
what was fixed, whether it is live. Do not paste the whole note.
