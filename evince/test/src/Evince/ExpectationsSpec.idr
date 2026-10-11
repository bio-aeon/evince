module Evince.ExpectationsSpec

import Evince

approx : Double -> Double -> Bool
approx x y = abs (x - y) < 1.0e-9

export
expectationsSpec : Spec IO () ()
expectationsSpec = describe "Expectations" $ do
  describe "mustBe" $ do
    it "confirms equal integers" $
      runPure (42 `mustBe` 42) `mustBe` Pass ()
    it "reports expected vs actual on mismatch" $
      runPure (1 `mustBe` 2) `mustBe` Fail (ExpectedButGot "not equal" "2" "1")

  describe "mustNotBe" $ do
    it "confirms distinct values" $
      runPure (1 `mustNotBe` 2) `mustBe` Pass ()
    it "reports when values are unexpectedly equal" $
      runPure (1 `mustNotBe` 1) `mustBe` Fail (ExpectedButGot "expected to differ" "1" "1")

  describe "mustEqual" $ do
    it "confirms equal strings" $
      runPure ("abc" `mustEqual` "abc") `mustBe` Pass ()
    it "reports mismatch with Show output" $
      runPure ("abc" `mustEqual` "def") `mustBe` Fail (ExpectedButGot "not equal" "\"def\"" "\"abc\"")

  describe "mustEqualBy" $ do
    it "shows both values when the relation does not hold" $
      runPure (mustEqualBy (==) 0.5 0.6)
        `mustBe` Fail (ExpectedButGot "not related by the given predicate" (show 0.6) (show 0.5))

    it "passes when the relation holds despite float imprecision" $
      runPure (mustEqualBy approx (0.1 + 0.2) 0.3) `mustBe` Pass ()

    it "passes on NaN values via a NaN-reflexive relation" $
      let nan = the Double (0.0 / 0.0)
      in runPure (mustEqualBy (\x, y => x == y || (x /= x && y /= y)) nan nan) `mustBe` Pass ()

  describe "mustSatisfy" $ do
    it "confirms when predicate holds" $
      runPure (4 `mustSatisfy` (> 3)) `mustBe` Pass ()
    it "reports the value when predicate fails" $
      runPure (2 `mustSatisfy` (> 3)) `mustBe` Fail (PredicateFailed "predicate not satisfied" "2")

  describe "mustBeTrue" $ do
    it "accepts True" $
      runPure (mustBeTrue True) `mustBe` Pass ()

  describe "mustBeFalse" $ do
    it "accepts False" $
      runPure (mustBeFalse False) `mustBe` Pass ()

  describe "mustBeJust" $ do
    it "accepts Just values" $
      runPure (mustBeJust (Just 1)) `mustBe` Pass ()
    it "rejects Nothing" $
      runPure (mustBeJust (the (Maybe Int) Nothing))
        `mustBe` Fail (Reason "expected Just but got Nothing")

  describe "mustBeNothing" $ do
    it "accepts Nothing" $
      runPure (mustBeNothing (the (Maybe Int) Nothing)) `mustBe` Pass ()

  describe "mustBeRight" $ do
    it "accepts Right values" $
      runPure (mustBeRight (the (Either String Int) (Right 1))) `mustBe` Pass ()

  describe "mustBeLeft" $ do
    it "accepts Left values" $
      runPure (mustBeLeft (the (Either String Int) (Left "err"))) `mustBe` Pass ()

  describe "mustContain" $ do
    it "finds a contiguous subsequence" $
      runPure ([1,2,3,4] `mustContain` [2,3]) `mustBe` Pass ()

  describe "mustStartWith" $ do
    it "confirms matching prefix" $
      runPure ([1,2,3] `mustStartWith` [1,2]) `mustBe` Pass ()

  describe "mustEndWith" $ do
    it "confirms matching suffix" $
      runPure ([1,2,3] `mustEndWith` [2,3]) `mustBe` Pass ()

  describe "mustBeEmpty" $ do
    it "accepts empty list" $
      runPure (mustBeEmpty (the (List Int) [])) `mustBe` Pass ()

  describe "mustNotBeEmpty" $ do
    it "accepts non-empty list" $
      runPure (mustNotBeEmpty [1]) `mustBe` Pass ()

  describe "pending" $ do
    it "skips without a reason" $
      runPure pending `mustBe` Skip Nothing

  describe "pendingWith" $ do
    it "skips with the given reason" $
      runPure (pendingWith "later") `mustBe` Skip (Just "later")

  describe "mustReturn" $ do
    it "accepts a matching result" $
      runPure (pure (the Nat 42) `mustReturn` 42) `mustBe` Pass ()
    it "rejects a mismatching result" $
      runPure (pure (the Nat 1) `mustReturn` 2) `mustBe` Fail (ExpectedButGot "not equal" "2" "1")
