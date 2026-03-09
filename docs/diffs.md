# Structural Diffs

When `mustBe` or `mustEqual` fail on complex values (records, nested constructors),
evince shows a colored structural diff instead of raw expected/actual output:

```
  ✗ returns the updated user
    not equal
      MkUser {
          firstName =
            "Alice"
        , lastName =
            "Wonderland"
        , age =
    -       30
    +       25
        , email =
            "alice@example.com"
      }
```

Removed lines are shown in red (`-`), added lines in green (`+`), unchanged
lines without prefix.

For simple one-liner values, the diff shows the full expected/actual as
removed/added lines. If a value can't be structurally parsed (via
`Text.Show.Pretty`), evince falls back to the standard `expected: ... actual: ...`
format.

In JUnit XML output, diffs are rendered as plain text (no ANSI colors) inside
the `<failure>` element.
