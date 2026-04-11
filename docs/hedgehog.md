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

spec : Spec () ()
spec = describe "Arithmetic" $ do
  itProp "addition is commutative" $ do
    x <- forAll $ int (linear (-100) 100)
    y <- forAll $ int (linear (-100) 100)
    diff (x + y) (==) (y + x)

  itProp1 "zero is identity" $ do
    diff (0 + 0) (==) (the Int 0)
```

## API

| Function  | Description                                  |
|-----------|----------------------------------------------|
| `prop`    | Embed a hedgehog `Property`                  |
| `itProp`  | Embed a `PropertyT ()` (wraps in `property`) |
| `itProp1` | Embed a single-run property                  |
