module Evince.Synchronized

%default total

||| A lock: a function that runs an action while holding mutual exclusion, for
||| any result type. `Synchronized.newLock` allocates one.
public export
record Lock (m : Type -> Type) where
  constructor MkLock
  withLock : {0 a : Type} -> m a -> m a

||| A monad whose actions can run under mutual exclusion. Sequential `IO` runs
||| can't race, so its lock is a no-op; a concurrent driver provides a real lock.
public export
interface Synchronized (m : Type -> Type) where
  newLock : IO (Lock m)

public export
Synchronized IO where
  newLock = pure (MkLock id)
