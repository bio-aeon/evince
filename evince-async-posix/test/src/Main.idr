module Main

import Evince
import Evince.Async.Posix.ParallelSpec

main : IO ()
main = runSpec posixSpec
