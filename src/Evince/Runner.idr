module Evince.Runner

import Data.IORef
import System
import Evince.Core
import Evince.Reporter.Console

hasFocused : List SpecTree -> Bool
hasFocused [] = False
hasFocused (Focused _ :: _) = True
hasFocused (Describe _ children :: rest) = hasFocused children || hasFocused rest
hasFocused (WithCleanup _ children :: rest) = hasFocused children || hasFocused rest
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
filterFocused (WithCleanup cleanup children :: rest) =
  let filtered = filterFocused children
  in case filtered of
       [] => filterFocused rest
       _  => WithCleanup cleanup filtered :: filterFocused rest
filterFocused (_ :: rest) = filterFocused rest

applyFocus : List SpecTree -> List SpecTree
applyFocus trees = if hasFocused trees then filterFocused trees else trees

mutual
  evalTree : RunConfig -> IORef Bool -> SpecTree -> Nat -> IO Summary
  evalTree cfg abortRef (Describe label children) level = do
    printDescribe label level
    evalForest cfg abortRef children (S level)
  evalTree cfg abortRef (It label test) level = do
    abort <- readIORef abortRef
    if abort
      then pure neutral
      else do
        result <- test
        printTestResult label result level
        let s = case result of
              Pass _   => { passed := 1 } neutral
              Fail _   => { failed := 1 } neutral
              Skip _   => { pending := 1 } neutral
        when (cfg.failFast && s.failed > 0) (writeIORef abortRef True)
        pure s
  evalTree cfg abortRef (Pending label reason) level = do
    printPending label reason level
    pure $ { pending := 1 } neutral
  evalTree cfg abortRef (Focused tree) level = evalTree cfg abortRef tree level
  evalTree cfg abortRef (WithCleanup cleanup children) level = do
    s <- evalForest cfg abortRef children level
    cleanup
    pure s

  evalForest : RunConfig -> IORef Bool -> List SpecTree -> Nat -> IO Summary
  evalForest _ _ [] _ = pure neutral
  evalForest cfg abortRef (t :: ts) level = do
    abort <- readIORef abortRef
    if abort
      then pure neutral
      else do
        s1 <- evalTree cfg abortRef t level
        s2 <- evalForest cfg abortRef ts level
        pure (s1 <+> s2)

runWithConfig : RunConfig -> List SpecTree -> IO Summary
runWithConfig cfg trees = do
  abortRef <- newIORef False
  evalForest cfg abortRef (applyFocus trees) 0

||| Run a spec suite with custom configuration and return the summary.
export
runSpecWithSummaryAndConfig : RunConfig -> Spec () -> IO Summary
runSpecWithSummaryAndConfig cfg spec =
  runWithConfig cfg (getSpecTrees spec)

||| Run a spec suite and return the summary without exiting. Useful for
||| meta-testing (testing evince with evince).
export
runSpecWithSummary : Spec () -> IO Summary
runSpecWithSummary = runSpecWithSummaryAndConfig defaultConfig

||| Run a spec suite with custom configuration.
export
runSpecWith : RunConfig -> Spec () -> IO ()
runSpecWith cfg spec = do
  summary <- runWithConfig cfg (getSpecTrees spec)
  printSummary summary
  when (summary.failed > 0) exitFailure

||| Run a spec suite, print colored results, exit with code 1 if any test failed.
export
runSpec : Spec () -> IO ()
runSpec = runSpecWith defaultConfig

||| Run with fail-fast enabled — stop after the first failure.
export
runSpecFailFast : Spec () -> IO ()
runSpecFailFast = runSpecWith ({ failFast := True } defaultConfig)
