module Main

import Evince
import Evince.AppSpec
import Evince.CoreSpec
import Evince.ExpectationsSpec
import Evince.HooksSpec
import Evince.JUnitSpec
import Evince.RunnerSpec

main : IO ()
main = runSpec $ do
  coreSpec
  expectationsSpec
  appSpec
  hooksSpec
  junitSpec
  runnerSpec
