module Main

import Evince
import Evince.Async.DriverSpec
import Evince.Async.ConcurrentSpec

main : IO ()
main = runSpec $ do
  driverSpec
  concurrentSpec
