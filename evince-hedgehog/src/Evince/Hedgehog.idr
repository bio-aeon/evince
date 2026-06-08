module Evince.Hedgehog

import Evince.Core
import Evince.Spec
import Hedgehog

%default covering

runProperty : Property -> IO (TestResult ())
runProperty p = do
  passed <- check p
  pure $ if passed
    then Pass ()
    else Fail (Reason "property check failed")

||| Embed a hedgehog Property as an evince test case.
export
prop : HasIO m => String -> Property -> Spec m a ()
prop label p = itIO label (runProperty p)

||| Embed a PropertyT action (wraps in `property`).
export
itProp : HasIO m => String -> PropertyT () -> Spec m a ()
itProp label = prop label . property

||| Embed a single-run property (wraps in `property1`).
export
itProp1 : HasIO m => String -> PropertyT () -> Spec m a ()
itProp1 label = prop label . property1
