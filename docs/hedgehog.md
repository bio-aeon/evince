# Property Testing with Hedgehog

The `evince-hedgehog` package integrates [idris2-hedgehog](https://github.com/stefan-hoeck/idris2-hedgehog)
property tests into evince's spec tree.

## Installation

`evince-hedgehog` is available in the
[pack](https://github.com/stefan-hoeck/idris2-pack) package collection.
Add it to your test package's `depends`:

```
depends = evince, evince-hedgehog
```

## Usage

```idris
import Evince
import Evince.Hedgehog
import Hedgehog

spec : Spec IO () ()
spec = describe "Arithmetic" $ do
  itProp "addition is commutative" $ do
    x <- forAll $ int (linear (-100) 100)
    y <- forAll $ int (linear (-100) 100)
    diff (x + y) (==) (y + x)

  itProp1 "zero is identity" $ do
    diff (0 + 0) (==) (the Int 0)

  -- prop embeds a configured Property (here: 1000 tests via withTests)
  prop "multiplication is commutative" $ withTests 1000 $ property $ do
    x <- forAll $ int (linear (-100) 100)
    y <- forAll $ int (linear (-100) 100)
    diff (x * y) (==) (y * x)
```

## API

| Function      | Description                                          |
|---------------|------------------------------------------------------|
| `prop`        | Embed a hedgehog `Property`                          |
| `itProp`      | Embed a `PropertyT ()` (wraps in `property`)         |
| `itProp1`     | Embed a single-run property                          |
| `runProperty` | Run a `Property` silently, returning a `TestResult`  |

## Failure output

Failures are reported through evince's own reporter, carrying hedgehog's full
report - the shrunk counterexample, diff and recheck seed - under the test's
label:

```
✗ equality
    ✗ equality failed after 1 test.

      ━━━ Failed (- lhs) (+ rhs) ━━━
      - "1"
      + "2"

      This failure can be reproduced by running:
      > recheck 0 (rawStdGen 8380056012993154136 11102715057609136849) equality
```

Hedgehog itself prints nothing to the terminal.
