module Evince.Spec

import Evince.Core

||| Group related specs under a label.
export
describe : String -> Spec () -> Spec ()
describe label body = MkSpec [< Describe label (getSpecTrees body)] ()

||| Alias for `describe` — use with "when"/"with" phrasing.
export
context : String -> Spec () -> Spec ()
context = describe

||| Define a test case with pure expectations.
export
it : String -> TestResult () -> Spec ()
it label result = MkSpec [< It label (pure result)] ()

||| Define a test case with IO-based expectations.
export
itIO : String -> IO (TestResult ()) -> Spec ()
itIO label action = MkSpec [< It label action] ()

||| Mark a test as pending — the body is ignored and not executed.
export
xit : String -> TestResult () -> Spec ()
xit label _ = MkSpec [< Pending label Nothing] ()

||| Mark an entire group as pending.
export
xdescribe : String -> Spec () -> Spec ()
xdescribe label _ = MkSpec [< Pending label Nothing] ()

||| Alias for `xdescribe`.
export
xcontext : String -> Spec () -> Spec ()
xcontext = xdescribe

||| Focus a test — when any focused specs exist, only focused ones run.
export
fit : String -> TestResult () -> Spec ()
fit label result = MkSpec [< Focused (It label (pure result))] ()

||| Focus an entire group.
export
fdescribe : String -> Spec () -> Spec ()
fdescribe label body = MkSpec [< Focused (Describe label (getSpecTrees body))] ()

||| Alias for `fdescribe`.
export
fcontext : String -> Spec () -> Spec ()
fcontext = fdescribe
