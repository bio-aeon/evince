module Evince.Async.Spec

import Language.Reflection
import Language.Reflection.TTImp
import IO.Async
import Evince.Core

%language ElabReflection

||| Define a test case with an `Async` body, so the test can spawn
||| fibers, await, and use the full async toolkit.
export
itAsync : String -> Async e [] (TestResult ()) -> Spec (Async e []) a ()
itAsync label action = MkSpec [< It label Nothing (\_ => action)] ()

||| Define an `Async` test case that receives the group's resource.
export
itAsyncWith : String -> (a -> Async e [] (TestResult ())) -> Spec (Async e []) a ()
itAsyncWith label f = MkSpec [< It label Nothing f] ()

||| Mark an `Async` test as pending - the body is ignored and not executed.
export
xitAsync : String -> Lazy (Async e [] (TestResult ())) -> Spec (Async e []) a ()
xitAsync label _ = MkSpec [< Pending label Nothing] ()

||| Define an `Async` test with source location captured at the call site.
|||   itAsyncLoc `(()) "test name" $ asyncAction
export
%macro
itAsyncLoc : TTImp -> String -> Async e [] (TestResult ()) -> Elab (Spec (Async e []) a ())
itAsyncLoc t label action =
  pure $ MkSpec [< It label (Just (fcToSrcLoc (getFC t))) (\_ => action)] ()
