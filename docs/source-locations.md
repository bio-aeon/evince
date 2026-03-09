# Source Locations

Use `itLoc` to capture the source file and line of a test definition. On failure,
the location is shown next to the test name:

```idris
import Language.Reflection
%language ElabReflection

spec : Spec () ()
spec = describe "Parser" $ do
  itLoc `(()) "parses integers" $
    parse "42" `mustBe` Right 42

  it "also works without location" $    -- regular `it` still works
    (1 + 1) `mustBe` 2
```

```
  ✗ parses integers (Parser.idr:7)
    not equal
    ...
```

`itIOLoc` is the IO variant. Both require `import Language.Reflection` and
`%language ElabReflection` in the test module.

## How It Works

`itLoc` is a `%macro` that takes a dummy `TTImp` argument. The user passes a
quasiquoted unit value `` `(()) ``. The compiler quotes this at the call site,
embedding the call-site's `FC` (File Context) in the TTImp node. The macro
extracts the FC via `getFC` and converts it to a `SrcLoc` with `fcToSrcLoc`.

This is the only reliable way to capture call-site locations in Idris 2 — a
zero-arg macro inside a do-block sees `EmptyFC` because the goal type comes from
`>>=` chain desugaring, not from the source.

## Limitations

A `%macro` call cannot be the last expression in a do-block (Idris 2 elaborator
limitation). In practice this is rarely an issue since spec blocks typically have
multiple tests.
