module Evince.Reporter.Console

import Data.List
import Data.String
import Evince.Core
import Evince.Diff
import Evince.Report
import Evince.Reporter

-- ANSI escape sequences
esc : String -> String -> String
esc code text = "\x1b[" ++ code ++ "m" ++ text ++ "\x1b[0m"

green : String -> String
green = esc "32"

red : String -> String
red = esc "31"

yellow : String -> String
yellow = esc "33"

indent : Nat -> String
indent Z     = ""
indent (S k) = "  " ++ indent k

formatDuration : Integer -> String
formatDuration nanos =
  let ms = nanos `div` 1000000
  in if ms >= 1000
       then nanosToSeconds nanos ++ "s"
       else show ms ++ "ms"

printDescribe : String -> Nat -> IO ()
printDescribe label level = putStrLn $ indent level ++ label

printPending : String -> Maybe String -> Nat -> IO ()
printPending label Nothing level =
  putStrLn $ indent level ++ yellow ("○ " ++ label ++ " (pending)")
printPending label (Just reason) level =
  putStrLn $ indent level ++ yellow ("○ " ++ label ++ " (" ++ reason ++ ")")

printTestDone : RunConfig -> TestReport -> Nat -> IO ()
printTestDone cfg report level =
  case report.outcome of
    Passed elapsed => do
      let label = lastLabel report.path
      let timing = if cfg.showTiming then " (" ++ formatDuration elapsed ++ ")" else ""
      putStrLn $ indent level ++ green ("✓ " ++ label) ++ timing
    Failed info elapsed => do
      let label = lastLabel report.path
      let timing = if cfg.showTiming then " (" ++ formatDuration elapsed ++ ")" else ""
      let locStr = maybe "" (\l => " (" ++ show l ++ ")") report.loc
      putStrLn $ indent level ++ red ("✗ " ++ label) ++ locStr ++ timing
      let detailIndent = indent (S level)
      case failureDiff info of
        Just (reason, diffs) => do
          putStrLn $ detailIndent ++ red reason
          for_ diffs $ \d => putStrLn $ detailIndent ++ case d of
            LineSame _    => renderLineDiffPlain d
            LineRemoved _ => red (renderLineDiffPlain d)
            LineAdded _   => green (renderLineDiffPlain d)
        Nothing => for_ (lines (show info)) $ \line =>
          putStrLn $ detailIndent ++ red line
    Skipped reason => printPending (lastLabel report.path) reason level
  where
    lastLabel : List String -> String
    lastLabel [] = ""
    lastLabel [x] = x
    lastLabel (_ :: xs) = lastLabel xs

printSummary : RunConfig -> Summary -> IO ()
printSummary cfg s = do
  putStrLn ""
  let parts = [ green (show s.passed ++ " passing")
              , red (show s.failed ++ " failing")
              , yellow (show s.pending ++ " pending")
              ]
  let timing = if cfg.showTiming then " (" ++ formatDuration s.duration ++ ")" else ""
  putStrLn $ "  " ++ concat (intersperse ", " parts) ++ timing

||| Create a console reporter that prints colored test results to stdout.
export
consoleReporter : RunConfig -> Reporter
consoleReporter cfg = MkReporter $ \case
  SuiteStarted           => pure ()
  GroupStarted label lvl  => printDescribe label lvl
  GroupDone _             => pure ()
  TestDone report lvl     => printTestDone cfg report lvl
  PendingTest label reason lvl => printPending label reason lvl
  SuiteDone summary       => printSummary cfg summary
