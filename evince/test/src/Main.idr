module Main

import Evince
import Evince.AppSpec
import Evince.CoreSpec
import Evince.DiffSpec
import Evince.ExpectationsSpec
import Evince.HooksSpec
import Evince.JUnitSpec
import Evince.RunnerSpec
import Evince.SrcLocSpec

main : IO ()
main = runSpec $ do
  coreSpec
  expectationsSpec
  diffSpec
  appSpec
  hooksSpec
  junitSpec
  srcLocSpec
  runnerSpec
