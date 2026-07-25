module Evince.Async.DriverSpec

import Data.IORef
import Language.Reflection
import System
import IO.Async
import IO.Async.Loop.Sync
import Evince
import Evince.Report
import Evince.Async

%language ElabReflection

-- Disambiguate from Data.Linear.Ref1's deprecated newIORef, pulled in by IO.Async.
%hide Data.Linear.Ref1.newIORef

extractAsyncLoc : Spec (Async SyncST []) () () -> Maybe SrcLoc
extractAsyncLoc spec = case getSpecTrees spec of
  [It _ loc _] => loc
  _ => Nothing

asyncLocSpec : Spec (Async SyncST []) () ()
asyncLocSpec = itAsyncLoc `(()) "test" $ pure (1 `mustBe` 1)

-- Drive evalAsyncForest directly with a probe reporter, returning the raw
-- events alongside the result.
runPool : RunConfig -> Spec (Async SyncST []) () () -> IO (List Event, EvalResult)
runPool cfg spec = do
  evsRef <- newIORef [<]
  out    <- newIORef Nothing
  syncApp $ do
    lock     <- liftIO newLock
    abortRef <- liftIO (newIORef False)
    let probe = MkReporter (\ev => liftIO (modifyIORef evsRef (:< ev)))
    r <- evalAsyncForest probe lock cfg abortRef (getSpecTrees spec)
    liftIO (writeIORef out (Just r))
  evs <- map (<>> []) (readIORef evsRef)
  Just r <- readIORef out
    | Nothing => die "evince-async-test: the event loop ended before the pool returned"
  pure (evs, r)

hasAborted : List Event -> Bool
hasAborted = any (\case SuiteAborted => True; _ => False)

export
driverSpec : Spec IO () ()
driverSpec = describe "async driver" $ do
  describe "itAsync" $ do
    itIO "runs an Async test body" $ do
      s <- runSpecAsyncWithSummary $
        itAsync "passes" $ pure (1 `mustBe` 1)
      pure $ s.passed `mustBe` 1

    itIO "reports a failing Async test body" $ do
      s <- runSpecAsyncWithSummary $
        itAsync "fails" $ pure (1 `mustBe` 2)
      pure $ s.failed `mustBe` 1

    itIO "xitAsync marks the test pending without running it" $ do
      s <- runSpecAsyncWithSummary $ do
        itAsync "runs" $ pure (1 `mustBe` 1)
        xitAsync "pended" $ pure (1 `mustBe` 2)
      pure $ do
        s.passed `mustBe` 1
        s.pending `mustBe` 1

  describe "itAsyncLoc" $ do
    it "captures a source location" $
      mustBeJust (extractAsyncLoc asyncLocSpec)

    it "captured line is positive" $
      case extractAsyncLoc asyncLocSpec of
        Just loc => loc.line `mustSatisfy` (> 0)
        Nothing => mustFail "expected SrcLoc"

  describe "hoistSpec" $ do
    itIO "runs a hoisted Spec IO under the driver" $ do
      ref <- newIORef (the Nat 0)
      let ioSpec = itIO "io" $ do modifyIORef ref (+ 1); pure (1 `mustBe` 1)
      s <- runSpecAsyncWithSummary (hoistSpec liftIO ioSpec)
      n <- readIORef ref
      pure $ do
        s.passed `mustBe` 1
        n `mustBe` 1

  describe "concurrency (jobs > 0)" $ do
    itIO "collects results from more groups than workers" $ do
      let cfg = { jobs := 2 } defaultConfig
      s <- runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "g1" $ itAsync "a" $ pure (1 `mustBe` 1)
        describe "g2" $ itAsync "b" $ pure (1 `mustBe` 1)
        describe "g3" $ itAsync "c" $ pure (1 `mustBe` 2)
      pure $ do
        s.passed `mustBe` 2
        s.failed `mustBe` 1

    itIO "starts the next group as soon as a slot frees" $ do
      ref <- newIORef (the (List String) [])
      let cfg = { jobs := 2 } defaultConfig
      _ <- runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "slow" $ itAsync "s" $ do
          sequence_ (replicate 50 cede)
          liftIO (modifyIORef ref ("slow-done" ::))
          pure (1 `mustBe` 1)
        describe "quick" $ itAsync "q" $ pure (1 `mustBe` 1)
        describe "late" $ itAsync "l" $ do
          liftIO (modifyIORef ref ("late-start" ::))
          pure (1 `mustBe` 1)
      order <- readIORef ref
      pure $ reverse order `mustEqual` ["late-start", "slow-done"]

  describe "fail-fast cancellation (jobs > 0)" $ do
    itIO "cancels in-flight groups after the first failure" $ do
      ref <- newIORef False
      let cfg = { jobs := 2, failFast := True } defaultConfig
      s <- runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "failing" $ itAsync "boom" $ do
          sequence_ (replicate 10 cede)
          pure (1 `mustBe` 2)
        describe "slow" $ itAsync "s" $ do
          sequence_ (replicate 200 cede)
          liftIO (writeIORef ref True)
          pure (1 `mustBe` 1)
      done <- readIORef ref
      pure $ do
        s.failed `mustBe` 1
        done `mustBe` False

    itIO "keeps results of groups completed before the failure" $ do
      let cfg = { jobs := 1, failFast := True } defaultConfig
      s <- runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "first" $ itAsync "ok" $ pure (1 `mustBe` 1)
        describe "second" $ itAsync "boom" $ pure (1 `mustBe` 2)
        describe "third" $ itAsync "never" $ pure (1 `mustBe` 1)
      pure $ do
        s.passed `mustBe` 1
        s.failed `mustBe` 1

    itIO "emits SuiteAborted and flushes a cancelled group's partial output" $ do
      (evs, r) <- runPool ({ jobs := 2, failFast := True } defaultConfig) $ do
        describe "failing" $ itAsync "boom" $ do
          sequence_ (replicate 10 cede)
          pure (1 `mustBe` 2)
        describe "slow" $ do
          itAsync "first" $ pure (1 `mustBe` 1)
          itAsync "long" $ do
            sequence_ (replicate 200 cede)
            pure (1 `mustBe` 1)
      let doneNames = mapMaybe (\case TestDone rep _ => Just rep.path; _ => Nothing) evs
      pure $ do
        hasAborted evs `mustBe` True
        doneNames `mustEqual` [["failing", "boom"], ["slow", "first"]]
        (fst r).passed `mustBe` 1
        (fst r).failed `mustBe` 1

    itIO "skips the aborted-run note when the failure cuts no work short" $ do
      (evs, r) <- runPool ({ jobs := 2, failFast := True } defaultConfig) $ do
        describe "g1" $ itAsync "a" $ pure (1 `mustBe` 1)
        describe "g2" $ itAsync "b" $ pure (1 `mustBe` 1)
        describe "last" $ itAsync "boom" $ do
          sequence_ (replicate 10 cede)
          pure (1 `mustBe` 2)
      pure $ do
        hasAborted evs `mustBe` False
        (fst r).passed `mustBe` 2
        (fst r).failed `mustBe` 1

  describe "sequential path (jobs = 0)" $ do
    itIO "runs all tests" $ do
      s <- runSpecAsyncWithSummary $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
        it "c" $ 3 `mustBe` 3
      pure $ s.passed `mustBe` 3

    itIO "runs before setup for each test" $ do
      ref <- newIORef (the Nat 0)
      _ <- runSpecAsyncWithSummary $
        before (liftIO (modifyIORef ref (+ 1))) $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
      count <- readIORef ref
      pure $ count `mustBe` 2

    itIO "runs beforeAll setup exactly once" $ do
      ref <- newIORef (the Nat 0)
      _ <- runSpecAsyncWithSummary $
        beforeAll (liftIO (modifyIORef ref (+ 1))) $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
      count <- readIORef ref
      pure $ count `mustBe` 1

    itIO "fail-fast skips remaining groups without a SuiteAborted event" $ do
      (evs, r) <- runPool ({ failFast := True } defaultConfig) $ do
        describe "failing" $ itAsync "boom" $ pure (1 `mustBe` 2)
        describe "after" $ itAsync "never" $ pure (1 `mustBe` 1)
      pure $ do
        hasAborted evs `mustBe` False
        (fst r).failed `mustBe` 1
        (fst r).passed `mustBe` 0
