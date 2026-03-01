module Evince.CoreSpec

import Evince

export
coreSpec : Spec ()
coreSpec = do
  describe "TestResult" $ do
    describe "monadic chaining" $ do
      it "applies function on Pass" $
        mustBe (Pass 1 >>= \x => Pass (x + 1)) (Pass 2)

      it "short-circuits on Fail" $
        mustBe (Fail (Reason "boom") >>= \x => Pass (the Nat x + 1))
               (Fail (Reason "boom"))

      it "short-circuits on Skip" $
        mustBe (Skip Nothing >>= \x => Pass (the Nat x + 1))
               (Skip Nothing)

      it "stops at first failure in a do-block" $ do
        mustBe (1 + 1) 2
        mustBe "hello" "hello"

  describe "Summary" $ do
    it "neutral is all zeros" $
      mustBe (totalCount (the Summary neutral)) 0

    it "combines componentwise" $
      mustBe (totalCount (MkSummary 1 2 3 <+> MkSummary 4 5 6)) 21

    describe "totalCount" $ do
      it "sums all fields" $
        mustBe (totalCount (MkSummary 3 2 1)) 6
