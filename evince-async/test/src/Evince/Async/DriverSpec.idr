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
asyncLocSpec = itLoc `(()) "test" $ 1 `mustBe` 1

failingIOChain : TestResultT IO ()
failingIOChain = do
  ref <- newIORef (the Nat 0)
  modifyIORef ref (+ 1)
  n <- readIORef ref
  n `mustBe` 2

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
  describe "pending" $ do
    it "reports a skipped test as pending without running it" $ do
      s <- liftIO $ runSpecAsyncWithSummary $ do
        it "runs" $ 1 `mustBe` 1
        xit "pended" $ 1 `mustBe` 2
      s.passed `mustBe` 1
      s.pending `mustBe` 1

  describe "chained Async expectations" $ do
    it "stops at the first failing expectation and skips the later effects" $ do
      ref <- newIORef (the Nat 0)
      s <- liftIO $ runSpecAsyncWithSummary $
        it "chain" $ do
          lift cede
          modifyIORef ref (+ 1)
          1 `mustBe` 2
          modifyIORef ref (+ 1)
          1 `mustBe` 1
      ran <- readIORef ref
      s.failed `mustBe` 1
      ran `mustBe` 1

  describe "it under an Async spec" $ do
    it "chains expectations and an Async action" $ do
      ref <- newIORef (the Nat 0)
      s <- liftIO $ runSpecAsyncWithSummary $
        it "chain" $ do
          lift cede
          modifyIORef ref (+ 1)
          1 `mustBe` 1
          n <- readIORef ref
          n `mustBe` 1
      s.passed `mustBe` 1

    it "runs an IO chain as the test body" $ do
      s <- liftIO $ runSpecAsyncWithSummary $ it "lifted" failingIOChain
      s.failed `mustBe` 1

    it "runs an IO chain hoisted into an Async chain" $ do
      s <- liftIO $ runSpecAsyncWithSummary $
        it "mixed" $ do
          lift cede
          hoistIO failingIOChain
      s.failed `mustBe` 1

  describe "itLoc under an Async spec" $ do
    it "captures a source location" $
      mustBeJust (extractAsyncLoc asyncLocSpec)

    it "captured line is positive" $
      case extractAsyncLoc asyncLocSpec of
        Just loc => loc.line `mustSatisfy` (> 0)
        Nothing => mustFail "expected SrcLoc"

  describe "hoistSpec" $ do
    it "runs a hoisted Spec IO under the driver" $ do
      ref <- newIORef (the Nat 0)
      let ioSpec = it "io" $ do modifyIORef ref (+ 1); 1 `mustBe` 1
      s <- liftIO $ runSpecAsyncWithSummary (hoistSpec liftIO ioSpec)
      n <- readIORef ref
      s.passed `mustBe` 1
      n `mustBe` 1

  describe "concurrency (jobs > 0)" $ do
    it "collects results from more groups than workers" $ do
      let cfg = { jobs := 2 } defaultConfig
      s <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "g1" $ it "a" $ 1 `mustBe` 1
        describe "g2" $ it "b" $ 1 `mustBe` 1
        describe "g3" $ it "c" $ 1 `mustBe` 2
      s.passed `mustBe` 2
      s.failed `mustBe` 1

    it "starts the next group as soon as a slot frees" $ do
      ref <- newIORef (the (List String) [])
      let cfg = { jobs := 2 } defaultConfig
      _ <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "slow" $ it "s" $ do
          lift (sequence_ (replicate 50 cede))
          liftIO (modifyIORef ref ("slow-done" ::))
          1 `mustBe` 1
        describe "quick" $ it "q" $ 1 `mustBe` 1
        describe "late" $ it "l" $ do
          liftIO (modifyIORef ref ("late-start" ::))
          1 `mustBe` 1
      order <- readIORef ref
      reverse order `mustEqual` ["late-start", "slow-done"]

  describe "fail-fast cancellation (jobs > 0)" $ do
    it "cancels in-flight groups after the first failure" $ do
      ref <- newIORef False
      let cfg = { jobs := 2, failFast := True } defaultConfig
      s <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "failing" $ it "boom" $ do
          lift (sequence_ (replicate 10 cede))
          1 `mustBe` 2
        describe "slow" $ it "s" $ do
          lift (sequence_ (replicate 200 cede))
          liftIO (writeIORef ref True)
          1 `mustBe` 1
      done <- readIORef ref
      s.failed `mustBe` 1
      done `mustBe` False

    it "keeps results of groups completed before the failure" $ do
      let cfg = { jobs := 1, failFast := True } defaultConfig
      s <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "first" $ it "ok" $ 1 `mustBe` 1
        describe "second" $ it "boom" $ 1 `mustBe` 2
        describe "third" $ it "never" $ 1 `mustBe` 1
      s.passed `mustBe` 1
      s.failed `mustBe` 1

    it "emits SuiteAborted and flushes a cancelled group's partial output" $ do
      (evs, r) <- liftIO $ runPool ({ jobs := 2, failFast := True } defaultConfig) $ do
        describe "failing" $ it "boom" $ do
          lift (sequence_ (replicate 10 cede))
          1 `mustBe` 2
        describe "slow" $ do
          it "first" $ 1 `mustBe` 1
          it "long" $ do
            lift (sequence_ (replicate 200 cede))
            1 `mustBe` 1
      let doneNames = mapMaybe (\case TestDone rep _ => Just rep.path; _ => Nothing) evs
      hasAborted evs `mustBe` True
      doneNames `mustEqual` [["failing", "boom"], ["slow", "first"]]
      (fst r).passed `mustBe` 1
      (fst r).failed `mustBe` 1

    it "skips the aborted-run note when the failure cuts no work short" $ do
      (evs, r) <- liftIO $ runPool ({ jobs := 2, failFast := True } defaultConfig) $ do
        describe "g1" $ it "a" $ 1 `mustBe` 1
        describe "g2" $ it "b" $ 1 `mustBe` 1
        describe "last" $ it "boom" $ do
          lift (sequence_ (replicate 10 cede))
          1 `mustBe` 2
      hasAborted evs `mustBe` False
      (fst r).passed `mustBe` 2
      (fst r).failed `mustBe` 1

  describe "sequential path (jobs = 0)" $ do
    it "runs all tests" $ do
      s <- liftIO $ runSpecAsyncWithSummary $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
        it "c" $ 3 `mustBe` 3
      s.passed `mustBe` 3

    it "runs before setup for each test" $ do
      ref <- newIORef (the Nat 0)
      _ <- liftIO $ runSpecAsyncWithSummary $
        before (liftIO (modifyIORef ref (+ 1))) $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
      count <- readIORef ref
      count `mustBe` 2

    it "runs beforeAll setup exactly once" $ do
      ref <- newIORef (the Nat 0)
      _ <- liftIO $ runSpecAsyncWithSummary $
        beforeAll (liftIO (modifyIORef ref (+ 1))) $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
      count <- readIORef ref
      count `mustBe` 1

    it "fail-fast skips remaining groups without a SuiteAborted event" $ do
      (evs, r) <- liftIO $ runPool ({ failFast := True } defaultConfig) $ do
        describe "failing" $ it "boom" $ 1 `mustBe` 2
        describe "after" $ it "never" $ 1 `mustBe` 1
      hasAborted evs `mustBe` False
      (fst r).failed `mustBe` 1
      (fst r).passed `mustBe` 0
