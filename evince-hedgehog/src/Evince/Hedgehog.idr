module Evince.Hedgehog

import Evince.Core
import Evince.Spec
import Hedgehog

%default covering

||| Run a property silently and return the outcome as a TestResult. A failure
||| carries hedgehog's report - the shrunk counterexample, diff and recheck
||| seed - under the given test label.
export
runProperty : String -> Property -> IO (TestResult ())
runProperty label p = do
  seed <- initSeed
  rep  <- checkReport p.config Nothing seed p.test (\_ => pure ())
  pure $ case rep.status of
    OK       => Pass ()
    Failed _ => Fail (Reason (renderResult DisableColor (Just (fromString label)) rep))

||| Embed a hedgehog Property as an evince test case.
export
prop : HasIO m => String -> Property -> Spec m a ()
prop label p = itIO label (runProperty label p)

||| Embed a PropertyT action (wraps in `property`).
export
itProp : HasIO m => String -> PropertyT () -> Spec m a ()
itProp label = prop label . property

||| Embed a single-run property (wraps in `property1`).
export
itProp1 : HasIO m => String -> PropertyT () -> Spec m a ()
itProp1 label = prop label . property1
