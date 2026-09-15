# Alloy v0.1

Formalization of the Alloy language so another LLM (or a future compiler)
can write and check programs.

| File | Role |
|------|------|
| `SPEC.md` | Language law. Give this to a model as the spec. |
| `LLM_SYSTEM.md` | Short system prompt. Stack it on top of SPEC.md. |
| `PROMPT.txt` | Single paste blob (system + spec pointer + task frame). |
| `examples/hello/` | Canonical package. |

There is no official compiler yet. “Build” means: emit a valid package,
typecheck against the spec, and name the artifact a backend would produce.

## Hand to a model

```
You write Alloy v0.1 only.
Follow LLM_SYSTEM.md and SPEC.md exactly.
Keyword for routines is function, never fn.
```

Then attach both markdown files.

## Check a program yourself

Walk `SPEC.md` §16. If every box is ticked, the program is valid Alloy v0.1.
