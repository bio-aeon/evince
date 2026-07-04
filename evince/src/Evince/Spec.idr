module Evince.Spec

import Language.Reflection
import Language.Reflection.TTImp
import Evince.Core

%language ElabReflection

||| Group related specs under a label.
export
describe : String -> Spec m a () -> Spec m a ()
describe label body = MkSpec [< Describe label (getSpecTrees body)] ()

||| Alias for `describe` - use with "when"/"with" phrasing.
export
context : String -> Spec m a () -> Spec m a ()
context = describe

||| Define a test case with pure expectations. The body is lazy, so it is
||| evaluated when the test runs, not when the spec is built.
export
it : Applicative m => String -> Lazy (TestResult ()) -> Spec m a ()
it label result = MkSpec [< It label Nothing (\_ => pure result)] ()

||| Define a test case with IO-based expectations.
export
itIO : HasIO m => String -> IO (TestResult ()) -> Spec m a ()
itIO label action = MkSpec [< It label Nothing (\_ => liftIO action)] ()

||| Define a test case that receives the resource.
export
itWith : Applicative m => String -> (a -> TestResult ()) -> Spec m a ()
itWith label f = MkSpec [< It label Nothing (\res => pure (f res))] ()

||| Define an IO test case that receives the resource.
export
itIOWith : HasIO m => String -> (a -> IO (TestResult ())) -> Spec m a ()
itIOWith label f = MkSpec [< It label Nothing (\res => liftIO (f res))] ()

||| Define a test with source location captured at the call site.
||| Pass a dummy quasiquoted value as the first argument:
|||   itLoc `(()) "test name" $ expectation
export
%macro
itLoc : Applicative m => TTImp -> String -> Lazy (TestResult ()) -> Elab (Spec m a ())
itLoc t label result = do
  let loc = fcToSrcLoc (getFC t)
  pure $ MkSpec [< It label (Just loc) (\_ => pure result)] ()

||| Define an IO test with source location captured at the call site.
|||   itIOLoc `(()) "test name" $ ioAction
export
%macro
itIOLoc : HasIO m => TTImp -> String -> IO (TestResult ()) -> Elab (Spec m a ())
itIOLoc t label action = do
  let loc = fcToSrcLoc (getFC t)
  pure $ MkSpec [< It label (Just loc) (\_ => liftIO action)] ()

||| Mark a test as pending - the body is ignored and not executed.
export
xit : String -> Lazy (TestResult ()) -> Spec m a ()
xit label _ = MkSpec [< Pending label Nothing] ()

||| Mark an IO test as pending - the body is ignored and not executed.
export
xitIO : String -> Lazy (IO (TestResult ())) -> Spec m a ()
xitIO label _ = MkSpec [< Pending label Nothing] ()

mutual
  -- Every test becomes a Pending node; cleanups are dropped (their setups
  -- will never run) and focus markers are ignored.
  pendTree : SpecTree m a -> List (SpecTree m a)
  pendTree (It label _ _)         = [Pending label Nothing]
  pendTree (Describe label cs)    = [Describe label (pendTrees cs)]
  pendTree (Pending label reason) = [Pending label reason]
  pendTree (Focused t)            = pendTree t
  pendTree (WithCleanup _ cs)     = pendTrees cs

  pendTrees : List (SpecTree m a) -> List (SpecTree m a)
  pendTrees []        = []
  pendTrees (t :: ts) = pendTree t ++ pendTrees ts

||| Mark an entire group as pending - every test in it is reported as
||| pending and nothing is executed.
export
xdescribe : String -> Spec m a () -> Spec m a ()
xdescribe label body = MkSpec [< Describe label (pendTrees (getSpecTrees body))] ()

||| Alias for `xdescribe`.
export
xcontext : String -> Spec m a () -> Spec m a ()
xcontext = xdescribe

||| Focus a test - when any focused specs exist, only focused ones run.
export
fit : Applicative m => String -> Lazy (TestResult ()) -> Spec m a ()
fit label result = MkSpec [< Focused (It label Nothing (\_ => pure result))] ()

||| Focus an entire group.
export
fdescribe : String -> Spec m a () -> Spec m a ()
fdescribe label body = MkSpec [< Focused (Describe label (getSpecTrees body))] ()

||| Alias for `fdescribe`.
export
fcontext : String -> Spec m a () -> Spec m a ()
fcontext = fdescribe

||| Focus every test in the given spec - composes with any test or group
||| combinator (`itIO`, `itAsync`, `describe`, ...).
export
focus : Spec m a () -> Spec m a ()
focus body = MkSpec (Lin <>< map Focused (getSpecTrees body)) ()
