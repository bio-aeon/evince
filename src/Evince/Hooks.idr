module Evince.Hooks

import Data.IORef
import Data.SnocList
import Evince.Core

mutual
  mapTest : (IO (TestResult ()) -> IO (TestResult ())) -> SpecTree -> SpecTree
  mapTest f (It label test) = It label (f test)
  mapTest f (Describe label children) = Describe label (mapTests f children)
  mapTest f (Focused t) = Focused (mapTest f t)
  mapTest f (WithCleanup cleanup children) = WithCleanup cleanup (mapTests f children)
  mapTest f t = t

  mapTests : (IO (TestResult ()) -> IO (TestResult ())) -> List SpecTree -> List SpecTree
  mapTests f [] = []
  mapTests f (t :: ts) = mapTest f t :: mapTests f ts

||| Run an IO action before each test in the group.
export
before : IO () -> Spec () -> Spec ()
before setup body =
  let trees = mapTests (\test => setup >> test) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Run an IO action after each test in the group.
export
after : IO () -> Spec () -> Spec ()
after teardown body =
  let trees = mapTests (\test => do r <- test; teardown; pure r) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Wrap each test with a setup/teardown action. The wrapper receives the
||| test action and must call it.
export
around : (IO (TestResult ()) -> IO (TestResult ())) -> Spec () -> Spec ()
around wrapper body =
  let trees = mapTests wrapper (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Run an IO action once before the first test in the group.
||| Subsequent tests reuse the cached result.
export
beforeAll : IO () -> Spec () -> Spec ()
beforeAll setup body =
  let ref = unsafePerformIO (newIORef False)
      wrappedSetup = do
        done <- readIORef ref
        unless done $ do setup; writeIORef ref True
      trees = mapTests (\test => wrappedSetup >> test) (getSpecTrees body)
  in MkSpec (Lin <>< trees) ()

||| Run an IO action once after all tests in the group have finished.
export
afterAll : IO () -> Spec () -> Spec ()
afterAll cleanup body =
  MkSpec [< WithCleanup cleanup (getSpecTrees body)] ()
