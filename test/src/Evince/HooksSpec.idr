module Evince.HooksSpec

import Data.IORef
import Evince

export
hooksSpec : Spec ()
hooksSpec = describe "Hooks" $ do
  describe "before" $ do
    itIO "executes for each test" $ do
      ref <- newIORef (the Nat 0)
      s <- runSpecWithSummary $ before (modifyIORef ref (+ 1)) $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
      count <- readIORef ref
      pure $ count `mustBe` 2

  describe "after" $ do
    itIO "executes for each test" $ do
      ref <- newIORef (the Nat 0)
      s <- runSpecWithSummary $ after (modifyIORef ref (+ 1)) $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
      count <- readIORef ref
      pure $ count `mustBe` 2

  describe "around" $ do
    itIO "wraps each test with setup and teardown" $ do
      ref <- newIORef (the (List String) [])
      let wrapper = \test => do
            modifyIORef ref ("setup" ::)
            r <- test
            modifyIORef ref ("teardown" ::)
            pure r
      s <- runSpecWithSummary $ around wrapper $ do
        it "a" $ 1 `mustBe` 1
      events <- readIORef ref
      pure $ events `mustBe` ["teardown", "setup"]

  describe "beforeAll" $ do
    itIO "runs setup only once across multiple tests" $ do
      ref <- newIORef (the Nat 0)
      s <- runSpecWithSummary $ beforeAll (modifyIORef ref (+ 1)) $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
        it "c" $ 3 `mustBe` 3
      count <- readIORef ref
      pure $ count `mustBe` 1

  describe "afterAll" $ do
    itIO "runs cleanup after all tests finish" $ do
      ref <- newIORef False
      s <- runSpecWithSummary $ afterAll (writeIORef ref True) $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
      cleaned <- readIORef ref
      pure $ cleaned `mustBe` True
