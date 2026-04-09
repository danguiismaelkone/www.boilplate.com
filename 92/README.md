Below is a **complete user documentation** for the Instruction Executor – a Bash script that automates file system operations, text edits, JSON manipulation, command execution, variable substitution, and template rendering from a plain‑text instruction file.

---

# Instruction Executor – User Guide

## Overview

The Instruction Executor reads a text file containing high‑level commands and executes them sequentially. It is designed for:

- Project scaffolding
- CI/CD pipelines
- Development environment setup
- Automated configuration management

All commands are **idempotent** – running the same instruction file multiple times produces the same final state without errors or duplicate changes.

---

## Requirements

- **Bash 3.2+** (macOS / Linux / WSL)
- **jq** – required for `JSONINSERT` command  
  Install: `apt install jq` (Debian/Ubuntu), `brew install jq` (macOS)
- **Optional:** `timeout` (GNU coreutils) – for `EXEC` command timeouts; not required on macOS (script falls back gracefully)

---

## Installation

1. Download all script files into a directory:
   ```
   instruction-executor/
   ├── main.sh
   ├── utils.sh
   └── commands/
       ├── filesystem.sh
       ├── content.sh
       ├── replace.sh
       ├── exec.sh
       ├── json.sh
       ├── linter.sh
       └── variables.sh
   ```

2. Make the main script executable:
   ```bash
   chmod +x main.sh
   ```

3. Run with `./main.sh --help` (see usage below).

---

## Usage

```bash
./main.sh [options] <instruction_file>
```

### Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Simulate execution – print what would be done without making any changes. |
| `--lint`    | Validate instruction file syntax without executing anything. |
| `--allowlist <file>` | Restrict `EXEC` commands to patterns listed in the file (one per line). |
| `--log-level <LEVEL>` | Set logging verbosity: `DEBUG`, `INFO` (default), `WARN`, `ERROR`. |
| `--log-file <file>`   | Append all log messages to the specified file. |
| `--log-json`          | Output logs in JSON format (one object per line). |

### Examples

```bash
# Normal execution
./main.sh instructions.txt

# Dry run (preview only)
./main.sh --dry-run instructions.txt

# Lint the instruction file
./main.sh --lint instructions.txt

# Run with debug logging to a file
./main.sh --log-level DEBUG --log-file executor.log instructions.txt

# Use an allowlist for EXEC commands
./main.sh --allowlist allowlist.txt instructions.txt

# Combine options
./main.sh --dry-run --log-level DEBUG instructions.txt
```

---

## Instruction File Format

- Lines starting with `#` are **comments** (ignored).
- Empty lines are ignored.
- Commands are **case‑sensitive** and must be at the beginning of a line.
- Arguments can be **quoted** with single or double quotes to include spaces or special characters.
- Multi‑line content for `WRITE` / `APPEND` ends with a line containing only `END`.

---

## Command Reference

### 1. File System Operations

#### `MKDIR <directory>`
Creates a directory (and any missing parents).

```
MKDIR project/src
MKDIR "project/data backups"
```

#### `CREATE <file>`
Creates an empty file. Does nothing if the file already exists (idempotent).

```
CREATE README.md
CREATE "docs/user guide.txt"
```

#### `DELETE <file>`
Deletes a file. Does not fail if the file is missing.

```
DELETE old.log
DELETE "temp/cache.tmp"
```

#### `RMDIR <directory>`
Deletes a directory and all its contents recursively.

```
RMDIR build/cache
RMDIR "old backups/2023"
```

#### `COPY <source> <destination>`
Copies a file or directory recursively. Skips if destination already exists.

```
COPY config.json project/config.json
COPY templates/ "project/templates backup"
```

#### `MOVE <source> <destination>`
Moves or renames a file or directory.

```
MOVE oldname.txt newname.txt
MOVE "data/draft.csv" "archive/final.csv"
```

---

### 2. Content Writing

#### `WRITE <file>`
Overwrites a file with the content that follows until an `END` line.  
If the file already contains exactly the same content, nothing is changed.

```
WRITE config.env
DB_HOST=localhost
DB_PORT=5432
END
```

#### `APPEND <file>`
Appends content to the end of a file.  
If the content is already present at the end, nothing is appended.

```
APPEND log.txt
[INFO] Setup completed at $(date)
END
```

---

### 3. Text Replacement

#### `REPLACE <file> <old_string> <new_string>`
Replaces **all occurrences** of `<old_string>` with `<new_string>` in the file.  
The replacement is literal (special regex characters are escaped automatically).  
Spaces are allowed – quote the arguments.

```
REPLACE README.md "version 1.0" "version 2.0"
REPLACE "src/main.py" "old_function" "new_function"
```

---

### 4. JSON Manipulation

#### `JSONINSERT <file> <key> <value> [json_path]`
Inserts a key‑value pair into a JSON file using `jq`.  
- The file must exist and contain valid JSON.  
- The key is inserted under the object at `json_path` (default: `.scripts`).  
- The value is stored as a JSON **string**.

```
# Insert into default .scripts object
JSONINSERT package.json "start" "node server.js"

# Insert into a custom path
JSONINSERT config.json "timeout" "30" ".server.settings"
```

---

### 5. Command Execution

#### `EXEC <command>`
Executes an arbitrary shell command.  
- Commands are run with `bash -c`.  
- A 30‑second timeout applies (change with `export EXEC_TIMEOUT=60`).  
- If an **allowlist** is provided, the command must match one of the patterns (glob syntax).

```
EXEC echo "Build complete"
EXEC "npm install && npm run build"
```

**Security note:** Use `--allowlist` to restrict allowed commands in production.

---

### 6. Variables

#### `SET <name>=<value>`
Defines a variable. Variables can be used later in any command argument (except `SET` itself).

```
SET PROJECT_NAME=myapp
SET PORT=3000
```

#### Variable substitution
Use `$VAR` or `${VAR}` in command arguments:

```
MKDIR $PROJECT_NAME
CREATE ${PROJECT_NAME}/.env
WRITE $PROJECT_NAME/.env
PORT=${PORT}
END
```

Variables are **not** substituted inside `WRITE`/`APPEND` content by default – use `RENDER` for templates.

---

### 7. Template Rendering

#### `RENDER <template> <output> [--vars <file>]`
Renders a template file, replacing `{{VAR}}` and `$VAR` with current variable values.  
Optionally load variables from a file (`--vars`), one per line `NAME=VALUE`.

Template file `config.tmpl`:
```json
{
  "app": "{{PROJECT_NAME}}",
  "port": $PORT
}
```

Instruction:
```
SET PROJECT_NAME=myapp
SET PORT=3000
RENDER config.tmpl config.json
```

Result `config.json`:
```json
{
  "app": "myapp",
  "port": 3000
}
```

---

### 8. Linting & Validation

The `--lint` mode checks the instruction file for:

- Unknown commands
- Missing arguments
- Unclosed `WRITE`/`APPEND` blocks
- Invalid `REPLACE` / `JSONINSERT` syntax

No filesystem changes occur. Use it in CI to catch errors early.

```bash
./main.sh --lint instructions.txt
```

---

## Complete Example

Instruction file `setup.txt`:

```text
# Create project structure
SET PROJECT_NAME=api
SET PORT=5000

MKDIR $PROJECT_NAME
MKDIR $PROJECT_NAME/src
CREATE $PROJECT_NAME/.env

WRITE $PROJECT_NAME/.env
PORT=${PORT}
END

# Copy configuration
COPY default-config.json $PROJECT_NAME/config.json

# Insert into package.json
JSONINSERT $PROJECT_NAME/package.json "start" "node server.js"

# Render template
RENDER templates/app.tmpl $PROJECT_NAME/app.js

# Install dependencies (only if allowlist permits)
EXEC cd $PROJECT_NAME && npm init -y && npm install express

echo "✅ Setup complete"
```

Run:

```bash
./main.sh --log-level INFO setup.txt
```

---

## Best Practices

- **Always test with `--dry-run`** before real execution.
- **Use `--lint` in CI pipelines** to validate instruction files.
- **Quote arguments** that contain spaces or special characters.
- **Use `--allowlist`** when running untrusted instruction files.
- **Make commands idempotent** – the script already handles `CREATE`, `WRITE`, `APPEND`, and `COPY` idempotently.
- **Set `EXEC_TIMEOUT`** for long‑running commands: `export EXEC_TIMEOUT=120`

---

## Troubleshooting

| Problem | Likely cause | Solution |
|---------|--------------|----------|
| `jq: command not found` | `jq` not installed | Install `jq` (see Requirements). |
| `File not found: package.json` | An `EXEC` that creates the file runs after a `JSONINSERT` that needs it | Reorder instructions – create files before modifying them. |
| `timeout: command not found` | macOS lacks GNU `timeout` | Ignore – script runs without timeout. Install `brew install coreutils` for full support. |
| `unbound variable` | Using `$VAR` before `SET` | Define variables before using them. |
| `Unknown command: import` | Linter saw content inside `WRITE` as commands | Use `--lint` correctly – it ignores content inside `WRITE`/`APPEND` blocks. |

---

## Exit Codes

- `0` – Success (or lint passed).
- `1` – Fatal error (missing file, command failure, invalid syntax, etc.).

---

## License

This script is open‑source. Use it freely in your projects.

---

## Support

For issues or feature requests, refer to the inline comments in the script or consult the source code.