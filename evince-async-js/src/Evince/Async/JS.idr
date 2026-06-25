module Evince.Async.JS

import public Evince.Async.Spec
import public Evince.Async.Synchronized
import public Evince.Async.Hoist
import public Evince.Async.Reporter
import public Evince.Async.Shared

import IO.Async
import IO.Async.JS
import Evince.Core

-- JS/Node entry points: idris2-async's `JS` event loop, run via `app`. These
-- mirror `Evince.Async.Runner`'s names exactly (no `JS` suffix), so a
-- polymorphic spec runs unchanged on either backend - only the import and the
-- package dependency differ.

||| Run a spec under the async driver with custom configuration, printing
||| results and exiting non-zero if any test failed. Concurrency is controlled
||| by `cfg.jobs` (`--jobs`).
export
runSpecAsyncWith : RunConfig -> Spec (Async JS []) () () -> IO ()
runSpecAsyncWith = runSpecVia app

||| Run a spec under the async driver with default configuration.
export
runSpecAsync : Spec (Async JS []) () () -> IO ()
runSpecAsync = runSpecAsyncWith defaultConfig

||| Run under the async driver with custom configuration and return the
||| summary without exiting. Useful for meta-testing.
export
runSpecAsyncWithSummaryAndConfig : RunConfig -> Spec (Async JS []) () () -> IO Summary
runSpecAsyncWithSummaryAndConfig = summaryVia app

||| Run under the async driver and return the summary without exiting.
export
runSpecAsyncWithSummary : Spec (Async JS []) () () -> IO Summary
runSpecAsyncWithSummary = runSpecAsyncWithSummaryAndConfig defaultConfig

||| Run a spec under the async driver, reading CLI args (e.g. `--jobs=N`).
export
runSpecAsyncWithArgs : Spec (Async JS []) () () -> IO ()
runSpecAsyncWithArgs = runSpecArgsVia app

||| Run under the async driver with fail-fast - stop after the first failure.
export
runSpecAsyncFailFast : Spec (Async JS []) () () -> IO ()
runSpecAsyncFailFast = runSpecFailFastVia app

||| Run under the async driver with per-test timing displayed.
export
runSpecAsyncTimed : Spec (Async JS []) () () -> IO ()
runSpecAsyncTimed = runSpecTimedVia app

||| Run a concrete `Spec IO` under the async driver, hoisting its actions into
||| `Async` via `liftIO`. Group hooks keep their `IO`-baked (no-op)
||| synchronization, so prefer an effect-polymorphic spec with `runSpecAsync`
||| if you run group-level setup concurrently.
export
runSpecAsyncIO : Spec IO () () -> IO ()
runSpecAsyncIO = runSpecAsync . hoistSpec liftIO

||| Like `runSpecAsyncIO`, with custom configuration.
export
runSpecAsyncIOWith : RunConfig -> Spec IO () () -> IO ()
runSpecAsyncIOWith cfg = runSpecAsyncWith cfg . hoistSpec liftIO
