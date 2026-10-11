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
    it "runs all tests sequentially (jobs = 0)" $ do
      s <- liftIO $ runSpecAsyncWithSummary $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
      s.passed `mustBe` 2

    it "runs an Async test body" $ do
      s <- liftIO $ runSpecAsyncWithSummary $
        it "passes" $ do lift cede; 1 `mustBe` 1
      s.passed `mustBe` 1

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

    it "runs beforeAll setup exactly once across concurrent groups" $ do
      ref <- newIORef (the Nat 0)
      let cfg = { jobs := 4 } defaultConfig
      _ <- liftIO $ runSpecAsyncWithSummaryAndConfig cfg $ beforeAll (liftIO (modifyIORef ref (+ 1))) $ do
        describe "group 1" $ do
          it "a" $ 1 `mustBe` 1
        describe "group 2" $ do
          it "b" $ 2 `mustBe` 2
        describe "group 3" $ do
          it "c" $ 3 `mustBe` 3
      count <- readIORef ref
      count `mustBe` 1
