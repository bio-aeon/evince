# CLI Options

Use `runSpecWithArgs` to enable command-line configuration:

```idris
main : IO ()
main = runSpecWithArgs spec
```

| Flag              | Description                                     |
|-------------------|-------------------------------------------------|
| `--fail-fast`     | Stop after the first failure                    |
| `--times`         | Show per-test and total duration                |
| `--match=PATTERN` | Run only tests whose name contains PATTERN      |
| `--skip=PATTERN`  | Skip tests whose name contains PATTERN          |
| `--randomize`     | Shuffle test order                              |
| `--seed=N`        | Deterministic seed for shuffle                  |
| `--junit=FILE`    | Write JUnit XML report to FILE                  |
| `--rerun`         | Re-run only previously failed tests             |
| `--jobs=N`        | Run top-level groups in parallel (N threads)    |

Flags can be combined freely: `--rerun --fail-fast`, `--jobs=4 --times`, etc.

## JUnit XML

Pass `--junit=report.xml` to produce a JUnit XML report alongside console output:

```sh
./my-tests --junit=report.xml
```

The output follows the standard JUnit XML format, compatible with GitHub Actions,
Jenkins, GitLab CI, and other CI systems. When source locations are captured
via `itLoc`, the XML includes `file` and `line` attributes on test cases.

## Rerun Failed

When any tests fail, evince writes their paths to `.evince-failures`. Pass `--rerun`
to re-run only those tests:

```sh
./my-tests                 # some tests fail -> .evince-failures created
./my-tests --rerun         # re-runs only the failed tests
./my-tests --rerun --fail-fast  # combines with other flags
```

When all tests pass, the failure file is automatically deleted.

## Parallel Execution

Run top-level `describe` groups concurrently with `--jobs=N`:

```sh
./my-tests --jobs=4
```

Tests within each group still run sequentially (preserving hook semantics).
`beforeAll` and `beforeAllWith` are thread-safe — setup runs exactly once even
when multiple threads reach it concurrently.

Requires the Chez Scheme backend.
