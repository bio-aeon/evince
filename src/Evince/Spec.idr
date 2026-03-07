module Evince.Spec

import Evince.Core

||| Group related specs under a label.
export
describe : String -> Spec a () -> Spec a ()
describe label body = MkSpec [< Describe label (getSpecTrees body)] ()

||| Alias for `describe` — use with "when"/"with" phrasing.
export
context : String -> Spec a () -> Spec a ()
context = describe

||| Define a test case with pure expectations.
export
it : String -> TestResult () -> Spec a ()
it label result = MkSpec [< It label (\_ => pure result)] ()

||| Define a test case with IO-based expectations.
export
itIO : String -> IO (TestResult ()) -> Spec a ()
itIO label action = MkSpec [< It label (\_ => action)] ()

||| Define a test case that receives the resource.
export
itWith : String -> (a -> TestResult ()) -> Spec a ()
itWith label f = MkSpec [< It label (\res => pure (f res))] ()

||| Define an IO test case that receives the resource.
export
itIOWith : String -> (a -> IO (TestResult ())) -> Spec a ()
itIOWith label f = MkSpec [< It label f] ()

||| Mark a test as pending — the body is ignored and not executed.
export
xit : String -> TestResult () -> Spec a ()
xit label _ = MkSpec [< Pending label Nothing] ()

||| Mark an entire group as pending.
export
xdescribe : String -> Spec a () -> Spec a ()
xdescribe label _ = MkSpec [< Pending label Nothing] ()

||| Alias for `xdescribe`.
export
xcontext : String -> Spec a () -> Spec a ()
xcontext = xdescribe

||| Focus a test — when any focused specs exist, only focused ones run.
export
fit : String -> TestResult () -> Spec a ()
fit label result = MkSpec [< Focused (It label (\_ => pure result))] ()

||| Focus an entire group.
export
fdescribe : String -> Spec a () -> Spec a ()
fdescribe label body = MkSpec [< Focused (Describe label (getSpecTrees body))] ()

||| Alias for `fdescribe`.
export
fcontext : String -> Spec a () -> Spec a ()
fcontext = fdescribe
