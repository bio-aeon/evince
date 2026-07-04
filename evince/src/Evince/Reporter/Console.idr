module Evince.Reporter.Console

import Data.List
import Data.String
import Evince.Core
import Evince.Diff
import Evince.Report
import Evince.Reporter

-- ANSI escape sequences
paint : RunConfig -> (code : String) -> String -> String
paint cfg code text =
  if cfg.color then "\x1b[" ++ code ++ "m" ++ text ++ "\x1b[0m" else text

green : RunConfig -> String -> String
green cfg = paint cfg "32"

red : RunConfig -> String -> String
red cfg = paint cfg "31"

yellow : RunConfig -> String -> String
yellow cfg = paint cfg "33"

indent : Nat -> String
indent Z     = ""
indent (S k) = "  " ++ indent k

formatDuration : Integer -> String
formatDuration nanos =
  let ms = nanos `div` 1000000
  in if ms >= 1000 then nanosToSeconds nanos ++ "s"
     else if ms == 0 then show (nanos `div` 1000) ++ "µs"
     else show ms ++ "ms"

printDescribe : String -> Nat -> IO ()
printDescribe label level = putStrLn $ indent level ++ label

printPending : RunConfig -> String -> Maybe String -> Nat -> IO ()
printPending cfg label Nothing level =
  putStrLn $ indent level ++ yellow cfg ("○ " ++ label ++ " (pending)")
printPending cfg label (Just reason) level =
  putStrLn $ indent level ++ yellow cfg ("○ " ++ label ++ " (" ++ reason ++ ")")

printTestDone : RunConfig -> TestReport -> Nat -> IO ()
printTestDone cfg report level =
  case report.outcome of
    Passed elapsed => do
      let label = lastLabel report.path
      let timing = if cfg.showTiming then " (" ++ formatDuration elapsed ++ ")" else ""
      putStrLn $ indent level ++ green cfg ("✓ " ++ label) ++ timing
    Failed info elapsed => do
      let label = lastLabel report.path
      let timing = if cfg.showTiming then " (" ++ formatDuration elapsed ++ ")" else ""
      let locStr = maybe "" (\l => " (" ++ show l ++ ")") report.loc
      putStrLn $ indent level ++ red cfg ("✗ " ++ label) ++ locStr ++ timing
      let detailIndent = indent (S level)
      case failureDiff info of
        Just (reason, diffs) => do
          putStrLn $ detailIndent ++ red cfg reason
          for_ diffs $ \d => putStrLn $ detailIndent ++ case d of
            LineSame _    => renderLineDiffPlain d
            LineRemoved _ => red cfg (renderLineDiffPlain d)
            LineAdded _   => green cfg (renderLineDiffPlain d)
        Nothing => for_ (lines (show info)) $ \line =>
          putStrLn $ detailIndent ++ red cfg line
    Skipped reason => printPending cfg (lastLabel report.path) reason level
  where
    lastLabel : List String -> String
    lastLabel [] = ""
    lastLabel [x] = x
    lastLabel (_ :: xs) = lastLabel xs

printSummary : RunConfig -> Summary -> IO ()
printSummary cfg s = do
  putStrLn ""
  let parts = [ green cfg (show s.passed ++ " passing")
              , red cfg (show s.failed ++ " failing")
              , yellow cfg (show s.pending ++ " pending")
              ]
  let timing = if cfg.showTiming then " (" ++ formatDuration s.duration ++ ")" else ""
  putStrLn $ "  " ++ concat (intersperse ", " parts) ++ timing

||| Create a console reporter that prints colored test results to stdout.
export
consoleReporter : HasIO m => RunConfig -> Reporter m
consoleReporter cfg = MkReporter $ \e => liftIO $ case e of
  SuiteStarted           => pure ()
  GroupStarted label lvl  => printDescribe label lvl
  GroupDone _             => pure ()
  TestDone report lvl     => printTestDone cfg report lvl
  PendingTest label reason lvl => printPending cfg label reason lvl
  SuiteDone summary       => printSummary cfg summary
