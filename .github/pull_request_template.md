## What changes

## Why

## Checks

- [ ] every new model says its grain in its first line and in the yml ("One row per …")
- [ ] every new finding has a row in README § Data-quality findings and a test; numbers in tests are ceilings, never today's count
- [ ] no model reads a reference date
- [ ] `make lint` and `make check` pass (CI runs both)
- [ ] a changed definition: `make answers` rerun, README results and the glossary updated
