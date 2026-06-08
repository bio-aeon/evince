module Evince.Synchronized

%default total

||| A monad that can run an action under mutual exclusion.
public export
interface Synchronized (m : Type -> Type) where
  ||| The lock representation.
  Lock : Type
  ||| Allocate a fresh lock.
  newLock : IO Lock
  ||| Run an action with the lock held.
  withLock : Lock -> m a -> m a

-- Sequential IO runs can't race, so no real lock is needed.
public export
Synchronized IO where
  Lock = ()
  newLock = pure ()
  withLock _ act = act
