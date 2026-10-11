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

||| Define a test case. The body chains expectations in the spec's own monad
||| `m`, or in `IO`, which is lifted into `m`; plain actions enter via
||| `lift`/`liftIO`. The body is evaluated when the test runs, not when the
||| spec is built.
export
it : Hoist n m => String -> Lazy (TestResultT n ()) -> Spec m a ()
it label body = MkSpec [< It label Nothing (\_ => runTestResultT (hoistChain body))] ()

||| Define a test case that receives the resource.
export
itWith : Hoist n m => String -> (a -> TestResultT n ()) -> Spec m a ()
itWith label f = MkSpec [< It label Nothing (runTestResultT . hoistChain . f)] ()

||| Define a test with source location captured at the call site.
||| Pass a dummy quasiquoted value as the first argument:
|||   itLoc `(()) "test name" $ expectation
export
%macro
itLoc : Hoist n m => TTImp -> String -> Lazy (TestResultT n ()) -> Elab (Spec m a ())
itLoc t label body = do
  let loc = fcToSrcLoc (getFC t)
  pure $ MkSpec [< It label (Just loc) (\_ => runTestResultT (hoistChain body))] ()

||| Mark a test as pending - the body is ignored and not executed.
export
xit : Hoist n m => String -> Lazy (TestResultT n ()) -> Spec m a ()
xit label _ = MkSpec [< Pending label Nothing] ()

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
fit : Hoist n m => String -> Lazy (TestResultT n ()) -> Spec m a ()
fit label body = MkSpec [< Focused (It label Nothing (\_ => runTestResultT (hoistChain body)))] ()

||| Focus an entire group.
export
fdescribe : String -> Spec m a () -> Spec m a ()
fdescribe label body = MkSpec [< Focused (Describe label (getSpecTrees body))] ()

||| Alias for `fdescribe`.
export
fcontext : String -> Spec m a () -> Spec m a ()
fcontext = fdescribe

||| Focus every test in the given spec - composes with any test or group
||| combinator (`it`, `itWith`, `describe`, ...).
export
focus : Spec m a () -> Spec m a ()
focus body = MkSpec (Lin <>< map Focused (getSpecTrees body)) ()
