module Evince.Async.Shared

import Data.IORef
import Data.List
import System
import IO.Async
import Evince.Config
import Evince.Core
import Evince.Report
import Evince.Reporter
import Evince.Rerun
import Evince.Runner
import Evince.Synchronized
import Evince.Async.Synchronized

-- `IORef` is ambiguous here: IO.Async re-exports Data.Linear.Ref1's IORef,
-- but core's runner hands us a base Data.IORef cell.
0 AbortRef : Type
AbortRef = Data.IORef.IORef Bool

-- Split a list into runs of at most `n` elements (`n >= 1`).
chunksOf : Nat -> List a -> List (List a)
chunksOf Z     xs = [xs]
chunksOf (S k) xs = go xs
  where
    go : List a -> List (List a)
    go []          = []
    go ys@(_ :: _) = let (h, t) = splitAt (S k) ys in h :: go (assert_smaller ys t)

-- Guard every event with the lock so events emitted from different fibers
-- can't interleave.
lockedReporter : Reporter (Async e []) -> Lock (Async e []) -> Reporter (Async e [])
lockedReporter base lock = MkReporter (\ev => lock.withLock (base.onEvent ev))

||| Evaluate the top-level groups, running up to `cfg.jobs` of them
||| concurrently. `jobs = 0` falls back to core's sequential walk; otherwise
||| each batch of `jobs` groups is run together, with an abort
||| check between batches so `--fail-fast` still short-circuits. A concurrent
||| group's events are buffered and replayed under the lock when the group
||| finishes, so groups' output never interleaves.
export
evalAsyncForest :
     Reporter (Async e [])
  -> Lock (Async e [])
  -> RunConfig
  -> AbortRef
  -> List (SpecTree (Async e []) ())
  -> Async e [] EvalResult
evalAsyncForest base lock cfg abortRef trees =
  case cfg.jobs of
    Z   => evalForest (lockedReporter base lock) cfg abortRef [] trees 0
    S k => go emptyResult (chunksOf (S k) trees)
  where
    runGroup : SpecTree (Async e []) () -> Async e [] EvalResult
    runGroup t = do
      buf <- liftIO (newIORef (the (SnocList Event) [<]))
      let buffered = MkReporter (\ev => liftIO (modifyIORef buf (:< ev)))
      r <- evalTree buffered cfg abortRef [] t 0
      evs <- liftIO (readIORef buf)
      lock.withLock (traverse_ base.onEvent (evs <>> []))
      pure r

    go : EvalResult -> List (List (SpecTree (Async e []) ())) -> Async e [] EvalResult
    go acc []              = pure acc
    go acc (chunk :: rest) = do
      stop <- liftIO (readIORef abortRef)
      if stop
        then pure acc
        else do
          results <- parseq (map runGroup chunk)
          let merged = maybe emptyResult (foldl mergeResults emptyResult) results
          go (mergeResults acc merged) rest

||| Run a spec on a caller-supplied event loop and return the full result.
||| The `runLoop` argument is the backend's `Async` runner (`syncApp` for the
||| SyncST loop, `app` for the JS loop). Dies if the loop terminates before
||| the suite completes, rather than reporting an empty successful run.
export
runResultVia :
     {e : Type}
  -> (Async e [] () -> IO ())
  -> RunConfig
  -> Spec (Async e []) () ()
  -> IO EvalResult
runResultVia runLoop cfg spec = do
  out <- newIORef (the (Maybe EvalResult) Nothing)
  runLoop $ do
    base <- makeReporter cfg
    lock <- liftIO newLock
    result <- runForestWith (lockedReporter base lock)
                            (\ref, ts => evalAsyncForest base lock cfg ref ts)
                            cfg (getSpecTrees spec)
    liftIO (writeIORef out (Just result))
  Just r <- readIORef out
    | Nothing => die "evince: the event loop ended before the suite completed"
  pure r

||| Run a spec on the given event loop, writing the failure list for `--rerun`
||| and exiting non-zero if any test failed.
export
runSpecVia : {e : Type} -> (Async e [] () -> IO ()) -> RunConfig -> Spec (Async e []) () () -> IO ()
runSpecVia runLoop cfg spec = do
  (summary, reports) <- runResultVia runLoop cfg spec
  writeFailures (failedPaths reports)
  when (summary.failed > 0) exitFailure

||| Run a spec on the given event loop and return the summary without exiting.
export
summaryVia : {e : Type} -> (Async e [] () -> IO ()) -> RunConfig -> Spec (Async e []) () () -> IO Summary
summaryVia runLoop cfg spec = fst <$> runResultVia runLoop cfg spec

||| Run a spec on the given event loop, reading CLI args (including `--jobs`)
||| for configuration.
export
runSpecArgsVia : {e : Type} -> (Async e [] () -> IO ()) -> Spec (Async e []) () () -> IO ()
runSpecArgsVia runLoop spec = do
  args <- getArgs
  cfg <- handleArgs (drop 1 args)
  runSpecVia runLoop cfg spec

||| Run a spec on the given event loop with fail-fast enabled.
export
runSpecFailFastVia : {e : Type} -> (Async e [] () -> IO ()) -> Spec (Async e []) () () -> IO ()
runSpecFailFastVia runLoop = runSpecVia runLoop ({ failFast := True } defaultConfig)

||| Run a spec on the given event loop with per-test timing displayed.
export
runSpecTimedVia : {e : Type} -> (Async e [] () -> IO ()) -> Spec (Async e []) () () -> IO ()
runSpecTimedVia runLoop = runSpecVia runLoop ({ showTiming := True } defaultConfig)
