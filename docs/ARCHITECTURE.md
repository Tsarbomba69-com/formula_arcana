# Project Directory & Vertical Slice Architecture

**Scope:** Directory layout, package structure, and file co-location rules for Odin game projects.  
**Status:** Living document — changes go through the same review process as code.

---

## 1. Core Architectural Principles

1. **High Cohesion via Feature Slices:** Code, types, assets, and tests that belong to a single domain concept live together in a single feature directory.
2. **Odin Directory-as-Package Mapping:** In Odin, **one directory equals one package**. A subdirectory is a separate Odin package. Slices are structured with explicit package boundaries and dependencies.
3. **Strict Dependency Hierarchy (Data Flow Down, Events Up):**
   * `features` may depend on `core`, `platform`, and `shared`.
   * `features` **must never** depend directly on other `features`. Inter-feature communication happens via event queues, state flags, or shared messages in `core/events`.
   * `core` and `platform` **must never** import any `features`.
4. **Co-location over Layering:** Keep data layouts, rendering procedures, update logic, and tests inside the feature directory rather than splitting them into top-level `systems/`, `components/`, or `views/` folders.

---

## 2. Root Directory Structure

```plaintext
my_game/
├── assets/                     # Static game assets (textures, audio, fonts, maps)
│   ├── shared/                 # Global UI themes, base shaders, standard fonts
│   └── features/               # Feature-specific graphics/audio (mirrors src/features)
├── bin/                        # Output directory for compiled binaries
├── build_scripts/              # Shell scripts / tool commands for building & packaging
├── src/                        # Source code root
│   ├── main.odin               # Application entry point (package main)
│   ├── app.odin                # Game loop orchestration, frame state, top-level init/cleanup
│   ├── core/                   # Engine domain abstractions, memory arenas, message bus
│   ├── platform/               # OS, windowing, Raylib bindings glue, raw input mapping
│   ├── shared/                 # Reusable math, spatial data structures, algorithms
│   └── features/               # Vertical slices (gameplay mechanics & subsystems)
│       ├── inventory/
│       ├── combat/
│       ├── dialogue/
│       └── player_movement/
├── tests/                      # Integration test suites & benchmark harnesses
├── odin.json / ols.json        # OLS language server configuration
└── build.sh / build.bat        # Standard build launcher
```

---

## 3. Directory Breakdown & Responsibilities

### 3.1 `src/main.odin` & `src/app.odin` (Application Entry)

* **`main.odin`**: Contains `main :: proc()`. Initializes memory allocators, configures runtime flags, parses CLI parameters, and passes control to `app.odin`.
* **`app.odin`**: Owns the main game loop (`init`, `update`, `draw`, `shutdown`). It imports `platform`, `core`, and required `features` to tick and render them in deterministic order.

### 3.2 `src/features/` (Vertical Slices)

Each subdirectory under `features/` represents a self-contained domain feature. Everything required for the feature to function sits within its package directory.

#### Feature Directory Rules

* Filenames inside a feature package are `snake_case.odin`.
* Related assets sit either inside the slice (`features/<feature_name>/assets/`) or under `assets/features/<feature_name>/`.
* Feature unit tests live directly in the slice as `*_test.odin`.

#### Anatomy of a Feature Slice (`src/features/inventory/`)

```plaintext
src/features/inventory/
├── inventory.odin            # Public API, main struct (Inventory_State), lifecycle (init/update)
├── inventory_types.odin      # Data structures, enums, structs (Item, Slot, Item_Id)
├── inventory_ui.odin         # Raylib UI rendering routines for inventory grid
├── inventory_actions.odin   # Domain logic (add_item, drop_item, swap_slots)
└── inventory_test.odin       # Package tests (@(test) proc)
```

### 3.3 `src/core/` (Engine Foundations)

`core` contains engine-level primitives that do not belong to any single gameplay mechanic.

```plaintext
src/core/
├── allocator/               # Custom arena, pool, and tracking allocators
├── events/                  # Decoupled publish/subscribe or message queue system
├── time/                    # Fixed timestep clock, delta-time utilities
├── logging/                 # Structured loggers and error sinks
└── state/                   # Top-level application state machine / scene router
```

### 3.4 `src/platform/` (Hardware & Renderer Isolation)

Hides Raylib and OS hardware calls behind deterministic project boundaries (per Coding Standards §8).

```plaintext
src/platform/
├── window.odin              # Raylib window creation, resolution scaling
├── input.odin               # Abstract key/gamepad mappings to game actions
├── render_batch.odin        # Drawing wrappers and raylib state encapsulation
└── audio_device.odin        # Sound playback engine setup
```

### 3.5 `src/shared/` (Pure Utilities & Math)

Pure procedures, zero-side-effect utilities, data structures, and mathematical primitives.

```plaintext
src/shared/
├── math/                    # Vector extensions, collision geometry, interpolation
├── spatial/                 # Quadtrees, grid hashes, spatial partitions
└── color/                   # Palette definitions and color utilities
```

---

## 4. Package Import Flow & Communication Rules

```plaintext
               +----------------------------------+
               |        src/main.odin             |
               |        src/app.odin              |
               +----------------+-----------------+
                                |
        +-----------------------+-----------------------+
        |                       |                       |
        v                       v                       v
+---------------+       +---------------+       +---------------+
| features/     |       | core/         |       | platform/     |
|  ├── combat   |------>|  ├── events   |------>|  ├── window   |
|  └── inventory|       |  └── state    |       |  └── input    |
+---------------+       +---------------+       +---------------+
        |                       |                       |
        +-----------------------+-----------------------+
                                |
                                v
                        +---------------+
                        | shared/       |
                        |  └── math     |
                        +---------------+
```

### 4.1 Inter-Feature Decoupling

To ensure high cohesion and low coupling:

1. **Never cross-import features:** `features/combat` **must not** `import "src/features/inventory"`.
2. **Use Event Channels:** When combat causes an item drop, `combat` emits an event (`Item_Dropped_Event`) to `core/events`. The `inventory` system listens for this event in its frame update.
3. **Shared Identifiers:** If two features must reference the same entity or concept (e.g., `Item_Id`), place that distinct type definition in `core/types` or `shared/ids`.

---

## 5. File Naming Conventions

All folder and file names inside the project must adhere to standard Odin conventions:

| Element | Format | Example |
| --- | --- | --- |
| Root & Module Folders | `snake_case` | `src/features/player_movement/` |
| Odin Source Files | `snake_case.odin` | `player_movement_controller.odin` |
| Test Files | `<name>_test.odin` | `inventory_test.odin` |
| Static Assets | `snake_case.<ext>` | `hero_walk_animation.png` |

---

## 6. Quick Reference Checklist

* [ ] Every feature lives in its own subdirectory under `src/features/` (§3.2)
* [ ] No feature imports another feature package directly (§4.1)
* [ ] Feature files are co-located (types, logic, rendering, tests in one folder) (§3.2)
* [ ] Vendor libraries (Raylib) sit behind wrapper layers in `src/platform/` (§3.4)
* [ ] Memory allocations in features accept an explicit `allocator` or use scratch arenas (§1)
* [ ] New asset directories mirror the source code structure under `assets/features/` (§2)
