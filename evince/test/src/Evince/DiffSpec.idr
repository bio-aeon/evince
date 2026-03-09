module Evince.DiffSpec

import Evince
import Evince.Diff

hasRemoved : String -> List LineDiff -> Bool
hasRemoved s = any (== LineRemoved s)

hasAdded : String -> List LineDiff -> Bool
hasAdded s = any (== LineAdded s)

export
diffSpec : Spec () ()
diffSpec = describe "Structural diffs" $ do
  describe "structuralDiff" $ do
    it "returns Nothing when both values are identical" $
      mustBeNothing (structuralDiff "MkPoint 1 2" "MkPoint 1 2")

    it "returns Nothing when values cannot be parsed" $
      mustBeNothing (structuralDiff "not a value !!!" "also not !!!")

    it "produces removed and added lines for one-liner constructor diff" $ do
      let Just diffs = structuralDiff "MkPoint 1 2" "MkPoint 1 3"
            | Nothing => mustFail "expected diff but got Nothing"
      diffs `mustSatisfy` hasRemoved "MkPoint 1 2"
      diffs `mustSatisfy` hasAdded "MkPoint 1 3"

    it "produces removed and added lines for list diff" $ do
      let Just diffs = structuralDiff "[1, 2, 3]" "[1, 4, 3]"
            | Nothing => mustFail "expected diff but got Nothing"
      diffs `mustSatisfy` hasRemoved "[1, 2, 3]"
      diffs `mustSatisfy` hasAdded "[1, 4, 3]"

    it "produces removed and added lines for nested constructor diff" $ do
      let Just diffs = structuralDiff "Just (Left 1)" "Just (Right 2)"
            | Nothing => mustFail "expected diff but got Nothing"
      diffs `mustSatisfy` hasRemoved "Just (Left 1)"
      diffs `mustSatisfy` hasAdded "Just (Right 2)"

    it "produces element-level diff for multi-line records" $ do
      let expected = "MkUser {firstName = \"Alice\", lastName = \"Wonderland\", age = 30, email = \"alice.wonderland@example.com\"}"
      let actual   = "MkUser {firstName = \"Alice\", lastName = \"Wonderland\", age = 25, email = \"alice.wonderland@example.com\"}"
      let Just diffs = structuralDiff expected actual
            | Nothing => mustFail "expected diff but got Nothing"
      diffs `mustSatisfy` hasRemoved "      30"
      diffs `mustSatisfy` hasAdded "      25"
      diffs `mustContain` [LineSame "    firstName ="]
