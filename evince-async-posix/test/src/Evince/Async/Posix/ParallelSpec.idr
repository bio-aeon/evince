module Evince.Async.Posix.ParallelSpec

import Data.IORef
import System.Clock
import IO.Async
import IO.Async.Loop.Posix
import Evince
import Evince.Async.Posix

-- Disambiguate from Data.Linear.Ref1's deprecated newIORef, pulled in by IO.Async.
%hide Data.Linear.Ref1.newIORef

-- CPU-bound work: a triangular sum over a runtime bound.
spin : Integer -> Integer -> Integer
spin acc 0 = acc
spin acc n = spin (acc + n) (n - 1)

tri : Integer -> Integer
tri n = (n * (n + 1)) `div` 2

-- Four independent CPU-bound groups. The work sits behind `cede` inside an
-- `itAsync` body so it runs in the fiber at execution time (on a worker
-- thread), not eagerly at spec-build time; the bound `n` is supplied at
-- runtime so it can't be constant-folded.
cpuGroups : Integer -> Spec (Async Poll []) () ()
cpuGroups n = do
  describe "g1" $ itAsync "w" $ do cede; pure (spin 0 n `mustEqual` tri n)
  describe "g2" $ itAsync "w" $ do cede; pure (spin 0 n `mustEqual` tri n)
  describe "g3" $ itAsync "w" $ do cede; pure (spin 0 n `mustEqual` tri n)
  describe "g4" $ itAsync "w" $ do cede; pure (spin 0 n `mustEqual` tri n)

export
posixSpec : Spec IO () ()
posixSpec = describe "evince-async-posix" $ do
  describe "multi-threaded execution" $ do
    itIO "runs groups concurrently and collects all results" $ do
      let cfg = { jobs := 4 } defaultConfig
      s <- runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "group 1" $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
        describe "group 2" $ do
          it "c" $ 3 `mustBe` 3
          it "d" $ 4 `mustBe` 4
      pure $ s.passed `mustBe` 4

    itIO "runs an itAsync test body" $ do
      s <- runSpecAsyncWithSummary $
        itAsync "passes" $ pure (1 `mustBe` 1)
      pure $ s.passed `mustBe` 1

    itIO "runs beforeAll setup exactly once across parallel groups" $ do
      ref <- newIORef (the Nat 0)
      let cfg = { jobs := 4 } defaultConfig
      _ <- runSpecAsyncWithSummaryAndConfig cfg $ beforeAll (liftIO (modifyIORef ref (+ 1))) $ do
        describe "group 1" $ it "a" $ 1 `mustBe` 1
        describe "group 2" $ it "b" $ 2 `mustBe` 2
        describe "group 3" $ it "c" $ 3 `mustBe` 3
        describe "group 4" $ it "d" $ 4 `mustBe` 4
      count <- readIORef ref
      pure $ count `mustBe` 1

    itIO "transforms beforeAllWith resource exactly once across parallel groups" $ do
      counter <- newIORef (the Nat 0)
      let cfg = { jobs := 4 } defaultConfig
      _ <- runSpecAsyncWithSummaryAndConfig cfg $
        provide (pure (the Nat 5)) $
        beforeAllWith (\n => do liftIO (modifyIORef counter (+ 1)); pure (show n)) $ do
          describe "group 1" $ itIOWith "a" $ \s => pure $ s `mustBe` "5"
          describe "group 2" $ itIOWith "b" $ \s => pure $ s `mustBe` "5"
          describe "group 3" $ itIOWith "c" $ \s => pure $ s `mustBe` "5"
          describe "group 4" $ itIOWith "d" $ \s => pure $ s `mustBe` "5"
      count <- readIORef counter
      pure $ count `mustBe` 1

    itIO "runs CPU-bound groups correctly in parallel (timing shown)" $ do
      -- derive the work bound from a runtime clock read so it isn't folded
      seed <- clockTime Monotonic
      let n = 30000000 + toNano (timeDifference seed seed)
      t0   <- clockTime Monotonic
      sseq <- runSpecAsyncWithSummaryAndConfig ({ jobs := 0 } defaultConfig) (cpuGroups n)
      t1   <- clockTime Monotonic
      spar <- runSpecAsyncWithSummaryAndConfig ({ jobs := 4 } defaultConfig) (cpuGroups n)
      t2   <- clockTime Monotonic
      let tseq = toNano (timeDifference t1 t0) `div` 1000000
      let tpar = toNano (timeDifference t2 t1) `div` 1000000
      putStrLn "    [parallelism] serial=\{show tseq}ms  parallel=\{show tpar}ms"
      -- assert correctness (both runs produce all results); the printed times
      -- show the speedup, which is environment-dependent so not asserted here.
      pure $ do
        sseq.passed `mustBe` 4
        spar.passed `mustBe` 4
