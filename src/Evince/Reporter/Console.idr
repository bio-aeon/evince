module Evince.Reporter.Console

import Data.List
import Data.String
import Evince.Core
import Evince.Report

-- ANSI escape sequences
esc : String -> String -> String
esc code text = "\x1b[" ++ code ++ "m" ++ text ++ "\x1b[0m"

green : String -> String
green = esc "32"

red : String -> String
red = esc "31"

yellow : String -> String
yellow = esc "33"

||| Render an indentation prefix (two spaces per level).
export
indent : Nat -> String
indent Z     = ""
indent (S k) = "  " ++ indent k

||| Print a describe/context label.
export
printDescribe : String -> Nat -> IO ()
printDescribe label level = putStrLn $ indent level ++ label

||| Print a pending test.
export
printPending : String -> Maybe String -> Nat -> IO ()
printPending label Nothing level =
  putStrLn $ indent level ++ yellow ("○ " ++ label ++ " (pending)")
printPending label (Just reason) level =
  putStrLn $ indent level ++ yellow ("○ " ++ label ++ " (" ++ reason ++ ")")

formatDuration : Integer -> String
formatDuration nanos =
  let ms = nanos `div` 1000000
  in if ms >= 1000
       then nanosToSeconds nanos ++ "s"
       else show ms ++ "ms"

||| Print the result of a single test case.
export
printTestResult : RunConfig -> String -> TestResult () -> (elapsed : Integer) -> Nat -> IO ()
printTestResult cfg label (Pass ()) elapsed level =
  let timing = if cfg.showTiming then " (" ++ formatDuration elapsed ++ ")" else ""
  in putStrLn $ indent level ++ green ("✓ " ++ label) ++ timing
printTestResult cfg label (Fail info) elapsed level = do
  let timing = if cfg.showTiming then " (" ++ formatDuration elapsed ++ ")" else ""
  putStrLn $ indent level ++ red ("✗ " ++ label) ++ timing
  let detailIndent = indent (S level)
  for_ (lines (show info)) $ \line =>
    putStrLn $ detailIndent ++ red line
printTestResult cfg label (Skip reason) _ level =
  printPending label reason level

||| Print the final summary line.
export
printSummary : RunConfig -> Summary -> IO ()
printSummary cfg s = do
  putStrLn ""
  let parts = [ green (show s.passed ++ " passing")
              , red (show s.failed ++ " failing")
              , yellow (show s.pending ++ " pending")
              ]
  let timing = if cfg.showTiming then " (" ++ formatDuration s.duration ++ ")" else ""
  putStrLn $ "  " ++ concat (intersperse ", " parts) ++ timing
