module Evince.Async.Posix

import public Evince.Async.Spec
import public Evince.Async.Synchronized
import public Evince.Async.Hoist
import public Evince.Async.Shared

import Data.Maybe
import System
import System.Info
import IO.Async
import IO.Async.Loop.Posix
import Evince.Core

-- The posix event-loop runner. idris2-async's `simpleApp` takes its worker-thread
-- count only from IDRIS2_ASYNC_THREADS (default 2). We give a better default for a
-- test runner - the processor count - by setting the variable when it's unset, so
-- users get full parallelism out of the box while keeping the env var as an
-- override (an explicit value is always respected).
posixRun : Async Poll [] () -> IO ()
posixRun prog = do
  Nothing <- getEnv "IDRIS2_ASYNC_THREADS"
    | Just _ => simpleApp prog
  cores <- getNProcessors
  ignore $ setEnv "IDRIS2_ASYNC_THREADS" (show (fromMaybe 2 cores)) True
  simpleApp prog

-- Multi-threaded entry points: idris2-async's poll-based `ThreadPool` distributes
-- top-level groups across OS worker threads, so they execute with genuine
-- multi-core parallelism. In practice this builds and runs only on Chez; Racket
-- and RefC hit upstream threading/FFI gaps that keep the posix loop from running
-- there. The `caswrite1` lock keeps group hooks correct under that true concurrency.

||| Run a spec under the multi-threaded posix driver with custom configuration,
||| printing results and exiting non-zero if any test failed.
export
runSpecAsyncWith : RunConfig -> Spec (Async Poll []) () () -> IO ()
runSpecAsyncWith = runSpecVia posixRun

||| Run a spec under the multi-threaded posix driver with default configuration.
export
runSpecAsync : Spec (Async Poll []) () () -> IO ()
runSpecAsync = runSpecAsyncWith defaultConfig

||| Run under the posix driver with custom configuration and return the summary
||| without exiting. Useful for meta-testing.
export
runSpecAsyncWithSummaryAndConfig : RunConfig -> Spec (Async Poll []) () () -> IO Summary
runSpecAsyncWithSummaryAndConfig = summaryVia posixRun

||| Run under the posix driver and return the summary without exiting.
export
runSpecAsyncWithSummary : Spec (Async Poll []) () () -> IO Summary
runSpecAsyncWithSummary = runSpecAsyncWithSummaryAndConfig defaultConfig

||| Run a spec under the posix driver, reading CLI args (e.g. `--jobs=N`).
export
runSpecAsyncWithArgs : Spec (Async Poll []) () () -> IO ()
runSpecAsyncWithArgs = runSpecArgsVia posixRun

||| Run under the posix driver with fail-fast - stop after the first failure.
export
runSpecAsyncFailFast : Spec (Async Poll []) () () -> IO ()
runSpecAsyncFailFast = runSpecFailFastVia posixRun

||| Run under the posix driver with per-test timing displayed.
export
runSpecAsyncTimed : Spec (Async Poll []) () () -> IO ()
runSpecAsyncTimed = runSpecTimedVia posixRun

||| Run a concrete `Spec IO` under the posix driver, hoisting its actions into
||| `Async` via `liftIO`.
export
runSpecAsyncIO : Spec IO () () -> IO ()
runSpecAsyncIO = runSpecAsync . hoistSpec liftIO

||| Like `runSpecAsyncIO`, with custom configuration.
export
runSpecAsyncIOWith : RunConfig -> Spec IO () () -> IO ()
runSpecAsyncIOWith cfg = runSpecAsyncWith cfg . hoistSpec liftIO
