module Evince.Synchronized

import Data.Linear.Ref1

%default total

-- The lock cell is a `Data.Linear.Ref1` ref so a concurrent driver can
-- compare-and-swap it atomically (`caswrite1`); the IO instance ignores it.
||| A monad that can run an action under mutual exclusion, using the given
||| cell as the lock. Sequential `IO` runs can't race, so its instance is a
||| no-op; a concurrent driver provides a real lock.
public export
interface Synchronized (m : Type -> Type) where
  withLock : IORef Bool -> m a -> m a

public export
Synchronized IO where
  withLock _ act = act
