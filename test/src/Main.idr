module Main

import Evince
import Evince.CoreSpec
import Evince.ExpectationsSpec
import Evince.HooksSpec
import Evince.RunnerSpec

main : IO ()
main = runSpec $ do
  coreSpec
  expectationsSpec
  hooksSpec
  runnerSpec
