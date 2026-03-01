module Evince.Runner

import System
import Evince.Core
import Evince.Reporter.Console

hasFocused : List SpecTree -> Bool
hasFocused [] = False
hasFocused (Focused _ :: _) = True
hasFocused (Describe _ children :: rest) = hasFocused children || hasFocused rest
hasFocused (_ :: rest) = hasFocused rest

-- Keep only focused branches. Describe nodes are kept if they contain
-- focused children (recursively), but their non-focused children are pruned.
filterFocused : List SpecTree -> List SpecTree
filterFocused [] = []
filterFocused (Focused t :: rest) = t :: filterFocused rest
filterFocused (Describe label children :: rest) =
  let filtered = filterFocused children
  in case filtered of
       [] => filterFocused rest
       _  => Describe label filtered :: filterFocused rest
filterFocused (_ :: rest) = filterFocused rest

mutual
  evalTree : SpecTree -> Nat -> IO Summary
  evalTree (Describe label children) level = do
    printDescribe label level
    evalForest children (S level)
  evalTree (It label test) level = do
    result <- test
    printTestResult label result level
    pure $ case result of
      Pass _   => { passed := 1 } neutral
      Fail _   => { failed := 1 } neutral
      Skip _   => { pending := 1 } neutral
  evalTree (Pending label reason) level = do
    printPending label reason level
    pure $ { pending := 1 } neutral
  evalTree (Focused tree) level = evalTree tree level

  evalForest : List SpecTree -> Nat -> IO Summary
  evalForest [] _ = pure neutral
  evalForest (t :: ts) level = do
    s1 <- evalTree t level
    s2 <- evalForest ts level
    pure (s1 <+> s2)

||| Run a spec suite, print colored results, exit with code 1 if any test failed.
export
runSpec : Spec () -> IO ()
runSpec spec = do
  let trees = getSpecTrees spec
  let trees' = if hasFocused trees then filterFocused trees else trees
  summary <- evalForest trees' 0
  printSummary summary
  when (summary.failed > 0) exitFailure

||| Run a spec suite and return the summary without exiting. Useful for
||| meta-testing (testing evince with evince).
export
runSpecWithSummary : Spec () -> IO Summary
runSpecWithSummary spec = do
  let trees = getSpecTrees spec
  let trees' = if hasFocused trees then filterFocused trees else trees
  evalForest trees' 0
