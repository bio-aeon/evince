module Evince.Hooks

import Data.IORef
import Data.SnocList
import System.Concurrency
import Evince.Core

-- Transform every It node's test action. Most general tree walker:
-- changes resource type and wraps the action in one pass.
mutual
  mapTree : ((a -> IO (TestResult ())) -> b -> IO (TestResult ())) -> SpecTree a -> SpecTree b
  mapTree f (It label loc test) = It label loc (f test)
  mapTree f (Describe label children) = Describe label (mapTrees f children)
  mapTree f (Focused t) = Focused (mapTree f t)
  mapTree f (WithCleanup cleanup children) = WithCleanup cleanup (mapTrees f children)
  mapTree f (Pending label reason) = Pending label reason

  mapTrees : ((a -> IO (TestResult ())) -> b -> IO (TestResult ())) -> List (SpecTree a) -> List (SpecTree b)
  mapTrees f [] = []
  mapTrees f (t :: ts) = mapTree f t :: mapTrees f ts

||| Run an IO action before each test in the group.
export
before : IO () -> Spec a () -> Spec a ()
before setup body =
  let trees = mapTrees (\test, res => setup >> test res) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Run an IO action after each test in the group.
export
after : IO () -> Spec a () -> Spec a ()
after teardown body =
  let trees = mapTrees (\test, res => do r <- test res; teardown; pure r) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Wrap each test with a setup/teardown action. The wrapper receives the
||| test action and must call it.
export
around : (IO (TestResult ()) -> IO (TestResult ())) -> Spec a () -> Spec a ()
around wrapper body =
  let trees = mapTrees (\test, res => wrapper (test res)) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Run an IO action once before the first test in the group.
||| Subsequent tests reuse the cached result.
export
beforeAll : IO () -> Spec a () -> Spec a ()
beforeAll setup body =
  let ref = unsafePerformIO (newIORef False)
      mtx = unsafePerformIO makeMutex
      wrappedSetup = do
        mutexAcquire mtx
        done <- readIORef ref
        unless done $ do setup; writeIORef ref True
        mutexRelease mtx
      trees = mapTrees (\test, res => wrappedSetup >> test res) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Run an IO action once after all tests in the group have finished.
export
afterAll : IO () -> Spec a () -> Spec a ()
afterAll cleanup body =
  MkSpec [< WithCleanup cleanup (getSpecTrees body)] ()

||| Transform the resource type. Runs `f` before each test to produce the
||| inner resource from the outer one.
export
beforeWith : (outer -> IO inner) -> Spec inner () -> Spec outer ()
beforeWith f body =
  let trees = mapTrees (\test, o => f o >>= test) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Most general hook: transform both the resource type and wrap the test action.
export
aroundWith : ((inner -> IO (TestResult ())) -> outer -> IO (TestResult ())) -> Spec inner () -> Spec outer ()
aroundWith f body =
  let trees = mapTrees f (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Run a cleanup action that has access to the resource after each test.
export
afterWith : (a -> IO ()) -> Spec a () -> Spec a ()
afterWith teardown body =
  let trees = mapTrees (\test, res => do r <- test res; teardown res; pure r) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Transform the resource type once for the entire group. Runs `f` once on
||| the first test and caches the result for subsequent tests.
export
beforeAllWith : (outer -> IO inner) -> Spec inner () -> Spec outer ()
beforeAllWith f body =
  let ref : IORef (Maybe inner) = unsafePerformIO (newIORef Nothing)
      mtx = unsafePerformIO makeMutex
      cachedF = \o => do
        mutexAcquire mtx
        cached <- readIORef ref
        val <- case cached of
          Just val => pure val
          Nothing => do val <- f o; writeIORef ref (Just val); pure val
        mutexRelease mtx
        pure val
      trees = mapTrees (\test, o => cachedF o >>= test) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Convenience: produce a resource from nothing and thread it into tests.
export
provide : IO a -> Spec a () -> Spec () ()
provide setup = beforeWith (\() => setup)
