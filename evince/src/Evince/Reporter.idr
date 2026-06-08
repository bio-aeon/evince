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

||| A reporter consumes events emitted by the runner, in the runner's monad `m`.
public export
record Reporter (m : Type -> Type) where
  constructor MkReporter
  onEvent : Event -> m ()

||| Combine multiple reporters into one. Each event is dispatched
||| to all reporters in order.
export
combineReporters : Applicative m => List (Reporter m) -> Reporter m
combineReporters rs = MkReporter $ \e => for_ rs $ \r => r.onEvent e
