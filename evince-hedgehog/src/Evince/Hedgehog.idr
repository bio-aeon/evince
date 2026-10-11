module Evince.Hedgehog

import Evince.Core
import Evince.Expectations
import Evince.Spec
import Hedgehog

%default covering

||| Run a property silently as a `TestResultT IO` chain. A failure carries
||| hedgehog's report - the shrunk counterexample, diff and recheck seed -
||| under the given test label.
export
runProperty : String -> Property -> TestResultT IO ()
runProperty label p = do
  seed <- liftIO initSeed
  rep  <- liftIO $ checkReport p.config Nothing seed p.test (\_ => pure ())
  case rep.status of
    OK       => pure ()
    Failed _ => mustFail (renderResult DisableColor (Just (fromString label)) rep)

||| Embed a hedgehog Property as an evince test case.
export
prop : HasIO m => String -> Property -> Spec m a ()
prop label p = it label (runProperty label p)

||| Embed a PropertyT action (wraps in `property`).
export
itProp : HasIO m => String -> PropertyT () -> Spec m a ()
itProp label = prop label . property

||| Embed a single-run property (wraps in `property1`).
export
itProp1 : HasIO m => String -> PropertyT () -> Spec m a ()
itProp1 label = prop label . property1
