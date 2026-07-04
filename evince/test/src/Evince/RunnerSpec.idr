module Evince.RunnerSpec

import Data.IORef
import Evince
import Evince.Rerun

export
runnerSpec : Spec IO () ()
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

    itIO "focuses IO tests via the focus combinator" $ do
      s <- runSpecWithSummary $ do
        it "skipped" $ 1 `mustBe` 1
        focus $ itIO "focused" $ pure (2 `mustBe` 2)
      pure $ do
        s.passed `mustBe` 1
        totalCount s `mustBe` 1

  describe "pending" $ do
    itIO "xdescribe marks every test in the group pending" $ do
      s <- runSpecWithSummary $ do
        xdescribe "group" $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
      pure $ s.pending `mustBe` 2

    itIO "xitIO marks an IO test pending without running it" $ do
      ref <- newIORef False
      s <- runSpecWithSummary $ do
        xitIO "io" $ do writeIORef ref True; pure (1 `mustBe` 1)
      ran <- readIORef ref
      pure $ do
        s.pending `mustBe` 1
        ran `mustBe` False

    itIO "xit does not evaluate its body" $ do
      s <- runSpecWithSummary $ do
        xit "deferred" (assert_total (idris_crash "body evaluated"))
      pure $ s.pending `mustBe` 1

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

    itIO "excludes pending tests not matching the pattern" $ do
      let cfg = { match := Just "alpha" } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        it "alpha" $ 1 `mustBe` 1
        xit "beta" $ 2 `mustBe` 2
      pure $ do
        s.passed `mustBe` 1
        s.pending `mustBe` 0

  describe "skip filtering" $ do
    itIO "excludes tests matching the pattern" $ do
      let cfg = { skip := Just "beta" } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        it "alpha" $ 1 `mustBe` 1
        it "beta" $ 2 `mustBe` 2
      pure $ s.passed `mustBe` 1

    itIO "excludes matching tests nested in non-matching groups" $ do
      let cfg = { skip := Just "beta" } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        describe "group" $ do
          it "alpha" $ 1 `mustBe` 1
          it "beta" $ 2 `mustBe` 2
      pure $ s.passed `mustBe` 1

    itIO "excludes an entire group whose label matches" $ do
      let cfg = { skip := Just "grp" } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        describe "grp group" $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
      pure $ totalCount s `mustBe` 0

    itIO "excludes pending tests matching the pattern" $ do
      let cfg = { skip := Just "beta" } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        it "alpha" $ 1 `mustBe` 1
        xit "beta" $ 2 `mustBe` 2
      pure $ do
        s.passed `mustBe` 1
        s.pending `mustBe` 0

  describe "rerun filtering" $ do
    itIO "excludes pending tests not in the failure list" $ do
      writeFailures [["fail"]]
      let cfg = { rerun := True } defaultConfig
      s <- runSpecWithSummaryAndConfig cfg $ do
        it "fail" $ 1 `mustBe` 2
        xit "pend" $ 1 `mustBe` 1
      writeFailures []
      pure $ do
        s.failed `mustBe` 1
        s.pending `mustBe` 0

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

    it "parses --no-color" $
      (parseArgs ["--no-color"]).color `mustBe` False

    it "ignores unknown flags" $
      (parseArgs ["--unknown"]).failFast `mustBe` False

    it "keeps the previous seed on an invalid value" $
      (parseArgs ["--seed=42", "--seed=abc"]).seed `mustBe` Just 42

    it "collects a warning for unknown arguments" $
      snd (parseArgsWarn ["--unknown"]) `mustBe` ["unknown argument: --unknown"]

    it "collects a warning for invalid values" $
      snd (parseArgsWarn ["--jobs=abc"]) `mustBe` ["invalid value for --jobs: abc"]

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

    itIO "randomize shuffles same-length sibling groups differently" $ do
      aRef <- newIORef []
      bRef <- newIORef []
      let cfg = { randomize := True, seed := Just 7 } defaultConfig
      let test : IORef (List Integer) -> Integer -> Spec IO () ()
          test = \ref, n => itIO (show n) $ do modifyIORef ref (n ::); pure (1 `mustBe` 1)
      _ <- runSpecWithSummaryAndConfig cfg $ do
        describe "A" $ do test aRef 1; test aRef 2; test aRef 3
        describe "B" $ do test bRef 1; test bRef 2; test bRef 3
      aOrder <- readIORef aRef
      bOrder <- readIORef bRef
      pure $ aOrder `mustNotEqual` bOrder
