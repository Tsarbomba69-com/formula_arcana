# Coding Conventions

**Scope:** Odin applications, game engines, tools, and background services (applies equally to core domain modules, renderers, systems, and CLI tools).  
**Status:** Living document — changes go through the same review process as code.

---

## 1. Foundation

This document is an *addendum*, not a replacement. Where it is silent, defer to:

- [Odin Language Overview & Overview Documentation](https://odin-lang.org/docs/overview/)
- [Odin `core` Library Conventions](https://github.com/odin-lang/Odin/tree/master/core)

Where this document *contradicts* official resources, this document wins for the specific case it explicitly covers, and official language conventions resume everywhere else.

---

## 2. Versioning — SemVer

All published packages/binaries follow [Semantic Versioning 2.0.0](https://semver.org/): `MAJOR.MINOR.PATCH`.

- **MAJOR** — breaking change to a public contract: procedure signature, package interface, memory ownership contract, or public struct/enum/union memory layout.
- **MINOR** — backward-compatible functionality added (new procedure, new struct field, new optional feature).
- **PATCH** — backward-compatible bug fix, no public procedure or type layout change.
- Pre-1.0 (`0.x.y`) is allowed only for genuinely unstable internal tooling, never for core engine modules or public library boundaries.
- Breaking changes must be called out explicitly in the changelog entry, not buried in a `fix` or `refactor` commit.

---

## 3. Commit Convention

```plaintext
<type>(<scope>): <short summary>
  │       │             │
  │       │             └─⫸ Present tense, not capitalized, no trailing period.
  │       │
  │       └─⫸ Scope: the module/feature area touched, e.g.
  │                  render | core | physics | ui | assets | spatial |
  │                  platform | audio | build | tools
  │
  └─⫸ Type: build | ci | docs | feat | fix | perf | refactor | test
```

| Type | Description |
| --- | --- |
| `build` | Build system, build scripts, or external library changes |
| `ci` | CI configuration/scripts |
| `docs` | Documentation only |
| `feat` | New feature |
| `fix` | Bug fix |
| `perf` | Performance improvement, no behavior change |
| `refactor` | Neither fixes a bug nor adds a feature |
| `test` | Adding/correcting tests |

Body (optional, but **required** for anything MAJOR per §2): explain *why*, not *what* — the diff already shows *what*. Footer: `BREAKING CHANGE: ...` when applicable, and issue references (`Refs #123`).

Keep the scope list in `CONTRIBUTING.md`, in sync with the actual package directories — don't let it drift.

---

## 4. Naming

In alignment with Odin community standards:

- **Procedures, variables, parameters, fields, package names:** `snake_case`
- **Types (structs, enums, unions, distinct types):** `PascalCase`
- **Constants, `#config` declarations, enum values:** `UPPER_SNAKE_CASE`

### 4.1 Public & Package API surface — verb-first, raylib/vendor-style

For **callable procedures** — package exports, service operations, systems, public functions — name using `snake_case` with verb-first ordering:

```odin
<verb>_<subject>_<complement>()
<action>_<object>_<attribute_or_state>()
```

Examples:

```odin
create_chapter_invite :: proc(...) -> (...)
revoke_chapter_access :: proc(...) -> (...)
mark_chapter_as_published :: proc(...) -> (...)
resolve_merge_conflict :: proc(...) -> (...)
```

It exists to keep procedure names scannable-by-verb in an editor's auto-complete or symbol list, and forces every procedure to state its effect, not just its subject.

**Explicitly exempt** from verb-first ordering (standard Odin rules apply instead):

- Struct field accessors / data fields
- Types, Structs, Unions, Enums (`ChapterRepository`, not a verb form)
- Initializer/Factory patterns expected in Odin: `make_x`, `destroy_x`, `init_x`, `clean_x` — these are already verb-first.
- Predicates returning `bool`: `is_x`, `has_x`, `can_x` — these satisfy verb-first intent natively (`is_valid`, `has_access`).

### 4.2 Structs / Value Types — one word, two at most

Struct names are `PascalCase`, constrained to one word; two only when one word is genuinely ambiguous without it. This is a forcing function against over-modeling — if you need three+ words to name a struct, it's very likely two concepts glued together and should be split.

```odin
// Preferred
ChapterId :: distinct u64
Money     :: struct { ... }
Percentage :: distinct f32

// Acceptable (two words, second disambiguates a unit/kind)
ChapterSlug :: distinct string
UtcTimestamp :: distinct i64

// Avoid — split it
ChapterCollaboratorInviteToken :: struct { ... } // → CollaboratorInvite + InviteToken
```

---

## 5. Procedure Signatures & Control Flow

> "Simplify function signatures to minimize branches at the call site, which are viral through the call graph."

- **≤ 5 parameters**, hard default. Above that, introduce a parameter struct (per §4.2's naming rules).
- Prefer explicit value types or small pointer passes (`^T`) over untargeted inputs.
- **Return-type hierarchy (utilizing Odin's explicit multi-returns and error idiomatics):**
  1. `(T, bool)` or `(T, Error)` — explicit tuple returns. Use `ok` or `err` as the last return parameter so call sites can use `or_return` or `or_else`.
  2. Bounded enum or union types (`enum` or `dynamic_union`) — finite, enumerable branches.
  3. Open types / raw string errors (`string`, arbitrary `rawptr`) — only when the first two genuinely cannot express the result. This is the last choice.
- **Explicit Allocation Context:** Any procedure that allocates dynamic memory **must** accept an explicit `allocator := context.allocator` parameter, or clearly accept a scratch buffer/arena. Never hide heap allocations inside procedures without exposing the allocator parameter.
- Push control flow *up* (callers decide branching) and data flow *down* (callees receive what they need, don't reach out to global state). Concretely: a procedure shouldn't query ambient global state to decide its branching — pass relevant parameters down explicitly.
- Declare variables as close as possible to first use. Use block-scoped statements (`if x := val; x != nil`) to limit variable lifetime.

---

## 6. Memory Ownership, Packages & Boundaries

- **Minimize package surface area.** Keep procedures and structs package-private (`@(private)` or file-scoped) by default. Export to other packages only what is required for external operations.
- **Memory Ownership & Fault Models:** Every procedure or package boundary handling resources (memory, file handles, sockets, GPU objects) must explicitly state ownership and cleanup semantics in doc comments (§7):
  - *Who allocates? Who frees?*
  - Use `defer` at call sites immediately after allocation (`defer delete(slice)`, `defer destroy_x(&x)`).
  - Explicitly document behavior on timeout, partial reads, or malformed data.
- **Abstract non-deterministic interfaces behind deterministic procedures.** System clock, random number generators, network I/O, file system reads, and direct windowing routines sit behind abstract procedure signatures or interface structs so core domain logic is replayable and testable with fixed inputs.

---

## 7. Documentation

- Every public procedure, struct, enum, and package entry point **must** have a comment directly preceding its declaration.
- Comments must state **contract and invariants**, not implementation:
  - Preconditions and postconditions.
  - Memory behavior (e.g., *"Allocates returning slice using `allocator`. Caller assumes ownership."*).
  - Return error conditions and fault behavior.
- Internal/private procedures: comment *why*, only when the *why* isn't obvious from reading the code. Do not restate the signature in prose.

---

## 8. Third-Party & Vendor Libraries — Wrap Core Dependencies

If an external dependency (or vendor package like `vendor:raylib`, `vendor:glfw`, custom C bindings) implements a **core feature** of the system — rendering backend, job systems, spatial indices, file parsers — access it **only** through a project-owned module wrapper, never call vendor APIs directly inside core domain logic.

Rules for the wrapper:

- The wrapper's public procedures follow §4.1/§5/§7 (Odin naming, procedure bounds, explicit allocators).
- The wrapper acts as the single seam for fault translation, error mapping, and memory conversion (e.g., converting C-style null-terminated strings or raw memory buffers into safe Odin slices/strings).
- Swapping the underlying library should touch only the wrapper's implementation, never domain call sites.

---

## 9. Testing — Invariants & Property-Based

Unit tests for domain logic define **invariants** (properties that must hold for *all* valid inputs), using Odin's built-in testing framework (`core:testing`).

- Place tests in `_test.odin` files alongside source code, using `@(test)` attribute annotations.
- Every test states its invariant explicitly in the test name or description comment — e.g. `test_chapter_merge_is_commutative`.
- Combine example-based unit tests with table-driven tests and randomized input generators to verify structural invariants across ranges.
- Pure procedures and value types (§4.2 structs) are the highest-value targets for invariant testing.

Run test suites using:

```bash
odin test . -all-packages
```

---

## 10. Zero Technical Debt — Compiler Discipline

> "Code, like steel, is easier to change while it's hot."

- All code compiles with warnings treated as errors **from day one**.
- Enforcement via strict build parameters across builds and CI pipelines:

```bash
odin build . -warnings-as-errors -vet-unused -vet-shadowing -vet-using-param -vet-using-stmt -vet-style
```

- Unused variables, shadowed names, or unused imports are treated as build errors.
- Never disable compiler checks without a explicit tracking comment and ticket link explaining the exception.

---

## 11. No Magic Values

- No bare literals (numbers, strings, magic indices) in domain logic that carry meaning beyond their literal self — `-1`, `"pending"`, frame rates, timeout ticks, or magic flags.
- Declare them using compile-time constants (`const_name :: value`), explicit `enum` values, or `#config` variables.
- Centralize event identifiers, configuration keys, or fixed buffer limits into package-level constant blocks so typos result in compile-time errors.
- Exception: self-evident mathematical or iteration constants (`0` and `1` in loop counters, `2.0` for halving) do not require named constants.

---

## 12. Quick Reference Checklist

- [ ] Package surface documented (§7) and passes `-warnings-as-errors` + `-vet` flags (§10)
- [ ] SemVer bump matches actual contract change (§2)
- [ ] Commit message matches `<type>(<scope>): <summary>` (§3)
- [ ] New structs: 1–2 word names in `PascalCase` (§4.2)
- [ ] New public procedures: verb-first naming in `snake_case` (§4.1)
- [ ] Procedures: ≤5 params, explicit `allocator` parameter if allocating, multi-return `(T, bool)` / `(T, Error)` (§5)
- [ ] Third-party / Vendor dependency isolated behind internal package wrapper (§8)
- [ ] No unnamed magic literals; use explicit `const` / `enum` / `#config` (§11)
- [ ] Domain logic: invariants defined and tested via `odin test` (§9)
- [ ] Explicit memory ownership and fault behavior stated for I/O and dynamic memory allocations (§6)
