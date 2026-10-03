# lector

Narrow JSON reading for Ada 2022 — SPARK-proven targeted scans over raw
JSON text (`Lector.Scan`) and a utilada-backed whole-document parse into a
flat property view (`Lector.Utilada`), packaged as a reusable,
independently proven crate.

The scans are the point: a REST consumer often needs one field out of a
nested payload a flattening parser would mangle, and a strict
document-shape check against file corruption. Those are pure string
functions, so they live in the SPARK core and are proved instead of
defensively coded. Everything reports results (`Ok : out Boolean`, `""`
for absent) rather than raising.

## Commands

- `make build`   — build the library (`alr build`)
- `make test`    — AUnit suite in BOTH modes (release -O3, debug -O0), offline
- `make features` — the Gherkin features under `tests/features/` in both
  modes, on fabula, printing the report as it goes (in colour on a
  terminal); checks the summary line, since fabula exits 0 for a
  missing path.  `alr test` runs them too
- `make features-report` — the living documentation: the features with
  `--report-json`, rendered by multiple-cucumber-html-reporter
  (`tools/features-report`, node) into `obj/features-report/html`.  CI
  keeps it with every run and publishes it from main to
  https://ldm5180.github.io/lector/
- `make prove`   — SPARK proof, `--checks-as-errors=on`; must exit 0
- `make format`  — `gnatformat --check` over all committed Ada sources
- `make example` / `make run` — build / run the demo mains (fully offline,
  so CI runs them)
- `alr --non-interactive build --validation` — warnings-as-errors gate (CI)

## Layout

- `src/core/` — the SPARK core (`Lector.Scan`): every unit carries
  `SPARK_Mode`, does zero IO, allocates nothing, and may `with` only other
  core units.
- `src/app/`  — the utilada adapter (`Lector.Utilada`): all utilada
  specifics stay behind this one unit; exceptions become `Ok` = False at
  this boundary and never escape.
- `tests/` — AUnit suite (`test_lector.gpr`, driver `test_runner.adb`)
  and the features: `tests/features/*.feature` run by
  `lector_features.ads` (Fabula.Main over `Lector_Steps`).  The steps
  are sml machines run by `Lector_Steps.Flows`, one per vocabulary --
  the document held (`Holding`), the values read (`Reading`), the
  parse, the single-object check, the masked text -- each offered
  every step as a region of the registry; a step none takes fails,
  naming every region's state.  A document a doc string would not
  suit is a named flat file under `tests/features/docs/<name>.json`.
- `example/` — standalone demo mains; offline, built and run in CI.
- `proof/` — gnatprove harness (`proof.gpr`; sources `../src/core` directly
  and withs nothing, keeping foreign code out of the proof tree).
- `docs/tdd-log.md` — git-ignored TDD audit log.

## SPARK

- Every `src/core` unit carries `SPARK_Mode`. After any core change,
  `make prove` must exit 0 (level 2, checks-as-errors). CI enforces the same.
- Prefer results over exceptions; document and prove behavior with
  contracts (`Pre`, `Post`, loop invariants).
- Scan results are slices or bounded copies of the input; keep the
  "result no longer than the input" Posts — callers size buffers by them.

## TDD protocol (strict)

- Red/green/refactor, always: failing test first (RED = compile error or
  failed assertion), then the minimal code (GREEN), then refactor under
  green. No production code without a preceding failing test.
- Log every cycle in `docs/tdd-log.md` (git-ignored, newest entries on top):
  date, what changed, exact RED output, GREEN pass counts.
- One `<unit>_tests.ads/.adb` pair per library unit under `tests/src/`,
  registered in `lector_suite.adb`. Test routines use
  `AUnit.Assertions.Assert` and are wired via `Register_Routine`.
- Tests are layers -- guidance for judgement, not a mechanical rule.
  A unit test typically tests a single function, or at most a simple
  interaction between two, and the unit tests always cover the function
  they test completely: where a scan stops and why, the key with no
  colon, the unterminated value.  A feature (BDD) binds what a consumer
  observes -- a value read, an absence, a verdict, a masked text --
  never how the scan got there.  Duplication across the layers is fine:
  a test is removed only when it is an integration test a scenario
  fully supplants, and lector's suites hold none.
- fabula's pattern rules: no quote inside a `{string}` capture (a JSON
  document is a doc string or a named file), and no `/` after a letter
  in a pattern (it is fabula's choice operator; capture a path or a
  fraction as a `{word}`).

## Programming best practices

- Lean hard into the type system; keep code DRY.
- Extract pure functions whenever possible — it forces naming and generality.
- Keep functions and procedures short and focused; move any second code block
  into its own named subprogram.
- Push exceptions and defensive programming into contracts and let the proof
  system do the heavy lifting; `SPARK_Mode => On` as much as possible.

## Style

- Formatting is `gnatformat`-enforced; wrap hand-aligned tables in
  `--!format off` / `--!format on`.
- Follow the Alire validation-profile switch set; fix warnings, never
  suppress them without a comment saying why.

## Commit style

- gitmoji `:code:` shortcode prefix + capitalized, imperative subject, no
  trailing period (`:sparkles:` feature, `:bug:` fix, `:recycle:` refactor,
  `:white_check_mark:` tests, `:wrench:` tooling, `:memo:` docs, `:fire:`
  removal).
- Never put test / prove / format result counts in commit messages.

## Reading contracts (do not break)

- Absence is empty, never an error: a missing key yields `""` from the
  scans and from `Lector.Utilada.Value`; only malformed input flips
  `Parse`'s `Ok` to False.
- `Lector.Scan` functions never raise and never read outside `Text`'s
  bounds — that is what the proof carries; keep it green.
- `Is_Single_Object` is the strict single-document rule (one object,
  its balancing `}` followed only by blanks): parsers that stop at the
  first complete value would silently accept `{...}trailing` and
  `{...}{...}`, so callers guarding files on disk check it BEFORE parsing.
