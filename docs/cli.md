# CLI Options

Use `runSpecWithArgs` to enable command-line configuration:

```idris
main : IO ()
main = runSpecWithArgs spec
```

Under an async driver package, use that package's `runSpecAsyncWithArgs` instead;
it accepts the same flags and additionally applies `--jobs`.

| Flag              | Description                                     |
|-------------------|-------------------------------------------------|
| `--help`          | Print the flag reference and exit               |
| `--fail-fast`     | Stop after the first failure                    |
| `--times`         | Show per-test and total duration                |
| `--match=PATTERN` | Run only tests whose name contains PATTERN      |
| `--skip=PATTERN`  | Skip tests and groups whose name contains PATTERN |
| `--randomize`     | Shuffle test order                              |
| `--seed=N`        | Deterministic seed for shuffle                  |
| `--junit=FILE`    | Write JUnit XML report to FILE                  |
| `--rerun`         | Re-run only previously failed tests             |
| `--jobs=N`        | Run top-level groups concurrently (async driver) |
| `--no-color`      | Disable colored output                          |

Flags can be combined freely: `--rerun --fail-fast`, `--jobs=4 --times`, etc.
Unknown or invalid arguments print a warning on stderr and are otherwise
ignored. Colored output is also disabled when the `NO_COLOR` environment
variable is set.

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

## Concurrent and Parallel Execution

`--jobs=N` runs up to N top-level `describe` groups at once:

```sh
./my-tests --jobs=4
```

Tests within each group still run sequentially (preserving hook semantics), and
`beforeAll` / `beforeAllWith` setup runs exactly once even when groups run
together.

`--jobs` only takes effect with an async driver package. With `evince` alone the
flag is accepted but ignored, and the suite runs sequentially. Which driver you
add decides whether you get concurrency or true parallelism:

- `evince-async` / `evince-async-js` - single-threaded concurrency (overlaps
  awaiting; no CPU speedup).
- `evince-async-posix` - true multi-core parallelism (Chez only).

See [Async drivers](async.md) for the full model and backend support.
