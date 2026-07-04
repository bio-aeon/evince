module Evince.Runner

import Data.IORef
import Data.List
import Data.String
import System
import System.Clock
import Evince.Config
import Evince.Core
import Evince.Random
import Evince.Report
import Evince.Reporter
import Evince.Reporter.Console
import Evince.Reporter.JUnit
import Evince.Rerun

hasFocused : List (SpecTree m a) -> Bool
hasFocused [] = False
hasFocused (Focused _ :: _) = True
hasFocused (Describe _ children :: rest) = hasFocused children || hasFocused rest
hasFocused (WithCleanup _ children :: rest) = hasFocused children || hasFocused rest
hasFocused (_ :: rest) = hasFocused rest

mutual
  filterFocused : List (SpecTree m a) -> List (SpecTree m a)
  filterFocused [] = []
  filterFocused (Focused t :: rest) = t :: filterFocused rest
  filterFocused (Describe label children :: rest) =
    focusedInto (Describe label) children (filterFocused rest)
  filterFocused (WithCleanup cleanup children :: rest) =
    focusedInto (WithCleanup cleanup) children (filterFocused rest)
  filterFocused (_ :: rest) = filterFocused rest

  focusedInto : (List (SpecTree m a) -> SpecTree m a) -> List (SpecTree m a) -> List (SpecTree m a) -> List (SpecTree m a)
  focusedInto wrap children rest =
    case filterFocused children of
      [] => rest
      filtered => wrap filtered :: rest

applyFocus : List (SpecTree m a) -> List (SpecTree m a)
applyFocus trees = if hasFocused trees then filterFocused trees else trees

-- Match-shaped selection: a matching group label selects its whole subtree;
-- otherwise recurse and keep the group only if some child survives.
filterByLabel : (keep : String -> Bool) -> List (SpecTree m a) -> List (SpecTree m a)
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
filterByLabel keep (Pending label reason :: rest) =
  if keep label
    then Pending label reason :: filterByLabel keep rest
    else filterByLabel keep rest
filterByLabel keep (Focused t :: rest) =
  case filterByLabel keep [t] of
    [t'] => Focused t' :: filterByLabel keep rest
    _    => filterByLabel keep rest
filterByLabel keep (WithCleanup cleanup children :: rest) =
  case filterByLabel keep children of
    [] => filterByLabel keep rest
    filtered => WithCleanup cleanup filtered :: filterByLabel keep rest

-- Skip-shaped exclusion: a matching label drops the node wholesale
-- (a matching group label skips its entire subtree); otherwise recurse.
dropByLabel : (matches : String -> Bool) -> List (SpecTree m a) -> List (SpecTree m a)
dropByLabel matches [] = []
dropByLabel matches (It label loc test :: rest) =
  if matches label
    then dropByLabel matches rest
    else It label loc test :: dropByLabel matches rest
dropByLabel matches (Describe label children :: rest) =
  if matches label
    then dropByLabel matches rest
    else case dropByLabel matches children of
           [] => dropByLabel matches rest
           filtered => Describe label filtered :: dropByLabel matches rest
dropByLabel matches (Pending label reason :: rest) =
  if matches label
    then dropByLabel matches rest
    else Pending label reason :: dropByLabel matches rest
dropByLabel matches (Focused t :: rest) =
  case dropByLabel matches [t] of
    [t'] => Focused t' :: dropByLabel matches rest
    _    => dropByLabel matches rest
dropByLabel matches (WithCleanup cleanup children :: rest) =
  case dropByLabel matches children of
    [] => dropByLabel matches rest
    filtered => WithCleanup cleanup filtered :: dropByLabel matches rest

filterByMatch : String -> List (SpecTree m a) -> List (SpecTree m a)
filterByMatch pat = filterByLabel (isInfixOf pat)

filterBySkip : String -> List (SpecTree m a) -> List (SpecTree m a)
filterBySkip pat = dropByLabel (isInfixOf pat)

filterByPaths : List String -> List String -> List (SpecTree m a) -> List (SpecTree m a)
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
filterByPaths paths ctx (Pending label reason :: rest) =
  if joinPath (ctx ++ [label]) `elem` paths
    then Pending label reason :: filterByPaths paths ctx rest
    else filterByPaths paths ctx rest
filterByPaths paths ctx (Focused t :: rest) =
  case filterByPaths paths ctx [t] of
    [t'] => Focused t' :: filterByPaths paths ctx rest
    _    => filterByPaths paths ctx rest
filterByPaths paths ctx (WithCleanup cleanup children :: rest) =
  case filterByPaths paths ctx children of
    [] => filterByPaths paths ctx rest
    filtered => WithCleanup cleanup filtered :: filterByPaths paths ctx rest

shuffleTrees : Nat -> List (SpecTree m a) -> List (SpecTree m a)
shuffleTrees seed [] = []
shuffleTrees seed trees = shuffle seed (go (nextSeed seed) trees)
  where
    goTree : Nat -> SpecTree m a -> SpecTree m a
    goTree s (Describe label children) = Describe label (shuffleTrees s children)
    goTree s (WithCleanup cleanup children) = WithCleanup cleanup (shuffleTrees s children)
    goTree s (Focused t) = Focused (goTree s t)
    goTree s t = t

    -- Thread the seed across siblings so same-length sibling groups
    -- don't get the same permutation.
    go : Nat -> List (SpecTree m a) -> List (SpecTree m a)
    go s [] = []
    go s (t :: ts) = goTree s t :: go (nextSeed s) ts

applyFilters : RunConfig -> List (SpecTree m a) -> List (SpecTree m a)
applyFilters cfg trees =
  let t1 = applyFocus trees
      t2 = maybe t1 (\p => filterByMatch p t1) cfg.match
      t3 = maybe t2 (\p => filterBySkip p t2) cfg.skip
      t4 = if cfg.randomize
             then let s = maybe 42 id cfg.seed in shuffleTrees s t3
             else t3
  in t4

||| A running tally: the summary counts plus the per-test reports collected
||| so far. Accumulated as the forest is evaluated.
public export
EvalResult : Type
EvalResult = (Summary, SnocList TestReport)

||| The empty tally - no counts and no reports - used as the starting
||| accumulator when folding results together.
export
emptyResult : EvalResult
emptyResult = (neutral, [<])

||| Combine two tallies, adding their summary counts and concatenating their
||| reports.
export
mergeResults : EvalResult -> EvalResult -> EvalResult
mergeResults (s1, r1) (s2, r2) = (s1 <+> s2, r1 ++ r2)

mutual
  ||| Evaluate one spec-tree node, emitting the matching reporter events and
  ||| returning its tally. Recurses through groups; runs and times each test,
  ||| honouring the abort flag (`--fail-fast`).
  export
  evalTree : HasIO m => Reporter m -> RunConfig -> IORef Bool -> List String -> SpecTree m () -> Nat -> m EvalResult
  evalTree reporter cfg abortRef path (Describe label children) level = do
    reporter.onEvent (GroupStarted label level)
    r <- evalForest reporter cfg abortRef (path ++ [label]) children (S level)
    reporter.onEvent (GroupDone label)
    pure r
  evalTree reporter cfg abortRef path (It label loc test) level = do
    abort <- liftIO (readIORef abortRef)
    if abort
      then pure emptyResult
      else do
        start <- liftIO (clockTime Monotonic)
        result <- test ()
        end <- liftIO (clockTime Monotonic)
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
        when (cfg.failFast && s.failed > 0) (liftIO (writeIORef abortRef True))
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

  ||| Evaluate a list of spec trees left to right, accumulating their tallies
  ||| and stopping early once the abort flag (`--fail-fast`) is set.
  export
  evalForest : HasIO m => Reporter m -> RunConfig -> IORef Bool -> List String -> List (SpecTree m ()) -> Nat -> m EvalResult
  evalForest _ _ _ _ [] _ = pure emptyResult
  evalForest reporter cfg abortRef path (t :: ts) level = do
    abort <- liftIO (readIORef abortRef)
    if abort
      then pure emptyResult
      else do
        r1 <- evalTree reporter cfg abortRef path t level
        r2 <- evalForest reporter cfg abortRef path ts level
        pure (mergeResults r1 r2)

||| Build the reporter for a run: the console reporter, combined with the
||| JUnit reporter when `--junit` is set. Colors are dropped when the
||| `NO_COLOR` environment variable is set.
export
makeReporter : HasIO m => RunConfig -> m (Reporter m)
makeReporter cfg0 = do
  noColor <- getEnv "NO_COLOR"
  let cfg = if maybe False (/= "") noColor then { color := False } cfg0 else cfg0
  let console = consoleReporter cfg
  case cfg.junitOutput of
    Just path => do
      junit <- junitReporter path
      pure (combineReporters [console, junit])
    Nothing => pure console

||| The paths of every failed test, for `--rerun` to replay next time.
export
failedPaths : SnocList TestReport -> List (List String)
failedPaths = foldl (\acc, r => case r.outcome of Failed _ _ => r.path :: acc; _ => acc) []

||| Run a suite's forest with a caller-supplied evaluator. Applies the CLI
||| filters and rerun selection, then brackets the evaluation with the
||| suite-started/done events.
export
runForestWith :
     HasIO m
  => Reporter m
  -> (eval : IORef Bool -> List (SpecTree m ()) -> m EvalResult)
  -> RunConfig
  -> List (SpecTree m ())
  -> m EvalResult
runForestWith reporter eval cfg trees = do
  let filtered = applyFilters cfg trees
  rerunFiltered <- if cfg.rerun
    then do
      Just failures <- liftIO readFailures
        | Nothing => pure filtered
      pure (filterByPaths failures [] filtered)
    else pure filtered
  abortRef <- liftIO (newIORef False)
  reporter.onEvent SuiteStarted
  r <- eval abortRef rerunFiltered
  reporter.onEvent (SuiteDone (fst r))
  pure r

-- Core runs sequentially. `cfg.jobs` is parsed and stored but ignored here;
-- a concurrent driver reads it to run groups concurrently.
runWithConfig : HasIO m => RunConfig -> List (SpecTree m ()) -> m EvalResult
runWithConfig cfg trees = do
  reporter <- makeReporter cfg
  runForestWith reporter (\abortRef, ts => evalForest reporter cfg abortRef [] ts 0) cfg trees

||| Run a spec suite with custom configuration and return the summary.
export
runSpecWithSummaryAndConfig : RunConfig -> Spec IO () () -> IO Summary
runSpecWithSummaryAndConfig cfg spec = do
  (summary, _) <- runWithConfig cfg (getSpecTrees spec)
  pure summary

||| Run a spec suite and return the summary without exiting. Useful for
||| meta-testing (testing evince with evince).
export
runSpecWithSummary : Spec IO () () -> IO Summary
runSpecWithSummary = runSpecWithSummaryAndConfig defaultConfig

||| Run a spec suite with custom configuration.
export
runSpecWith : RunConfig -> Spec IO () () -> IO ()
runSpecWith cfg spec = do
  (summary, reports) <- runWithConfig cfg (getSpecTrees spec)
  writeFailures (failedPaths reports)
  when (summary.failed > 0) exitFailure

||| Run a spec suite, print colored results, exit with code 1 if any test failed.
export
runSpec : Spec IO () () -> IO ()
runSpec = runSpecWith defaultConfig

||| Run with fail-fast enabled - stop after the first failure.
export
runSpecFailFast : Spec IO () () -> IO ()
runSpecFailFast = runSpecWith ({ failFast := True } defaultConfig)

||| Run with per-test timing displayed.
export
runSpecTimed : Spec IO () () -> IO ()
runSpecTimed = runSpecWith ({ showTiming := True } defaultConfig)

||| Run a spec suite, reading CLI args for configuration. `--help` prints the
||| flag reference and exits; unknown or invalid arguments warn on stderr.
export
runSpecWithArgs : Spec IO () () -> IO ()
runSpecWithArgs spec = do
  args <- getArgs
  cfg <- handleArgs (drop 1 args)
  runSpecWith cfg spec
