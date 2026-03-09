# Runners

| Function                      | Description                                       |
|-------------------------------|---------------------------------------------------|
| `runSpec`                     | Run suite, print results, exit 1 on failure       |
| `runSpecFailFast`             | Stop after the first failure                      |
| `runSpecTimed`                | Show per-test timing                              |
| `runSpecWith`                 | Run with custom `RunConfig`                       |
| `runSpecWithArgs`             | Run with CLI arg parsing                          |
| `runSpecWithSummary`          | Run and return `Summary` (for meta-testing)       |
| `runSpecWithSummaryAndConfig` | Run with config and return `Summary`              |

The `IO ()` variants print colored results and call `exitFailure` if any test
fails. They also write `.evince-failures` for the rerun feature.

The `IO Summary` variants return the summary without printing, exiting, or
writing failure files — useful for meta-testing (testing your framework with
itself).

## Fail-Fast

Stop execution after the first failing test:

```idris
main : IO ()
main = runSpecFailFast spec
```

Or via CLI: `--fail-fast`.

## Timing

Show per-test and total duration:

```idris
main : IO ()
main = runSpecTimed spec
```

Or via CLI: `--times`.

## Custom Configuration

Build a `RunConfig` manually for full control:

```idris
main : IO ()
main = runSpecWith ({ failFast := True, showTiming := True } defaultConfig) spec
```

Or use `runSpecWithArgs` to let users pass flags on the command line.
