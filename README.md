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

## Documentation

| Topic | Description |
|-------|-------------|
| [Expectations](docs/expectations.md) | `mustBe`, `mustSatisfy`, `mustBeJust`, `mustReturn`, Control.App bridge, ... |
| [Hooks](docs/hooks.md) | `before`, `after`, `beforeAll`, `provide`, `beforeWith`, resource-passing |
| [Runners](docs/runners.md) | `runSpec`, `runSpecFailFast`, `runSpecWith`, `runSpecWithArgs`, ... |
| [CLI Options](docs/cli.md) | `--fail-fast`, `--match`, `--skip`, `--jobs`, `--junit`, `--rerun`, ... |
| [Source Locations](docs/source-locations.md) | `itLoc`/`itIOLoc` — capture file and line via elaborator reflection |
| [Structural Diffs](docs/diffs.md) | Colored diff output for complex value failures |
| [Hedgehog](docs/hedgehog.md) | Property testing via `evince-hedgehog` + idris2-hedgehog |
