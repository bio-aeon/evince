module Evince.ExpectationsSpec

import Evince

export
expectationsSpec : Spec ()
expectationsSpec = describe "Expectations" $ do
  describe "mustBe" $ do
    it "confirms equal integers" $
      mustBe (mustBe 42 42) (Pass ())
    it "reports expected vs actual on mismatch" $
      mustBe (mustBe 1 2) (Fail $ ExpectedButGot "not equal" "2" "1")

  describe "mustNotBe" $ do
    it "confirms distinct values" $
      mustBe (mustNotBe 1 2) (Pass ())
    it "reports when values are unexpectedly equal" $
      mustBe (mustNotBe 1 1) (Fail $ ExpectedButGot "expected to differ" "1" "1")

  describe "mustEqual" $ do
    it "confirms equal strings" $
      mustBe (mustEqual "abc" "abc") (Pass ())
    it "reports mismatch with Show output" $
      mustBe (mustEqual "abc" "def") (Fail $ ExpectedButGot "not equal" "\"def\"" "\"abc\"")

  describe "mustSatisfy" $ do
    it "confirms when predicate holds" $
      mustBe (mustSatisfy 4 (> 3)) (Pass ())
    it "reports the value when predicate fails" $
      mustBe (mustSatisfy 2 (> 3)) (Fail $ PredicateFailed "predicate not satisfied" "2")

  describe "mustBeTrue" $ do
    it "accepts True" $
      mustBe (mustBeTrue True) (Pass ())

  describe "mustBeFalse" $ do
    it "accepts False" $
      mustBe (mustBeFalse False) (Pass ())

  describe "mustBeJust" $ do
    it "accepts Just values" $
      mustBe (mustBeJust (Just 1)) (Pass ())
    it "rejects Nothing" $
      mustBe (mustBeJust (the (Maybe Int) Nothing))
             (Fail $ Reason "expected Just but got Nothing")

  describe "mustBeNothing" $ do
    it "accepts Nothing" $
      mustBe (mustBeNothing (the (Maybe Int) Nothing)) (Pass ())

  describe "mustBeRight" $ do
    it "accepts Right values" $
      mustBe (mustBeRight (the (Either String Int) (Right 1))) (Pass ())

  describe "mustBeLeft" $ do
    it "accepts Left values" $
      mustBe (mustBeLeft (the (Either String Int) (Left "err"))) (Pass ())

  describe "mustContain" $ do
    it "finds a contiguous subsequence" $
      mustBe (mustContain [1,2,3,4] [2,3]) (Pass ())

  describe "mustStartWith" $ do
    it "confirms matching prefix" $
      mustBe (mustStartWith [1,2,3] [1,2]) (Pass ())

  describe "mustEndWith" $ do
    it "confirms matching suffix" $
      mustBe (mustEndWith [1,2,3] [2,3]) (Pass ())

  describe "mustBeEmpty" $ do
    it "accepts empty list" $
      mustBe (mustBeEmpty (the (List Int) [])) (Pass ())

  describe "mustNotBeEmpty" $ do
    it "accepts non-empty list" $
      mustBe (mustNotBeEmpty [1]) (Pass ())

  describe "pending" $ do
    it "skips without a reason" $
      mustBe pending (Skip Nothing)

  describe "pendingWith" $ do
    it "skips with the given reason" $
      mustBe (pendingWith "later") (Skip (Just "later"))
