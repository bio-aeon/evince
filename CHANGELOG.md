# Changelog

All notable changes to the evince package family (`evince`, `evince-hedgehog`,
`evince-async`, `evince-async-js`, `evince-async-posix`) are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
While pre-1.0, breaking changes may land in minor releases - they are marked
**Breaking** below.

## [Unreleased]

### Added

- `evince-hedgehog`: `runProperty` - run a `Property` silently, returning a
  `TestResult`.

### Changed

- `evince-hedgehog`: property failures now show hedgehog's shrunk
  counterexample, diff and recheck seed under the test's label; hedgehog itself
  no longer prints to the terminal.

## [0.7.0] - 2026-07-04

### Added

- `focus` - focus every test in a spec; composes with any combinator, unlike
  the pure-only `fit`.
- `xitIO` / `xitAsync` - pend an IO / `Async` test without rewriting its body.
- `--help`, `--no-color` (and `NO_COLOR`); unknown or invalid arguments now
  warn on stderr.

### Changed

- `xdescribe` reports every test in the group as pending, not a single entry.
- Pure test bodies (`it`, `xit`, `fit`, `itLoc`) are `Lazy` - evaluated at run
  time, not spec-build time.
- JUnit: failure details are the `<failure>` element's body; added `errors="0"`.
- Under `--jobs`, each group's output prints as one block, so concurrent groups
  don't interleave.
- **Breaking:** `evalAsyncForest` gained a `Lock` parameter - the reporter lock
  used to serialize group output.

### Removed

- **Breaking:** `makeAsyncReporter` - superseded by the locked,
  per-group-buffered reporting built into the async runners.

### Fixed

- `--skip` now works through nesting: a matching group skips its subtree, and
  nested matching tests are skipped.
- `--match` / `--skip` / `--rerun` now also filter pending tests and
  `afterAll`-wrapped groups.
- The async drivers fail loudly if the event loop ends before the suite
  completes, instead of exiting 0.

## [0.6.0] - 2026-06-16

The core became effect-polymorphic, and concurrent/parallel execution moved out
of core into dedicated driver packages - which also unblocks the Node backend.

### Added

- **Effect-polymorphic core.** `Spec`/`SpecTree`, hooks and expectations are now
  parameterized over the test-action monad `m` (any `HasIO m`), so a single spec
  can run under `IO` or any compatible effect.
- **`evince-async`** - concurrent test driver on the `SyncST` loop from `async`
  (Chez/Racket). Adds the `runSpecAsync*` runner family, `itAsync` /
  `itAsyncWith` for native `Async` test bodies and `hoistSpec` for re-targeting
  a `Spec` from one effect monad to another.
- **`evince-async-js`** - concurrent driver on the event loop from `async-js`
  (Node).
- **`evince-async-posix`** - true multi-core parallel driver on the thread pool
  from `async-posix` (Chez).
- `itAsyncLoc` - source-location capture for `Async` test bodies, the `Async`
  sibling of `itLoc` / `itIOLoc`.
- `Synchronized` interface in core - the lock seam the drivers use to keep
  `beforeAll` / `beforeAllWith` memoization correct under concurrency.
- `docs/async.md` documenting the driver model, concurrency vs parallelism and
  per-backend support.

### Changed

- **Breaking:** `Spec` gained a leading effect-monad parameter - `Spec a b` is
  now `Spec m a b`. Concrete specs annotated `Spec () ()` become `Spec IO () ()`.
  The `it` / `itIO` / `itWith` / `itIOWith` combinators are unchanged at call
  sites (they constrain `m` themselves).
- `--jobs=N` is now acted on by an async driver package; with `evince` alone the
  flag is accepted but ignored and the suite runs sequentially.
- Core no longer depends on the unused `contrib`.

### Removed

- **Breaking:** Chez-only parallel execution left core (`Evince.Parallel`). Core
  runs strictly sequentially on all supported backends now; concurrent and parallel
  execution come from the driver packages. This removes the unconditional `Mutex`
  usage that had made core fail to build on Node.

## [0.5.0] - 2026-03-10

### Added

- Custom reporter API (`Evince.Reporter`): `Reporter` and `Event` types for
  pluggable result reporting.
- Source-location capture: the `itLoc` / `itIOLoc` macros report the call-site
  file and line on failure, via elaborator reflection.
- Re-run failed tests: `--rerun` replays only the previously failed tests
  (failures are recorded to `.evince-failures`).
- Parallel execution: `--jobs=N` runs top-level groups concurrently (Chez only).

## [0.4.0] - 2026-03-09

### Added

- Structural diffs on failure (`Evince.Diff`): colored, tree-structured diff
  output for complex value mismatches (built on `pretty-show`).
- **`evince-hedgehog`** package - a property-testing bridge to idris2-hedgehog:
  `prop`, `itProp`, `itProp1`.

### Changed

- Repository restructured into a multi-package layout (`evince/`,
  `evince-hedgehog/`).

## [0.3.0] - 2026-03-07

### Added

- Resource-passing hooks: `provide`, `beforeWith`, `aroundWith`, `afterWith`,
  `beforeAllWith`, plus `itWith` / `itIOWith` to thread a resource into tests.
- Typed-error testing (`Evince.App`, a `Control.App` bridge): `tryApp`,
  `mustError`, `mustErrorWith`.
- CLI options (`Evince.Config`, `runSpecWithArgs`): `--match`, `--skip`,
  `--randomize`, `--seed`.
- Timing: `runSpecTimed` / `--times` show per-test and total duration.
- JUnit XML reporter: `--junit=FILE` writes a JUnit report alongside console
  output.

## [0.2.0] - 2026-03-01

### Added

- Lifecycle hooks: `before`, `after`, `around`.
- IO-based tests and expectations: `itIO`, `mustReturn`, `mustReturnEqual`.
- Fail-fast: `runSpecFailFast` / `--fail-fast` stop after the first failure.

## [0.1.0] - 2026-03-01

### Added

- Initial release - an Hspec-inspired BDD testing framework for Idris 2.
- `describe` / `context` and `it` blocks composed through a `Spec` monad.
- `DecEq`-powered expectations: `mustBe` / `mustNotBe` (decidable equality),
  `mustEqual` / `mustNotEqual` (`Eq` fallback), plus predicate, `Maybe`,
  `Either` and `List` matchers.
- Colored console reporter and the `runSpec` runner family.
