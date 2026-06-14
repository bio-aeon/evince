module Evince.Hooks

import Data.IORef
import Data.Linear.Ref1
import Data.SnocList
import public Evince.Synchronized
import Evince.Core

-- The lock cell is a Data.Linear.Ref1 ref (`newref`); the done-flag stays a
-- base Data.IORef. Hide Ref1's deprecated newIORef so it doesn't clash.
%hide Data.Linear.Ref1.newIORef

-- Transform every It node's test action. Most general tree walker:
-- changes resource type and wraps the action in one pass.
mutual
  mapTree : ((a -> m (TestResult ())) -> b -> m (TestResult ())) -> SpecTree m a -> SpecTree m b
  mapTree f (It label loc test) = It label loc (f test)
  mapTree f (Describe label children) = Describe label (mapTrees f children)
  mapTree f (Focused t) = Focused (mapTree f t)
  mapTree f (WithCleanup cleanup children) = WithCleanup cleanup (mapTrees f children)
  mapTree f (Pending label reason) = Pending label reason

  mapTrees : ((a -> m (TestResult ())) -> b -> m (TestResult ())) -> List (SpecTree m a) -> List (SpecTree m b)
  mapTrees f [] = []
  mapTrees f (t :: ts) = mapTree f t :: mapTrees f ts

||| Run an action before each test in the group.
export
before : Monad m => m () -> Spec m a () -> Spec m a ()
before setup body =
  let trees = mapTrees (\test, res => setup >> test res) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Run an action after each test in the group.
export
after : Monad m => m () -> Spec m a () -> Spec m a ()
after teardown body =
  let trees = mapTrees (\test, res => do r <- test res; teardown; pure r) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Wrap each test with a setup/teardown action. The wrapper receives the
||| test action and must call it.
export
around : (m (TestResult ()) -> m (TestResult ())) -> Spec m a () -> Spec m a ()
around wrapper body =
  let trees = mapTrees (\test, res => wrapper (test res)) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Run an action once before the first test in the group.
||| Subsequent tests reuse the cached result.
export
beforeAll : {m : Type -> Type} -> (Synchronized m, HasIO m) => m () -> Spec m a () -> Spec m a ()
beforeAll setup body =
  let ref  = unsafePerformIO (newIORef False)
      lock = unsafePerformIO (newref False)
      wrappedSetup = withLock lock $ do
        done <- liftIO (readIORef ref)
        unless done $ do setup; liftIO (writeIORef ref True)
      trees = mapTrees (\test, res => wrappedSetup >> test res) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Run an action once after all tests in the group have finished.
export
afterAll : m () -> Spec m a () -> Spec m a ()
afterAll cleanup body =
  MkSpec [< WithCleanup cleanup (getSpecTrees body)] ()

||| Transform the resource type. Runs `f` before each test to produce the
||| inner resource from the outer one.
export
beforeWith : Monad m => (outer -> m inner) -> Spec m inner () -> Spec m outer ()
beforeWith f body =
  let trees = mapTrees (\test, o => f o >>= test) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Most general hook: transform both the resource type and wrap the test action.
export
aroundWith : ((inner -> m (TestResult ())) -> outer -> m (TestResult ())) -> Spec m inner () -> Spec m outer ()
aroundWith f body =
  let trees = mapTrees f (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Run a cleanup action that has access to the resource after each test.
export
afterWith : Monad m => (a -> m ()) -> Spec m a () -> Spec m a ()
afterWith teardown body =
  let trees = mapTrees (\test, res => do r <- test res; teardown res; pure r) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Transform the resource type once for the entire group. Runs `f` once on
||| the first test and caches the result for subsequent tests.
export
beforeAllWith : {m : Type -> Type} -> (Synchronized m, HasIO m) => (outer -> m inner) -> Spec m inner () -> Spec m outer ()
beforeAllWith f body =
  let ref  = unsafePerformIO (newIORef (the (Maybe inner) Nothing))
      lock = unsafePerformIO (newref False)
      cachedF = \o => withLock lock $ do
        cached <- liftIO (readIORef ref)
        case cached of
          Just val => pure val
          Nothing => do val <- f o; liftIO (writeIORef ref (Just val)); pure val
      trees = mapTrees (\test, o => cachedF o >>= test) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Convenience: produce a resource from nothing and thread it into tests.
export
provide : Monad m => m a -> Spec m a () -> Spec m () ()
provide setup = beforeWith (\() => setup)
