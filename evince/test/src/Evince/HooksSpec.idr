module Evince.HooksSpec

import Data.IORef
import Evince

export
hooksSpec : Spec () ()
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

  describe "provide" $ do
    itIO "threads resource into tests via itIOWith" $ do
      ref <- newIORef (the (List Nat) [])
      s <- runSpecWithSummary $ provide (pure (the Nat 42)) $ do
        itIOWith "a" $ \n => do
          modifyIORef ref (n ::)
          pure $ n `mustBe` 42
      vals <- readIORef ref
      pure $ vals `mustBe` [42]

  describe "beforeWith" $ do
    itIO "transforms resource type" $ do
      ref <- newIORef (the (List String) [])
      s <- runSpecWithSummary $
        provide (pure (the Nat 10)) $
        beforeWith (\n => pure (show n)) $ do
          itIOWith "a" $ \s => do
            modifyIORef ref (s ::)
            pure $ s `mustBe` "10"
      vals <- readIORef ref
      pure $ vals `mustBe` ["10"]

  describe "afterWith" $ do
    itIO "runs cleanup with access to resource" $ do
      ref <- newIORef (the (List Nat) [])
      s <- runSpecWithSummary $
        provide (pure (the Nat 7)) $
        afterWith (\n => modifyIORef ref (n ::)) $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
      vals <- readIORef ref
      pure $ vals `mustBe` [7, 7]

  describe "beforeAllWith" $ do
    itIO "transforms resource once and caches" $ do
      counter <- newIORef (the Nat 0)
      s <- runSpecWithSummary $
        provide (pure (the Nat 5)) $
        beforeAllWith (\n => do modifyIORef counter (+ 1); pure (show n)) $ do
          itIOWith "a" $ \s => pure $ s `mustBe` "5"
          itIOWith "b" $ \s => pure $ s `mustBe` "5"
      count <- readIORef counter
      pure $ count `mustBe` 1
