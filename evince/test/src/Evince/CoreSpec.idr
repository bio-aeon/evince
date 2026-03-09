module Evince.CoreSpec

import Evince

export
coreSpec : Spec () ()
coreSpec = do
  describe "TestResult" $ do
    describe "monadic chaining" $ do
      it "applies function on Pass" $
        (Pass 1 >>= \x => Pass (x + 1)) `mustBe` Pass 2

      it "short-circuits on Fail" $
        (Fail (Reason "boom") >>= \x => Pass (the Nat x + 1))
          `mustBe` Fail (Reason "boom")

      it "short-circuits on Skip" $
        (Skip Nothing >>= \x => Pass (the Nat x + 1))
          `mustBe` Skip Nothing

      it "stops at first failure in a do-block" $
        (do 1 `mustBe` 2
            mustFail "should not reach here")
          `mustBe` Fail (ExpectedButGot "not equal" "2" "1")

  describe "Summary" $ do
    it "neutral is all zeros" $
      totalCount (the Summary neutral) `mustBe` 0

    it "combines componentwise" $
      totalCount (MkSummary 1 2 3 0 <+> MkSummary 4 5 6 0) `mustBe` 21

    describe "totalCount" $ do
      it "sums all fields" $
        totalCount (MkSummary 3 2 1 0) `mustBe` 6
