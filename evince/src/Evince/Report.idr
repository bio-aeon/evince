module Evince.Report

import Evince.Core

||| Outcome of a single test for structured reporting.
public export
data TestOutcome
  = Passed Integer
  | Failed FailureInfo Integer
  | Skipped (Maybe String)

||| A completed test with its describe path, source location, and outcome.
public export
record TestReport where
  constructor MkTestReport
  path    : List String
  loc     : Maybe SrcLoc
  outcome : TestOutcome

||| Convert nanoseconds to "S.MMMMs" (no unit suffix). Shared by reporters.
export
nanosToSeconds : Integer -> String
nanosToSeconds nanos =
  let ms = nanos `div` 1000000
      s  = ms `div` 1000
      r  = ms `mod` 1000
      pad = if r < 10 then "00" else if r < 100 then "0" else ""
  in show s ++ "." ++ pad ++ show r
