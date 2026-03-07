module Evince.Reporter.JUnit

import Data.List
import Data.String
import System.File
import Evince.Core
import Evince.Report

escape : String -> String
escape = concatMap escChar . unpack
  where
    escChar : Char -> String
    escChar '&'  = "&amp;"
    escChar '<'  = "&lt;"
    escChar '>'  = "&gt;"
    escChar '"'  = "&quot;"
    escChar '\'' = "&apos;"
    escChar c    = singleton c

splitLast : List String -> (List String, String)
splitLast [] = ([], "")
splitLast [x] = ([], x)
splitLast (x :: xs) = let (pre, l) = splitLast xs in (x :: pre, l)

classname : List String -> String
classname path = concat (intersperse "." (fst (splitLast path)))

testName : List String -> String
testName path = snd (splitLast path)

renderTestCase : TestReport -> String
renderTestCase report =
  let cn   = escape (classname report.path)
      name = escape (testName report.path)
  in case report.outcome of
       Passed elapsed =>
         "    <testcase name=\"" ++ name ++ "\" classname=\"" ++ cn
           ++ "\" time=\"" ++ nanosToSeconds elapsed ++ "\"/>\n"
       Failed info elapsed =>
         "    <testcase name=\"" ++ name ++ "\" classname=\"" ++ cn
           ++ "\" time=\"" ++ nanosToSeconds elapsed ++ "\">\n"
           ++ "      <failure message=\"" ++ escape (show info) ++ "\"/>\n"
           ++ "    </testcase>\n"
       Skipped reason =>
         "    <testcase name=\"" ++ name ++ "\" classname=\"" ++ cn ++ "\">\n"
           ++ "      <skipped"
           ++ maybe "/>\n" (\r => " message=\"" ++ escape r ++ "\"/>\n") reason
           ++ "    </testcase>\n"

countFailures : List TestReport -> Nat
countFailures = foldl (\acc, r => case r.outcome of Failed _ _ => S acc; _ => acc) 0

countSkipped : List TestReport -> Nat
countSkipped = foldl (\acc, r => case r.outcome of Skipped _ => S acc; _ => acc) 0

totalTime : List TestReport -> Integer
totalTime = foldl (\acc, r => case r.outcome of
  Passed e => acc + e; Failed _ e => acc + e; Skipped _ => acc) 0

||| Render test reports as a JUnit XML string.
export
renderXml : List TestReport -> String
renderXml reports =
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    ++ "<testsuites>\n"
    ++ "  <testsuite name=\"evince\" tests=\"" ++ show (length reports)
    ++ "\" failures=\"" ++ show (countFailures reports)
    ++ "\" skipped=\"" ++ show (countSkipped reports)
    ++ "\" time=\"" ++ nanosToSeconds (totalTime reports) ++ "\">\n"
    ++ concatMap renderTestCase reports
    ++ "  </testsuite>\n"
    ++ "</testsuites>\n"

||| Write test results as JUnit XML to the given file path.
export
writeJUnitXml : String -> List TestReport -> IO ()
writeJUnitXml filepath reports = do
  Right () <- writeFile filepath (renderXml reports)
    | Left err => putStrLn $ "Error writing JUnit XML: " ++ show err
  pure ()
