# lector

Narrow JSON reading for Ada 2022, with the scanning half SPARK-proven.

`lector` (Latin: *reader*) packages the two ways a REST consumer actually
reads JSON, and nothing else:

- **`Lector.Scan`** — targeted, pure scans over raw JSON text, for payloads
  whose nesting a flattening parser would mangle: the string or digit-run
  value following a quoted key, iteration over the flat `{...}` objects of
  an array, and a strict "the document ends where the object closes" check
  that catches truncated-or-doubled-write corruption. Every function lives
  in the SPARK core: no exceptions, no allocation, proved free of runtime
  errors.
- **`Lector.Utilada`** — a whole-document parse over
  [utilada](https://github.com/stcarrez/ada-util)'s JSON reader into a flat
  property view (`Parse` / `Has` / `Value`), reporting `Ok : out Boolean`
  instead of raising: malformed input is a result, never an exception.

## Use it

Add the dependency (via a git pin until it is in the community index):

```toml
[[depends-on]]
lector = "*"
```

```ada
with Lector.Utilada;

Doc : Lector.Utilada.Document;
Ok  : Boolean;
...
Lector.Utilada.Parse ("{""status"": ""FILLED""}", Doc, Ok);
--  Ok and then Lector.Utilada.Value (Doc, "status") = "FILLED"
```

```ada
with Lector.Scan;

--  Pull one field out of a nested payload without parsing all of it:
Id : constant String :=
  Lector.Scan.Number_Value (Reply, "orderId", From => Reply'First);
```

## Develop

```sh
make build    # build the library
make test     # AUnit suite, both -O modes, fully offline
make features # the Gherkin features in tests/features/, both -O modes
make features-report # the living documentation, as CI publishes it
make prove    # SPARK proof, --checks-as-errors=on
make format   # gnatformat --check
make run      # run the json_fields example (offline; CI runs it too)
make help     # all targets
```

What the reader does is stated as Gherkin features in
[tests/features](tests/features), and published as living documentation
at <https://ldm5180.github.io/lector/> from every push to main.

Conventions (SPARK, strict TDD, commit style) live in [CLAUDE.md](CLAUDE.md).
