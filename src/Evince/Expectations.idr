module Evince.Expectations

import Data.List
import Decidable.Equality
import Evince.Core

%default total

||| Passes if `actual` is decidably equal to `expected`. Uses `DecEq` for
||| constructive equality — the primary assertion in evince.
export
mustBe : DecEq a => Show a => (actual : a) -> (expected : a) -> TestResult ()
mustBe actual expected = case decEq actual expected of
  Yes _ => Pass ()
  No  _ => Fail $ ExpectedButGot "not equal" (show expected) (show actual)

||| Passes if `actual` is decidably not equal to `expected`.
export
mustNotBe : DecEq a => Show a => (actual : a) -> (expected : a) -> TestResult ()
mustNotBe actual expected = case decEq actual expected of
  Yes _ => Fail $ ExpectedButGot "expected to differ" (show expected) (show actual)
  No  _ => Pass ()

||| Passes if `actual == expected` via `Eq`. Fallback for types without `DecEq`
||| (e.g. `Double`).
export
mustEqual : Eq a => Show a => (actual : a) -> (expected : a) -> TestResult ()
mustEqual actual expected =
  if actual == expected then Pass ()
  else Fail $ ExpectedButGot "not equal" (show expected) (show actual)

||| Passes if `actual /= expected` via `Eq`.
export
mustNotEqual : Eq a => Show a => (actual : a) -> (expected : a) -> TestResult ()
mustNotEqual actual expected =
  if actual /= expected then Pass ()
  else Fail $ ExpectedButGot "expected to differ" (show expected) (show actual)

||| Passes if `pred actual` is `True`.
export
mustSatisfy : Show a => (actual : a) -> (pred : a -> Bool) -> TestResult ()
mustSatisfy actual pred =
  if pred actual then Pass ()
  else Fail $ PredicateFailed "predicate not satisfied" (show actual)

||| Passes if `pred actual` is `False`.
export
mustNotSatisfy : Show a => (actual : a) -> (pred : a -> Bool) -> TestResult ()
mustNotSatisfy actual pred =
  if not (pred actual) then Pass ()
  else Fail $ PredicateFailed "predicate unexpectedly satisfied" (show actual)

||| Passes if the value is `True`.
export
mustBeTrue : Bool -> TestResult ()
mustBeTrue True  = Pass ()
mustBeTrue False = Fail $ Reason "expected True but got False"

||| Passes if the value is `False`.
export
mustBeFalse : Bool -> TestResult ()
mustBeFalse False = Pass ()
mustBeFalse True  = Fail $ Reason "expected False but got True"

||| Passes if the value is `Just _`.
export
mustBeJust : Show a => Maybe a -> TestResult ()
mustBeJust (Just _)  = Pass ()
mustBeJust Nothing   = Fail $ Reason "expected Just but got Nothing"

||| Passes if the value is `Nothing`.
export
mustBeNothing : Show a => Maybe a -> TestResult ()
mustBeNothing Nothing  = Pass ()
mustBeNothing (Just x) = Fail $ PredicateFailed "expected Nothing but got Just" (show x)

||| Passes if the value is `Right _`.
export
mustBeRight : (Show a, Show b) => Either a b -> TestResult ()
mustBeRight (Right _) = Pass ()
mustBeRight (Left x)  = Fail $ PredicateFailed "expected Right but got Left" (show x)

||| Passes if the value is `Left _`.
export
mustBeLeft : (Show a, Show b) => Either a b -> TestResult ()
mustBeLeft (Left _)  = Pass ()
mustBeLeft (Right x) = Fail $ PredicateFailed "expected Left but got Right" (show x)

||| Passes if `needle` is a contiguous subsequence of `haystack`.
export
mustContain : Eq a => Show a => (haystack : List a) -> (needle : List a) -> TestResult ()
mustContain haystack needle =
  if isInfixOf needle haystack then Pass ()
  else Fail $ ExpectedButGot "does not contain" (show needle) (show haystack)

||| Passes if `needle` is not a contiguous subsequence of `haystack`.
export
mustNotContain : Eq a => Show a => (haystack : List a) -> (needle : List a) -> TestResult ()
mustNotContain haystack needle =
  if not (isInfixOf needle haystack) then Pass ()
  else Fail $ ExpectedButGot "unexpectedly contains" (show needle) (show haystack)

||| Passes if the list starts with `prefx`.
export
mustStartWith : Eq a => Show a => (actual : List a) -> (prefx : List a) -> TestResult ()
mustStartWith actual prefx =
  if isPrefixOf prefx actual then Pass ()
  else Fail $ ExpectedButGot "does not start with" (show prefx) (show actual)

||| Passes if the list ends with `sufx`.
export
mustEndWith : Eq a => Show a => (actual : List a) -> (sufx : List a) -> TestResult ()
mustEndWith actual sufx =
  if isSuffixOf sufx actual then Pass ()
  else Fail $ ExpectedButGot "does not end with" (show sufx) (show actual)

||| Passes if the list is empty.
export
mustBeEmpty : Show a => List a -> TestResult ()
mustBeEmpty [] = Pass ()
mustBeEmpty xs = Fail $ PredicateFailed "expected empty list" (show xs)

||| Passes if the list is non-empty.
export
mustNotBeEmpty : List a -> TestResult ()
mustNotBeEmpty [] = Fail $ Reason "expected non-empty list but got []"
mustNotBeEmpty _  = Pass ()

||| Unconditionally fails with the given message.
export
mustFail : String -> TestResult ()
mustFail msg = Fail $ Reason msg

||| Marks a test as pending (skipped, not counted as failure).
export
pending : TestResult ()
pending = Skip Nothing

||| Marks a test as pending with a reason.
export
pendingWith : String -> TestResult ()
pendingWith msg = Skip (Just msg)
