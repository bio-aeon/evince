# Evince

*Behavioral specifications that evince correctness.*

A testing framework for Idris 2.

Evince provides an Hspec-inspired BDD interface with `describe`/`it` blocks,
colored console output, and assertions powered by `DecEq` — Idris 2's
decidable equality.

> **Note:** Evince is experimental. The API may change between versions.

## Installation

Add evince as a dependency in your `pack.toml`:

```toml
[custom.all.evince]
type   = "github"
url    = "https://github.com/bio-aeon/evince"
commit = "latest:main"
ipkg   = "evince/evince.ipkg"
```

Then add `evince` to your test package's `depends`:

```
depends = evince
```

## Quick Start

```idris
module Main

import Evince

spec : Spec () ()
spec = describe "Parser" $ do
  it "parses positive integers" $
    parse "42" `mustBe` Right 42

  it "rejects invalid input" $
    mustBeLeft (parse "abc")

  it "supports multiple expectations" $ do
    (1 + 2) `mustBe` 3
    (2 + 1) `mustBe` 3

main : IO ()
main = runSpec spec
```

Run with `pack test <your-package>`. Exit code is 1 if any test fails, 0 otherwise.

## DSL

| Function    | Purpose                                              |
|-------------|------------------------------------------------------|
| `describe`  | Group related specs under a label                    |
| `context`   | Alias for `describe`                                 |
| `it`        | Define a test with pure expectations                 |
| `itIO`      | Define a test with `IO`-based expectations           |
| `itWith`    | Define a test that receives a resource               |
| `itIOWith`  | Define an IO test that receives a resource           |
| `xit`       | Skip a test (pending)                                |
| `xdescribe` | Skip an entire group                                 |
| `fit`       | Focus a test — only focused tests run when any exist |
| `fdescribe` | Focus an entire group                                |

## Expectations

### Equality

| Function       | Constraint    | Description                              |
|----------------|---------------|------------------------------------------|
| `mustBe`       | `DecEq, Show` | Decidable equality (primary assertion)   |
| `mustNotBe`    | `DecEq, Show` | Decidable inequality                     |
| `mustEqual`    | `Eq, Show`    | Boolean equality (fallback for `Double`) |
| `mustNotEqual` | `Eq, Show`    | Boolean inequality                       |

### Predicates

| Function         | Description                     |
|------------------|---------------------------------|
| `mustSatisfy`    | Passes if predicate holds       |
| `mustNotSatisfy` | Passes if predicate fails       |
| `mustBeTrue`     | Passes if value is `True`       |
| `mustBeFalse`    | Passes if value is `False`      |

### Maybe / Either

| Function        | Description                  |
|-----------------|------------------------------|
| `mustBeJust`    | Passes if value is `Just _`  |
| `mustBeNothing` | Passes if value is `Nothing` |
| `mustBeRight`   | Passes if value is `Right _` |
| `mustBeLeft`    | Passes if value is `Left _`  |

### Lists

| Function         | Description                                  |
|------------------|----------------------------------------------|
| `mustContain`    | Passes if needle is a contiguous sublist     |
| `mustNotContain` | Passes if needle is not a contiguous sublist |
| `mustStartWith`  | Passes if list starts with the given prefix  |
| `mustEndWith`    | Passes if list ends with the given suffix    |
| `mustBeEmpty`    | Passes if list is empty                      |
| `mustNotBeEmpty` | Passes if list is non-empty                  |

### IO

| Function           | Constraint    | Description                                      |
|--------------------|---------------|--------------------------------------------------|
| `mustReturn`       | `DecEq, Show` | Passes if IO action returns decidably equal value |
| `mustReturnEqual`  | `Eq, Show`    | Passes if IO action returns equal value via `Eq`  |

Used with `itIO`:

```idris
itIO "reads the config file" $
  readConfig "test.toml" `mustReturn` expectedConfig
```

### Control.App

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

### Other

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

## Focused and Pending Tests

Prefix with `x` to skip, or `f` to focus:

```idris
spec : Spec () ()
spec = describe "Feature" $ do
  xit "not implemented yet" $      -- skipped, shown in yellow
    pending

  fit "only this one runs" $       -- when any test is focused,
    1 `mustBe` 1                   -- unfocused tests are excluded

  it "normally runs" $             -- excluded when focused tests exist
    2 `mustBe` 2
```

## Hooks

Hooks run setup/teardown actions around tests:

| Function         | Description                                          |
|------------------|------------------------------------------------------|
| `before`         | Run an IO action before each test                    |
| `after`          | Run an IO action after each test                     |
| `around`         | Wrap each test with a custom IO action               |
| `beforeAll`      | Run an IO action once before all tests               |
| `afterAll`       | Run an IO action once after all tests                |
| `provide`        | Produce a resource and thread it into tests          |
| `beforeWith`     | Transform the resource type before each test         |
| `aroundWith`     | Transform both resource type and wrap the test action|
| `afterWith`      | Run cleanup with access to the resource              |
| `beforeAllWith`  | Transform the resource type once (cached)            |

```idris
spec : Spec () ()
spec = describe "Database" $
  before (connect "test.db") $
  after disconnect $ do
    it "inserts a record" $
      insertCount `mustBe` 1

    it "queries records" $
      queryAll `mustNotBeEmpty`
```

`beforeAll`/`afterAll` run once for the entire group rather than per-test.

### Resource-Passing Hooks

`provide`, `beforeWith`, and `aroundWith` thread a resource into tests:

```idris
spec : Spec () ()
spec = describe "Database" $
  provide (connectDb "test.db") $
  afterWith closeDb $ do
    itIOWith "inserts a record" $ \conn => do
      n <- insertRecord conn
      pure $ n `mustBe` 1
```

## Runners

| Function                      | Description                                       |
|-------------------------------|---------------------------------------------------|
| `runSpec`                     | Run suite, print results, exit 1 on failure       |
| `runSpecFailFast`             | Stop after the first failure                      |
| `runSpecTimed`                | Show per-test timing                              |
| `runSpecWith`                 | Run with custom `RunConfig`                       |
| `runSpecWithArgs`             | Run with CLI arg parsing                          |
| `runSpecWithSummary`          | Run and return `Summary` (for meta-testing)       |
| `runSpecWithSummaryAndConfig` | Run with config and return `Summary`              |

Fail-fast mode stops execution after the first failing test:

```idris
main : IO ()
main = runSpecFailFast spec
```

## CLI Options

Use `runSpecWithArgs` to enable command-line configuration:

```idris
main : IO ()
main = runSpecWithArgs spec
```

| Flag              | Description                                     |
|-------------------|-------------------------------------------------|
| `--fail-fast`     | Stop after the first failure                    |
| `--times`         | Show per-test and total duration                |
| `--match=PATTERN` | Run only tests whose name contains PATTERN      |
| `--skip=PATTERN`  | Skip tests whose name contains PATTERN          |
| `--randomize`     | Shuffle test order                              |
| `--seed=N`        | Deterministic seed for shuffle                  |
| `--junit=FILE`    | Write JUnit XML report to FILE                  |

## JUnit XML

Pass `--junit=report.xml` to produce a JUnit XML report alongside console output:

```sh
./my-tests --junit=report.xml
```

The output follows the standard JUnit XML format, compatible with GitHub Actions,
Jenkins, GitLab CI, and other CI systems.

## Structural Diffs

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

For simple one-liner values, the diff shows the full expected/actual as removed/added lines.
If a value can't be structurally parsed, evince falls back to the standard format.

## Property Testing with Hedgehog

The `evince-hedgehog` package integrates [idris2-hedgehog](https://github.com/stefan-hoeck/idris2-hedgehog)
property tests into evince's spec tree.

Add `evince-hedgehog` to your `pack.toml`:

```toml
[custom.all.evince-hedgehog]
type   = "github"
url    = "https://github.com/bio-aeon/evince"
commit = "latest:main"
ipkg   = "evince-hedgehog/evince-hedgehog.ipkg"
```

Then add it to your test package's `depends`:

```
depends = evince, evince-hedgehog, hedgehog
```

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

| Function  | Description                                  |
|-----------|----------------------------------------------|
| `prop`    | Embed a hedgehog `Property`                  |
| `itProp`  | Embed a `PropertyT ()` (wraps in `property`) |
| `itProp1` | Embed a single-run property                  |

## Output

```
Parser
  ✓ parses positive integers
  ✗ rejects invalid input
    expected Right but got Left
      value: Left "parse error"
  ○ not implemented yet (pending)

  1 passing, 1 failing, 1 pending
```

With `--times`:

```
Parser
  ✓ parses positive integers (0ms)
  ✓ parses negative integers (0ms)

  2 passing, 0 failing, 0 pending (1ms)
```
