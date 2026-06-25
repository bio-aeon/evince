# Async Drivers: Concurrent and Parallel Execution

Evince's core (`evince`) runs tests sequentially on every backend. The optional
async driver packages add concurrent or parallel execution of top-level
`describe` groups. They expose one shared API; which package you add decides the
execution model and the backends it runs on.

## The packages

| Package | Event loop | Execution | Backends |
|---|---|---|---|
| `evince` | - | sequential | all |
| `evince-async` | `async` (`SyncST`) | single-threaded concurrency | Chez, Racket |
| `evince-async-js` | `async-js` (`JS`) | single-threaded concurrency | Node/JS |
| `evince-async-posix` | `async-posix` (`ThreadPool`) | true multi-core parallelism | Chez |

## Concurrency vs parallelism

- **Concurrency** (`evince-async`, `evince-async-js`): groups are interleaved on a
  single thread, yielding at suspension points. This overlaps *waiting* (I/O,
  timers, awaits) but not CPU work, so CPU-bound suites see no speedup.
- **Parallelism** (`evince-async-posix`): groups run on multiple OS worker threads
  across cores, so CPU-bound suites get a real wall-clock speedup.

Rule of thumb: reach for `evince-async-posix` when a suite is CPU-bound (and
you're on Chez); reach for `evince-async` / `evince-async-js` when groups spend
time awaiting I/O; otherwise core's sequential runner is fine everywhere.

## Write once, swap import

Write specs effect-polymorphically - `HasIO m => Spec m () ()`, importing only
`Evince` - and the same spec runs unchanged under core or any driver:

```idris
import Evince

spec : HasIO m => Spec m () ()
spec = describe "math" $ do
  it "adds" $ (1 + 1) `mustBe` 2
```

`main` is then a thin per-backend shim. The runner names are identical across the
driver packages, so moving between backends changes only the import and the
package dependency:

```idris
import Evince.Async        -- native concurrency (Chez/Racket)
main = runSpecAsync spec

import Evince.Async.JS      -- Node concurrency
main = runSpecAsync spec

import Evince.Async.Posix   -- true parallelism (Chez)
main = runSpecAsync spec
```

## Async test bodies

`it` / `itIO` cover pure and `IO` test bodies. To write a body that is itself an
`Async` computation - so it can await a `Promise`, `cede`, spawn fibers, or race -
use the async cousins (from `Evince.Async.Spec`, re-exported by every driver):

| Function | Test body | Mirrors |
|---|---|---|
| `itAsync` | `Async e [] (TestResult ())` | `it` / `itIO` |
| `itAsyncWith` | `a -> Async e [] (TestResult ())`, receiving the group's resource | `itWith` / `itIOWith` |

```idris
itAsync "runs in a fiber" $ do
  cede                       -- yield: await a Promise, spawn fibers, race, ...
  pure ((1 + 1) `mustBe` 2)
```

Assert with the pure matchers (as above); the IO-shaped helpers (`mustReturn`,
`mustError`) need `liftIO`.

## Runner entry points

Each driver package provides the full family, mirroring core's `runSpec*`:

| Function | Description |
|---|---|
| `runSpecAsync` | Run, print results, exit 1 on failure |
| `runSpecAsyncWith` | Run with a custom `RunConfig` |
| `runSpecAsyncWithArgs` | Run with CLI arg parsing (`--jobs=N`, ...) |
| `runSpecAsyncFailFast` | Stop after the first failure |
| `runSpecAsyncTimed` | Show per-test timing |
| `runSpecAsyncWithSummary` / `...AndConfig` | Return `Summary` without exiting (meta-testing) |
| `runSpecAsyncIO` / `runSpecAsyncIOWith` | Run a concrete `Spec IO` under the driver |

## `--jobs`

`--jobs=N` (or `{ jobs := N } defaultConfig`) bounds how many top-level groups run
at once; `--jobs=0` runs sequentially. Tests within a group always run
sequentially, preserving hook semantics. `beforeAll` / `beforeAllWith` setup runs
exactly once even when groups run together - it is guarded by a lock.

## Backend support

| | Chez | Racket | RefC | Node/JS |
|---|---|---|---|---|
| `evince` (sequential) | yes | yes | yes | yes |
| `evince-async` (concurrency) | yes | yes | no | - |
| `evince-async-js` (concurrency) | - | - | - | yes |
| `evince-async-posix` (parallelism) | yes | no | no | - |

`-` = not applicable; `no` = targeted but not yet supported (see below).

`evince-async` covers Chez and Racket but not RefC - its `caswrite1` lock has no
RefC backend.

True multi-core parallelism currently works on Chez only. Racket's `fork` is
green-threaded (no parallelism) and its codegen rejects `async-posix`'s poll FFI;
RefC's threading is unimplemented. On Racket use `evince-async` (concurrency) or
core; on RefC use core (sequential). JS has no OS threads, so `evince-async-js`
is concurrency-only by construction.

The posix worker pool sizes itself to the processor count by default; set
`IDRIS2_ASYNC_THREADS=N` to override.
