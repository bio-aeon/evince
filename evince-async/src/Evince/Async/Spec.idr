module Evince.Async.Spec

import IO.Async
import Evince.Core

||| Define a test case with an `Async` body, so the test can spawn
||| fibers, await, and use the full async toolkit.
export
itAsync : String -> Async e [] (TestResult ()) -> Spec (Async e []) a ()
itAsync label action = MkSpec [< It label Nothing (\_ => action)] ()

||| Define an `Async` test case that receives the group's resource.
export
itAsyncWith : String -> (a -> Async e [] (TestResult ())) -> Spec (Async e []) a ()
itAsyncWith label f = MkSpec [< It label Nothing f] ()
