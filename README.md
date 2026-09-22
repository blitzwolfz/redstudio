# Red Studio

A native pixel-scene workbench for Red projects. Red Studio uses the native `andy-gui` window backend for its desktop UI and keeps project, document, task, HTTP, JSON and gallery code in Red modules.

![Red Studio mark](studio/assets/logo.png)

## Run

The checked-out Red repository should sit beside this folder at `~/Desktop/Red`, with its interpreter built at `Red/build/red`.

```sh
./studio/run.sh
```

`RED_EXECUTABLE` can point to another Red interpreter and `RED_STUDIO_PROJECT` can select the project to open. The default project is the sibling `Red` checkout.

To render the same native pixel scene without opening a macOS window:

```sh
./studio/run-headless.sh
```

Headless mode writes the native scene protocol to `/tmp/red-studio.scene` (override with `RED_STUDIO_SCENE`) and exits. It does not start the native window process.

## Current workbench

- Project explorer with lazy one-directory-at-a-time navigation, text-file tabs, create, rename and confirmed file delete.
- Per-tab editing buffers, dirty markers, atomic save, and basic keyboard editing.
- Background Red run, build and test jobs with output and duration reporting.
- HTTP GET inspector for plain HTTP, including response headers and JSON formatting.
- JSON file view and native component gallery.
- Dark native pixel layout with status and output panels.

Keyboard shortcuts: `Ctrl+S` save, `Ctrl+R` run, `Ctrl+B` build an executable, `Ctrl+Shift+B` compile bytecode, `Ctrl+Shift+F` format, `Ctrl+T` test, arrow keys move the editor cursor, `F2` rename the selected file, and `Ctrl+D` then type `DELETE` to confirm deletion. `Ctrl+Alt+S` opens Save As. Clicking **New file** in the explorer opens its name prompt. The Tasks view shows queued, running and completed work. In the HTTP view, click the URL field, edit it, then press Return or **Send GET**.

The current Red HTTP client is plain HTTP only. The source editor is intentionally a lightweight buffer/editor foundation, not a language-server editor.
