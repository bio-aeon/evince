# Expectations

Pure functions returning `TestResult ()` (or `IO (TestResult ())` for IO variants).

## Equality

| Function       | Constraint    | Description                              |
|----------------|---------------|------------------------------------------|
| `mustBe`       | `DecEq, Show` | Decidable equality (primary assertion)   |
| `mustNotBe`    | `DecEq, Show` | Decidable inequality                     |
| `mustEqual`    | `Eq, Show`    | Boolean equality (fallback for `Double`) |
| `mustNotEqual` | `Eq, Show`    | Boolean inequality                       |

`mustBe` uses `DecEq` (decidable equality) — constructive proof that values are
equal or not. This is idiomatic Idris 2. `mustEqual` exists as a fallback for
types like `Double` that have `Eq` but not `DecEq`.

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

## IO

| Function           | Constraint    | Description                                      |
|--------------------|---------------|--------------------------------------------------|
| `mustReturn`       | `DecEq, Show` | Passes if IO action returns decidably equal value |
| `mustReturnEqual`  | `Eq, Show`    | Passes if IO action returns equal value via `Eq`  |

Used with `itIO`:

```idris
itIO "reads the config file" $
  readConfig "test.toml" `mustReturn` expectedConfig
```

## Control.App

| Function         | Constraint              | Description                                      |
|------------------|-------------------------|--------------------------------------------------|
| `tryApp`         | —                       | Run `App (err :: Init) a` as `IO (Either err a)` |
| `mustError`      | `Show err`              | Passes if the `App` computation throws           |
| `mustErrorWith`  | `Show err, DecEq err`   | Passes if the error matches the expected value   |

Used with `itIO`:

```idris
itIO "rejects negative transfer" $
  mustError (transfer (-100))

itIO "rejects with InvalidAmount" $
  mustErrorWith (transfer (-100)) (InvalidAmount (-100))
```

## Other

| Function      | Description                                  |
|---------------|----------------------------------------------|
| `mustFail`    | Unconditionally fails with the given message |
| `pending`     | Marks a test as pending (skipped)            |
| `pendingWith` | Marks a test as pending with a reason        |

## Chaining Expectations

Multiple expectations in a single test short-circuit on first failure:

```idris
it "validates a user" $ do
  user.age `mustBe` 25
  user.name `mustBe` "Alice"    -- skipped if age check fails
```
