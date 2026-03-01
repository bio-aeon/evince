module Evince.RunnerSpec

import Evince

export
runnerSpec : Spec ()
runnerSpec = describe "Runner" $ do
  describe "summary" $ do
    itIO "counts passing tests" $ do
      s <- runSpecWithSummary $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
      pure $ s.passed `mustBe` 2

    itIO "counts failing tests" $ do
      s <- runSpecWithSummary $ do
        it "a" $ 1 `mustBe` 2
      pure $ s.failed `mustBe` 1

    itIO "counts pending tests" $ do
      s <- runSpecWithSummary $ do
        xit "a" $ 1 `mustBe` 1
      pure $ s.pending `mustBe` 1

  describe "focus filtering" $ do
    itIO "runs only focused tests when any exist" $ do
      s <- runSpecWithSummary $ do
        it "skipped" $ 1 `mustBe` 1
        fit "focused" $ 2 `mustBe` 2
      pure $ do
        s.passed `mustBe` 1
        s.failed `mustBe` 0
