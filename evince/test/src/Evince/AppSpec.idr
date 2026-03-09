module Evince.AppSpec

import Control.App
import Evince

isFail : TestResult a -> Bool
isFail (Fail _) = True
isFail _        = False

export
appSpec : Spec () ()
appSpec = describe "App bridge" $ do
  describe "tryApp" $ do
    itIO "returns Left on error" $ do
      let act : App (String :: Init) Nat = throw "boom"
      r <- tryApp act
      pure $ mustBeLeft r

    itIO "returns Right on success" $ do
      let act : App (String :: Init) Nat = pure 42
      r <- tryApp act
      pure $ r `mustBe` Right 42

  describe "mustError" $ do
    itIO "passes when the computation throws" $ do
      let act : App (String :: Init) Nat = throw "boom"
      mustError act

    itIO "fails when the computation succeeds" $ do
      let act : App (String :: Init) Nat = pure 42
      r <- mustError act
      pure $ r `mustSatisfy` isFail

  describe "mustErrorWith" $ do
    itIO "passes when the error matches" $ do
      let act : App (String :: Init) Nat = throw "boom"
      mustErrorWith act "boom"

    itIO "fails when the error does not match" $ do
      let act : App (String :: Init) Nat = throw "oops"
      r <- mustErrorWith act "boom"
      pure $ r `mustSatisfy` isFail

    itIO "fails when the computation succeeds" $ do
      let act : App (String :: Init) Nat = pure 42
      r <- mustErrorWith act "boom"
      pure $ r `mustSatisfy` isFail
