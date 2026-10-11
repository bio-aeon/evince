module Evince.Expectations

import Data.List
import Decidable.Equality
import Evince.Core

%default total

||| Passes if `actual` is decidably equal to `expected`. Uses `DecEq` for
||| constructive equality - the primary assertion in evince.
export
mustBe : (Applicative m, DecEq a, Show a) => (actual : a) -> (expected : a) -> TestResultT m ()
mustBe actual expected = liftResult $ case decEq actual expected of
  Yes _ => Pass ()
  No  _ => Fail $ ExpectedButGot "not equal" (show expected) (show actual)

||| Passes if `actual` is decidably not equal to `expected`.
export
mustNotBe : (Applicative m, DecEq a, Show a) => (actual : a) -> (expected : a) -> TestResultT m ()
mustNotBe actual expected = liftResult $ case decEq actual expected of
  Yes _ => Fail $ ExpectedButGot "expected to differ" (show expected) (show actual)
  No  _ => Pass ()

||| Passes if `actual == expected` via `Eq`. Fallback for types without `DecEq`
||| (e.g. `Double`).
export
mustEqual : (Applicative m, Eq a, Show a) => (actual : a) -> (expected : a) -> TestResultT m ()
mustEqual actual expected = liftResult $
  if actual == expected then Pass ()
  else Fail $ ExpectedButGot "not equal" (show expected) (show actual)

||| Passes if `rel actual expected` holds. Fallback for comparisons `Eq`
||| can't express, such as approximate or NaN-reflexive equality on `Double`.
export
mustEqualBy : (Applicative m, Show a) => (rel : a -> a -> Bool) -> (actual, expected : a) -> TestResultT m ()
mustEqualBy rel actual expected = liftResult $
  if rel actual expected then Pass ()
  else Fail $ ExpectedButGot "not related by the given predicate" (show expected) (show actual)

||| Passes if `actual /= expected` via `Eq`.
export
mustNotEqual : (Applicative m, Eq a, Show a) => (actual : a) -> (expected : a) -> TestResultT m ()
mustNotEqual actual expected = liftResult $
  if actual /= expected then Pass ()
  else Fail $ ExpectedButGot "expected to differ" (show expected) (show actual)

||| Passes if `pred actual` is `True`.
export
mustSatisfy : (Applicative m, Show a) => (actual : a) -> (pred : a -> Bool) -> TestResultT m ()
mustSatisfy actual pred = liftResult $
  if pred actual then Pass ()
  else Fail $ PredicateFailed "predicate not satisfied" (show actual)

||| Passes if `pred actual` is `False`.
export
mustNotSatisfy : (Applicative m, Show a) => (actual : a) -> (pred : a -> Bool) -> TestResultT m ()
mustNotSatisfy actual pred = liftResult $
  if not (pred actual) then Pass ()
  else Fail $ PredicateFailed "predicate unexpectedly satisfied" (show actual)

||| Passes if the value is `True`.
export
mustBeTrue : Applicative m => Bool -> TestResultT m ()
mustBeTrue True  = liftResult $ Pass ()
mustBeTrue False = liftResult $ Fail $ Reason "expected True but got False"

||| Passes if the value is `False`.
export
mustBeFalse : Applicative m => Bool -> TestResultT m ()
mustBeFalse False = liftResult $ Pass ()
mustBeFalse True  = liftResult $ Fail $ Reason "expected False but got True"

||| Passes if the value is `Just _`.
export
mustBeJust : Applicative m => Maybe a -> TestResultT m ()
mustBeJust (Just _)  = liftResult $ Pass ()
mustBeJust Nothing   = liftResult $ Fail $ Reason "expected Just but got Nothing"

||| Passes if the value is `Nothing`.
export
mustBeNothing : (Applicative m, Show a) => Maybe a -> TestResultT m ()
mustBeNothing Nothing  = liftResult $ Pass ()
mustBeNothing (Just x) = liftResult $ Fail $ PredicateFailed "expected Nothing but got Just" (show x)

||| Passes if the value is `Right _`.
export
mustBeRight : (Applicative m, Show a) => Either a b -> TestResultT m ()
mustBeRight (Right _) = liftResult $ Pass ()
mustBeRight (Left x)  = liftResult $ Fail $ PredicateFailed "expected Right but got Left" (show x)

||| Passes if the value is `Left _`.
export
mustBeLeft : (Applicative m, Show b) => Either a b -> TestResultT m ()
mustBeLeft (Left _)  = liftResult $ Pass ()
mustBeLeft (Right x) = liftResult $ Fail $ PredicateFailed "expected Left but got Right" (show x)

||| Passes if `needle` is a contiguous subsequence of `haystack`.
export
mustContain : (Applicative m, Eq a, Show a) => (haystack : List a) -> (needle : List a) -> TestResultT m ()
mustContain haystack needle = liftResult $
  if isInfixOf needle haystack then Pass ()
  else Fail $ ExpectedButGot "does not contain" (show needle) (show haystack)

||| Passes if `needle` is not a contiguous subsequence of `haystack`.
export
mustNotContain : (Applicative m, Eq a, Show a) => (haystack : List a) -> (needle : List a) -> TestResultT m ()
mustNotContain haystack needle = liftResult $
  if not (isInfixOf needle haystack) then Pass ()
  else Fail $ ExpectedButGot "unexpectedly contains" (show needle) (show haystack)

||| Passes if the list starts with `prefx`.
export
mustStartWith : (Applicative m, Eq a, Show a) => (actual : List a) -> (prefx : List a) -> TestResultT m ()
mustStartWith actual prefx = liftResult $
  if isPrefixOf prefx actual then Pass ()
  else Fail $ ExpectedButGot "does not start with" (show prefx) (show actual)

||| Passes if the list ends with `sufx`.
export
mustEndWith : (Applicative m, Eq a, Show a) => (actual : List a) -> (sufx : List a) -> TestResultT m ()
mustEndWith actual sufx = liftResult $
  if isSuffixOf sufx actual then Pass ()
  else Fail $ ExpectedButGot "does not end with" (show sufx) (show actual)

||| Passes if the list is empty.
export
mustBeEmpty : (Applicative m, Show a) => List a -> TestResultT m ()
mustBeEmpty [] = liftResult $ Pass ()
mustBeEmpty xs = liftResult $ Fail $ PredicateFailed "expected empty list" (show xs)

||| Passes if the list is non-empty.
export
mustNotBeEmpty : Applicative m => List a -> TestResultT m ()
mustNotBeEmpty [] = liftResult $ Fail $ Reason "expected non-empty list but got []"
mustNotBeEmpty _  = liftResult $ Pass ()

||| Unconditionally fails with the given message.
export
mustFail : Applicative m => String -> TestResultT m ()
mustFail msg = liftResult $ Fail $ Reason msg

||| Marks a test as pending (skipped, not counted as failure).
export
pending : Applicative m => TestResultT m ()
pending = liftResult $ Skip Nothing

||| Marks a test as pending with a reason.
export
pendingWith : Applicative m => String -> TestResultT m ()
pendingWith msg = liftResult $ Skip (Just msg)

||| Passes if the action returns a value decidably equal to `expected`.
||| The action runs in the chain's monad.
export covering
mustReturn : (Monad m, DecEq a, Show a) => m a -> a -> TestResultT m ()
mustReturn action expected = do
  actual <- lift action
  actual `mustBe` expected

||| Passes if the action returns a value equal to `expected` via Eq.
||| Fallback for types without `DecEq`.
export covering
mustReturnEqual : (Monad m, Eq a, Show a) => m a -> a -> TestResultT m ()
mustReturnEqual action expected = do
  actual <- lift action
  actual `mustEqual` expected
