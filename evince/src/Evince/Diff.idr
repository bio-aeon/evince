module Evince.Diff

import public Text.Show.Diff
import Text.Show.Pretty
import Evince.Core

||| Render a single LineDiff as plain text with a two-character prefix.
export
renderLineDiffPlain : LineDiff -> String
renderLineDiffPlain (LineSame x)    = "  " ++ x
renderLineDiffPlain (LineRemoved x) = "- " ++ x
renderLineDiffPlain (LineAdded x)   = "+ " ++ x

||| Compute a structural diff between two Show-output strings. Returns Nothing
||| if either value can't be parsed or if they are structurally identical.
export
structuralDiff : (expected : String) -> (actual : String) -> Maybe (List LineDiff)
structuralDiff expected actual = do
  ve <- parseValue expected
  va <- parseValue actual
  guard (ve /= va)
  Just $ toLineDiff (valueDiff ve va)

||| Try to extract a structural diff from a FailureInfo. Returns the reason and
||| diff lines for ExpectedButGot failures that can be structurally parsed,
||| Nothing otherwise.
export
failureDiff : FailureInfo -> Maybe (String, List LineDiff)
failureDiff (ExpectedButGot reason expected actual) = do
  diffs <- structuralDiff expected actual
  Just (reason, diffs)
failureDiff _ = Nothing
