module Evince.Async.Reporter

import Data.Linear.Ref1
import IO.Async
import Evince.Core
import Evince.Reporter
import Evince.Runner
import Evince.Async.Synchronized

||| Build the run's reporter (console plus optional JUnit, via core's
||| `makeReporter`) and guard each emit with a lock, so groups scheduled
||| concurrently can't interleave halfway through a line.
export
makeAsyncReporter : RunConfig -> Async e [] (Reporter (Async e []))
makeAsyncReporter cfg = do
  base <- makeReporter cfg
  lock <- newref False
  pure $ MkReporter $ \ev => asyncWithLock lock (base.onEvent ev)
