module Evince.HooksSpec

import Data.IORef
import Evince

logged : HasIO m => IORef (List String) -> m a -> m a
logged ref test = do
  modifyIORef ref ("setup" ::)
  r <- test
  modifyIORef ref ("teardown" ::)
  pure r

export
hooksSpec : Spec IO () ()
hooksSpec = describe "Hooks" $ do
  describe "before" $ do
    it "executes for each test" $ do
      ref <- newIORef (the Nat 0)
      s <- liftIO $ runSpecWithSummary $ before (modifyIORef ref (+ 1)) $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
      count <- readIORef ref
      count `mustBe` 2

  describe "after" $ do
    it "executes for each test" $ do
      ref <- newIORef (the Nat 0)
      s <- liftIO $ runSpecWithSummary $ after (modifyIORef ref (+ 1)) $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
      count <- readIORef ref
      count `mustBe` 2

  describe "around" $ do
    it "wraps each test with setup and teardown" $ do
      ref <- newIORef []
      s <- liftIO $ runSpecWithSummary $ around (logged ref) $ do
        it "a" $ 1 `mustBe` 1
      events <- readIORef ref
      events `mustBe` ["teardown", "setup"]

    it "runs teardown even when the wrapped test fails" $ do
      ref <- newIORef []
      s <- liftIO $ runSpecWithSummary $ around (logged ref) $ do
        it "a" $ 1 `mustBe` 2
      events <- readIORef ref
      s.failed `mustBe` 1
      events `mustBe` ["teardown", "setup"]

  describe "aroundWith" $ do
    it "runs teardown even when the wrapped test fails" $ do
      ref <- newIORef []
      s <- liftIO $ runSpecWithSummary $
        provide (pure (the Nat 1)) $
        aroundWith (\test => logged ref . test) $ do
          itWith "a" $ \n => n `mustBe` 2
      events <- readIORef ref
      s.failed `mustBe` 1
      events `mustBe` ["teardown", "setup"]

  describe "beforeAll" $ do
    it "runs setup only once across multiple tests" $ do
      ref <- newIORef (the Nat 0)
      s <- liftIO $ runSpecWithSummary $ beforeAll (modifyIORef ref (+ 1)) $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
        it "c" $ 3 `mustBe` 3
      count <- readIORef ref
      count `mustBe` 1

    it "keeps setups independent across sibling groups" $ do
      c1 <- newIORef (the Nat 0)
      c2 <- newIORef (the Nat 0)
      _ <- liftIO $ runSpecWithSummary $ do
        beforeAll (modifyIORef c1 (+ 1)) $ describe "g1" $ it "a" $ 1 `mustBe` 1
        beforeAll (modifyIORef c2 (+ 1)) $ describe "g2" $ it "b" $ 2 `mustBe` 2
      n1 <- readIORef c1
      n2 <- readIORef c2
      n1 `mustBe` 1
      n2 `mustBe` 1

  describe "afterAll" $ do
    it "runs cleanup after all tests finish" $ do
      ref <- newIORef False
      s <- liftIO $ runSpecWithSummary $ afterAll (writeIORef ref True) $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
      cleaned <- readIORef ref
      cleaned `mustBe` True

  describe "provide" $ do
    it "threads the resource into each test" $ do
      ref <- newIORef []
      s <- liftIO $ runSpecWithSummary $ provide (pure (the Nat 42)) $ do
        itWith "a" $ \n => do
          modifyIORef ref (n ::)
          n `mustBe` 42
      vals <- readIORef ref
      vals `mustBe` [42]

  describe "beforeWith" $ do
    it "transforms resource type" $ do
      ref <- newIORef []
      s <- liftIO $ runSpecWithSummary $
        provide (pure (the Nat 10)) $
        beforeWith (\n => pure (show n)) $ do
          itWith "a" $ \s => do
            modifyIORef ref (s ::)
            s `mustBe` "10"
      vals <- readIORef ref
      vals `mustBe` ["10"]

  describe "afterWith" $ do
    it "runs cleanup with access to resource" $ do
      ref <- newIORef []
      s <- liftIO $ runSpecWithSummary $
        provide (pure (the Nat 7)) $
        afterWith (\n => modifyIORef ref (n ::)) $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
      vals <- readIORef ref
      vals `mustBe` [7, 7]

  describe "beforeAllWith" $ do
    it "transforms resource once and caches" $ do
      counter <- newIORef (the Nat 0)
      s <- liftIO $ runSpecWithSummary $
        provide (pure (the Nat 5)) $
        beforeAllWith (\n => do modifyIORef counter (+ 1); pure (show n)) $ do
          itWith "a" $ \s => s `mustBe` "5"
          itWith "b" $ \s => s `mustBe` "5"
      count <- readIORef counter
      count `mustBe` 1
