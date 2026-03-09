module Evince.Reporter

import Evince.Core
import Evince.Report

||| Lifecycle events emitted by the runner during suite evaluation.
public export
data Event
  = SuiteStarted
  | GroupStarted String Nat
  | GroupDone String
  | TestDone TestReport Nat
  | PendingTest String (Maybe String) Nat
  | SuiteDone Summary

||| A reporter consumes events emitted by the runner.
public export
record Reporter where
  constructor MkReporter
  onEvent : Event -> IO ()

||| Combine multiple reporters into one. Each event is dispatched
||| to all reporters in order.
export
combineReporters : List Reporter -> Reporter
combineReporters rs = MkReporter $ \e => for_ rs $ \r => r.onEvent e
