module Main

import Evince
import Evince.Hedgehog
import Hedgehog

main : IO ()
main = runSpec $ do
  describe "evince-hedgehog" $ do
    itProp1 "passes a trivially true property" $ do
      diff 1 (==) (the Int 1)

    itProp "passes a generated property" $ do
      x <- forAll $ int (linear 0 100)
      diff (x + 0) (==) x

    itIO "reports failure for a false property" $ do
      passed <- check (property1 $ diff 1 (==) (the Int 2))
      pure $ passed `mustBe` False
