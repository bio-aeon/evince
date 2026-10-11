module Evince.AppSpec

import Control.App
import Evince

isFail : TestResult a -> Bool
isFail (Fail _) = True
isFail _        = False

export
appSpec : Spec IO () ()
appSpec = describe "App bridge" $ do
  describe "tryApp" $ do
    it "returns Left on error" $ do
      let act : App (String :: Init) Nat = throw "boom"
      r <- liftIO $ tryApp act
      mustBeLeft r

    it "returns Right on success" $ do
      let act : App (String :: Init) Nat = pure 42
      r <- liftIO $ tryApp act
      r `mustBe` Right 42

  describe "mustError" $ do
    it "passes when the computation throws" $ do
      let act : App (String :: Init) Nat = throw "boom"
      mustError act

    it "fails when the computation succeeds" $ do
      let act : App (String :: Init) Nat = pure 42
      r <- liftIO $ runTestResultT (mustError act)
      r `mustSatisfy` isFail

  describe "mustErrorWith" $ do
    it "passes when the error matches" $ do
      let act : App (String :: Init) Nat = throw "boom"
      mustErrorWith act "boom"

    it "fails when the error does not match" $ do
      let act : App (String :: Init) Nat = throw "oops"
      r <- liftIO $ runTestResultT (mustErrorWith act "boom")
      r `mustSatisfy` isFail

    it "fails when the computation succeeds" $ do
      let act : App (String :: Init) Nat = pure 42
      r <- liftIO $ runTestResultT (mustErrorWith act "boom")
      r `mustSatisfy` isFail
