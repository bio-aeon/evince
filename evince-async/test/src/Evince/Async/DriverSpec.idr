module Evince.Async.DriverSpec

import Data.IORef
import Language.Reflection
import IO.Async
import IO.Async.Loop.Sync
import Evince
import Evince.Async

%language ElabReflection

-- Disambiguate from Data.Linear.Ref1's deprecated newIORef, pulled in by IO.Async.
%hide Data.Linear.Ref1.newIORef

extractAsyncLoc : Spec (Async SyncST []) () () -> Maybe SrcLoc
extractAsyncLoc spec = case getSpecTrees spec of
  [It _ loc _] => loc
  _ => Nothing

asyncLocSpec : Spec (Async SyncST []) () ()
asyncLocSpec = itAsyncLoc `(()) "test" $ pure (1 `mustBe` 1)

export
driverSpec : Spec IO () ()
driverSpec = describe "async driver" $ do
  describe "itAsync" $ do
    itIO "runs an Async test body" $ do
      s <- runSpecAsyncWithSummary $
        itAsync "passes" $ pure (1 `mustBe` 1)
      pure $ s.passed `mustBe` 1

    itIO "reports a failing Async test body" $ do
      s <- runSpecAsyncWithSummary $
        itAsync "fails" $ pure (1 `mustBe` 2)
      pure $ s.failed `mustBe` 1

    itIO "xitAsync marks the test pending without running it" $ do
      s <- runSpecAsyncWithSummary $ do
        itAsync "runs" $ pure (1 `mustBe` 1)
        xitAsync "pended" $ pure (1 `mustBe` 2)
      pure $ do
        s.passed `mustBe` 1
        s.pending `mustBe` 1

  describe "itAsyncLoc" $ do
    it "captures a source location" $
      mustBeJust (extractAsyncLoc asyncLocSpec)

    it "captured line is positive" $
      case extractAsyncLoc asyncLocSpec of
        Just loc => loc.line `mustSatisfy` (> 0)
        Nothing => mustFail "expected SrcLoc"

  describe "hoistSpec" $ do
    itIO "runs a hoisted Spec IO under the driver" $ do
      ref <- newIORef (the Nat 0)
      let ioSpec = itIO "io" $ do modifyIORef ref (+ 1); pure (1 `mustBe` 1)
      s <- runSpecAsyncWithSummary (hoistSpec liftIO ioSpec)
      n <- readIORef ref
      pure $ do
        s.passed `mustBe` 1
        n `mustBe` 1

  describe "sequential path (jobs = 0)" $ do
    itIO "runs all tests" $ do
      s <- runSpecAsyncWithSummary $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
        it "c" $ 3 `mustBe` 3
      pure $ s.passed `mustBe` 3

    itIO "runs before setup for each test" $ do
      ref <- newIORef (the Nat 0)
      _ <- runSpecAsyncWithSummary $
        before (liftIO (modifyIORef ref (+ 1))) $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
      count <- readIORef ref
      pure $ count `mustBe` 2

    itIO "runs beforeAll setup exactly once" $ do
      ref <- newIORef (the Nat 0)
      _ <- runSpecAsyncWithSummary $
        beforeAll (liftIO (modifyIORef ref (+ 1))) $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
      count <- readIORef ref
      pure $ count `mustBe` 1
