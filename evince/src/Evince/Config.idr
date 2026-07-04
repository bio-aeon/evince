module Evince.Config

import Data.SnocList
import Data.String
import System
import System.File
import Evince.Core

parseNat : String -> Maybe Nat
parseNat s = do
  n <- parseInteger {a = Integer} s
  if n >= 0 then Just (cast n) else Nothing

applyArg : RunConfig -> String -> (RunConfig, Maybe String)
applyArg cfg "--fail-fast" = ({ failFast := True } cfg, Nothing)
applyArg cfg "--randomize" = ({ randomize := True } cfg, Nothing)
applyArg cfg "--times"     = ({ showTiming := True } cfg, Nothing)
applyArg cfg "--rerun"     = ({ rerun := True } cfg, Nothing)
applyArg cfg "--no-color"  = ({ color := False } cfg, Nothing)
applyArg cfg "--help"      = (cfg, Nothing)
applyArg cfg arg =
  let (key, rest) = break (== '=') arg
      val = substr 1 (length rest) rest
      strArg : (String -> RunConfig) -> (RunConfig, Maybe String)
      strArg f = if val == "" then (cfg, Just "missing value for \{key}")
                 else (f val, Nothing)
      natArg : (Nat -> RunConfig) -> (RunConfig, Maybe String)
      natArg f = if val == "" then (cfg, Just "missing value for \{key}")
                 else case parseNat val of
                        Just n  => (f n, Nothing)
                        Nothing => (cfg, Just "invalid value for \{key}: \{val}")
  in case key of
       "--match" => strArg (\v => { match := Just v } cfg)
       "--skip"  => strArg (\v => { skip := Just v } cfg)
       "--junit" => strArg (\v => { junitOutput := Just v } cfg)
       "--seed"  => natArg (\n => { seed := Just n } cfg)
       "--jobs"  => natArg (\n => { jobs := n } cfg)
       _         => (cfg, Just "unknown argument: \{arg}")

||| Parse command-line arguments, also collecting a warning for every
||| argument that is unknown or has a missing/invalid value.
export
parseArgsWarn : List String -> (RunConfig, List String)
parseArgsWarn args =
  let (cfg, ws) = foldl step (defaultConfig, [<]) args
  in (cfg, ws <>> [])
  where
    step : (RunConfig, SnocList String) -> String -> (RunConfig, SnocList String)
    step (cfg, ws) arg =
      let (cfg', w) = applyArg cfg arg
      in (cfg', maybe ws (ws :<) w)

||| Parse command-line arguments into a RunConfig. Unknown or invalid
||| arguments are ignored; use `parseArgsWarn` to also collect warnings.
export
parseArgs : List String -> RunConfig
parseArgs = fst . parseArgsWarn

||| Reference text for the CLI flags understood by the `*WithArgs` runners.
export
usage : String
usage = """
Usage: <test-binary> [OPTIONS]

  --help         Show this help and exit
  --fail-fast    Stop after the first failure
  --times        Show per-test and total duration
  --match=PAT    Run only tests whose label contains PAT
  --skip=PAT     Skip tests and groups whose label contains PAT
  --randomize    Shuffle top-level execution order
  --seed=N       Deterministic seed for --randomize
  --junit=FILE   Write a JUnit XML report to FILE
  --rerun        Re-run only the tests that failed in the last run
  --jobs=N       Run up to N top-level groups concurrently (async drivers)
  --no-color     Disable colored output (NO_COLOR is also respected)
"""

||| Parse CLI arguments for a runner: `--help` prints the flag reference and
||| exits, and each unknown or invalid argument gets a warning on stderr.
export
handleArgs : List String -> IO RunConfig
handleArgs args = do
  when ("--help" `elem` args) $ do
    putStrLn usage
    exitSuccess
  let (cfg, warnings) = parseArgsWarn args
  for_ warnings $ \w => ignore $ fPutStrLn stderr "warning: \{w}"
  pure cfg
