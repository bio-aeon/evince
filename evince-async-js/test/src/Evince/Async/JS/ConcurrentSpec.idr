module Evince.Async.JS.ConcurrentSpec

import Data.IORef
import IO.Async
import IO.Async.JS
import Evince
import Evince.Async.JS

-- Disambiguate from Data.Linear.Ref1's deprecated newIORef, pulled in by IO.Async.
%hide Data.Linear.Ref1.newIORef

export
jsSpec : Spec IO () ()
jsSpec = describe "evince-async-js" $ do
  describe "JS event loop" $ do
    itIO "runs all tests sequentially (jobs = 0)" $ do
      s <- runSpecAsyncWithSummary $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
      pure $ s.passed `mustBe` 2

    itIO "runs an Async test body" $ do
      s <- runSpecAsyncWithSummary $
        itAsync "passes" $ pure (1 `mustBe` 1)
      pure $ s.passed `mustBe` 1

    itIO "runs groups concurrently and collects all results" $ do
      let cfg = { jobs := 2 } defaultConfig
      s <- runSpecAsyncWithSummaryAndConfig cfg $ do
        describe "group 1" $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
        describe "group 2" $ do
          it "c" $ 3 `mustBe` 3
          it "d" $ 4 `mustBe` 4
      pure $ s.passed `mustBe` 4

    itIO "runs beforeAll setup exactly once across concurrent groups" $ do
      ref <- newIORef (the Nat 0)
      let cfg = { jobs := 4 } defaultConfig
      _ <- runSpecAsyncWithSummaryAndConfig cfg $ beforeAll (liftIO (modifyIORef ref (+ 1))) $ do
        describe "group 1" $ do
          it "a" $ 1 `mustBe` 1
        describe "group 2" $ do
          it "b" $ 2 `mustBe` 2
        describe "group 3" $ do
          it "c" $ 3 `mustBe` 3
      count <- readIORef ref
      pure $ count `mustBe` 1
