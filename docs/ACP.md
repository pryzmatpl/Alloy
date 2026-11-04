# Alloy Compilation Protocol (ACP) 0.2

ACP is the JSON wire format that lets the Alloy CLI talk to any LLM that
exposes an OpenAI-compatible `/v1/chat/completions` endpoint. It is the
foundation of the Alloy v0.2 "LLM-as-compiler" architecture.

## Design goals

- **Provider agnostic**: Ollama, OpenAI, Groq, Anthropic (via compatibility
  layers), DeepSeek, etc. all work with the same schema.
- **Self-contained**: one request carries the full package text.
- **Structured output**: the LLM returns JSON, not free-form prose.
- **Extensible**: new `passes`, `options`, and `emit` formats can be added
  without breaking existing tools.

## Transport

The CLI sends the ACP request as the *user* message of a chat completion.
The *system* message is the content of `COMPILER_SYSTEM.md`. The model must
reply with a single assistant message whose entire content is a JSON object
matching the response schema in `ACP_SCHEMA.json`.

```
POST /v1/chat/completions
{
  "model": "qwen2.5:0.5b",
  "messages": [
    { "role": "system", "content": "... COMPILER_SYSTEM.md ..." },
    { "role": "user",   "content": "{ \"protocol\": \"acp/0.2\", ... }" }
  ],
  "temperature": 0.0
}
```

## Request schema

```json
{
  "protocol": "acp/0.2",
  "package": {
    "name": "hello",
    "kind": "bin",
    "files": {
      "alloy.toml": "[package]\nname = \"hello\"\n...",
      "src/main.al": "use std.io..."
    }
  },
  "target": "x86_64-unknown-linux-gnu",
  "passes": ["typecheck", "lower", "emit"],
  "options": {
    "opt_level": 0,
    "emit": "c"
  }
}
```

Fields:

| Field | Required | Description |
|-------|----------|-------------|
| `protocol` | yes | Must be `"acp/0.2"`. |
| `package.name` | yes | Package name from `alloy.toml`. |
| `package.kind` | yes | `"bin"` or `"lib"`. |
| `package.files` | yes | Map of relative path → file content. Must include `alloy.toml` and every `.al` source. |
| `target` | yes | Target triple, e.g. `x86_64-unknown-linux-gnu`. |
| `passes` | yes | Ordered list of passes to run: `typecheck`, `lower`, `emit`. |
| `options.opt_level` | no | Optimization level `0..3`. Default `0`. |
| `options.emit` | no | One of `ir`, `assembly`, `c`, `wasm`, `object`. Default `c`. |

## Response schema

```json
{
  "protocol": "acp/0.2",
  "status": "ok",
  "diagnostics": [],
  "resolved_target": "x86_64-unknown-linux-gnu",
  "ir": "@function main() -> i32 { ... }",
  "artifacts": [
    { "name": "hello.c", "content": "#include <stdio.h>\nint main(void) {...}", "encoding": "text" }
  ],
  "notes": "Compiled with opt_level=0."
}
```

Fields:

| Field | Required | Description |
|-------|----------|-------------|
| `protocol` | yes | Must be `"acp/0.2"`. |
| `status` | yes | `"ok"` or `"error"`. |
| `diagnostics` | no | Array of diagnostic objects. Non-empty diagnostics do not necessarily imply `status=error`; an `error` level diagnostic does. |
| `resolved_target` | no | The target the model actually compiled for. |
| `ir` | no | Textual Alloy IR produced by the `lower` pass. |
| `artifacts` | no | Files to write to the build directory. |
| `notes` | no | Human-readable notes from the compiler model. |

### Diagnostic object

```json
{
  "level": "error",
  "message": "Unknown identifier 'Writter'",
  "file": "src/main.al",
  "line": 5,
  "column": 12
}
```

`level` is one of `error`, `warning`, `info`.

### Artifact object

```json
{
  "name": "hello.s",
  "content": "...",
  "encoding": "text"
}
```

`encoding` defaults to `text`. Use `base64` for binary artifacts such as WASM
binaries or object files.

## Passes

### `typecheck`

Validate the package against the Alloy v0.2 spec. Return only diagnostics.
`ir` and `artifacts` are optional and usually omitted.

### `lower`

Translate the source into Alloy IR (§17 of `SPEC.md`). The `ir` field should
contain the IR text.

### `emit`

Generate artifacts for the requested `options.emit` format. The `artifacts`
array must contain at least one file.

For `emit=c`, the artifact should be a single self-contained C source file
that can be compiled with a host C compiler to produce the final binary.

## Target triples

ACP/0.2 recognizes at least these triples:

- `x86_64-unknown-linux-gnu`
- `aarch64-unknown-linux-gnu`
- `aarch64-apple-darwin`
- `x86_64-pc-windows-msvc`
- `wasm32-wasi`

Models are encouraged to fall back to portable C when a specific assembly
target is not supported.

## Error handling

If the model cannot compile the package it must set `status=error` and include
at least one diagnostic with `level=error` explaining why. It must still emit
valid JSON; the CLI will surface the diagnostics and exit with a non-zero
status.

## Example golden request/response

### Request

```json
{
  "protocol": "acp/0.2",
  "package": {
    "name": "hello",
    "kind": "bin",
    "files": {
      "alloy.toml": "[package]\nname = \"hello\"\nversion = \"0.2.0\"\nkind = \"bin\"\n\n[compiler]\nprovider = \"ollama\"\nmodel = \"qwen2.5:0.5b\"\n",
      "src/main.al": "use std.io.{Writer, write_str, register_io};\nuse std.di.Container;\n\nfunction main(): i32 {\n    let di = Container();\n    register_io(di);\n    let out: Writer = di.get<Writer>();\n    match write_str(out, \"Hello, world!\\n\") {\n        Ok(_)  => { return 0; }\n        Err(_) => { return 1; }\n    }\n}\n"
    }
  },
  "target": "x86_64-unknown-linux-gnu",
  "passes": ["typecheck", "lower", "emit"],
  "options": { "opt_level": 0, "emit": "c" }
}
```

### Response

```json
{
  "protocol": "acp/0.2",
  "status": "ok",
  "diagnostics": [],
  "resolved_target": "x86_64-unknown-linux-gnu",
  "ir": "@function main() -> i32 {\nentry:\n  %r = call @write_str(\"Hello, world!\\n\")\n  %code = match %r { Ok(%_) => 0, Err(%_) => 1 }\n  ret %code\n}",
  "artifacts": [
    {
      "name": "hello.c",
      "content": "#include <stdio.h>\n#include <stdlib.h>\nint main(void) {\n    if (printf(\"Hello, world!\\n\") < 0) return 1;\n    return 0;\n}\n",
      "encoding": "text"
    }
  ],
  "notes": "Stub C backend for hello world."
}
```
