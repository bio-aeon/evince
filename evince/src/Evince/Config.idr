module Evince.Config

import Data.String
import Evince.Core

parseNat : String -> Maybe Nat
parseNat s = do
  n <- parseInteger {a = Integer} s
  if n >= 0 then Just (cast n) else Nothing

applyArg : RunConfig -> String -> RunConfig
applyArg cfg "--fail-fast"  = { failFast  := True } cfg
applyArg cfg "--randomize"  = { randomize := True } cfg
applyArg cfg "--times"      = { showTiming := True } cfg
applyArg cfg arg =
  let (key, rest) = break (== '=') arg
      val = substr 1 (length rest) rest
  in if val == "" then cfg
     else case key of
       "--match" => { match := Just val } cfg
       "--skip"  => { skip  := Just val } cfg
       "--seed"  => { seed  := parseNat val } cfg
       "--junit" => { junitOutput := Just val } cfg
       _         => cfg

||| Parse command-line arguments into a RunConfig.
export
parseArgs : List String -> RunConfig
parseArgs = foldl applyArg defaultConfig
