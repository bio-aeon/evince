module Evince.RunnerSpec

import Evince

export
runnerSpec : Spec () ()
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

  describe "fail-fast" $ do
    itIO "stops after the first failure" $ do
      let cfg = { failFast := True } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        it "a" $ 1 `mustBe` 2
        it "b" $ 1 `mustBe` 1
      pure $ do
        s.failed `mustBe` 1
        s.passed `mustBe` 0

  describe "focus filtering" $ do
    itIO "runs only focused tests when any exist" $ do
      s <- runSpecWithSummary $ do
        it "skipped" $ 1 `mustBe` 1
        fit "focused" $ 2 `mustBe` 2
      pure $ do
        s.passed `mustBe` 1
        s.failed `mustBe` 0

  describe "timing" $ do
    itIO "records non-negative duration" $ do
      s <- runSpecWithSummary $ do
        it "a" $ 1 `mustBe` 1
      pure $ (s.duration >= 0) `mustSatisfy` id

  describe "match filtering" $ do
    itIO "runs only tests matching the pattern" $ do
      let cfg = { match := Just "alpha" } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        it "alpha" $ 1 `mustBe` 1
        it "beta" $ 2 `mustBe` 2
      pure $ s.passed `mustBe` 1

  describe "skip filtering" $ do
    itIO "excludes tests matching the pattern" $ do
      let cfg = { skip := Just "beta" } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        it "alpha" $ 1 `mustBe` 1
        it "beta" $ 2 `mustBe` 2
      pure $ s.passed `mustBe` 1

  describe "parseArgs" $ do
    it "parses --fail-fast" $
      (parseArgs ["--fail-fast"]).failFast `mustBe` True

    it "parses --times" $
      (parseArgs ["--times"]).showTiming `mustBe` True

    it "parses --match=pattern" $
      (parseArgs ["--match=foo"]).match `mustBe` Just "foo"

    it "parses --skip=pattern" $
      (parseArgs ["--skip=bar"]).skip `mustBe` Just "bar"

    it "parses --seed=42" $
      (parseArgs ["--seed=42"]).seed `mustBe` Just 42

    it "parses --randomize" $
      (parseArgs ["--randomize"]).randomize `mustBe` True

    it "parses --junit=file" $
      (parseArgs ["--junit=report.xml"]).junitOutput `mustBe` Just "report.xml"

    it "ignores unknown flags" $
      (parseArgs ["--unknown"]).failFast `mustBe` False
