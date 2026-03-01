module Evince.ExpectationsSpec

import Evince

export
expectationsSpec : Spec ()
expectationsSpec = describe "Expectations" $ do
  describe "mustBe" $ do
    it "confirms equal integers" $
      (42 `mustBe` 42) `mustBe` Pass ()
    it "reports expected vs actual on mismatch" $
      (1 `mustBe` 2) `mustBe` Fail (ExpectedButGot "not equal" "2" "1")

  describe "mustNotBe" $ do
    it "confirms distinct values" $
      (1 `mustNotBe` 2) `mustBe` Pass ()
    it "reports when values are unexpectedly equal" $
      (1 `mustNotBe` 1) `mustBe` Fail (ExpectedButGot "expected to differ" "1" "1")

  describe "mustEqual" $ do
    it "confirms equal strings" $
      ("abc" `mustEqual` "abc") `mustBe` Pass ()
    it "reports mismatch with Show output" $
      ("abc" `mustEqual` "def") `mustBe` Fail (ExpectedButGot "not equal" "\"def\"" "\"abc\"")

  describe "mustSatisfy" $ do
    it "confirms when predicate holds" $
      (4 `mustSatisfy` (> 3)) `mustBe` Pass ()
    it "reports the value when predicate fails" $
      (2 `mustSatisfy` (> 3)) `mustBe` Fail (PredicateFailed "predicate not satisfied" "2")

  describe "mustBeTrue" $ do
    it "accepts True" $
      mustBeTrue True `mustBe` Pass ()

  describe "mustBeFalse" $ do
    it "accepts False" $
      mustBeFalse False `mustBe` Pass ()

  describe "mustBeJust" $ do
    it "accepts Just values" $
      mustBeJust (Just 1) `mustBe` Pass ()
    it "rejects Nothing" $
      mustBeJust (the (Maybe Int) Nothing)
        `mustBe` Fail (Reason "expected Just but got Nothing")

  describe "mustBeNothing" $ do
    it "accepts Nothing" $
      mustBeNothing (the (Maybe Int) Nothing) `mustBe` Pass ()

  describe "mustBeRight" $ do
    it "accepts Right values" $
      mustBeRight (the (Either String Int) (Right 1)) `mustBe` Pass ()

  describe "mustBeLeft" $ do
    it "accepts Left values" $
      mustBeLeft (the (Either String Int) (Left "err")) `mustBe` Pass ()

  describe "mustContain" $ do
    it "finds a contiguous subsequence" $
      ([1,2,3,4] `mustContain` [2,3]) `mustBe` Pass ()

  describe "mustStartWith" $ do
    it "confirms matching prefix" $
      ([1,2,3] `mustStartWith` [1,2]) `mustBe` Pass ()

  describe "mustEndWith" $ do
    it "confirms matching suffix" $
      ([1,2,3] `mustEndWith` [2,3]) `mustBe` Pass ()

  describe "mustBeEmpty" $ do
    it "accepts empty list" $
      mustBeEmpty (the (List Int) []) `mustBe` Pass ()

  describe "mustNotBeEmpty" $ do
    it "accepts non-empty list" $
      mustNotBeEmpty [1] `mustBe` Pass ()

  describe "pending" $ do
    it "skips without a reason" $
      pending `mustBe` Skip Nothing

  describe "pendingWith" $ do
    it "skips with the given reason" $
      pendingWith "later" `mustBe` Skip (Just "later")
