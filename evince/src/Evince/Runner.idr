module Evince.Runner

import Data.IORef
import Data.List
import Data.String
import System
import System.Clock
import System.Concurrency
import Evince.Config
import Evince.Core
import Evince.Parallel
import Evince.Random
import Evince.Report
import Evince.Reporter
import Evince.Reporter.Console
import Evince.Reporter.JUnit
import Evince.Rerun

hasFocused : List (SpecTree a) -> Bool
hasFocused [] = False
hasFocused (Focused _ :: _) = True
hasFocused (Describe _ children :: rest) = hasFocused children || hasFocused rest
hasFocused (WithCleanup _ children :: rest) = hasFocused children || hasFocused rest
hasFocused (_ :: rest) = hasFocused rest

mutual
  filterFocused : List (SpecTree a) -> List (SpecTree a)
  filterFocused [] = []
  filterFocused (Focused t :: rest) = t :: filterFocused rest
  filterFocused (Describe label children :: rest) =
    focusedInto (Describe label) children (filterFocused rest)
  filterFocused (WithCleanup cleanup children :: rest) =
    focusedInto (WithCleanup cleanup) children (filterFocused rest)
  filterFocused (_ :: rest) = filterFocused rest

  focusedInto : (List (SpecTree a) -> SpecTree a) -> List (SpecTree a) -> List (SpecTree a) -> List (SpecTree a)
  focusedInto wrap children rest =
    case filterFocused children of
      [] => rest
      filtered => wrap filtered :: rest

applyFocus : List (SpecTree a) -> List (SpecTree a)
applyFocus trees = if hasFocused trees then filterFocused trees else trees

filterByLabel : (keep : String -> Bool) -> List (SpecTree a) -> List (SpecTree a)
filterByLabel keep [] = []
filterByLabel keep (It label loc test :: rest) =
  if keep label
    then It label loc test :: filterByLabel keep rest
    else filterByLabel keep rest
filterByLabel keep (Describe label children :: rest) =
  if keep label
    then Describe label children :: filterByLabel keep rest
    else let filtered = filterByLabel keep children
         in case filtered of
              [] => filterByLabel keep rest
              _  => Describe label filtered :: filterByLabel keep rest
filterByLabel keep (Focused t :: rest) =
  case filterByLabel keep [t] of
    [t'] => Focused t' :: filterByLabel keep rest
    _    => filterByLabel keep rest
filterByLabel keep (t :: rest) = t :: filterByLabel keep rest

filterByMatch : String -> List (SpecTree a) -> List (SpecTree a)
filterByMatch pat = filterByLabel (isInfixOf pat)

filterBySkip : String -> List (SpecTree a) -> List (SpecTree a)
filterBySkip pat = filterByLabel (not . isInfixOf pat)

joinPath : List String -> String
joinPath = concat . intersperse "."

filterByPaths : List String -> List String -> List (SpecTree a) -> List (SpecTree a)
filterByPaths _ _ [] = []
filterByPaths paths ctx (It label loc test :: rest) =
  if joinPath (ctx ++ [label]) `elem` paths
    then It label loc test :: filterByPaths paths ctx rest
    else filterByPaths paths ctx rest
filterByPaths paths ctx (Describe label children :: rest) =
  let filtered = filterByPaths paths (ctx ++ [label]) children
  in case filtered of
       [] => filterByPaths paths ctx rest
       _  => Describe label filtered :: filterByPaths paths ctx rest
filterByPaths paths ctx (Focused t :: rest) =
  case filterByPaths paths ctx [t] of
    [t'] => Focused t' :: filterByPaths paths ctx rest
    _    => filterByPaths paths ctx rest
filterByPaths paths ctx (t :: rest) = t :: filterByPaths paths ctx rest

shuffleTrees : Nat -> List (SpecTree a) -> List (SpecTree a)
shuffleTrees seed [] = []
shuffleTrees seed trees = shuffle seed (map go trees)
  where
    go : SpecTree a -> SpecTree a
    go (Describe label children) = Describe label (shuffleTrees seed children)
    go (WithCleanup cleanup children) = WithCleanup cleanup (shuffleTrees seed children)
    go (Focused t) = Focused (go t)
    go t = t

applyFilters : RunConfig -> List (SpecTree a) -> List (SpecTree a)
applyFilters cfg trees =
  let t1 = applyFocus trees
      t2 = maybe t1 (\p => filterByMatch p t1) cfg.match
      t3 = maybe t2 (\p => filterBySkip p t2) cfg.skip
      t4 = if cfg.randomize
             then let s = maybe 42 id cfg.seed in shuffleTrees s t3
             else t3
  in t4

EvalResult : Type
EvalResult = (Summary, SnocList TestReport)

emptyResult : EvalResult
emptyResult = (neutral, [<])

mergeResults : EvalResult -> EvalResult -> EvalResult
mergeResults (s1, r1) (s2, r2) = (s1 <+> s2, r1 ++ r2)

mutual
  evalTree : Reporter -> RunConfig -> IORef Bool -> List String -> SpecTree () -> Nat -> IO EvalResult
  evalTree reporter cfg abortRef path (Describe label children) level = do
    reporter.onEvent (GroupStarted label level)
    r <- evalForest reporter cfg abortRef (path ++ [label]) children (S level)
    reporter.onEvent (GroupDone label)
    pure r
  evalTree reporter cfg abortRef path (It label loc test) level = do
    abort <- readIORef abortRef
    if abort
      then pure emptyResult
      else do
        start <- clockTime Monotonic
        result <- test ()
        end <- clockTime Monotonic
        let elapsed = toNano (timeDifference end start)
        let testPath = path ++ [label]
        let s = case result of
              Pass _   => { passed := 1, duration := elapsed } neutral
              Fail _   => { failed := 1, duration := elapsed } neutral
              Skip _   => { pending := 1 } neutral
        let report = case result of
              Pass _      => MkTestReport testPath loc (Passed elapsed)
              Fail info   => MkTestReport testPath loc (Failed info elapsed)
              Skip reason => MkTestReport testPath loc (Skipped reason)
        reporter.onEvent (TestDone report level)
        when (cfg.failFast && s.failed > 0) (writeIORef abortRef True)
        pure (s, [< report])
  evalTree reporter cfg abortRef path (Pending label reason) level = do
    reporter.onEvent (PendingTest label reason level)
    let report = MkTestReport (path ++ [label]) Nothing (Skipped reason)
    pure ({ pending := 1 } neutral, [< report])
  evalTree reporter cfg abortRef path (Focused tree) level =
    evalTree reporter cfg abortRef path tree level
  evalTree reporter cfg abortRef path (WithCleanup cleanup children) level = do
    r <- evalForest reporter cfg abortRef path children level
    cleanup
    pure r

  evalForest : Reporter -> RunConfig -> IORef Bool -> List String -> List (SpecTree ()) -> Nat -> IO EvalResult
  evalForest _ _ _ _ [] _ = pure emptyResult
  evalForest reporter cfg abortRef path (t :: ts) level = do
    abort <- readIORef abortRef
    if abort
      then pure emptyResult
      else do
        r1 <- evalTree reporter cfg abortRef path t level
        r2 <- evalForest reporter cfg abortRef path ts level
        pure (mergeResults r1 r2)

makeReporter : RunConfig -> IO Reporter
makeReporter cfg = do
  let console = consoleReporter cfg
  case cfg.junitOutput of
    Just path => do
      junit <- junitReporter path
      pure (combineReporters [console, junit])
    Nothing => pure console

threadSafeReporter : Reporter -> IO Reporter
threadSafeReporter r = do
  m <- makeMutex
  pure $ MkReporter $ \e => do
    mutexAcquire m
    r.onEvent e
    mutexRelease m

collectResults : Channel EvalResult -> Nat -> EvalResult -> IO EvalResult
collectResults _ Z acc = pure acc
collectResults chan (S k) acc = do
  r <- channelGet chan
  collectResults chan k (mergeResults acc r)

evalParallel : Reporter -> RunConfig -> List (SpecTree ()) -> IO EvalResult
evalParallel reporter cfg trees = do
  chan <- makeChannel
  abortRef <- newIORef False
  let n = length trees
  for_ trees $ \tree =>
    forkIO $ do
      r <- tryIO (evalTree reporter cfg abortRef [] tree 0) (pure emptyResult)
      channelPut chan r
  collectResults chan n emptyResult

failedPaths : SnocList TestReport -> List (List String)
failedPaths = foldl (\acc, r => case r.outcome of Failed _ _ => r.path :: acc; _ => acc) []

runWithConfig : RunConfig -> List (SpecTree ()) -> IO EvalResult
runWithConfig cfg trees = do
  let filtered = applyFilters cfg trees
  rerunFiltered <- if cfg.rerun
    then do
      Just failures <- readFailures
        | Nothing => pure filtered
      pure (filterByPaths failures [] filtered)
    else pure filtered
  baseReporter <- makeReporter cfg
  reporter <- if cfg.jobs > 0
    then threadSafeReporter baseReporter
    else pure baseReporter
  abortRef <- newIORef False
  reporter.onEvent SuiteStarted
  r <- if cfg.jobs > 0
    then evalParallel reporter cfg rerunFiltered
    else evalForest reporter cfg abortRef [] rerunFiltered 0
  reporter.onEvent (SuiteDone (fst r))
  pure r

||| Run a spec suite with custom configuration and return the summary.
export
runSpecWithSummaryAndConfig : RunConfig -> Spec () () -> IO Summary
runSpecWithSummaryAndConfig cfg spec = do
  (summary, _) <- runWithConfig cfg (getSpecTrees spec)
  pure summary

||| Run a spec suite and return the summary without exiting. Useful for
||| meta-testing (testing evince with evince).
export
runSpecWithSummary : Spec () () -> IO Summary
runSpecWithSummary = runSpecWithSummaryAndConfig defaultConfig

||| Run a spec suite with custom configuration.
export
runSpecWith : RunConfig -> Spec () () -> IO ()
runSpecWith cfg spec = do
  (summary, reports) <- runWithConfig cfg (getSpecTrees spec)
  writeFailures (failedPaths reports)
  when (summary.failed > 0) exitFailure

||| Run a spec suite, print colored results, exit with code 1 if any test failed.
export
runSpec : Spec () () -> IO ()
runSpec = runSpecWith defaultConfig

||| Run with fail-fast enabled — stop after the first failure.
export
runSpecFailFast : Spec () () -> IO ()
runSpecFailFast = runSpecWith ({ failFast := True } defaultConfig)

||| Run with per-test timing displayed.
export
runSpecTimed : Spec () () -> IO ()
runSpecTimed = runSpecWith ({ showTiming := True } defaultConfig)

||| Run a spec suite, reading CLI args for configuration.
export
runSpecWithArgs : Spec () () -> IO ()
runSpecWithArgs spec = do
  args <- getArgs
  let cfg = parseArgs (drop 1 args)
  runSpecWith cfg spec
