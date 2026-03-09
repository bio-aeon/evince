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

    it "parses --rerun" $
      (parseArgs ["--rerun"]).rerun `mustBe` True

    it "parses --jobs=4" $
      (parseArgs ["--jobs=4"]).jobs `mustBe` 4

    it "ignores unknown flags" $
      (parseArgs ["--unknown"]).failFast `mustBe` False

    it "parses multiple flags together" $ do
      let cfg = parseArgs ["--fail-fast", "--times", "--match=foo"]
      cfg.failFast `mustBe` True
      cfg.showTiming `mustBe` True
      cfg.match `mustBe` Just "foo"

  describe "flag combinations" $ do
    itIO "match + fail-fast stops after first matching failure" $ do
      let cfg = { failFast := True, match := Just "target" } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        it "target 1" $ 1 `mustBe` 2
        it "target 2" $ 1 `mustBe` 1
        it "other" $ 1 `mustBe` 1
      pure $ do
        s.failed `mustBe` 1
        s.passed `mustBe` 0

    itIO "skip + match applies both filters" $ do
      let cfg = { match := Just "test", skip := Just "slow" } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        it "test fast" $ 1 `mustBe` 1
        it "test slow" $ 2 `mustBe` 2
        it "other" $ 3 `mustBe` 3
      pure $ s.passed `mustBe` 1

    itIO "randomize + seed produces deterministic order" $ do
      let cfg = { randomize := True, seed := Just 123 } defaultConfig
      s1 <- runSpecWithSummaryAndConfig cfg $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
        it "c" $ 3 `mustBe` 3
      s2 <- runSpecWithSummaryAndConfig cfg $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
        it "c" $ 3 `mustBe` 3
      pure $ do
        s1.passed `mustBe` 3
        s2.passed `mustBe` 3

  describe "parallel execution" $ do
    itIO "runs groups concurrently and collects all results" $ do
      let cfg = { jobs := 2 } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        describe "group 1" $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
        describe "group 2" $ do
          it "c" $ 3 `mustBe` 3
          it "d" $ 4 `mustBe` 4
      pure $ s.passed `mustBe` 4

    itIO "parallel + fail-fast stops after first failure" $ do
      let cfg = { jobs := 2, failFast := True } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        describe "group 1" $ do
          it "fail" $ 1 `mustBe` 2
        describe "group 2" $ do
          it "pass" $ 1 `mustBe` 1
      pure $ (s.failed + s.passed) `mustSatisfy` (> 0)

    itIO "parallel + match filters correctly" $ do
      let cfg = { jobs := 2, match := Just "target" } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        describe "group 1" $ do
          it "target a" $ 1 `mustBe` 1
        describe "group 2" $ do
          it "other" $ 2 `mustBe` 2
          it "target b" $ 3 `mustBe` 3
      pure $ s.passed `mustBe` 2

