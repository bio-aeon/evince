module Evince.Async.Synchronized

import Data.Linear.Ref1
import IO.Async
import public Evince.Synchronized

%default total

-- Atomic compare-and-swap spinlock. Acquire flips the flag False -> True with
-- `caswrite1` (one atomic step), so it serializes correctly even when worker
-- threads contend (true parallelism); on failure we `cede` - yielding the
-- fiber, never blocking the worker thread - and retry. Release is *also* a
-- `caswrite1` (True -> False, which always succeeds since the holder set it),
-- not a plain write: the CAS is a memory barrier, so writes made inside the
-- critical section are published to the next acquirer (release/acquire ordering
-- across threads).
acquire : IORef Bool -> Async e [] ()
acquire ref = assert_total $ do
  got <- runIO (caswrite1 ref False True)
  if got then pure () else (cede >> acquire ref)

||| Run an action with the lock held, serializing concurrent `Async` fibers
||| (across worker threads) via the atomic CAS spinlock.
export
asyncWithLock : IORef Bool -> ({0 a : Type} -> Async e [] a -> Async e [] a)
asyncWithLock ref act = do
  acquire ref
  r <- act
  ignore $ runIO (caswrite1 ref True False)
  pure r

export
{e : Type} -> Synchronized (Async e []) where
  newLock = do
    ref <- newref False
    pure (MkLock (asyncWithLock ref))
