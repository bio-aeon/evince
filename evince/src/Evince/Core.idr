module Evince.Core

import Data.SnocList
import public Decidable.Equality

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

public export
data SpecTree : Type -> Type where
  Describe    : (label : String) -> (children : List (SpecTree a)) -> SpecTree a
  It          : (label : String) -> (test : a -> IO (TestResult ())) -> SpecTree a
  Pending     : (label : String) -> (reason : Maybe String) -> SpecTree a
  Focused     : SpecTree a -> SpecTree a
  WithCleanup : (cleanup : IO ()) -> (children : List (SpecTree a)) -> SpecTree a

-- SnocList gives O(1) appending per describe/it in a do-block.
-- Idris 2 resolves the correct monad (Spec vs TestResult) via
-- type-directed elaboration based on the expected return type.
public export
data Spec : Type -> Type -> Type where
  MkSpec : SnocList (SpecTree a) -> b -> Spec a b

export
Functor (Spec a) where
  map f (MkSpec trees x) = MkSpec trees (f x)

export
Applicative (Spec a) where
  pure x = MkSpec [<] x
  (MkSpec ts1 f) <*> (MkSpec ts2 x) = MkSpec (ts1 ++ ts2) (f x)

export
Monad (Spec a) where
  (MkSpec ts1 x) >>= f = let (MkSpec ts2 y) = f x in MkSpec (ts1 ++ ts2) y

||| Extract the tree list from a completed spec.
export
getSpecTrees : Spec a () -> List (SpecTree a)
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
  (MkSummary p1 f1 d1 t1) <+> (MkSummary p2 f2 d2 t2) =
    MkSummary (p1 + p2) (f1 + f2) (d1 + d2) (t1 + t2)

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

||| Default configuration: no fail-fast, no timing, no filters.
export
defaultConfig : RunConfig
defaultConfig = MkRunConfig False False Nothing Nothing False Nothing Nothing
