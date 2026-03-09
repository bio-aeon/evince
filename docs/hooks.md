# Hooks

Hooks run setup/teardown actions around tests.

## Per-Test Hooks

| Function | Description                            |
|----------|----------------------------------------|
| `before` | Run an IO action before each test      |
| `after`  | Run an IO action after each test       |
| `around` | Wrap each test with a custom IO action |

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

## Group-Level Hooks

| Function    | Description                                 |
|-------------|---------------------------------------------|
| `beforeAll` | Run an IO action once before all tests      |
| `afterAll`  | Run an IO action once after all tests       |

`beforeAll`/`afterAll` run once for the entire group rather than per-test.
`beforeAll` is thread-safe — under parallel execution, the setup runs exactly
once even when multiple threads reach it concurrently.

## Resource-Passing Hooks

These hooks thread a resource into tests, transforming the `Spec` resource type:

| Function        | Description                                          |
|-----------------|------------------------------------------------------|
| `provide`       | Produce a resource and thread it into tests          |
| `beforeWith`    | Transform the resource type before each test         |
| `aroundWith`    | Transform both resource type and wrap the test action|
| `afterWith`     | Run cleanup with access to the resource              |
| `beforeAllWith` | Transform the resource type once (cached)            |

`provide` is the most common entry point — it runs a setup action and makes the
result available to all tests in the group via `itWith`/`itIOWith`:

```idris
spec : Spec () ()
spec = describe "Database" $
  provide (connectDb "test.db") $
  afterWith closeDb $ do
    itIOWith "inserts a record" $ \conn => do
      n <- insertRecord conn
      pure $ n `mustBe` 1
```

`beforeWith` transforms an existing resource into a different type:

```idris
spec : Spec () ()
spec = describe "API" $
  provide (startServer 8080) $
  beforeWith (\server => mkClient server.url) $ do
    itIOWith "fetches status" $ \client => do
      resp <- client.get "/health"
      pure $ resp.status `mustBe` 200
```

`beforeAllWith` is like `beforeWith` but caches the result — the transformation
runs once on the first test and subsequent tests reuse the cached value.
Thread-safe under parallel execution.
