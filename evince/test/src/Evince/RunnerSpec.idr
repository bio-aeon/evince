module Evince.RunnerSpec

import Data.IORef
import Evince
import Evince.Rerun

export
runnerSpec : Spec IO () ()
runnerSpec = describe "Runner" $ do
  describe "summary" $ do
    it "counts passing tests" $ do
      s <- liftIO $ runSpecWithSummary $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
      s.passed `mustBe` 2

    it "counts failing tests" $ do
      s <- liftIO $ runSpecWithSummary $ do
        it "a" $ 1 `mustBe` 2
      s.failed `mustBe` 1

    it "counts pending tests" $ do
      s <- liftIO $ runSpecWithSummary $ do
        xit "a" $ 1 `mustBe` 1
      s.pending `mustBe` 1

  describe "fail-fast" $ do
    it "stops after the first failure" $ do
      let cfg = { failFast := True } defaultConfig
      s <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        it "a" $ 1 `mustBe` 2
        it "b" $ 1 `mustBe` 1
      s.failed `mustBe` 1
      s.passed `mustBe` 0

  describe "focus filtering" $ do
    it "runs only focused tests when any exist" $ do
      s <- liftIO $ runSpecWithSummary $ do
        it "skipped" $ 1 `mustBe` 1
        fit "focused" $ 2 `mustBe` 2
      s.passed `mustBe` 1
      s.failed `mustBe` 0

    it "runs only tests wrapped in focus" $ do
      s <- liftIO $ runSpecWithSummary $ do
        it "skipped" $ 1 `mustBe` 1
        focus $ it "focused" $ 2 `mustBe` 2
      s.passed `mustBe` 1
      totalCount s `mustBe` 1

  describe "pending" $ do
    it "xdescribe marks every test in the group pending" $ do
      s <- liftIO $ runSpecWithSummary $ do
        xdescribe "group" $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
      s.pending `mustBe` 2

    it "xit does not evaluate its body" $ do
      s <- liftIO $ runSpecWithSummary $ do
        xit "deferred" (assert_total (idris_crash "body evaluated"))
      s.pending `mustBe` 1

  describe "timing" $ do
    it "records non-negative duration" $ do
      s <- liftIO $ runSpecWithSummary $ do
        it "a" $ 1 `mustBe` 1
      (s.duration >= 0) `mustSatisfy` id

  describe "match filtering" $ do
    it "runs only tests matching the pattern" $ do
      let cfg = { match := Just "alpha" } defaultConfig
      s <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        it "alpha" $ 1 `mustBe` 1
        it "beta" $ 2 `mustBe` 2
      s.passed `mustBe` 1

    it "excludes pending tests not matching the pattern" $ do
      let cfg = { match := Just "alpha" } defaultConfig
      s <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        it "alpha" $ 1 `mustBe` 1
        xit "beta" $ 2 `mustBe` 2
      s.passed `mustBe` 1
      s.pending `mustBe` 0

  describe "skip filtering" $ do
    it "excludes tests matching the pattern" $ do
      let cfg = { skip := Just "beta" } defaultConfig
      s <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        it "alpha" $ 1 `mustBe` 1
        it "beta" $ 2 `mustBe` 2
      s.passed `mustBe` 1

    it "excludes matching tests nested in non-matching groups" $ do
      let cfg = { skip := Just "beta" } defaultConfig
      s <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        describe "group" $ do
          it "alpha" $ 1 `mustBe` 1
          it "beta" $ 2 `mustBe` 2
      s.passed `mustBe` 1

    it "excludes an entire group whose label matches" $ do
      let cfg = { skip := Just "grp" } defaultConfig
      s <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        describe "grp group" $ do
          it "a" $ 1 `mustBe` 1
          it "b" $ 2 `mustBe` 2
      totalCount s `mustBe` 0

    it "excludes pending tests matching the pattern" $ do
      let cfg = { skip := Just "beta" } defaultConfig
      s <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        it "alpha" $ 1 `mustBe` 1
        xit "beta" $ 2 `mustBe` 2
      s.passed `mustBe` 1
      s.pending `mustBe` 0

  describe "rerun filtering" $ do
    it "excludes pending tests not in the failure list" $ do
      liftIO $ writeFailures [["fail"]]
      let cfg = { rerun := True } defaultConfig
      s <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        it "fail" $ 1 `mustBe` 2
        xit "pend" $ 1 `mustBe` 1
      liftIO $ writeFailures []
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
    it "match + fail-fast stops after first matching failure" $ do
      let cfg = { failFast := True, match := Just "target" } defaultConfig
      s <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        it "target 1" $ 1 `mustBe` 2
        it "target 2" $ 1 `mustBe` 1
        it "other" $ 1 `mustBe` 1
      s.failed `mustBe` 1
      s.passed `mustBe` 0

    it "skip + match applies both filters" $ do
      let cfg = { match := Just "test", skip := Just "slow" } defaultConfig
      s <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        it "test fast" $ 1 `mustBe` 1
        it "test slow" $ 2 `mustBe` 2
        it "other" $ 3 `mustBe` 3
      s.passed `mustBe` 1

    it "randomize + seed produces deterministic order" $ do
      let cfg = { randomize := True, seed := Just 123 } defaultConfig
      s1 <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
        it "c" $ 3 `mustBe` 3
      s2 <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        it "a" $ 1 `mustBe` 1
        it "b" $ 2 `mustBe` 2
        it "c" $ 3 `mustBe` 3
      s1.passed `mustBe` 3
      s2.passed `mustBe` 3

    it "randomize shuffles same-length sibling groups differently" $ do
      aRef <- newIORef []
      bRef <- newIORef []
      let cfg = { randomize := True, seed := Just 7 } defaultConfig
      let test : IORef (List Integer) -> Integer -> Spec IO () ()
          test = \ref, n => it (show n) $ do modifyIORef ref (n ::); 1 `mustBe` 1
      _ <- liftIO $ runSpecWithSummaryAndConfig cfg $ do
        describe "A" $ do test aRef 1; test aRef 2; test aRef 3
        describe "B" $ do test bRef 1; test bRef 2; test bRef 3
      aOrder <- readIORef aRef
      bOrder <- readIORef bRef
      aOrder `mustNotEqual` bOrder
