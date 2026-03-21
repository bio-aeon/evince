module Evince.SrcLocSpec

import Evince
import Language.Reflection

%language ElabReflection

extractLoc : Spec () () -> Maybe SrcLoc
extractLoc spec = case getSpecTrees spec of
  [It _ loc _] => loc
  _ => Nothing

locSpec : Spec () ()
locSpec = itLoc `(()) "test" $ 1 `mustBe` 1

noLocSpec : Spec () ()
noLocSpec = it "test" $ 1 `mustBe` 1

export
srcLocSpec : Spec () ()
srcLocSpec = describe "source locations" $ do
  describe "itLoc" $ do
    it "captures a source location" $
      mustBeJust (extractLoc locSpec)

    it "captured file contains the module path" $
      case extractLoc locSpec of
        Just loc => loc.file `mustSatisfy` (isInfixOf "SrcLocSpec")
        Nothing => mustFail "expected SrcLoc"

    it "captured line is positive" $
      case extractLoc locSpec of
        Just loc => loc.line `mustSatisfy` (> 0)
        Nothing => mustFail "expected SrcLoc"

  describe "it" $ do
    it "has no source location" $
      mustBeNothing (extractLoc noLocSpec)
