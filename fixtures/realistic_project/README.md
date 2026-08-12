# Stream Guard

A small multi-package example representing a reusable MoonBit service
component. The root package validates incoming batches and the `engine`
package owns retry and backoff policy.

Run the project with MoonBit 0.10.3:

```bash
moon check --target js
moon test --target js
```
