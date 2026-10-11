# Expectations

Expectations are statements of a test body: each returns `TestResultT m ()`,
and several chain in one `it` (see [Chaining](#chaining)). Running a chain
yields a `TestResult`: `Pass`, `Fail` or `Skip`.

## Equality

| Function       | Constraint    | Description                              |
|----------------|---------------|------------------------------------------|
| `mustBe`       | `DecEq, Show` | Decidable equality (primary assertion)   |
| `mustNotBe`    | `DecEq, Show` | Decidable inequality                     |
| `mustEqual`    | `Eq, Show`    | Boolean equality (fallback for `Double`) |
| `mustEqualBy`  | `Show`        | Comparison by a custom relation          |
| `mustNotEqual` | `Eq, Show`    | Boolean inequality                       |

`mustBe` uses `DecEq` (decidable equality) - constructive proof that values are
equal or not. This is idiomatic Idris 2. `mustEqual` exists as a fallback for
types like `Double` that have `Eq` but not `DecEq`.

`mustEqualBy` takes the relation as a plain argument, for comparisons no `Eq`
instance can express - approximate equality, or an exact-but-NaN-reflexive
relation. NaN is not reflexive under `Eq`, so `mustEqual nan nan` fails while
printing two identical values.

```idris
approx : Double -> Double -> Bool
approx x y = abs (x - y) < 1.0e-9

it "produces the pre-calculated cdf value" $ do
  v <- liftIO $ cdf gaussian (tensor [[-1.5]])
  mustEqualBy approx v 0.04779036
```

## Predicates

| Function         | Description                     |
|------------------|---------------------------------|
| `mustSatisfy`    | Passes if predicate holds       |
| `mustNotSatisfy` | Passes if predicate fails       |
| `mustBeTrue`     | Passes if value is `True`       |
| `mustBeFalse`    | Passes if value is `False`      |

## Maybe / Either

| Function        | Description                  |
|-----------------|------------------------------|
| `mustBeJust`    | Passes if value is `Just _`  |
| `mustBeNothing` | Passes if value is `Nothing` |
| `mustBeRight`   | Passes if value is `Right _` |
| `mustBeLeft`    | Passes if value is `Left _`  |

## Lists

| Function         | Description                                  |
|------------------|----------------------------------------------|
| `mustContain`    | Passes if needle is a contiguous sublist     |
| `mustNotContain` | Passes if needle is not a contiguous sublist |
| `mustStartWith`  | Passes if list starts with the given prefix  |
| `mustEndWith`    | Passes if list ends with the given suffix    |
| `mustBeEmpty`    | Passes if list is empty                      |
| `mustNotBeEmpty` | Passes if list is non-empty                  |

## Actions

| Function           | Constraint    | Description                                          |
|--------------------|---------------|------------------------------------------------------|
| `mustReturn`       | `DecEq, Show` | Passes if the action returns a decidably equal value |
| `mustReturnEqual`  | `Eq, Show`    | Passes if the action returns an equal value via `Eq` |

The action runs in the chain's monad - `IO` in any spec, `Async` in an `Async`
spec:

```idris
it "reads the config file" $
  readConfig "test.toml" `mustReturn` expectedConfig
```

## Control.App

| Function         | Constraint              | Description                                      |
|------------------|-------------------------|--------------------------------------------------|
| `tryApp`         | -                       | Run `App (err :: Init) a` as `IO (Either err a)` |
| `mustError`      | -                       | Passes if the `App` computation throws           |
| `mustErrorWith`  | `Show err, DecEq err`   | Passes if the error matches the expected value   |

`mustError` and `mustErrorWith` return an `IO` chain, which `it` lifts into
any spec:

```idris
it "rejects negative transfer" $
  mustError (transfer (-100))

it "rejects with InvalidAmount" $
  mustErrorWith (transfer (-100)) (InvalidAmount (-100))
```

## Other

| Function      | Description                                  |
|---------------|----------------------------------------------|
| `mustFail`    | Unconditionally fails with the given message |
| `pending`     | Marks a test as pending (skipped)            |
| `pendingWith` | Marks a test as pending with a reason        |

## Chaining

Several expectations in one test stop at the first failure or skip:

```idris
it "validates a user" $ do
  user.age `mustBe` 25
  user.name `mustBe` "Alice"    -- skipped if the age check fails
```

Action-shaped expectations (`mustReturn`, `mustError`) are statements like any
other; plain actions enter with `lift` or `liftIO`, and base's
`HasIO`-polymorphic primitives (`newIORef`, `readFile`, `putStrLn`, ...) need
neither:

```idris
it "transfers between accounts and leaves balances consistent" $ do
  (alice, bob) <- liftIO (openAccounts 100 0)   -- a plain IO action
  transfer 30 alice bob `mustReturn` 70         -- an IO-shaped expectation
  lift $ audit "transfer done"                  -- a plain action
  balance <- readBalance bob                    -- HasIO-polymorphic: no lift
  balance `mustBe` 30
```

### Custom expectations

Write helpers polymorphically, so they fit any spec:

```idris
mustBeAdult : Monad m => User -> TestResultT m ()
mustBeAdult u = do
  u.age `mustSatisfy` (>= 18)
  u.name `mustNotBe` ""
```

A plain `TestResult ()` value - `Pass ()`, `Fail info` - enters a chain
through `liftResult`. `runPure` runs an effect-free chain, e.g. to unit-test
a helper:

```idris
it "accepts an adult" $
  runPure (mustBeAdult alice) `mustBe` Pass ()
```
