module Evince.Async.Runner

import IO.Async
import IO.Async.Loop.Sync
import Evince.Core
import Evince.Async.Hoist
import Evince.Async.Shared

-- Entry points for the synchronous `SyncST` event loop (run via `syncApp`),
-- which works on the Chez/Racket/RefC backends. The loop-agnostic
-- orchestration lives in `Evince.Async.Shared`; these entry points just supply
-- the `syncApp` loop runner.

||| Run a spec under the async driver with custom configuration, printing
||| results and exiting non-zero if any test failed. Concurrency is controlled
||| by `cfg.jobs` (`--jobs`).
export
runSpecAsyncWith : RunConfig -> Spec (Async SyncST []) () () -> IO ()
runSpecAsyncWith = runSpecVia syncApp

||| Run a spec under the async driver with default configuration.
export
runSpecAsync : Spec (Async SyncST []) () () -> IO ()
runSpecAsync = runSpecAsyncWith defaultConfig

||| Run under the async driver with custom configuration and return the
||| summary without exiting. Useful for meta-testing.
export
runSpecAsyncWithSummaryAndConfig : RunConfig -> Spec (Async SyncST []) () () -> IO Summary
runSpecAsyncWithSummaryAndConfig = summaryVia syncApp

||| Run under the async driver and return the summary without exiting.
export
runSpecAsyncWithSummary : Spec (Async SyncST []) () () -> IO Summary
runSpecAsyncWithSummary = runSpecAsyncWithSummaryAndConfig defaultConfig

||| Run a spec under the async driver, reading CLI args (e.g. `--jobs=N`).
export
runSpecAsyncWithArgs : Spec (Async SyncST []) () () -> IO ()
runSpecAsyncWithArgs = runSpecArgsVia syncApp

||| Run under the async driver with fail-fast - stop after the first failure.
export
runSpecAsyncFailFast : Spec (Async SyncST []) () () -> IO ()
runSpecAsyncFailFast = runSpecFailFastVia syncApp

||| Run under the async driver with per-test timing displayed.
export
runSpecAsyncTimed : Spec (Async SyncST []) () () -> IO ()
runSpecAsyncTimed = runSpecTimedVia syncApp

||| Run a concrete `Spec IO` under the async driver, hoisting its actions into
||| `Async` via `liftIO`. Group hooks (`beforeAll`/`beforeAllWith`) keep their
||| `IO`-baked (no-op) synchronization, so prefer an effect-polymorphic spec
||| with `runSpecAsync` if you run group-level setup concurrently.
export
runSpecAsyncIO : Spec IO () () -> IO ()
runSpecAsyncIO = runSpecAsync . hoistSpec liftIO

||| Like `runSpecAsyncIO`, with custom configuration.
export
runSpecAsyncIOWith : RunConfig -> Spec IO () () -> IO ()
runSpecAsyncIOWith cfg = runSpecAsyncWith cfg . hoistSpec liftIO
