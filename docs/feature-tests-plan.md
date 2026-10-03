# Feature tests plan

**Status:** F0-F9 landed 2026-10-03; F10-F11 not started.

The crate's behavior, stated in Gherkin and run against the real
reader.  `*.feature` files under `tests/features/` say what a JSON
reader does for the consumer that calls it -- a field is read out of
a nested payload without parsing all of it, a missing key is empty and
never an error, a malformed document is a result and never an
exception, a corrupt file is caught before it is parsed, a secret is
masked before it is logged -- and a small Ada step registry on
[fabula](https://github.com/ldm5180/fabula) runs them, each feature's
steps as an [sml](https://github.com/ldm5180/sml-ada) state machine.
The unit suite keeps the mechanism (which byte a scan stops at); the
features keep the contract (`CLAUDE.md` "Reading contracts (do not
break)", stated once each, in the consumer's words).

This is the third of a family: `fructus/docs/feature-tests-plan.md`
is the first and `nuntius/docs/feature-tests-plan.md` the second,
and their decisions carry over wherever this crate does not say
otherwise.  nuntius is implemented and merged, so its code is the
shape to copy, not only its text.  What is different here is the
world: nuntius opens sockets; lector reads strings.  A feature's
whole world is a document and what was read out of it, so the world
package is small and every scenario is instant.

## How to use this plan

Work the items in order; each is one TDD cycle (RED first, the exact
assertion given) and one commit, logged in `docs/tdd-log.md`.  F0 is
the dependency and F1 the runner -- the machines from the first
commit, never a `case` to convert later; F2 the world; F3-F7 the five
features of the first wave; F8 the streaming, coloured `make
features`; F9 the living documentation; F10 the testing-layers
judgement over the AUnit suites; F11 the documentation.  After each
item: `alr --non-interactive build --validation`, `make test`, `make
features`, `make format`.  Nothing in this plan touches `src/`, so
`make prove` is never owed by it.

Five decisions, taken up front, each settled in the nuntius work and
recorded there:

- **The steps are sml machines from the start.**  Each feature's
  steps are the events of one state machine in its own child package
  (`Lector_Steps.Scanning`, ...), run by one generic runner
  (`Lector_Steps.Flows`): every condition that would choose a body is
  a guard, every body an action, and a guarded row is followed by an
  unguarded fallback row whose action fails the step with the reason.
  The registry offers each step to every feature as a region; a step
  no feature takes fails, naming every feature's state.  A step taken
  out of order therefore fails instead of doing something undefined.
- **A document that does not fit a line is named, never spelled.**
  fabula's `{string}` capture is double-quoted only, so no JSON
  snippet with a quote in it is ever a capture.  A short document is
  a doc string (`"""`, inline, where the reader should see it); a
  longer or reused one is a flat file, `tests/features/docs/<name>.json`,
  named from a step (section 3.2).
- **Living documentation, published.**  The features' `--report-json`
  rendered by multiple-cucumber-html-reporter, kept as an artifact on
  every CI run and deployed to GitHub Pages from main.
- **Tests are layers; coverage first.**  A unit test typically tests
  a single function, or a simple interaction between two, and covers
  it completely; a feature tests the larger interaction that forms a
  conceptual feature.  Duplication across the layers is fine.  A test
  goes only when it is an integration test a scenario fully supplants
  -- and lector's suites are unit tests of single functions, so F10
  expects to remove nothing (section 4, F10).
- **A feature binds behavior; a unit test pins the mechanism.**  A
  scenario tests from the outside: what a consumer of lector gets
  back, what is absent, what is refused.  It is not black-box -- a
  step may hold a document, name a file, choose a scan -- but every
  check must still be something a consumer could observe and would
  want promised, and would stay true if the scans were rewritten to
  the same contract.  How a scan finds its value, where it stops,
  what it allocates, which branch ran: those are the unit tests'
  (`lector_scan_tests`, `lector_utilada_tests`), which cover each
  function completely and are never replaced by a feature.

### Do not

- Do not promise what the reader does not do.  `Lector.Scan.String_Value`
  returns the bytes between the quotes and stops at the next `"`: it
  does not unescape `\"` or `é`, and `Lector.Utilada.Value (Doc,
  "a.b")` does not reach a nested key (its header comment says
  "flatten"; the body copies the top-level map only -- a known, named
  gap).  A feature states the limit as a limit ("a value holding an
  escaped quote reads up to the escape"); it never papers over it.
- Do not put a quote inside a `{string}` capture.  fabula's quoted
  capture ends at the first `"`; a JSON snippet is a doc string or a
  named file (3.2).  A key, a bare value and a word are `{word}`.
- Do not write a `/` after a letter in a step pattern.  It is
  fabula's choice operator and cannot be escaped; a path or a
  fraction is a `{word}` capture.
- Do not read a file in a step by a path from the repository root.
  `Named_Document` takes the directory of the feature file that names
  it (from the step's frame) plus `/docs`, so a feature and its
  documents move together.
- Do not add fabula to `proof/proof.gpr`.  It is a test dependency;
  the proof tree sources `src/core` and withs nothing.
- Do not check how.  A step that wants a byte offset, an internal
  count, an intermediate buffer or which branch ran is a unit test;
  write or extend the unit test for that function and keep the
  feature's step at the outcome.  The one offset a feature names --
  "after the first <key>" -- is the public `From` parameter, a thing
  the consumer passes, not an internal.
- Do not name a package or a subprogram in a feature or scenario
  title.  "the flat parse", "the close check", "`String_Value`" are
  how; the title says what the consumer does -- parses a document,
  reads a field, checks a document is one object.
- Do not remove a unit test to "avoid duplication".  The reading
  scans' edge cases (an unterminated value, a key with no colon, a
  value of the wrong shape) are each one function's behavior and stay
  where they are, whatever a feature also states.
- Do not fix fabula's `-gnatwu` warning (`fabula-run.adb:258`, a GNAT
  15 false positive in a declare expression) from here.  Under the
  dependency profile it is a warning, and this crate builds clean with
  it under `--validation` (section 5).

## 1. What fabula is, in the terms this crate uses

A fabula binary is one instantiation of `Fabula.Main` over a
`Fabula.Registry` instance: an enumeration of step kinds, a table
mapping a Cucumber-expression pattern to a kind
(`Step ("the {word} value reads {string}") >= E_Check_Value`), an
enumeration of hook kinds with its table, a `Context` record one
scenario owns, and two procedures -- `Execute (Kind, Ctx, Args,
Frame, Outcome)` and `Run_Hook`.  Checks record into an `Outcome`
(`Fabula.Check.Text_Equal`, `Fabula.Check.Is_True`, `Fail_Step`); a
step body that raises becomes a failed step and the run goes on,
which here would mean a scan raised -- the proof says it cannot, and a
feature that sees it has found a bug.  Captures read 1-based
(`Fabula.Args.Int`, `.Text`, `.Word`); a step's doc string is
`Fabula.Args.Doc_String`; a data table reads as raw cells or as
hashes.  The binary walks its paths sorted, exits 1 on any failed
scenario, and prints `N Scenarios (...)`.

fabula copies the `Context` once per step and keeps the copy only on
a normal return.  A document here is a string of at most a few
kilobytes and copies fine, so unlike nuntius the context holds the
whole world: the document, the last value read, the last parse's
verdict, the masked text.  Nothing lives at library level but each
machine's state, which the `Before` hook resets.

Three fabula limits matter.  `Fabula.Limits.Max_Line_Length` is 2 048,
so a feature-file line -- a step, a doc-string line, a table cell --
holds a document of that length at most; past it, a named file
(3.2).  `Max_Message_Length` is 512, so a failed check quotes the
value it read, never the document.  And the `{string}` capture ends at
the first `"`, which is why no JSON is ever a capture (the Do-not
list).

## 2. Where things live

```
tests/
  features/
    scanning.feature         F3  a field out of a nested payload
    absence.feature          F4  a missing key is empty, never an error
    parsing.feature          F5  a parsed document reads its fields, or fails without raising
    shape.feature            F6  a document is one complete object, or it is not
    masking.feature          F7  secrets masked, bodies escaped, for a log
    docs/                    named documents, one .json per name (3.2)
  src/
    lector_features.ads      F1  the main: Fabula.Main instantiated
    lector_steps.ads/.adb    F1  Step_Kind, Hook_Kind, the tables, the regions
    lector_steps-flows.ads/.adb  F1  the runner: one machine per feature
    lector_steps-scanning.ads/.adb   F3  one machine, and so on per feature
    lector_world.ads/.adb    F2  the document in hand, Named_Document
    lector_scan_tests.adb        unchanged
    lector_utilada_tests.adb     unchanged
  test_lector.gpr            F1  with "fabula"; a second main
tools/
  features-report/           F9  report.js, package.json, package-lock.json
```

Each feature's steps are a child of `Lector_Steps`, and the registry
body is a table of regions over them.  The step kinds carry the house
`E_` prefix (so a table's bare-name wrapper can be `Check_Value`),
actions carry `A_`, and an action helper never shares a wrapper's
name.

## 3. The step vocabulary

Every pattern, the kind it names, and what the body does.  A key and a
bare value are `{word}` captures; an expected string value is a
`{string}` capture (quoted, no quote inside); a document is a doc
string or a named file.  The document in hand is `Ctx.W.Doc`; every
"reads" step reads out of it and keeps the result in `Ctx.W.Value`,
which every "is" step checks.

| Pattern | Kind | Body |
|---|---|---|
| `a document:` + doc string | `E_Hold_Doc` | the doc string, lines joined by LF, into `Ctx.W.Doc` |
| `the document named {word}` | `E_Hold_Named` | `Lector_World.Named_Document (Dir, Name)` into `Ctx.W.Doc`; guard: the file exists |
| `an empty document` | `E_Hold_Empty` | `""` |
| `the string value of {word} is read` | `E_Scan_String` | `Lector.Scan.String_Value (Doc, Key, Doc'First)` |
| `the string value of {word} after the first {word} is read` | `E_Scan_String_After` | `From` past `Find (Doc, Quoted (Key_2))` |
| `the number value of {word} is read` | `E_Scan_Number` | `Lector.Scan.Number_Value` |
| `the {word} of the object whose {word} is {word} is read` | `E_Scan_Object` | `Lector.Scan.Object_Value (Doc, Match_Key, Match_Value, Want_Key)` |
| `the document is parsed` | `E_Parse` | `Lector.Utilada.Parse`; the verdict and the `Document` kept |
| `the field {word} is read` | `E_Field` | `Lector.Utilada.Value (Doc, Key)`; guard: the document parsed |
| `the document is checked for a single object` | `E_Check_Shape` | `Lector.Scan.Ends_With_Object_Close` into `Ctx.W.Verdict` |
| `the values of {word} are masked` | `E_Mask_One` | `Lector.Scan.Mask_Values (Doc, Key)` into `Ctx.W.Value` |
| `the values of these keys are masked:` + one-column table | `E_Mask_Many` | `Mask_Values (Doc, Key_List)`; guard: every key fits `Max_Key` |
| `the document is escaped for a log` | `E_Escape` | `Lector.Scan.Json_Escape (Doc)` |
| `the value is {string}` | `E_Check_Value` | `Text_Equal (Ctx.W.Value, Want)` |
| `the value is empty` | `E_Check_Empty` | `Ctx.W.Value = ""` |
| `the value is absent` | `E_Check_Empty` | the same check, read as the contract says it |
| `the parse succeeds` / `fails` | `E_Check_Parsed` / `E_Check_Refused` | `Ctx.W.Parsed` |
| `the field {word} is present` / `absent` | `E_Check_Has` / `E_Check_Lacks` | `Lector.Utilada.Has` |
| `the document is a single object` / `is not a single object` | `E_Check_Shape_Ok` / `E_Check_Shape_Bad` | `Ctx.W.Verdict` |
| `the text reads:` + doc string | `E_Check_Text` | `Ctx.W.Value = the doc string`, for a masked or escaped text |
| `the text is unchanged` | `E_Check_Unchanged` | `Ctx.W.Value = Ctx.W.Doc` |
| `masking it again changes nothing` | `E_Check_Idempotent` | `Mask_Values (Value, Key) = Value` |

Steps whose capture must read -- a key longer than `Max_Key` (128),
a named document that is not there -- are guarded rows with a
refusing fallback (`A_Refuse_Key`, `A_Refuse_Document`) that names
what was wrong.

### 3.1 The machines

Each feature is one machine; the states are what the scenario has in
hand.

- `scanning`, `absence`: `Blank -> Held -> Read`.  A read needs a
  document (`Held`), a check needs a read (`Read`); another read from
  `Read` is allowed, since one document is scanned several ways.
- `parsing`: `Blank -> Held -> Parsed`, and `Parsed + E_Field` is
  guarded on the verdict: a field read after a failed parse is the
  contract ("a failed parse leaves an empty document"), so it is a
  row, not a refusal, and the check that follows reads `""`.
- `shape`: `Blank -> Held -> Checked`.
- `masking`: `Blank -> Held -> Masked`, where `E_Check_Idempotent`
  masks again from `Masked`.

The one follow-up event: `E_Hold_Named` reads the file in its action
and posts `E_Document_Settled`, whose guard asks whether the read
succeeded -- the file's absence is then a refusing row, not an `if`.

### 3.2 Documents that do not fit a line

A JSON document holds quotes, so it is never a `{string}` capture.
Two forms, chosen by what the reader should see:

- **A short document is a doc string**, inline under the step, where
  the scenario's point is the document's shape:

  ```gherkin
  Given a document:
    """
    {"status": "WORKING", "children": [{"status": "PENDING"}]}
    """
  ```

  fabula joins the lines with LF and hands the whole text to the
  step; a doc-string line is bounded by `Max_Line_Length`.  Every
  document the existing unit tests spell inline fits here.

- **A long or reused document is a named flat file**,
  `tests/features/docs/<name>.json`, read by `Lector_World.Named_Document`
  from the directory of the feature file that names it: `Given the
  document named order-status`.  Named files are for the documents
  that recur across features (the order-status reply, the account
  roster) or outgrow a doc string; the first wave needs two
  (`order-status.json`, `account-roster.json`), and the scanning and
  parsing features both read them.  A missing name fails the step and
  says which directory it looked in.

This is the family's rule (fructus: a JSON file; nuntius: a `.hex`
file per sequence): the feature names the bytes, it never spells them
in a capture.

## 4. Items

### F0 -- fabula is a test dependency

- **Where:** `alire.toml:14-16` (`[[depends-on]]`: `utilada`,
  `aunit`); there is no `[[pins]]` table, and no `sml` pin.
- **What is wrong:** nothing runs a `.feature` file.
- **Why:** the suite is AUnit end to end.
- **Fix:** `fabula = "*"` after `aunit`, and a new `[[pins]]` table
  before `[build-switches]` holding
  `fabula = { url = "https://github.com/ldm5180/fabula.git", commit = "746a234df5581c2e38c4202aeee8b07473fb6a51" }`
  with a comment in the house shape: pinned by commit because nothing
  of ldm5180's is in the community index, and a note that fabula's
  own pin brings `sml 3ccd0e4` into this crate's closure -- lector
  pins no `sml` itself, so there is no chain to align and nothing a
  consumer must match that it does not already (fructus and arb-ada
  pin that same `sml`).
- **RED first:** `alr --non-interactive build --validation` with the
  dependency line and no pin warns that the solution is incomplete
  (fabula is in no index); with the pin it builds, verified in section
  5 at 2.0 s.

### F1 -- The feature binary runs an empty feature, as a machine

- **Where:** `tests/test_lector.gpr:1-2` (`with "aunit"; with
  "../lector.gpr";`) and `:16` (`for Main`); `alire.toml:28-43` (the
  four `[[actions]]` of type `test`); `Makefile:8` (`.PHONY`),
  `:16-21` (`test:`), `:29-33` (`format:`, whose `tests/src/*.ad[sb]`
  glob covers the new packages); `.github/workflows/ci.yml:64-69` (the
  `alr test` step).
- **What is wrong:** no runner, no registry, no machine.
- **Why:** there was no Gherkin runner in Ada until fabula.
- **Fix:** `with "fabula";` beside `aunit` and
  `for Main use ("test_runner.adb", "lector_features.ads");` -- a
  generic instantiation is a SPEC, so the main is an `.ads`.
  `tests/src/lector_features.ads` instantiates `Fabula.Main` over
  `Lector_Steps`.  `tests/src/lector_steps-flows.ads/.adb` is the
  runner, copied from nuntius's `Nuntius_Steps.Flows`: a
  `Sml.Simple_Machines` instance over `Step_Kind` and a `Step_Context`
  (the World, the step's `Fabula.Args.List`, its frame and outcome, an
  optional follow-up event), the operator layer (`with
  Sml.Machines.Operators` is needed to instantiate it), and `Take` --
  make the machine at the feature's state, process the step, then any
  follow-up an action asked for (bounded), and keep the state.
  `tests/src/lector_steps.ads/.adb` holds the smoke registry: three
  steps as ONE small machine (`Empty -> Read`, a `Count_Read` guard
  with a refusing fallback row), and the `Before` hook resets the
  context and the machine.  `tests/features/smoke.feature` holds two
  scenarios: the count, and a check before any read, which must fail
  naming the state.  Two more `[[actions]]` after the existing four,
  argv-only like them:
  `["alr", "exec", "--", "tests/bin/release/lector_features", "tests/features"]`
  and its `debug` twin; the gprbuild actions already build every main
  of the gpr.  The `features` target is F8's; this item adds the
  plain form (build both modes, run both, grep the summary line) and
  F8 makes it stream.  The CI workflow needs no new step: `alr test`
  runs the actions.
- **RED first:** `make features` -- "No rule to make target".  Then,
  with the target and an empty transition table, the smoke scenario's
  first step fails as "not a step this scenario can take now: EMPTY"
  and the binary exits 1; the rows turn it green.  Verified in section
  5: the whole sketch, typed in, builds in 2.4 s and prints
  `2 Scenarios (1 failed, 1 passed)` -- the out-of-order scenario
  failing is the point.

  ```gherkin
  Feature: The feature runner runs
    Scenario: Fields are counted
      Given nothing has been read
      When 3 fields are read
      And 4 fields are read
      Then 7 fields have been read
  ```

### F2 -- The world: the document in hand

- **Where:** new `tests/src/lector_world.ads/.adb`; the `World`
  record in `lector_steps.ads`.
- **What is wrong:** nothing holds a document across steps, and
  nothing reads a named one.
- **Why:** the AUnit tests each spell their document inline.
- **Fix:** the `World` record carries `Doc`, `Value`, `Parsed`,
  `Verdict` (all per scenario, reset by `Before`) and the
  `Lector.Utilada.Document` of the last parse.  `Lector_World` holds
  what is not per scenario: `Named_Document (Dir, Name, Text, Ok)`
  over `Ada.Text_IO` (the file whole, LF-joined, at most
  `Max_Document` bytes; `Ok` False when missing or over the bound),
  `Docs_Dir (Frame)` (the feature file's directory plus `/docs`), and
  `Quoted (Key)` for the `From` offsets.  Small on purpose: this
  crate's world is a string.
- **RED first:** a scenario `Given the document named order-status`
  against an empty `docs/` fails with "no document named order-status
  in tests/features/docs"; the file turns it green.

### F3 -- `scanning.feature`: a field out of a nested payload

- **Where:** `tests/src/lector_scan_tests.adb:13-29`
  (`Test_String_Value`), `:31-40` (`Test_From_Offset`), `:42-55`
  (`Test_Number_Value`), `:57-76` (`Test_Object_Value`);
  `example/src/json_fields.adb:15-20` (the order-status sample).
- **What is wrong:** that one field comes out of a nested payload
  without parsing it, that a number past what an integer holds comes
  back verbatim, and that the object whose key matches is the one read, are
  the crate's reason to exist and are stated only as `Assert`
  messages.
- **Why:** that is what a unit test is.
- **Fix:** the first feature, and the one that defines most of the
  vocabulary:

  ```gherkin
  Feature: A field is read out of a nested payload without parsing it

    A field is read straight out of a payload's text: the value after
    a key, the digits after one, or a field of the object whose other
    field matches.  No parse is needed -- a document the parser would
    refuse still gives up its field -- and nothing raises.

    Scenario: The string value after a key, spaced or tight
      Given a document:
        """
        {"name": "ada", "kind":"crate"}
        """
      When the string value of name is read
      Then the value is "ada"
      When the string value of kind is read
      Then the value is "crate"

    Scenario: A number past what an integer holds comes back verbatim
      Given a document:
        """
        {"orderId": 100047, "big": 99999999999999999999}
        """
      When the number value of big is read
      Then the value is "99999999999999999999"

    Scenario: The field of the object whose key matches
      Given the document named account-roster
      When the hashValue of the object whose accountNumber is 222 is read
      Then the value is "BBB"

    Scenario: A later occurrence is read by starting after the first
      Given a document:
        """
        {"id": "first"} {"id": "second"}
        """
      When the string value of id after the first id is read
      Then the value is "second"

    Scenario: A field inside a nested array is read directly
      Given the document named order-status
      When the quantity of the object whose symbol is QQQ is read
      Then the value is "7"

    Scenario: An escaped quote is not unescaped: the value ends at it
      Given a document:
        """
        {"k": "a\"b"}
        """
      When the string value of k is read
      Then the value is "a\"
  ```

  The last scenario states the Do-not list's limit as the consumer
  meets it: the value handed back is `a\` and nothing more -- what
  the scan returns is its edge, so a feature may bind it; WHY it
  stops there (the next `"`, escaped or not) is `Test_String_Value`'s
  to pin.  The unit tests' assertions all stay where they are; the
  feature restates the outcomes only, and a scenario that fails here
  while the unit test passes is a behavior change, which is the
  point.  The two named documents are `tests/features/docs/order-status.json`
  (the example's sample) and `account-roster.json` (the suite's
  accountNumbers shape).
- **RED first:** `make features` reports `a document:` `UNDEFINED`;
  each row and action turns one step green, in the order the first
  scenario reads.  The expected values are the unit tests' own.

### F4 -- `absence.feature`: a missing key is empty, never an error

- **Where:** `tests/src/lector_scan_tests.adb:13-29` (the absent-key,
  unterminated, no-colon and wrong-shape asserts of
  `Test_String_Value`), `:42-55` (the same for numbers), `:57-76` (no
  match, empty match value); `CLAUDE.md:83-86` (the first reading
  contract).
- **What is wrong:** "absence is empty, never an error" is the first
  contract in `CLAUDE.md` and no single place states it across the
  three scans and the parse.
- **Fix:** one feature, one scenario per way a key can be absent:
  not there; there with no colon; there with an unterminated value;
  there with a value of the other shape (a number where a string is
  asked, a string where a number is); no object matches; an empty
  match value matches nothing; and, over the parse, a field the
  document lacks is absent and reads empty.  Each `Then the value is
  absent`.  Every one is the outcome a consumer sees; the unit tests
  keep their asserts on the same cases, and anything about where the
  scan gave up stays there.
- **RED first:** `the value is absent` is `UNDEFINED`; green when the
  six scan scenarios and the one parse scenario all read `""`.

### F5 -- `parsing.feature`: a parsed document reads its fields, or fails without raising

- **Where:** `tests/src/lector_utilada_tests.adb:9-25`
  (`Test_Parse_Object`), `:27-45` (`Test_Nested_Top_Level`), `:47-57`
  (`Test_Malformed`), `:59-72` (`Test_Trailing_Garbage`);
  `src/app/lector-utilada.ads:1-16` (the header, whose "flatten" is
  the known gap).
- **What is wrong:** that malformed input is `Ok = False` and leaves
  an empty document, that a top-level field reads by name beside a
  nested one, and that the reader accepts trailing garbage (which is
  why F6 exists), are the parse's whole contract and live in one
  96-line suite.
- **Fix:** scenarios over `E_Parse`: a well-formed object parses and
  its fields read; a nested payload parses and the top-level field is
  not shadowed; malformed input fails and a field read after it is
  empty; trailing garbage parses (stated as the reader's behavior,
  with the next feature named as the guard).  And the gap, stated as a
  limit: `When the field children.status is read / Then the value is
  absent` -- a parsed document does not reach a nested field by a
  dotted key; the scans (F3) read it.  Stated as what the consumer
  gets, not as how the parse stores its keys.  `children.status` is a
  `{word}`, so the dot is fine.  The utilada suite's assertions stay
  as they are.
- **RED first:** `the document is parsed` is `UNDEFINED`; green on
  `the parse succeeds` and `the field status is present`.

### F6 -- `shape.feature`: a document is one complete object, or it is not

- **Where:** `tests/src/lector_scan_tests.adb:127-138`
  (`Test_Object_Close`); `CLAUDE.md:89-92` (the third contract);
  `src/app/lector-utilada.ads:10-13`.
- **What is wrong:** the one question a caller must ask BEFORE
  parsing a file on disk -- is this one complete object, and nothing
  after it -- is stated in a contract and a unit test, never as the
  story of the corrupt file it catches.
- **Fix:** a short feature: a plain object is a single object;
  trailing blanks are fine; trailing garbage is not; an empty
  document is not; and the pair that is the point -- the same
  `{"a": "1"}trailing` the parse accepts, the shape check refuses, so
  a consumer checks the shape first.
- **RED first:** `the document is checked for a single object` is
  `UNDEFINED`; green on the trailing-garbage refusal.

### F7 -- `masking.feature`: secrets masked and bodies escaped, for a log

- **Where:** `tests/src/lector_scan_tests.adb:93-125`
  (`Test_Mask_Values`), `:140-163` (`Test_Mask_Values_Keys`), `:78-91`
  (`Test_Json_Escape`).
- **What is wrong:** that a logged wire body never carries an account
  number or a hash is a consumer-facing promise (fructus's wire log
  rests on it) stated only as the shape of the masked text.
- **Fix:** scenarios over `E_Mask_One`, `E_Mask_Many` and `E_Escape`:
  a quoted value masks in place and its neighbours stay; a bare
  number masks; every occurrence masks; an absent key changes
  nothing; an unterminated value still masks; a non-scalar value is
  left alone; masking is idempotent; several keys mask in one pass in
  the text's order; and a body with a quote, a backslash and a control
  character escapes to a legal JSON string.  The expected texts are
  doc strings (`the text reads:`), since they hold quotes; the
  multi-key step takes a one-column table of keys.  A masked text is
  what the consumer logs, so its whole shape is the outcome and a
  feature may state it; the unit tests keep their asserts beside it.
- **RED first:** `the values of hashValue are masked` is `UNDEFINED`;
  green on `{"hashValue":"***","id":7}` read back from a doc string.

### F8 -- `make features` streams its report, in colour

- **Where:** the `features:` target F1 added to `Makefile`; nuntius's
  `Makefile` (its `features:` recipe, under "## features") is the
  one to copy.
- **What is wrong:** the F1 form holds the output in a variable and
  prints it only on a failure, so a run sits silent; and once it is
  teed, fabula sees a pipe and drops its colour.
- **Why:** fabula colours only a terminal (and honours `NO_COLOR`),
  and a `$(...)` capture or a `tee` makes its stdout a pipe.
- **Fix:** per mode, `{ runner; echo $? > rc; } | tee log`, then
  check the rc and the summary line from the log (POSIX sh, no
  `PIPESTATUS`); test `[ -t 1 ]` BEFORE the pipe and, on a terminal,
  run the runner as `script -qefc "$run" /dev/null` (a pty; `-e`
  keeps the exit status); strip `\x1b[..m` and `\r` from the log
  before grepping `^[1-9][0-9]* Scenarios? \([0-9]+ passed\)$`.  The
  recipe is nuntius's, line for line but the binary's name.
- **RED first:** `script -qefc "make features" log` on the F1 target
  shows no `\x1b[32m` in the log; with the recipe it does, a broken
  expectation shows red and the target exits 2, and a piped run
  (`make features > log`) stays plain and green.

### F9 -- The living documentation

- **Where:** new `tools/features-report/` (`report.js`,
  `package.json`, `package-lock.json`), a `features-report:` target in
  `Makefile`, `.gitignore:9` (after `/example/bin/`),
  `.github/workflows/ci.yml:71-76` (after the example step).
- **What is wrong:** the features are readable only in a checkout.
- **Why:** nothing renders fabula's `--report-json`.
- **Fix:** nuntius's tool, copied with the names changed: `report.js`
  calls `multiple-cucumber-html-reporter` on the JSON directory with
  `pageTitle "lector — features"`, `reportName "lector — what the
  reader does"`, the commit and run from CI's environment, and
  `displayDuration: false` (fabula reports no durations);
  `package.json` pins `multiple-cucumber-html-reporter ^3.9.0` and the
  lockfile is committed so CI can `npm ci`.  `make features-report`
  builds release, runs the features with `--report-json
  obj/features-report/json/features.json`, renders into
  `obj/features-report/html`, and fails with the runner's status AFTER
  rendering -- the page is most worth reading when a scenario failed.
  `.gitignore` gains `/tools/features-report/node_modules/`.  CI: in
  the build job after the example step, `actions/setup-node@v7`
  (node 22, npm cache on the lockfile), `make features-report`,
  `actions/upload-artifact@v7` of the html (all three `if: success()
  || failure()`), then on a push to `main` `actions/upload-pages-artifact@v5`
  and a `pages` job (`needs: build-and-test`, `permissions: pages:
  write, id-token: write`, `environment: github-pages`) running
  `actions/deploy-pages@v5`.  Pages is enabled once with
  `gh api -X POST repos/ldm5180/lector/pages -f build_type=workflow`
  -- a step for the person landing the branch, not the plan; the first
  deploy happens on the first push to main after it.
- **RED first:** `make features-report` -- "No rule to make target";
  then `obj/features-report/html/index.html` exists and names the five
  features; a broken expectation still renders and the target exits
  non-zero.

### F10 -- The testing layers, judged over both suites

- **Where:** `tests/src/lector_scan_tests.adb` (8 tests),
  `tests/src/lector_utilada_tests.adb` (4 tests).
- **What is wrong:** nothing, and the item exists to say so on the
  record.  The guidance: a unit test typically tests a single
  function, or a simple interaction between two, and must cover it
  completely; a feature tests the larger interaction that forms a
  conceptual feature; duplication across the layers is fine; a test
  goes only when it is an integration test a scenario fully supplants.
- **Why:** every test in both suites calls one function of one unit
  (`String_Value`, `Mask_Values`, `Parse` then `Value`) on an inline
  document and asserts its edge cases -- the unterminated value, the
  key with no colon, the value of the wrong shape, the `From` offset,
  the trailing-garbage acceptance.  Each is the complete coverage of
  that function, and none is an integration across units; there is no
  larger interaction in this crate than "parse, then read a field".
- **Fix:** remove nothing.  Record the judgement in the plan's
  revision notes and in `CLAUDE.md` (F11), so the next reader does
  not re-run it: the features duplicate the suites by design, and the
  suites keep the mechanism: where a scan stops and why, the key
  with no colon, the unterminated value.  A feature may state a
  returned value, even an odd one like `a\`, because a returned
  value is the crate's edge; it never states how the scan got there.
- **RED first:** none -- a judgement item.  The gate is `make test`
  still reporting 12 tests after F3-F7, and every scenario green beside
  them.

### F11 -- The docs say so

- **Where:** `CLAUDE.md:15-23` ("Commands"), `:33` (the `tests/`
  layout line), `:48-57` ("TDD protocol"), `README.md:47-58`
  ("Develop").
- **Fix:** `make features` and `make features-report` lines in both;
  the layout line names `tests/features/`, `lector_features.ads`, the
  machines and `tests/features/docs/`; the TDD section gains the
  layers guidance (unit tests cover their function completely; a
  feature tests the larger interaction; duplication is fine; a test
  goes only when it is an integration test a scenario fully supplants)
  and the fabula pattern rules (no quote in a `{string}`, no `/` after
  a letter); the README links the published page
  (`https://ldm5180.github.io/lector/`) beside the example.  The plan
  gets its status line.

## 5. Verified in a scratch worktree (iteration 3)

Against the tree at `c06039aa`, in a detached worktree under the
session scratchpad, GNAT 15.2.0, gprbuild 26.0.1, 2026-10-03:

1. `fabula = "*"` and its pin added to `alire.toml` (lector pins no
   `sml`, so the pin is a new `[[pins]]` table):
   `alr --non-interactive build --validation` succeeds in 2.0 s (3.9 s
   wall), deploying `fabula_746a234d` and `sml_3ccd0e4b` with no
   conflict and no other crate moving.  fabula compiles under the
   dependency profile with its `-gnatwu` line as a warning.
2. The F1 sketch typed in: `with "fabula"`, the second main
   `lector_features.ads`, `lector_steps-flows.ads/.adb` (the runner,
   nuntius's shape), `lector_steps.ads/.adb` (three steps as one
   machine, `Empty -> Read`, a `Count_Read` guard with a refusing
   fallback row, a region-style refusal naming the state), and a
   two-scenario smoke feature.  `gprbuild -P tests/test_lector.gpr`
   builds both mains in 2.4 s with no warning; the run prints
   `2 Scenarios (1 failed, 1 passed) / 5 Steps (1 failed, 4 passed)`
   -- the first scenario green, the out-of-order check failing with
   `E_CHECK_READ is not a step this scenario can take now: EMPTY`, as
   F1 requires; `test_runner` beside it still reports 12 successful
   tests.  No correction was needed in the typing: the main as `.ads`,
   the `Op.Ev` wrappers, the guard as a body with the event
   unreferenced, and the capture read inside its own arm are nuntius's
   lessons applied once.
3. Not verified here, and the reason they are their own items: the
   `script(1)` colour recipe (F8) and the report rendering (F9) are
   copied from nuntius, where each was run and mutation-checked on
   2026-10-03; the gates in those items say what to measure.

## 6. The second wave, sketched

Not itemized; each is a feature of its own when it is wanted.

- **The example as a scenario.**  `example/src/json_fields.adb` is a
  side-by-side of the two readers on one sample; it is already the
  scanning feature's named document, and a scenario could state the
  example's four readings so `make run` and the features agree by
  construction.
- **Property-shaped outlines.**  `Scenario Outline` over a table of
  `key | value` pairs for the string scan, and of `key | digits` for
  the number scan, including keys at `Max_Key` and one past it (the
  refusing row).
- **A consumer's document.**  fructus's journal line and token file
  shapes, as named documents, read the way fructus reads them -- the
  flat parse for the top level, the scans for a leg inside an array.

## Revision notes

- **Iteration 1 (draft):** the seam (strings, not sockets), the
  layout, the step table, eleven items, a second wave -- the nuntius
  plan's shape with the world replaced by a document in hand.
- **Iteration 2 (as a newcomer):** added "How to use this plan" with
  the four up-front decisions (machines from the start, named
  documents, living docs, the layers), the "Do not" list -- three of
  its entries are limits of the reader a feature must state as limits
  (`String_Value` does not unescape; `Utilada.Value` does not reach a
  nested key; `Parse` carries no location, so "refused with its
  location" is not a thing this crate can promise and the draft's
  wording of it is gone) -- section 1 with the three fabula limits
  that bite here (line length, message length, the quoted capture),
  section 3.1 (the machines' states and the one follow-up event),
  section 3.2 (doc string versus named file, and when each), a full
  Gherkin sketch for F3, and a RED assertion and gates per item.
  Moved the colour recipe (F8) and the living docs (F9) out of F1 so
  each is one cycle, and added F10 as an explicit judgement item
  because the layers guidance asks for a judgement on the record.
- **Iteration 3 (against the tree at `c06039aa`, and the scratch
  builds of section 5):** every `file:line` re-located.  Corrected:
  F0 first said "a `[[pins]]` entry" as if the table existed -- lector
  has no `[[pins]]` table and no `sml` pin, so the item creates the
  table and the draft's "the chain" paragraph (the five-crate `sml`
  alignment the nuntius plan needed) is deleted as not applying;
  `Test_From_Offset` is `31-40` and `Test_Number_Value` `42-55`, not
  the draft's `30-41` and `43-56`; `Test_Mask_Values_Keys` starts at
  140 with its comment, the body at 143; the reading contracts are
  `CLAUDE.md:83-92`, not a section 7; the CI example step runs the
  example in BOTH modes (`:71-76`), so F9's steps go after it, not
  after the test step; and the directive's "numbers and strings read
  with their edge cases (escapes, unicode)" became F3's last scenario
  and a Do-not entry once the scan body showed `String_Value` stops at
  the next `"` (`lector-scan.adb:103-117`, its three returns at 109,
  114 and 117) and does no unescaping.
  Also corrected on the re-read: the three later utilada tests end at
  45, 57 and 72, not 43, 55 and 70, and README's "Develop" block is
  `47-58`.  Confirmed: `aunit` at `alire.toml:16`, the actions at `:28-43`,
  `for Main` at `tests/test_lector.gpr:16`, `test:` at `Makefile:17`,
  `format:` at `:29`, the `alr test` step at `ci.yml:64-69`,
  `/example/bin/` at `.gitignore:9`, the suite at 12 tests.
- **After the behavior guidelines (2026-10-03):** audited every check
  step and title against "a feature binds behavior, a unit test holds
  the mechanism".  Changed: F3's feature description dropped "nothing
  is parsed, nothing is allocated" (a feature cannot observe
  allocation; the observable form is "a document the parser would
  refuse still gives up its field") and two scenario titles that named
  the mechanism ("a flat parse would mangle" -> "a field inside a
  nested array is read directly"; "reads up to the escape" -> "an
  escaped quote is not unescaped: the value ends at it"); F5's and
  F6's titles, in the tree and the items ("the flat parse", "the
  strict document-close check" -> what the consumer does); F5's limit
  reworded from how the parse stores keys to what a dotted key gets;
  F10's claim that the unit test "pins the byte" of `a\` reconciled --
  a returned value is the crate's edge and a feature may bind it, the
  unit test keeps why the scan stops there.  Added: a fifth up-front
  decision, two Do-not entries ("do not check how"; no package or
  subprogram in a title), and a note under F3, F4, F5 and F7 that the
  lifted unit tests' assertions stay and the feature restates outcomes
  only.  Judged and left: the `From` offset step ("after the first
  <key>") -- `From` is a public parameter the consumer passes, so the
  second-occurrence read is behavior; every `the value is` / `is
  absent` / `is present` / `the parse succeeds` check -- each reads
  what a function returns at the crate's edge; the three stated limits
  -- each is a behavior the consumer meets, now phrased as what they
  get.  No step was demoted: the step table held no check that reaches
  past a return value.  No anchor moved.
- **Implementation (2026-10-03):** F1's smoke feature holds the one
  passing scenario only.  The out-of-order check is run from a scratch
  directory, where it fails as "E_CHECK_READ is not a step this
  scenario can take now: smoke=EMPTY"; committed, it would turn `make
  features` and `alr test` red, since fabula has no expected-failure
  marker.  The smoke machine is a region of its own
  (`Lector_Steps.Smoke`), so the regions table exists from F1 and each
  feature after it adds one row.
  F2 holds the document in its own region, `Lector_Steps.Holding`
  (`Blank -> Loading -> Holding`), not in each feature's machine:
  the features share the hold steps, and a step every region took
  would run once per region.  The reading regions guard their first
  step on `Holding.Held` instead, with a refusing fallback row.  The
  `World` gains each field in the item whose steps first read it, not
  all of them in F2.
  F3's scanning machine replaces the smoke one: it is the runner's
  proof from then on, so `smoke.feature`, `Lector_Steps.Smoke` and the
  counting helpers go in the same commit, as nuntius's first feature
  replaced its smoke.  F3 adds a second `hashValue` read (`111` ->
  `AAA`) to the matching-object scenario, the unit test's other
  assertion, and the scans refuse a key past `Max_Key` and an "after
  the first" key the document lacks, each naming it.
  F4 needs the parse and a field read for its last scenario, so the
  parse arrives here as its own region (`Lector_Steps.Parsing`,
  `Unparsed -> Parsed`) and F5 adds only its checks.  Every read that
  gives a value -- the four scans and the field read -- is one region,
  `Lector_Steps.Reading` (F3's `Scanning`, renamed), which owns the
  value checks: two regions each taking `the value is` would check it
  twice.  A field read is guarded on `Parsing.Done`, whatever the
  verdict, so "a failed parse reads empty" stays a row (3.1).  An
  empty match value is a quoted capture, `whose accountNumber is ""`,
  matched by a pattern placed before the `{word}` one (fabula takes
  the first matching row of the step table).
  F5's limit scenario uses a nested OBJECT (`{"child": {"status":
  ...}}`), not the array of the unit test: an array would never read
  by a dotted key under any parser, so only an object states the limit.
  Its trailing-garbage scenario also reads the field back (`a` is
  `"1"`), which the unit test does not assert.
  F6 adds "a file cut short is not a single object" (the truncated
  write the check exists for) and does not claim a doubled write is
  caught: `{...}{...}` ends with `}` and passes the check, so that is
  no promise the crate makes.  A doc string keeps its trailing blank
  lines (fabula joins them with LF), which is how the blank-lines
  scenario holds its blanks; a mutant that wants `}` as the very last
  byte fails exactly that scenario.
  F7's masked or escaped text is its own World field (`Text`), not
  `Value`: the masking region owns its checks (`the text reads:`, `the
  text is unchanged`, `masking it again changes nothing`), and the
  keys it masked by are kept beside the text so the idempotence check
  masks again by the same list -- one key or a table.  After an escape
  that check is refused ("the text was escaped, not masked").  The
  escape scenario uses a line break, not a tab or a NUL: a control
  character a reader can see in the feature file.
