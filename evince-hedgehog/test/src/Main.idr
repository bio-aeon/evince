module Main

import Data.String
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

    itIO "reports the label, counterexample and recheck seed on failure" $ do
      Fail (Reason msg) <- runProperty "false property" (property1 $ diff 1 (==) (the Int 2))
        | _ => pure (Fail (Reason "expected Fail (Reason ...) from the bridge"))
      pure $ do
        msg `mustSatisfy` isInfixOf "false property"
        msg `mustSatisfy` isInfixOf "recheck"
        msg `mustSatisfy` isInfixOf "2"

    itIO "counts a failing property in the summary" $ do
      s <- runSpecWithSummary $ prop "fails" (property1 $ diff 1 (==) (the Int 2))
      pure $ s.failed `mustBe` 1
