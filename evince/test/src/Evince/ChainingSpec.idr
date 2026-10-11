module Evince.ChainingSpec

import Data.IORef
import Language.Reflection
import Evince

%language ElabReflection

crashIfEvaluated : TestResultT m ()
crashIfEvaluated = assert_total (idris_crash "body evaluated")

concreteChain : Spec IO () ()
concreteChain = it "chains expectations and an IO action" $ do
  ref <- newIORef (the Nat 0)
  modifyIORef ref (+ 1)
  1 `mustBe` 1
  n <- readIORef ref
  n `mustBe` 1

polyChain : HasIO m => Spec m () ()
polyChain = it "chains expectations and an IO action" $ do
  ref <- newIORef (the Nat 0)
  modifyIORef ref (+ 1)
  1 `mustBe` 1
  n <- readIORef ref
  n `mustBe` 1

hookedChains : Spec IO () ()
hookedChains = do
  before (pure ()) $
    it "runs under before" $ do
      1 `mustBe` 1
      2 `mustBe` 2
  provide (pure (the Nat 5)) $
    beforeWith (\n => pure (n + 1)) $
      itWith "runs under beforeWith and provide" $ \n => do
        n `mustBe` 6
        (n * 2) `mustBe` 12

pendedChain : Spec IO () ()
pendedChain = xdescribe "pended group" $
  it "never runs" $ do
    1 `mustBe` 1
    crashIfEvaluated

focusedChain : Spec IO () ()
focusedChain = focus $
  it "focused" $ do
    1 `mustBe` 1
    2 `mustBe` 2

-- itLoc must not end its do-block: a %macro there fails to elaborate.
locatedChain : Spec IO () ()
locatedChain = do
  itLoc `(()) "located" $ do
    ref <- newIORef (the Nat 0)
    modifyIORef ref (+ 1)
    1 `mustBe` 1
    n <- readIORef ref
    n `mustBe` 1
  it "plain" $ 1 `mustBe` 1

failingIOChain : TestResultT IO ()
failingIOChain = do
  ref <- newIORef (the Nat 0)
  modifyIORef ref (+ 1)
  n <- readIORef ref
  n `mustBe` 2

liftedChain : HasIO m => Spec m () ()
liftedChain = it "lifted" failingIOChain

export
chainingSpec : Spec IO () ()
chainingSpec = describe "chained expectations" $ do
  it "stops at the first failing expectation and skips the later effects" $ do
    counter <- newIORef (the Nat 0)
    let tick : Nat -> IO Nat
        tick val = do modifyIORef counter (+ 1); pure val
    s <- liftIO $ runSpecWithSummary $
      it "chain" $ do
        tick 1 `mustReturn` 1
        tick 2 `mustReturn` 99
        tick 3 `mustReturn` 3
    ran <- readIORef counter
    s.failed `mustBe` 1
    ran `mustBe` 2

  it "stops at a pending expectation and reports the test pending" $ do
    counter <- newIORef (the Nat 0)
    s <- liftIO $ runSpecWithSummary $
      it "chain" $ do
        modifyIORef counter (+ 1)
        pending
        modifyIORef counter (+ 1)
    ran <- readIORef counter
    s.pending `mustBe` 1
    s.failed `mustBe` 0
    ran `mustBe` 1

  it "runs a mixed chain of lifted actions and expectations to completion" $ do
    account  <- newIORef (the Nat 100)
    auditLog <- newIORef (the (List String) [])
    let withdraw : Nat -> IO Nat
        withdraw amt = do modifyIORef account (`minus` amt); readIORef account
    s <- liftIO $ runSpecWithSummary $
      it "chain" $ do
        lift $ modifyIORef auditLog ("withdraw" ::)
        withdraw 30 `mustReturn` 70
        balance <- liftIO (readIORef account)
        balance `mustBe` 70
    log <- readIORef auditLog
    s.passed `mustBe` 1
    log `mustBe` ["withdraw"]

  describe "in every it position" $ do
    it "under a concrete IO spec" $ do
      s <- liftIO $ runSpecWithSummary concreteChain
      s.passed `mustBe` 1

    it "under a polymorphic spec run as IO" $ do
      s <- liftIO $ runSpecWithSummary polyChain
      s.passed `mustBe` 1

    it "under before, beforeWith and provide" $ do
      s <- liftIO $ runSpecWithSummary hookedChains
      s.passed `mustBe` 2

    it "inside xdescribe, without evaluating the body" $ do
      s <- liftIO $ runSpecWithSummary pendedChain
      s.pending `mustBe` 1

    it "inside focus" $ do
      s <- liftIO $ runSpecWithSummary focusedChain
      s.passed `mustBe` 1

    it "as itLoc" $ do
      s <- liftIO $ runSpecWithSummary locatedChain
      s.passed `mustBe` 2

    it "as an IO chain in a polymorphic spec" $ do
      s <- liftIO $ runSpecWithSummary liftedChain
      s.failed `mustBe` 1

  describe "it" $
    it "does not evaluate its body when the spec is built" $ do
      let spec : Spec IO () ()
          spec = it "deferred" crashIfEvaluated
      length (getSpecTrees spec) `mustBe` 1
