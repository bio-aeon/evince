module Evince.Core

import Data.SnocList
import public Decidable.Equality
import public Evince.SrcLoc
import public Control.Monad.Trans
import public Control.Monad.Identity

%default total

public export
data FailureInfo : Type where
  ExpectedButGot  : (reason : String) -> (expected : String) -> (actual : String) -> FailureInfo
  PredicateFailed : (reason : String) -> (actual : String) -> FailureInfo
  Reason          : (message : String) -> FailureInfo

export
Show FailureInfo where
  show (ExpectedButGot reason expected actual) =
    reason ++ "\nexpected: " ++ expected ++ "\n  actual: " ++ actual
  show (PredicateFailed reason actual) =
    reason ++ "\n  value: " ++ actual
  show (Reason message) = message

export
DecEq FailureInfo where
  decEq (ExpectedButGot r1 e1 a1) (ExpectedButGot r2 e2 a2) =
    case (decEq r1 r2, decEq e1 e2, decEq a1 a2) of
      (Yes Refl, Yes Refl, Yes Refl) => Yes Refl
      (No c, _, _) => No $ \case Refl => c Refl
      (_, No c, _) => No $ \case Refl => c Refl
      (_, _, No c) => No $ \case Refl => c Refl
  decEq (PredicateFailed r1 a1) (PredicateFailed r2 a2) =
    case (decEq r1 r2, decEq a1 a2) of
      (Yes Refl, Yes Refl) => Yes Refl
      (No c, _) => No $ \case Refl => c Refl
      (_, No c) => No $ \case Refl => c Refl
  decEq (Reason m1) (Reason m2) = case decEq m1 m2 of
    Yes Refl => Yes Refl
    No c     => No $ \case Refl => c Refl
  decEq (ExpectedButGot _ _ _) (PredicateFailed _ _) = No $ \case Refl impossible
  decEq (ExpectedButGot _ _ _) (Reason _)            = No $ \case Refl impossible
  decEq (PredicateFailed _ _)  (ExpectedButGot _ _ _) = No $ \case Refl impossible
  decEq (PredicateFailed _ _)  (Reason _)            = No $ \case Refl impossible
  decEq (Reason _)             (ExpectedButGot _ _ _) = No $ \case Refl impossible
  decEq (Reason _)             (PredicateFailed _ _) = No $ \case Refl impossible

-- Short-circuit on Fail/Skip: once a failure occurs, subsequent
-- expectations in a do-block are skipped.
public export
data TestResult : Type -> Type where
  Pass : a -> TestResult a
  Fail : FailureInfo -> TestResult a
  Skip : (reason : Maybe String) -> TestResult a

export
Show a => Show (TestResult a) where
  show (Pass x)      = "Pass " ++ show x
  show (Fail info)   = "Fail (" ++ show info ++ ")"
  show (Skip reason) = "Skip " ++ show reason

export
DecEq a => DecEq (TestResult a) where
  decEq (Pass x) (Pass y) = case decEq x y of
    Yes Refl => Yes Refl
    No c     => No $ \case Refl => c Refl
  decEq (Fail i1) (Fail i2) = case decEq i1 i2 of
    Yes Refl => Yes Refl
    No c     => No $ \case Refl => c Refl
  decEq (Skip r1) (Skip r2) = case decEq r1 r2 of
    Yes Refl => Yes Refl
    No c     => No $ \case Refl => c Refl
  decEq (Pass _) (Fail _)   = No $ \case Refl impossible
  decEq (Pass _) (Skip _)   = No $ \case Refl impossible
  decEq (Fail _) (Pass _)   = No $ \case Refl impossible
  decEq (Fail _) (Skip _)   = No $ \case Refl impossible
  decEq (Skip _) (Pass _)   = No $ \case Refl impossible
  decEq (Skip _) (Fail _)   = No $ \case Refl impossible

export
Functor TestResult where
  map f (Pass x)      = Pass (f x)
  map f (Fail info)   = Fail info
  map f (Skip reason) = Skip reason

export
Applicative TestResult where
  pure = Pass
  (Pass f)      <*> x = map f x
  (Fail info)   <*> _ = Fail info
  (Skip reason) <*> _ = Skip reason

export
Monad TestResult where
  (Pass x)      >>= f = f x
  (Fail info)   >>= _ = Fail info
  (Skip reason) >>= _ = Skip reason

||| A chain of expectations in an inner monad `m`: `>>=` stops at the first
||| `Fail` or `Skip`, so a test body of several expectations reports its
||| first failure. Plain `m` actions enter via `lift`/`liftIO`, a plain
||| `TestResult` via `liftResult`; `runTestResultT` runs the chain.
public export
data TestResultT : (Type -> Type) -> Type -> Type where
  MkTestResultT : m (TestResult a) -> TestResultT m a

||| Run a chain in its inner monad, producing its final result.
export
runTestResultT : TestResultT m a -> m (TestResult a)
runTestResultT (MkTestResultT x) = x

export
Functor m => Functor (TestResultT m) where
  map f (MkTestResultT x) = MkTestResultT (map (map f) x)

export
Monad m => Applicative (TestResultT m) where
  pure = MkTestResultT . pure . Pass
  (MkTestResultT mf) <*> (MkTestResultT mx) = MkTestResultT $ do
    Pass f <- mf
      | Fail i => pure (Fail i)
      | Skip r => pure (Skip r)
    map (map f) mx

export
Monad m => Monad (TestResultT m) where
  (MkTestResultT mx) >>= f = MkTestResultT $ do
    Pass x <- mx
      | Fail i => pure (Fail i)
      | Skip r => pure (Skip r)
    runTestResultT (f x)

export
MonadTrans TestResultT where
  lift = MkTestResultT . map Pass

export
HasIO m => HasIO (TestResultT m) where
  liftIO = lift . liftIO

||| Run a chain that performs no effects, e.g. to compare a custom
||| expectation's result against `Pass`, `Fail` or `Skip`.
export
runPure : TestResultT Identity a -> TestResult a
runPure = runIdentity . runTestResultT

||| Lift a plain result into a chain, e.g. a custom expectation built from
||| `Pass` and `Fail`.
export
liftResult : Applicative m => TestResult a -> TestResultT m a
liftResult = MkTestResultT . pure

||| Lift an `IO` chain into a chain over any monad that can run IO.
export
hoistIO : HasIO m => TestResultT IO a -> TestResultT m a
hoistIO = MkTestResultT . liftIO . runTestResultT

||| Lifts a body written in monad `n` into a spec over monad `m`. A chain in
||| the spec's own monad runs as it is, an `IO` chain through `liftIO`, and a
||| body whose monad nothing else fixes runs in the spec's monad.
public export
interface Hoist (0 n : Type -> Type) (0 m : Type -> Type) where
  hoistChain : TestResultT n a -> TestResultT m a

public export
HasIO m => Hoist IO m where
  hoistChain = hoistIO

||| The fallback that runs a body in the spec's own monad.
%defaulthint
public export
SameMonad : Hoist m m
SameMonad = Same
  where
    [Same] Hoist m m where
      hoistChain = id

-- `m` is the test-action monad.
public export
data SpecTree : (m : Type -> Type) -> Type -> Type where
  Describe    : (label : String) -> (children : List (SpecTree m a)) -> SpecTree m a
  It          : (label : String) -> (loc : Maybe SrcLoc) -> (test : a -> m (TestResult ())) -> SpecTree m a
  Pending     : (label : String) -> (reason : Maybe String) -> SpecTree m a
  Focused     : SpecTree m a -> SpecTree m a
  WithCleanup : (cleanup : m ()) -> (children : List (SpecTree m a)) -> SpecTree m a

-- SnocList gives O(1) appending per describe/it in a do-block.
public export
data Spec : (m : Type -> Type) -> Type -> Type -> Type where
  MkSpec : SnocList (SpecTree m a) -> b -> Spec m a b

export
Functor (Spec m a) where
  map f (MkSpec trees x) = MkSpec trees (f x)

export
Applicative (Spec m a) where
  pure x = MkSpec [<] x
  (MkSpec ts1 f) <*> (MkSpec ts2 x) = MkSpec (ts1 ++ ts2) (f x)

export
Monad (Spec m a) where
  (MkSpec ts1 x) >>= f = let (MkSpec ts2 y) = f x in MkSpec (ts1 ++ ts2) y

||| Extract the tree list from a completed spec.
export
getSpecTrees : Spec m a () -> List (SpecTree m a)
getSpecTrees (MkSpec trees ()) = trees <>> []

public export
record Summary where
  constructor MkSummary
  passed   : Nat
  failed   : Nat
  pending  : Nat
  duration : Integer

export
Semigroup Summary where
  (MkSummary p1 f1 pn1 d1) <+> (MkSummary p2 f2 pn2 d2) =
    MkSummary (p1 + p2) (f1 + f2) (pn1 + pn2) (d1 + d2)

export
Monoid Summary where
  neutral = MkSummary 0 0 0 0

export
Show Summary where
  show s = show s.passed ++ " passing, "
        ++ show s.failed ++ " failing, "
        ++ show s.pending ++ " pending"

export
totalCount : Summary -> Nat
totalCount s = s.passed + s.failed + s.pending

public export
record RunConfig where
  constructor MkRunConfig
  failFast    : Bool
  showTiming  : Bool
  match       : Maybe String
  skip        : Maybe String
  randomize   : Bool
  seed        : Maybe Nat
  junitOutput : Maybe String
  rerun       : Bool
  jobs        : Nat
  color       : Bool

||| Default configuration: no fail-fast, no timing, no filters, colored output.
export
defaultConfig : RunConfig
defaultConfig = MkRunConfig False False Nothing Nothing False Nothing Nothing False 0 True
