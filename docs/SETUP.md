# Setup

## 1. System Prerequisites

Official compiler requirements depend on your operating system:

### Windows

* **C++ Toolchain:** Install [Visual Studio](https://visualstudio.microsoft.com/) with the **"Desktop development with C++"** workload enabled (includes MSVC and the Windows SDK).
* **Environment:** Execute builds inside the **x64 Native Tools Command Prompt for VS** or run `vcvarsall.bat x64` in your terminal session.

### macOS

* **Command Line Tools:** Install via terminal:

  ```bash
  xcode-select --install
  ```

* **LLVM:** Install LLVM (versions 17–22 supported):

  ```bash
  brew install llvm
  ```

### Linux (Debian/Ubuntu/Fedora)

* **Clang & LLVM:** Install `clang`, `llvm` (17+), and development dependencies:

  ```bash
  # Debian/Ubuntu
  sudo apt install clang llvm-17 lld-17 libstdc++-12-dev git-lfs
  ```

---

## 2. Installing Odin

Choose between downloading official binary releases or building the compiler from source.

### Method A: Official Binary Release

Download the latest pre-compiled archive for your OS from the official [Odin Releases page](https://github.com/odin-lang/Odin/releases). Extract the archive to your preferred directory (e.g., `C:\Odin` or `/opt/odin`).

### Method B: Building from Source (Recommended)

Cloning and building directly ensures access to the latest core/vendor updates:

1. **Clone the repository:**

   ```bash
   git clone [https://github.com/odin-lang/Odin](https://github.com/odin-lang/Odin)
   cd Odin
   ```

2. **Pull assets & compile:**
   * **Windows:**

     ```cmd
     git lfs install
     git lfs pull
     build.bat release
     ```

   * **macOS / Linux:**

     ```bash
     git lfs install
     git lfs pull
     make release-native
     ```

---

## 3. Environment Variables & System PATH

The compiler binary expects to be located alongside its `base`, `core`, and `vendor` package directories.

> **Note:** Always use **absolute paths** (e.g., `$HOME/Odin`) in your `PATH`. Relative paths will cause command failures when running from different directories.

### 1. Add `odin` to User `PATH`

* **Linux/macOS (`~/.bashrc` or `~/.zshrc`):**

  ```bash
  export PATH="$PATH:$HOME/path/to/Odin"
  ```

* **Windows (PowerShell):**

  ```powershell
  [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\path\to\Odin", "User")
  ```

### 2. System-wide Symlink (Recommended for IDEs & Subshells)

Tooling (such as OLS) often invokes the compiler via non-interactive subshells (`sh`), which do not load user shell configuration files (`~/.bashrc`). Symlinking `odin` into `/usr/local/bin` guarantees availability across all subshells:

```bash
sudo ln -sf /absolute/path/to/Odin/odin /usr/local/bin/odin
```

Verify in a plain subshell:

```bash
sh -c "odin version"
```

### 3. `ODIN_ROOT` (Optional)

If you move the `odin` executable outside of the main Odin installation directory, set `ODIN_ROOT` to point explicitly to the base repository path:

```bash
export ODIN_ROOT="/absolute/path/to/Odin"
```

---

## 4. IDE & Language Server (OLS) Setup

For autocompletion, go-to-definition, and formatting, set up the official community-standard **Odin Language Server (OLS)**.

### 1. Build OLS

```bash
git clone --depth 1 [https://github.com/DanielGavin/ols.git](https://github.com/DanielGavin/ols.git)
cd ols

# Build OLS binary and odinfmt formatter
./build.sh      # On Windows: build.bat
./odinfmt.sh    # On Windows: odinfmt.bat
```

### 2. Configure `builtin` Definitions & Binaries

OLS requires the `builtin` folder from its source repository to reside right next to the executable (or be defined via environment variable).

* **Option A: System PATH Installation (Linux/macOS)**

  Copy/symlink binaries and the `builtin` directory together:

  ```bash
  # Copy binaries
  sudo cp ols odinfmt /usr/local/bin/
  
  # Copy or symlink builtin folder alongside the binaries
  sudo cp -r builtin /usr/local/bin/builtin
  ```

* **Option B: VS Code Remote/WSL Extension Directory**

  If using the VS Code OLS extension (`DanielGavin.ols`) on WSL/Remote host, ensure the binary and `builtin` folder are placed in the extension's storage directory:

  ```bash
  # Set up storage path
  mkdir -p ~/.vscode-server/data/User/globalStorage/danielgavin.ols/0/
  
  # Copy binary and builtin definitions
  cp ols ~/.vscode-server/data/User/globalStorage/danielgavin.ols/0/ols-x86_64-unknown-linux-gnu
  cp -r builtin ~/.vscode-server/data/User/globalStorage/danielgavin.ols/0/builtin
  chmod +x ~/.vscode-server/data/User/globalStorage/danielgavin.ols/0/ols-x86_64-unknown-linux-gnu
  ```

* **Option C: Environment Variable Override**

  Alternatively, point OLS to your `builtin` path globally in your `~/.bashrc` or `~/.zshrc`:

  ```bash
  export OLS_BUILTIN_FOLDER="/absolute/path/to/ols/builtin"
  ```

### 3. Editor Configuration

* **VS Code:** Install the **Odin Language Server** extension (`DanielGavin.ols`).
* **Neovim / Helix:** Point your LSP client configuration to the `ols` binary executable.

---

## 5. Verification

Verify the environment and run a quick test program:

1. **Check Compiler & Toolchain Setup:**

   ```bash
   odin version
   odin report
   ```

2. **Run a Test Program:**
   Create `main.odin`:

   ```odin
   package main

   import "core:fmt"

   main :: proc() {
       fmt.println("Odin environment operational.")
   }
   ```

3. **Execute:**

   ```bash
   odin run main.odin -file
   ```
