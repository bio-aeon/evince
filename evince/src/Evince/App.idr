module Evince.App

import Control.App
import Evince.Core
import Evince.Expectations

||| Run an App computation, capturing the typed error as Either.
export covering
tryApp : App (err :: Init) a -> IO (Either err a)
tryApp act = run $ handle act (\ok => pure (Right ok)) (\e => pure (Left e))

||| Passes if the App computation produces an error of the expected type.
export covering
mustError : Show err => App (err :: Init) a -> IO (TestResult ())
mustError act = do
  result <- tryApp act
  case result of
    Left _  => pure (Pass ())
    Right _ => pure (Fail (Reason "expected error but succeeded"))

||| Passes if the App computation produces the specific error value.
export covering
mustErrorWith : (Show err, DecEq err) => App (err :: Init) a -> err -> IO (TestResult ())
mustErrorWith act expected = do
  result <- tryApp act
  case result of
    Left e  => pure (e `mustBe` expected)
    Right _ => pure (Fail (Reason "expected error but succeeded"))
