module Evince.Async.Posix.ParallelSpec

import Data.IORef
import Data.List
import System
import System.Clock
import IO.Async
import IO.Async.Loop.Posix
import Evince
import Evince.Report
import Evince.Async.Posix

-- Disambiguate from Data.Linear.Ref1's deprecated newIORef, pulled in by IO.Async.
%hide Data.Linear.Ref1.newIORef

-- CPU-bound work: a triangular sum over a runtime bound.
spin : Integer -> Integer -> Integer
spin acc 0 = acc
spin acc n = spin (acc + n) (n - 1)

tri : Integer -> Integer
tri n = (n * (n + 1)) `div` 2

-- The bound `n` is supplied at runtime so it can't be constant-folded.
cpuGroups : Integer -> Spec (Async Poll []) () ()
cpuGroups n = do
  describe "g1" $ it "w" $ spin 0 n `mustEqual` tri n
  describe "g2" $ it "w" $ spin 0 n `mustEqual` tri n
  describe "g3" $ it "w" $ spin 0 n `mustEqual` tri n
  describe "g4" $ it "w" $ spin 0 n `mustEqual` tri n

-- Drive the worker pool directly on the posix loop, discarding reporter output.
runPoolPosix : RunConfig -> Spec (Async Poll []) () () -> IO EvalResult
runPoolPosix cfg spec = do
  out <- newIORef Nothing
  simpleApp $ do
    lock     <- liftIO newLock
    abortRef <- liftIO (newIORef False)
    let silent = MkReporter (\_ => pure ())
    r <- evalAsyncForest silent lock cfg abortRef (getSpecTrees spec)
    liftIO (writeIORef out (Just r))
  Just r <- readIORef out
    | Nothing => die "evince-async-posix-test: the event loop ended before the pool returned"
  pure r

-- One failing group plus four quick passing groups; the per-iteration `cede`
-- jitter sweeps different cancellation interleavings.
soakSpec : Nat -> Spec (Async Poll []) () ()
soakSpec i = do
  describe "boom" $ do
    it "pre" $ 1 `mustBe` 1
    it "fail" $ do
      lift $ sequence_ (replicate (i `mod` 5) cede)
      1 `mustBe` 2
  for_ [1 .. 4] $ \g =>
    describe "g\{show g}" $
      for_ [1 .. 4] $ \t =>
        it "t\{show t}" $ do
          lift $ sequence_ (replicate ((g + t + i) `mod` 4) cede)
          1 `mustBe` 1

export
posixSpec : Spec IO () ()
posixSpec = describe "evince-async-posix" $ do
  describe "fail-fast cancellation soak" $ do
    it "reports each test at most once across repeated cancelled runs" $ do
      results <- liftIO $ for [0 .. 24] $ \i => do
        r <- runPoolPosix ({ jobs := 4, failFast := True } defaultConfig) (soakSpec i)
        let paths = map (.path) (snd r <>> [])
        pure (i, (fst r).failed, length paths `minus` length (nub paths))
      let bad = filter (\(_, f, dups) => f /= 1 || dups /= 0) results
      bad `mustEqual` []

  describe "multi-threaded execution" $ do
    it "runs groups concurrently and collects all results" $ do
      let cfg = { jobs := 4 } defaultConfig
      s <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "group 1" $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
        describe "group 2" $ do
          it "c" $ 3 `mustBe` 3
          it "d" $ 4 `mustBe` 4
      s.passed `mustBe` 4

    it "runs an Async test body" $ do
      s <- liftIO $ runSpecAsyncWithSummary $
        it "passes" $ do lift cede; 1 `mustBe` 1
      s.passed `mustBe` 1

    it "runs beforeAll setup exactly once across parallel groups" $ do
      ref <- newIORef (the Nat 0)
      let cfg = { jobs := 4 } defaultConfig
      _ <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $ beforeAll (liftIO (modifyIORef ref (+ 1))) $ do
        describe "group 1" $ it "a" $ 1 `mustBe` 1
        describe "group 2" $ it "b" $ 2 `mustBe` 2
        describe "group 3" $ it "c" $ 3 `mustBe` 3
        describe "group 4" $ it "d" $ 4 `mustBe` 4
      count <- readIORef ref
      count `mustBe` 1

    it "transforms beforeAllWith resource exactly once across parallel groups" $ do
      counter <- newIORef (the Nat 0)
      let cfg = { jobs := 4 } defaultConfig
      _ <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $
        provide (pure (the Nat 5)) $
        beforeAllWith (\n => do liftIO (modifyIORef counter (+ 1)); pure (show n)) $ do
          describe "group 1" $ itWith "a" $ \s => s `mustBe` "5"
          describe "group 2" $ itWith "b" $ \s => s `mustBe` "5"
          describe "group 3" $ itWith "c" $ \s => s `mustBe` "5"
          describe "group 4" $ itWith "d" $ \s => s `mustBe` "5"
      count <- readIORef counter
      count `mustBe` 1

    it "runs CPU-bound groups correctly in parallel (timing shown)" $ do
      -- derive the work bound from a runtime clock read so it isn't folded
      seed <- liftIO $ clockTime Monotonic
      let n = 30000000 + toNano (timeDifference seed seed)
      t0   <- liftIO $ clockTime Monotonic
      sseq <- liftIO $ runSpecAsyncWithSummaryAndConfig ({ jobs := 0 } defaultConfig) (cpuGroups n)
      t1   <- liftIO $ clockTime Monotonic
      spar <- liftIO $ runSpecAsyncWithSummaryAndConfig ({ jobs := 4 } defaultConfig) (cpuGroups n)
      t2   <- liftIO $ clockTime Monotonic
      let tseq = toNano (timeDifference t1 t0) `div` 1000000
      let tpar = toNano (timeDifference t2 t1) `div` 1000000
      putStrLn "    [parallelism] serial=\{show tseq}ms  parallel=\{show tpar}ms"
      -- The speedup is environment-dependent, so only correctness is asserted.
      sseq.passed `mustBe` 4
      spar.passed `mustBe` 4
