---
name: mirror-3-term
description: Mirror or port the DepEd IBED three-term or periodic grading feature for all configured K-12 non-college academic programs, including dynamic component-based ECR, plus SHS-specific Cluster, Cluster Plotting, and Subject Picking workflows, from a designated source repository into a sibling repository.
metadata:
  short-description: Safely mirror all-program K-12 3-term grading and SHS extensions
---

# Mirror 3-Term

Use this skill to investigate, remediate, or runtime-certify periodic IBED grading
across sibling school-system repositories. It covers any configured non-college K-12
academic program. Cluster, Cluster Plotting, and SHS Subject Picking are additional
SHS-only workflows. College grading is out of scope unless explicitly requested.

## Authoritative records

Before acting, read the relevant current files under `D:\laragon\www\3terms_md`,
especially `3-term-mirror-porting-guide.md`, `3TERM-RUNTIME-CERTIFICATION.md`, and
the functional-parity, ECR, conversion, remediation, verdict, and execution records.
For a new mirror, also read `3TERM-CANONICAL-IMPLEMENTATION-INVENTORY.md` first.
It contains the audited canonical SHA, comparison boundary, exact changed-file and
line counts, route families, module count, portal count, public-method snapshot, and
the required linear port order. Recompute the inventory when the canonical remote
SHA changes; never assume these counts remain current.
Update those existing files after each investigated or fixed issue. Do not create
repository-local duplicate guides. Newer runtime evidence supersedes historical
READY statements.

## Respect the requested phase

Distinguish read-only investigation, controlled remediation, and runtime
certification. Never implement during an audit-only phase. Do not commit, push,
reset, discard existing work, broadly replace target files, or mutate source data
unless explicitly authorized. Runtime mutations belong only in a verified
disposable database.

## Baseline and comparison

1. Record source/target paths, branch, HEAD, dirty files, runtime, and database.
2. Preserve target-specific permissions, branding, reports, Form 10 engines, school
   workflows, and semester behavior. Port behavior, not files.
3. Refresh the designated canonical remote before comparison and re-read its SHA at
   the end; it can move during the work.
4. Compare from the real divergence point and dismiss whitespace-only noise before
   deciding a file needs reconciliation.
5. Pair methods with routes, middleware, portal menus, Blade controls, AJAX,
   database/config dependencies, and downstream callers. Scan both directions.

## Functional chain

Trace:

`Term Configuration -> Subject Plotting -> Scheduling -> SHS Subject Picking ->
Cluster Setup -> Cluster Plotting -> Teacher Grading -> ECR -> Posting/Return ->
Final Grade -> Promotion -> SF9/SF10/Form 5/Master Sheet/reports`.

At each boundary track `syid`, `acadprogid`, `levelid`, `termid`, `semid`,
`prev_semid`, `sectionid`, schedule ID, `clusterplotid`, grade-header ID, student ID,
and `active_term_id`. A file, route, term column, or HTTP 200 with an empty body is
not functional proof.

## Term and semester invariants

- Resolve configuration by school year, academic program, and grade level. Two
  semester options are correct when no active config applies; do not fabricate one.
- Genuine term/whole-year headers and converted SHS plot/schedule rows use
  `semid = NULL`. Enrollment can remain semester-scoped. Omit its semester predicate
  only for verified whole-year classes; never backfill enrollment to NULL.
- Generate selectors, assignments, report columns, and formulas from active terms.
  A 1T/2T/3T header with a fourth-cell final formula is a failure.
- Preserve and retest ordinary semester mode.

## Subject and cluster workflows

- Subject Plotting owns bulk/per-row conversion/revert and collision-aware editing.
- Cluster Plotting owns cluster conversion. Treat student preview, conversion
  preview/execute, routes, modal, CSRF/confirmation, AJAX, schema guards, and route
  ordering as one vertical slice. Canonical preserves `prev_semid` but has no
  application-level Cluster revert; disclose that limitation.
- Subject Picking consumes converted state; Term Configuration does not canonically
  add a conversion button there.
- Cluster headers store `clusterplotid` in `grades.sectionid`. Preserve it through
  ECR, submit, approve, post, pending/return, unpost, final grade, and reports.
- Fetch the assigned teacher's real `/teacher/schedule` after conversion. Direct
  backend success is insufficient if a semester predicate hides NULL plots.
- Assert cluster teacher-assignment quarters are a subset of configured active terms.
- Render pages and modals; static checks can miss null teacher data.

## Dynamic ECR and Upload Excel

Trace:

`schedule is_term_mode/terms -> selector -> /ecr/check-ibed -> first header ->
/ibed-ecr view/download/upload -> item storage -> grading/posting/final`.

- Component mode requires valid `component_scores` configuration and component JSON.
- Scope static/dynamic legacy checks to the selected quarter.
- Initialize missing headers before rendering; roster and header semesters are separate.
- Preserve all identifiers, including cluster context, and await endpoint selection.
- Reconcile independent workbook engines semantically: sheets, hidden header IDs,
  column maps, parser behavior, and cluster support.

Certify with authenticated filter, first-open headers, download, PhpSpreadsheet and
preferably desktop opening, hidden-ID inspection, edited values, multipart upload,
stored-row queries, submit/post, and final-grade consumption for every term. A
correct-looking workbook can still have a broken parser.

## Downstream certification

Test Pending Grades list/open/edit/resubmit, including strand/no-strand setup
fallback. Test Promotion term status, sequential promote/unpromote,
`active_term_id`, `promotion_status_per_terms`, year-end progression, and semester
fallback. Test Final Grade Excel labels/formulas/download/upload and all relevant
PDF/Excel reports. Inspect term order, totals, identity, school branding, and wording;
zero-byte output or another school's hard-coded name is a fail.

## Runtime safety and evidence

For each target:

1. Record source fingerprints and take a backup.
2. Create an explicitly named disposable clone and verify required counts.
3. Point Laravel to the clone, accounting for config caches without repository edits.
4. Use real authenticated HTTP; direct controller/reflection calls are diagnostic.
5. Record role, URI, identifiers, expected/actual result, artifact, and before/after rows.
6. Drop only the exact verified clone name.
7. Recheck source fingerprints and all worktree statuses.

Mark unavailable scenarios NOT TESTABLE and explain why. Never infer E2E PASS from
static evidence or fabricate production data.

## Completion standard

Do not declare deployment readiness while any P0/P1 chain is FAIL or NOT TESTABLE.
Separate implemented, runtime-validated, static-only, blocked, target-specific, and
manual results. Do not commit or push unless explicitly requested.

## Grade Equivalency optional Grade Point rule

When porting the IBED Grade Equivalency editor to a target, treat each scale
row's `grade_point` as optional. Preserve the required percent range and at
least one scale row. Update both the Blade/JavaScript validator and
`IbedGradeEquivalencyController`: blank input must be accepted and persisted as
`NULL`; a supplied value must still be numeric. Check both embedded Term
Configuration and standalone Grade Equivalency partials. Verify the database
column is nullable before considering a migration. This target rule does not
authorize changing the canonical source unless explicitly requested.
