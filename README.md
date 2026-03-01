# Evince

*Behavioral specifications that evince correctness.*

A testing framework for Idris 2.

Evince provides an Hspec-inspired BDD interface with `describe`/`it` blocks,
colored console output, and assertions powered by `DecEq` — Idris 2's
decidable equality.

## Installation

Add evince as a dependency in your `pack.toml`:

```toml
[custom.all.evince]
type   = "github"
url    = "https://github.com/bio-aeon/evince"
commit = "latest"
ipkg   = "evince.ipkg"
```

Then add `evince` to your test package's `depends`:

```
depends = evince
```

## Quick Start

```idris
module Main

import Evince

spec : Spec ()
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
spec : Spec ()
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

| Function    | Description                                |
|-------------|--------------------------------------------|
| `before`    | Run an IO action before each test          |
| `after`     | Run an IO action after each test           |
| `around`    | Wrap each test with a custom IO action     |
| `beforeAll` | Run an IO action once before all tests     |
| `afterAll`  | Run an IO action once after all tests      |

```idris
spec : Spec ()
spec = describe "Database" $
  before (connect "test.db") $
  after  disconnect $ do
    it "inserts a record" $
      insertCount `mustBe` 1

    it "queries records" $
      queryAll `mustNotBeEmpty`
```

`beforeAll`/`afterAll` run once for the entire group rather than per-test.

## Runners

| Function                     | Description                                  |
|------------------------------|----------------------------------------------|
| `runSpec`                    | Run suite, print results, exit 1 on failure  |
| `runSpecFailFast`            | Stop after the first failure                 |
| `runSpecWith`                | Run with custom `RunConfig`                  |
| `runSpecWithSummary`         | Run and return `Summary` (for meta-testing)  |
| `runSpecWithSummaryAndConfig`| Run with config and return `Summary`         |

Fail-fast mode stops execution after the first failing test:

```idris
main : IO ()
main = runSpecFailFast spec
```

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
