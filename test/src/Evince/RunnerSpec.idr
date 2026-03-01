module Evince.RunnerSpec

import Evince

export
runnerSpec : Spec ()
runnerSpec = describe "Runner" $ do
  describe "summary" $ do
    itIO "counts passing tests" $ do
      s <- runSpecWithSummary $ do
        it "a" $ mustBe 1 1
        it "b" $ mustBe 2 2
      pure $ mustBe s.passed 2

    itIO "counts failing tests" $ do
      s <- runSpecWithSummary $ do
        it "a" $ mustBe 1 2
      pure $ mustBe s.failed 1

    itIO "counts pending tests" $ do
      s <- runSpecWithSummary $ do
        xit "a" $ mustBe 1 1
      pure $ mustBe s.pending 1

  describe "focus filtering" $ do
    itIO "runs only focused tests when any exist" $ do
      s <- runSpecWithSummary $ do
        it "skipped" $ mustBe 1 1
        fit "focused" $ mustBe 2 2
      pure $ do
        mustBe s.passed 1
        mustBe s.failed 0
