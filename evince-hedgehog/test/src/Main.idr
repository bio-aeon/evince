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

    it "reports the label, counterexample and recheck seed on failure" $ do
      Fail (Reason msg) <- liftIO $ runTestResultT $
                              runProperty "false property" (property1 $ diff 1 (==) (the Int 2))
        | _ => mustFail "expected Fail (Reason ...) from the bridge"
      msg `mustSatisfy` isInfixOf "false property"
      msg `mustSatisfy` isInfixOf "recheck"
      msg `mustSatisfy` isInfixOf "2"

    it "counts a failing property in the summary" $ do
      s <- liftIO $ runSpecWithSummary $ prop "fails" (property1 $ diff 1 (==) (the Int 2))
      s.failed `mustBe` 1
