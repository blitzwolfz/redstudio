# Red Studio — Product Requirements Document

**Version:** 1.0  
**Status:** Draft  
**Target platforms:** macOS and Linux  
**Implementation language:** Red  
**GUI:** Native pixel-based GUI using Andy's native rendering backend  
**Repository:** https://github.com/blitzwolfz/Red

## 1. Product overview

### 1.1 Summary

Red Studio is a native desktop developer workbench built in Red. It combines a project explorer, source editor, command runner, task manager, HTTP inspector, JSON viewer, and native GUI component gallery. It serves both as a practical environment for Red projects and as a substantial demonstration of the language's GUI, concurrency, networking, filesystem, error handling, compilation, and distribution capabilities.

The primary interface **must use native pixel scenes**, not the terminal-compatible cell renderer in a desktop window. The native GUI should feel like a purpose-built desktop application.

### 1.2 Goals

| ID | Goal |
|---|---|
| G-01 | Deliver a complete native desktop application implemented in Red. |
| G-02 | Demonstrate major language and standard-library features through useful workflows. |
| G-03 | Support everyday editing, running, testing, and building of Red projects. |
| G-04 | Keep the GUI responsive during concurrent work. |
| G-05 | Showcase native rendering, components, themes, input, and interaction. |
| G-06 | Support macOS and Linux. |
| G-07 | Package the application for distribution. |
| G-08 | Establish a reference application for Red. |

### 1.3 Non-goals for the initial release

Full VS Code compatibility, an extension marketplace, collaborative editing, remote development, browser delivery, Windows support, a full-featured debugger UI, and a complete replacement for an established IDE are out of scope. Do not add an integrated AI assistant.

### 1.4 Target users

- **Red developers:** edit, run, test, and manage programs.
- **Language contributors:** browse Red's own repository and invoke the toolchain.
- **Developers evaluating Red:** inspect a working native application and its source.

## 2. Technical direction

### 2.1 Native GUI requirement

The application uses `andy.NativeScene`, `andy/native`, and `andy-gui` as its native rendering foundation, with Cocoa on macOS and X11 on Linux. The GUI must support pixel-based layout, native text drawing, varied font sizes, colors, borders, rounded corners, pointer interaction, and keyboard input.

```text
Red Studio
  ├─ Application state and services
  ├─ Native component/layout layer
  └─ NativeScene
       └─ andy/native → andy-gui
            ├─ Cocoa (macOS)
            └─ X11 (Linux)
```

**Boundary:** Andy's existing cell-based widgets do not automatically become native pixel-layout widgets. Any required native controls or event primitives missing from the current API must be implemented as part of the GUI foundation; do not quietly substitute the terminal widget system. Consult [`docs/andy.md`](https://github.com/blitzwolfz/Red/blob/master/docs/andy.md) and the latest native-scene implementation before locking the API.

### 2.2 Design principles

- Pixel-based, resizable, responsive desktop layout.
- Central theme, spacing, typography, and component-state definitions.
- Clear focus, hover, selection, disabled, loading, and error states.
- Native GUI objects are updated only by the GUI/event owner; workers communicate through channels.
- Keyboard access for major actions.
- Real error feedback; no silent data loss.
- Background work must not block input and painting.

## 3. Application layout

```text
┌─────────────────────────────────────────────────────────────────────┐
│ Red Studio                                             window       │
├─────────────────────────────────────────────────────────────────────┤
│ File   Edit   View   Run   Build   Tools   Help                       │
├──────────┬──────────────────────────────────────────────────────────┤
│ ACTIVITY │ main.red       utils.red       README.md                  │
│ Explorer ├──────────────────────────────────────────────────────────┤
│ Search   │ 1  import "std/http" as http;                             │
│ Tasks    │ 2                                                        │
│ HTTP     │ 3  fun main() {                                          │
│ Gallery  │ 4    print("Hello, Red!");                               │
│          │ 5  }                                                     │
├──────────┼──────────────────────────────────────────────────────────┤
│ PROJECT  │ OUTPUT  |  PROBLEMS  |  TASKS                              │
│ src/     │ > red main.red                                           │
│ tests/   │ Hello, Red!                                              │
├──────────┴──────────────────────────────────────────────────────────┤
│ Ready       main.red           Ln 4, Col 8        Red       UTF-8    │
└─────────────────────────────────────────────────────────────────────┘
```

The main window has a title bar, menus, activity rail, contextual sidebar, central content area, lower output panel, and status bar. Sidebar and output panel must be resizable and collapsible, with usable minimum dimensions and persisted sizes.

## 4. Functional requirements

Priorities: **P0** = required for MVP; **P1** = required for v1; **P2** = later enhancement.

### 4.1 Project explorer

| ID | Requirement | Priority |
|---|---|---|
| PRJ-01 | Open a directory as a project and show a hierarchy. | P0 |
| PRJ-02 | Expand/collapse folders and lazy-load their children. | P0 |
| PRJ-03 | Open selected files in editor tabs. | P0 |
| PRJ-04 | Create, rename, and delete files/folders; confirm destructive operations. | P0 |
| PRJ-05 | Display file metadata and recent projects. | P1 |
| PRJ-06 | Search files and provide context menus. | P1 |
| PRJ-07 | Support multiple project roots. | P2 |

**Acceptance:** A user can open the Red repository, navigate it, create a `.red` file, rename it, edit it, and save it without leaving Red Studio. Filesystem errors must be visible and existing files must never be overwritten silently.

### 4.2 Source editor

| ID | Requirement | Priority |
|---|---|---|
| EDT-01 | Open, edit, save, and Save As text files. | P0 |
| EDT-02 | Multiple tabs with preserved cursor/scroll/selection state. | P0 |
| EDT-03 | Dirty indicators and confirmation before discarding changes. | P0 |
| EDT-04 | Keyboard shortcuts and clipboard operations. | P0 |
| EDT-05 | Line numbers and cursor-position status. | P1 |
| EDT-06 | Undo/redo, find/replace, and auto-indentation. | P1 |
| EDT-07 | Red syntax highlighting for keywords, strings, numbers, comments, declarations, operators, and imports. | P1 |
| EDT-08 | Configurable editor font size and autosave. | P1/P2 |

Document state includes path, contents, saved revision, dirty flag, cursor, selection, scroll position, and encoding. Implement a lightweight tokenizer initially; semantic language-server highlighting is not a prerequisite.

**Acceptance:** Several files can be edited independently, switched between, saved, and closed safely without losing unsaved work.

### 4.3 Toolchain integration

Invoke Red's tools as child processes; do not reimplement the toolchain for MVP.

| Action | Command shape |
|---|---|
| Run | `red program.red` |
| Compile bytecode | `red compile program.red` |
| Build executable | `red build program.red` |
| Format | `red fmt -w program.red` |
| Test | `red test tests` |
| Disassemble | `red disasm program.red` |
| Debug | `red debug program.red` (basic launch; full debugger UI later) |

Support a configurable Red executable, entry point, working directory, program arguments, and environment variables. Every run gets its own output record: command, start/end times, exit code, stdout, stderr, and status. Users can inspect, copy, clear, and switch outputs. Recognizable file/line diagnostics should be clickable in v1. Avoid passing untrusted user text through a shell when an argument-vector API is available.

**Acceptance:** Open a Red source file, run it, inspect output, compile it, run tests, and inspect disassembly through the GUI.

### 4.4 Concurrent task manager

| ID | Requirement | Priority |
|---|---|---|
| TSK-01 | Queue and execute background operations. | P0 |
| TSK-02 | Show queued, running, completed, and failed tasks. | P0 |
| TSK-03 | Record durations and outputs. | P0 |
| TSK-04 | Run independent jobs concurrently while GUI stays responsive. | P0 |
| TSK-05 | Cancel supported tasks and bound worker concurrency. | P1 |
| TSK-06 | Show progress and retain task history. | P1 |
| TSK-07 | Provide an optional many-task concurrency demo. | P1 |

Use a defined status enum and a lifecycle of `QUEUED → RUNNING → COMPLETED | FAILED | CANCELLED`. Jobs flow through a channel to workers; results flow back through a channel to the application state and GUI. Workers must not mutate native GUI objects directly. Distinguish cancellation requests from confirmed termination of external processes.

**Acceptance:** A project scan and a test run can proceed together while the user continues navigating and editing. The demo reports submitted/running/completed/failed tasks, elapsed time, and completion throughput without presenting itself as a CPU benchmark.

### 4.5 HTTP inspector

| ID | Requirement | Priority |
|---|---|---|
| HTTP-01 | Send GET and POST requests; show status, headers, and body. | P0 |
| HTTP-02 | Parse and display JSON responses. | P0 |
| HTTP-03 | Edit headers/body and support PUT, PATCH, DELETE. | P1 |
| HTTP-04 | Report duration and save request history. | P1 |
| HTTP-05 | Support concurrent requests. | P1 |
| HTTP-06 | Cancel requests where feasible. | P2 |

The initial inspector targets localhost and plain HTTP. Red's documented HTTP client does **not** provide TLS; do not promise HTTPS until a TLS implementation or proxy is added.

### 4.6 Optional local HTTP API

The API is off by default and binds only to loopback when enabled.

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/status` | App status |
| GET | `/api/project` | Current project summary |
| GET | `/api/tasks` | Task list |
| GET | `/api/tasks/:id` | Task detail |
| POST | `/api/tasks` | Start a supported, validated task |
| POST | `/api/build` | Build the current project |

Mutating routes require an application-generated token. Restrict actions to the selected project and explicitly supported operations, validate paths and arguments, and never expose arbitrary command execution to remote clients. Require an additional security review before binding to a non-loopback interface.

### 4.7 JSON inspector

Open JSON files or HTTP responses; show objects and arrays as expandable nodes with visibly distinct scalar types. Support formatting, copying selected values, searching keys/values, and actionable parsing errors. Reuse Red's JSON library and ordinary arrays/maps rather than introducing a second JSON representation without need.

### 4.8 Native GUI component gallery

Create a gallery with interactive previews, editable properties, state demonstrations, and valid Red snippets. It must use the same native component layer as Red Studio rather than mockups or terminal widgets.

| Components | Initial target |
|---|---|
| Label, button, input, multiline editor | P0 |
| Scroll container, split panel, tabs, tree | P0 |
| Checkbox, switch, radio group, slider, progress bar | P1 |
| Dropdown, list, table, dialog, context menu, tooltip | P1 |

Selecting a component opens an inspector for relevant properties (text, dimensions, enabled state, style, corner radius, etc.). Updates should render immediately. Include hover/focus/disabled states, resizing, and keyboard interaction. Components not yet available in the native pixel API are **required implementation work**, not assumed existing capabilities.

## 5. Native GUI foundation

A reusable component abstraction is required. Conceptually each component can measure, lay out, render, receive events, and invalidate itself; final API names should follow Andy's implementation conventions.

**Layout:** horizontal/vertical composition, fixed and flexible sizes, minimum/maximum constraints, padding, gaps, alignment, clipping, scrolling, overlays, and split panes.

**Input:** mouse move/click/drag/wheel, keyboard events, text entry, focus changes, window resize, and close requests. Maintain one logical focus target per window; Tab and Shift+Tab navigate focusable elements, and modal dialogs capture relevant input.

**Performance:** avoid rebuilding all application state for routine interactions. Complete scene redraws are acceptable initially if responsiveness targets are met; introduce partial invalidation later when justified by measurement.

## 6. Visual design

A modern, readable developer-tool aesthetic with a dark default theme, restrained red accent, consistent spacing, and clear status colors.

| Token | Hex |
|---|---|
| Background | `#171B23` |
| Sidebar | `#202631` |
| Surface | `#2B3341` |
| Border | `#3B4555` |
| Accent | `#E05B50` |
| Main text | `#F0F2F6` |
| Muted text | `#98A5B8` |
| Success | `#49B58B` |

Use proportional text for controls and monospaced text for code/output. Ship dark, light, and high-contrast themes by v1. Theme switches take effect without a restart and persist across launches. Do not rely on color alone to convey status.

## 7. State and persistence

### 7.1 Persistent user preferences

Save theme, window bounds, sidebar/output panel sizes, editor font size, Red executable path, recent projects, and keyboard preferences. Store settings in an application-specific user configuration directory using JSON, with atomic writes where possible.

### 7.2 Project settings

Keep entry point, working directory, run arguments, environment overrides, and approved build/test configurations separate from global preferences. Avoid storing secrets in project files by default.

### 7.3 Session restoration

On launch, restore the last project, open files, active tab, and panel layout when the underlying paths still exist. Missing paths are reported gracefully. If the application crashes, recover unsaved buffers where feasible in v1; an MVP must at minimum never silently discard dirty buffers during ordinary close operations.

## 8. Architecture and module plan

```text
studio/
  main.red
  app/
    state.red
    commands.red
    settings.red
    persistence.red
  native_ui/
    window.red
    scene.red
    layout.red
    components.red
    theme.red
    focus.red
  project/
    model.red
    explorer.red
    operations.red
    search.red
  editor/
    document.red
    editor.red
    tokenizer.red
  tasks/
    manager.red
    worker.red
    process.red
  tools/
    red_toolchain.red
    diagnostics.red
  inspector/
    http.red
    json.red
  gallery/
    gallery.red
    examples.red
  api/
    server.red
  tests/
```

These are proposed module boundaries; revise to match actual import and compilation behavior. Keep filesystem/process/network services independent from GUI components so they can be tested without a window. Centralize side effects and use channels to deliver background results to application state.

## 9. Error handling and safety

- Use typed errors or distinguishable error kinds for filesystem, process, HTTP, JSON, and GUI failures.
- Use `finally` for reliable cleanup of files, sockets, and task resources.
- Report operation failures with actionable context, not silent toasts alone.
- Confirm deletes and destructive overwrites.
- Protect unsaved editor documents on close, project switch, and external file modification.
- Validate project-relative paths before any API-triggered file operation.
- Avoid shell interpolation for subprocess arguments.
- Avoid persisting authorization headers or secrets in plaintext request history without an explicit opt-in and warning.

## 10. Non-functional requirements

| Area | Requirement |
|---|---|
| Responsiveness | GUI remains interactive during scans, builds, tests, and requests. |
| Startup | Open to a usable window without waiting for a full recursive project scan. |
| Large projects | Lazy directory expansion and bounded worker concurrency. |
| Cross-platform | Same Red application logic on macOS and Linux; platform-specific behavior confined to native backend. |
| Unicode | Correct text input, display, and cursor behavior for supported scripts. |
| Resizing | No overlapping or inaccessible primary controls at documented minimum window size. |
| Reliability | Errors do not terminate the whole GUI unnecessarily; dirty work is guarded. |
| Observability | Task logs, durations, error details, and optional renderer trace. |
| Packaging | Reproducible documented build and launch instructions. |

Performance budgets should be measured on reference macOS/Linux hardware during implementation rather than claimed in advance. Record startup time, interaction latency, and responsiveness during a representative scan/test workload.

## 11. Testing and acceptance

### 11.1 Test layers

- Unit tests for project models, settings, path validation, tokenization, JSON transformations, and task state transitions.
- Service tests for file operations, process execution, HTTP, and cancellation using temporary directories and local endpoints.
- Native GUI integration tests for focus, pointer input, resize, dialogs, and scene updates; add a test harness for pixel-scene behavior where Andy's cell-based headless backend is not applicable.
- End-to-end tests for open → edit → save → run → inspect output → compile → test.
- Platform smoke tests on macOS and Linux.

Do not assume `andy.backend.Headless` validates the native pixel scene renderer: it is documented for the cell-based widget path. Native scene tests need their own appropriate coverage.

### 11.2 Release acceptance

A v1 release is accepted when a user can launch a native desktop window, open the Red repository, browse and edit source, safely save, execute and test a program, inspect output and JSON, start an HTTP request, run independent tasks without UI blocking, explore the native component gallery, change themes, restore a session, and launch the packaged application on both supported platforms.

## 12. Development phases

| Phase | Deliverables | Exit criterion |
|---|---|---|
| 0 — Native foundation | Window lifecycle, scene/event plumbing, layout, text input, focus, basic controls | Interactive resizable native window |
| 1 — Explorer | Project opening, lazy tree, file operations | Navigate and manage a real project |
| 2 — Editor + runner | Tabs, dirty state, save, run, output | Edit and execute a Red program |
| 3 — Task manager | Queue, workers, result channel, statuses | Build/scan while GUI stays responsive |
| 4 — Inspectors | HTTP requests and JSON tree | Inspect local HTTP JSON responses |
| 5 — Gallery + polish | Native controls, themes, keyboard coverage | Complete native component showcase |
| 6 — Packaging + tests | Regression suite and standalone distribution | v1 acceptance criteria pass on macOS and Linux |

**MVP:** Phases 0–3, including a small gallery of the native controls already used by the workbench. Full HTTP/JSON inspection, richer controls, and packaging polish follow in v1.

## 13. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Native pixel API is newer and less complete than cell-based Andy | Treat native component/layout/input infrastructure as Phase 0 and validate primitives early. |
| Rich editor scope overwhelms the project | Start with reliable text editing; defer language-server-grade features. |
| Background workers corrupt UI state | Single GUI owner; channels for worker results; test lifecycle transitions. |
| Process cancellation differs by platform | Abstract process management and distinguish requested vs confirmed termination. |
| HTTP client lacks TLS | Limit initial inspector to HTTP/local services; document limitation. |
| Cell-based headless tests miss native bugs | Add dedicated native scene/event tests and platform smoke tests. |
| Files are lost on failed or interrupted saves | Atomic writes when possible, dirty-buffer safeguards, and recovery plan. |

## 14. Feature-to-language demonstration map

| Red capability | Red Studio use |
|---|---|
| Classes/inheritance | Project, document, task, and native component models |
| Functions/closures | Callbacks, actions, and event handlers |
| Modules/imports | Separate UI, editor, services, and inspectors |
| Enums | Task and document states |
| Destructuring | Configuration and result handling |
| Arrays/maps/sets | Documents, settings, selections, and caches |
| Unicode/strings/regex | Editor text and search |
| Typed errors and `finally` | Failed operations and cleanup |
| Tasks/channels | Worker pool and GUI notifications |
| Mutex/semaphore/wait groups | Bounded and coordinated workloads |
| Filesystem | Explorer and persistence |
| Subprocesses | Run, compile, build, format, test |
| HTTP/JSON | Inspector and optional local API |
| Timers | Autosave and UI/task updates |
| FFI/native integration | Native backend where necessary |
| Bytecode/standalone build | Compile and distribute the application |
| Native GUI | All screens and component gallery |
| Testing | Application and native GUI regression suite |

## 15. Core demonstration scenario

Launch Red Studio as a native desktop application. Open the Red repository, browse its source tree, edit a Red program, run a test suite while continuing to interact with the GUI, inspect errors and output, compile the program, view a local JSON HTTP response, and open the native component gallery. Show the application's source and build steps so the demonstration is reproducible.

## 16. Source references

- [Red repository](https://github.com/blitzwolfz/Red)
- [Red README](https://github.com/blitzwolfz/Red/blob/master/README.md)
- [Red changelog](https://github.com/blitzwolfz/Red/blob/master/CHANGELOG.md)
- [Andy GUI reference](https://github.com/blitzwolfz/Red/blob/master/docs/andy.md)
- [Red standard library](https://github.com/blitzwolfz/Red/blob/master/docs/std.md)
- [Native pixel scenes commit](https://github.com/blitzwolfz/Red/commit/a8739a799c04154a09dfb2da8f6873194e6b8885)
