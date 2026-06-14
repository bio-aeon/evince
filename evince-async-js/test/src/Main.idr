module Main

import Evince
import Evince.Async.JS.ConcurrentSpec

main : IO ()
main = runSpec jsSpec
