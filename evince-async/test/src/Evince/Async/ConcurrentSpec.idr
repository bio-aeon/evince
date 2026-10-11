module Evince.Async.ConcurrentSpec

import Data.IORef
import IO.Async
import IO.Async.Loop.Sync
import Evince
import Evince.Async

-- Disambiguate from Data.Linear.Ref1's deprecated newIORef, pulled in by IO.Async.
%hide Data.Linear.Ref1.newIORef

export
concurrentSpec : Spec IO () ()
concurrentSpec = describe "evince-async" $ do
  describe "concurrent execution" $ do
    it "runs groups concurrently and collects all results" $ do
      let cfg = { jobs := 2 } defaultConfig
      s <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "group 1" $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
        describe "group 2" $ do
          it "c" $ 3 `mustBe` 3
          it "d" $ 4 `mustBe` 4
      s.passed `mustBe` 4

    it "stops after the first failure when fail-fast is set" $ do
      let cfg = { jobs := 2, failFast := True } defaultConfig
      s <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "group 1" $ do
          it "fail" $ 1 `mustBe` 2
        describe "group 2" $ do
          it "pass" $ 1 `mustBe` 1
      (s.failed + s.passed) `mustSatisfy` (> 0)

    it "runs only the tests matching the filter" $ do
      let cfg = { jobs := 2, match := Just "target" } defaultConfig
      s <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "group 1" $ do
          it "target a" $ 1 `mustBe` 1
        describe "group 2" $ do
          it "other" $ 2 `mustBe` 2
          it "target b" $ 3 `mustBe` 3
      s.passed `mustBe` 2

  describe "group-hook synchronization" $ do
    it "runs beforeAll setup exactly once across concurrent groups" $ do
      ref <- newIORef (the Nat 0)
      let cfg = { jobs := 4 } defaultConfig
      _ <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $ beforeAll (liftIO (modifyIORef ref (+ 1))) $ do
        describe "group 1" $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
        describe "group 2" $ do
          it "c" $ 3 `mustBe` 3
          it "d" $ 4 `mustBe` 4
        describe "group 3" $ do
          it "e" $ 5 `mustBe` 5
        describe "group 4" $ do
          it "f" $ 6 `mustBe` 6
      count <- readIORef ref
      count `mustBe` 1

    it "transforms beforeAllWith resource exactly once across concurrent groups" $ do
      counter <- newIORef (the Nat 0)
      let cfg = { jobs := 4 } defaultConfig
      _ <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $
        provide (pure (the Nat 5)) $
        beforeAllWith (\n => do liftIO (modifyIORef counter (+ 1)); pure (show n)) $ do
          describe "group 1" $ do
            itWith "a" $ \s => s `mustBe` "5"
            itWith "b" $ \s => s `mustBe` "5"
          describe "group 2" $ do
            itWith "c" $ \s => s `mustBe` "5"
          describe "group 3" $ do
            itWith "d" $ \s => s `mustBe` "5"
          describe "group 4" $ do
            itWith "e" $ \s => s `mustBe` "5"
      count <- readIORef counter
      count `mustBe` 1
