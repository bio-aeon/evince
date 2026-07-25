module Evince.Async.Shared

import Data.IORef
import Data.Linear.Ref1
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

||| The fail-fast abort flag threaded through the runner - a base `Data.IORef`
||| cell (not the `IORef` that IO.Async re-exports from Data.Linear.Ref1).
public export
0 AbortRef : Type
AbortRef = Data.IORef.IORef Bool

-- Guard every event with the lock so events emitted from different fibers
-- can't interleave.
lockedReporter : Reporter (Async e []) -> Lock (Async e []) -> Reporter (Async e [])
lockedReporter base lock = MkReporter (\ev => lock.withLock (base.onEvent ev))

||| Evaluate the top-level groups, running up to `cfg.jobs` of them
||| concurrently. `jobs = 0` falls back to core's sequential walk; otherwise a
||| pool of `jobs` workers claims groups from a shared queue as slots free up
||| (sliding window - a slow group never stalls the ones after it). Under
||| `--fail-fast` the first failure also cancels the in-flight groups: their
||| partial output is flushed, their completed tests keep their results, and a
||| `SuiteAborted` event notes that the run was cut short. A concurrent group's
||| events are buffered and replayed under the lock when the group finishes, so
||| groups' output never interleaves.
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
    S k => do
      queue       <- newref trees
      results     <- newref emptyResult
      cancelled   <- newref False
      interrupted <- newref False
      registry    <- newref (the (List (Nat, Fiber [] ())) [])
      let idxs = workerIds (min (S k) (length trees))
      fibs <- traverse (\i => start (worker queue results cancelled registry interrupted i)) idxs
      writeref registry (zip idxs fibs)
      traverse_ wait fibs
      unclaimed <- readref queue
      cut       <- readref interrupted
      when (cut || not (null unclaimed)) (lock.withLock (base.onEvent SuiteAborted))
      readref results
  where
    workerIds : Nat -> List Nat
    workerIds Z     = []
    workerIds (S m) = [0 .. m]

    toSummary : TestReport -> Summary
    toSummary rep = case rep.outcome of
      Passed d   => MkSummary 1 0 0 d
      Failed _ d => MkSummary 0 1 0 d
      Skipped _  => MkSummary 0 0 1 0

    -- A cancelled group's buffer is the source of truth: the results of its
    -- completed tests are recovered from the buffered events.
    partialResult : List Event -> EvalResult
    partialResult evs =
      let reps = mapMaybe (\case TestDone rep _ => Just rep; _ => Nothing) evs
      in (foldMap toSummary reps, Lin <>< reps)

    deposit : Ref World EvalResult -> EvalResult -> Async e [] ()
    deposit results r = runIO $ casupdate1 results (\acc => (mergeResults acc r, ()))

    runGroup : Ref World EvalResult -> Ref World Bool -> SpecTree (Async e []) () -> Async e [] ()
    runGroup results interrupted t = do
      buf  <- liftIO (newIORef (the (SnocList Event) [<]))
      done <- liftIO (newIORef False)
      let buffered = MkReporter (\ev => liftIO (modifyIORef buf (:< ev)))
          flush : Async e [] (List Event)
          flush = do
            evs <- liftIO (readIORef buf)
            let l = evs <>> []
            lock.withLock (traverse_ base.onEvent l)
            pure l
      onCancel
        (do r <- evalTree buffered cfg abortRef [] t 0
            -- Masked so a fiber is never cancelled while holding the reporter
            -- lock (the cancel finalizer flushes too, and the lock is not
            -- reentrant).
            uncancelable $ \_ => do
              ignore flush
              deposit results r
              liftIO (writeIORef done True))
        -- A cancel requested during the masked tail is observed right after
        -- it, with the group already flushed and deposited - the finalizer
        -- must be a no-op then, or the group would be counted twice.
        (do d <- liftIO (readIORef done)
            when (not d) $ do
              writeref interrupted True
              evs <- flush
              deposit results (partialResult evs))

    claim : Ref World (List (SpecTree (Async e []) ())) -> Async e [] (Maybe (SpecTree (Async e []) ()))
    claim queue = runIO $ casupdate1 queue $ \case
      []        => ([], Nothing)
      (t :: ts) => (ts, Just t)

    worker :
         Ref World (List (SpecTree (Async e []) ()))
      -> Ref World EvalResult
      -> Ref World Bool
      -> Ref World (List (Nat, Fiber [] ()))
      -> Ref World Bool
      -> Nat
      -> Async e [] ()
    worker queue results cancelled registry interrupted me = loop
      where
        -- Only the first observer cancels, so siblings are cancelled once.
        cancelSiblings : Async e [] ()
        cancelSiblings = do
          won <- runIO (caswrite1 cancelled False True)
          when won $ do
            fibs <- readref registry
            traverse_ (\(i, f) => when (i /= me) (cancel f)) fibs

        loop : Async e [] ()
        loop = do
          stop <- liftIO (readIORef abortRef)
          if stop then cancelSiblings else do
            Just t <- claim queue
              | Nothing => pure ()
            runGroup results interrupted t
            st <- liftIO (readIORef abortRef)
            if st then cancelSiblings else loop

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
