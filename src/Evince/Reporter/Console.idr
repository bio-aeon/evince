module Evince.Reporter.Console

import Data.List
import Data.String
import Evince.Core

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

||| Print the result of a single test case.
export
printTestResult : String -> TestResult () -> Nat -> IO ()
printTestResult label (Pass ()) level =
  putStrLn $ indent level ++ green ("✓ " ++ label)
printTestResult label (Fail info) level = do
  putStrLn $ indent level ++ red ("✗ " ++ label)
  let detailIndent = indent (S level)
  for_ (lines (show info)) $ \line =>
    putStrLn $ detailIndent ++ red line
printTestResult label (Skip reason) level =
  printPending label reason level

||| Print the final summary line.
export
printSummary : Summary -> IO ()
printSummary s = do
  putStrLn ""
  let parts = [ green (show s.passed ++ " passing")
              , red (show s.failed ++ " failing")
              , yellow (show s.pending ++ " pending")
              ]
  putStrLn $ "  " ++ concat (intersperse ", " parts)
