# Alloy Language Specification
Version 0.1 — 2026-09-15
Status: design freeze for LLM consumption (not a production compiler)

This document is the source of truth for Alloy. An implementation or an LLM
must follow it. If example code and a rule conflict, the rule wins.

Goals Alloy is allowed to have:
- C++-class raw pointers, pointer arithmetic, and extern C/WASI/Win32
- PHP-class interfaces, classes, and constructor-style dependency injection
- Rust-class “one package, many targets” builds
- No borrow checker, no lifetime parameters, no `fn` keyword

---

## 1. Design axioms

1. Classes are GC-managed reference objects. Structs and primitives are values.
2. `*T`, `*const T`, and `*mut T` are machine addresses. The compiler does not
   prove they are live. Dereferencing an invalid pointer is undefined behavior.
3. An interface is a named set of methods. Dispatch is by vtable (fat pointer).
4. A container maps a type id to a factory. That is the DI system.
5. Target differences live behind `#if target…`. Application code must not
   mention OS handles unless it is a sys layer.
6. Functions are introduced with the keyword `function`. Never `fn`, `func`,
   or `def`.
7. Types are written after names in bindings (`x: i32`) and after `:` on
   function returns (`function f(): i32`).

---

## 2. Lexical grammar

```
comment      ::= "//" ~[\n]* | "/*" .* "*/"
ident        ::= [A-Za-z_][A-Za-z0-9_]*
int          ::= [0-9]+ | "0x" [0-9A-Fa-f]+
float        ::= [0-9]+ "." [0-9]+ (("e"|"E") [+-]? [0-9]+)?
string       ::= '"' { escape | ~["\\] } '"'
escape       ::= "\\" ["\\nrt0] | "\\x" hex hex | "\\u{" hex+ "}"
punct        ::= { { } ( ) [ ] , ; . : :: -> => + - * / % & | ^ ! = == !=
                  < > <= >= && || += -= *mut *const }
```

Keywords (cannot be idents):

```
as break class continue else enum extern false function if implements
interface let match null private public return static struct true
use var while
```

Contextual words (idents unless in their slot): `self`, `target`, `Ok`, `Err`.

Whitespace and comments are ignored except as token separators.

---

## 3. Compilation units and modules

A package is a directory with `alloy.toml` and `src/`.

```
package-root/
  alloy.toml
  src/
    main.al          # binary crate entry
    lib.al           # library crate entry (optional)
    io/
      sys.al
```

`alloy.toml`:

```toml
[package]
name = "hello"
version = "0.1.0"
kind = "bin"          # bin | lib

[dependencies]
# packages resolve by name; no version solver required at 0.1
```

Module path = file path under `src/` without `.al`, `/` becomes `.`.

```
src/io/sys.al   =>  crate.io.sys
```

Import:

```
use std.io.{Writer, write_str, register_io};
use std.di.Container;
use std.io.sys;                  # whole module
```

`use` only imports public names. Cycles between modules are illegal.

The prelude (always in scope): `i8 i16 i32 i64 u8 u16 u32 u64 usize isize
f32 f64 bool void string bytes Result Ok Err null true false`.

---

## 4. Types

### 4.1 Primitives

| Name    | Meaning                         |
|---------|---------------------------------|
| `void`  | unit; only value is `()`        |
| `bool`  | `true` / `false`                |
| `iN/uN` | two’s-complement / unsigned     |
| `usize` | pointer-sized unsigned          |
| `isize` | pointer-sized signed            |
| `f32/f64` | IEEE-754                      |
| `string`| GC UTF-8 string (length-prefixed) |
| `bytes` | alias of `*const u8` (not a fat pointer) |

`string` is not a pointer. Convert with `s.as_ptr(): *const u8` and `s.len(): usize`.

### 4.2 Pointers

```
pointer-type ::= "*" type | "*const" type | "*mut" type
```

- `*T` and `*const T` are identical: read-only raw pointer.
- `*mut T` is a writable raw pointer.
- `null` inhabits every pointer type.
- Arithmetic: `p + n`, `p - n`, `p - q` where `n: usize`/`isize`.
  Units are elements of `T`, not bytes, unless `T` is `u8`/`i8`/`void`.
- Load: `*p`. Store: `*p = v` only if `p: *mut T`.
- Address-of: `&expr` yields `*const T`. `&mut expr` yields `*mut T`.
- Cast: `p as *mut U` / `p as *const U` / `p as usize`.

There is no reference type `&T` as a distinct checked type. Write a pointer.

### 4.3 Structs (values)

```
struct IoError {
    public code: i32;
    public msg: string;
}
```

- Copied by assignment.
- Fields default to public if unmarked; `private` is allowed.
- No inheritance.
- May be packed later; v0.1 layout is C layout, pointer-aligned.

### 4.4 Classes (GC objects)

```
class Fd implements Reader, Writer {
    private raw: fd;
    private owned: bool;
}
```

- Assignment copies the reference, not the object.
- Identity is the heap address.
- `implements I, J` requires every method of those interfaces.
- Single inheritance is **not** in v0.1. Compose instead.
- Optional `function drop(self)` runs before GC reclaims (not guaranteed instant).

### 4.5 Interfaces

```
interface Writer {
    function write(self, ptr: *const u8, len: usize): Result<usize, IoError>;
    function flush(self): Result<void, IoError>;
}
```

- Methods must name `self` as the first parameter. `self` is the receiver object.
- No fields, no constructors, no static methods.
- A value of interface type is a fat pointer `{ data: *mut void, vtable: *const void }`.
- Casting `obj as Writer` succeeds if the class implements `Writer`.
- Casting failure is a runtime panic in v0.1 (no `as?` yet).

### 4.6 Enums and Result

```
enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

User enums are allowed:

```
enum Whence { Set, Cur, End }
```

Payload variants use `Variant(Type)` or `Variant { field: Type }`.

### 4.7 Generics (minimal)

Only type parameters on classes, functions, and `Result`. No bounds language
beyond “T is a type”. No generic interfaces in v0.1 except the written
`Result<T, E>` and `Container` methods `bind<T>` / `get<T>`.

### 4.8 Function types

```
function(Container): Writer
function(i32, i32): i32
```

These are closures or function pointers. Closures that capture GC objects are
GC-managed. Closures that capture raw pointers do not extend those pointers’
validity.

---

## 5. Declarations

### 5.1 Functions

```
function name(param: Type, ...): RetType { block }
static function name(...): RetType { block }          # class associated
public function name(self, ...): RetType { block }    # method
```

Rules:
- Keyword is always `function`.
- Return type is mandatory except for `function drop(self)`.
- `return expr;` or `return;` when RetType is `void`.
- Nested functions are illegal. Closures are expressions (see §6).

### 5.2 Variables

```
let x: i32 = 1;     # immutable binding
var y: i32 = 1;     # mutable binding
let z = 1;          # type inferred from initializer; required to have one
```

`let` cannot be assigned after init. `var` can. No `const` keyword in v0.1
(`let` at module scope is a constant if the initializer is a constant expr).

### 5.3 Visibility

`public` / `private` on class members and top-level items. Default at module
top-level is private. Default on struct fields is public. Default on class
fields is private.

---

## 6. Expressions and statements

### 6.1 Operators (precedence high to low)

```
.call  []  .  as
unary + - ! *
* / %
+ -
<< >>                    # if implemented; v0.1 includes << >>
< > <= >=
== !=
&
^
|
&&
||
=  +=  -=
```

### 6.2 Calls

```
write_str(out, "Hello\n")
Stdout::writer()
obj.write(ptr, len)
```

`::` is static / enum / module path access. `.` is instance access.

### 6.3 Closures

```
function(c: Container): Writer { return Stdout::writer() as Writer; }
```

A closure is `function (params) [: Ret]? { body }`. If used as a factory
argument, parameter and return types must be written.

### 6.4 match

```
match expr {
    Ok(n)  => stmt-or-block
    Err(e) => stmt-or-block
}
```

`match` on `Result` must be exhaustive. `match` is a statement in v0.1, not
an expression, unless every arm yields a value of one type and the match is
used as `let x = match …`.

Allowed:

```
let n = match w.write(p, n) {
    Ok(k)  => k
    Err(e) => return Err(e)
};
```

### 6.5 Control

```
if cond { } else if cond { } else { }
while cond { }
break; continue;
```

No C-style `for`. Iterate with `while` and an index. No exceptions. Errors
are `Result` values.

### 6.6 Object and struct literals

```
IoError { code: -1, msg: "short write" }
Fd { raw: 1, owned: false }          # only legal inside the class or a static factory
```

Class literals from outside the class are illegal. Use a static factory.

---

## 7. Memory and undefined behavior

Defined:
- Reading a `let`/`var` of a primitive, struct, or class reference that was initialized.
- Loading through a pointer that points at a live object of the right type
  and alignment, during that object’s lifetime.
- GC moving is **not** allowed to move an object whose address was taken
  with `&` / `&mut` while that pointer may still be used. Implementations
  must pin any object whose address escapes to a raw pointer, or use a
  non-moving GC.

Undefined:
- Dereference of `null`
- Use-after-free of a non-GC allocation (if an allocator API is used)
- Data race on `*mut T` from two threads (threads are not in v0.1)
- Type-punned load that violates alignment or trap representations

The language does not insert bounds checks on raw pointer arithmetic.

`string.as_ptr()` is valid until the string becomes unreachable **and** GC
collects it. Keep the `string` live while using the pointer.

---

## 8. Targets and conditional compilation

```
#if target.family == "unix"
    …code…
#elif target.os == "windows"
    …code…
#elif target.os == "wasi"
    …code…
#else
    …code…
#endif
```

`target` fields:

| Field    | Values                                      |
|----------|---------------------------------------------|
| `os`     | `linux`, `macos`, `windows`, `wasi`, `none` |
| `family` | `unix`, `windows`, `wasi`, `none`           |
| `arch`   | `x86_64`, `aarch64`, `wasm32`, `arm`        |
| `env`    | `gnu`, `msvc`, `musl`, `eabi`, ``           |

`#if` may wrap items or statements. Both branches must parse.

`extern` linkage:

```
extern "C" write(fd: i32, buf: *const u8, n: usize): isize;
extern "wasi" fd_write(fd: i32, iovs: *const Ciovec, iovcnt: usize, nwritten: *mut usize): i32;
```

`extern` declarations have no body. They are not introduced with `function`.

---

## 9. Dependency injection

```
class Container {
    public function bind<T>(self, factory: function(Container): T);
    public function get<T>(self): T;
}
```

Semantics:
- `bind<T>` stores one factory per type id. A second bind replaces the first.
- `get<T>` calls the factory and returns the value. If T is an interface,
  the factory must return a class instance cast to that interface.
- Missing binding: runtime panic with message `"unbound type"`.
- Factories may call `c.get<U>()` (constructor injection). Cycles panic.

Std registration for IO:

```
function register_io(c: Container) {
    c.bind<Writer>(function(_c: Container): Writer {
        return Stdout::writer() as Writer;
    });
    c.bind<Reader>(function(_c: Container): Reader {
        return Fd::from_raw(0, false) as Reader;
    });
}
```

---

## 10. Standard library (mandatory subset)

Package name `std`. Always available.

### 10.1 `std.io`

```
struct IoError {
    public code: i32;
    public msg: string;
}

interface Writer {
    function write(self, ptr: *const u8, len: usize): Result<usize, IoError>;
    function flush(self): Result<void, IoError>;
}

interface Reader {
    function read(self, ptr: *mut u8, cap: usize): Result<usize, IoError>;
}

class Fd implements Reader, Writer {
    public static function from_raw(raw: i32, owned: bool): Fd;
    public function write(self, ptr: *const u8, len: usize): Result<usize, IoError>;
    public function read(self, ptr: *mut u8, cap: usize): Result<usize, IoError>;
    public function flush(self): Result<void, IoError>;
}

class Stdout {
    public static function writer(): Fd;   # fd 1 on unix/wasi; GetStdHandle on win
}

function write_str(w: Writer, s: string): Result<usize, IoError>;
function write_all(w: Writer, ptr: *const u8, len: usize): Result<void, IoError>;
function register_io(c: Container);
```

On POSIX, `Stdout::writer()` is `Fd::from_raw(1, false)`.
On Windows, it wraps `GetStdHandle(-11)`.
On WASI, it uses `fd_write` on fd 1.

### 10.2 `std.di`

```
class Container {
    public function bind<T>(self, factory: function(Container): T);
    public function get<T>(self): T;
}
```

### 10.3 string operations (prelude)

```
s.len(): usize
s.as_ptr(): *const u8
```

No other string API is required to accept a program as valid Alloy v0.1.

---

## 11. Programs and entry

A `bin` package must define:

```
function main(): i32 { … }
```

Return `0` on success. Arguments, env, and async are out of scope.

A `lib` package exports its public items; no `main`.

---

## 12. Build interface (for LLMs that “compile”)

Commands an Alloy tool or a simulated tool must understand:

```
alloy build
alloy build --target <triple>
alloy check                  # parse + type check only
alloy run                    # build host target and execute
```

Triples (v0.1):

```
x86_64-unknown-linux-gnu
aarch64-unknown-linux-gnu
aarch64-apple-darwin
x86_64-pc-windows-msvc
wasm32-wasi
```

Emit:
- native: an executable named after `[package].name`
- wasi: `name.wasm`

When an LLM cannot actually invoke a backend, it must still:
1. Emit a complete package tree.
2. Run `alloy check` rules from this spec mentally.
3. State the target and the resolved `#if` branch.

---

## 13. Concrete syntax summary (EBNF, simplified)

```
file         ::= { item }
item         ::= use-item | struct-item | class-item | interface-item
               | enum-item | function-item | extern-item | if-target-item

use-item     ::= "use" path [ "." "{" ident { "," ident } "}" ] ";"

function-item::= [ "public" | "private" ] [ "static" ]
                 "function" ident "(" [ params ] ")" ":" type block

params       ::= param { "," param }
param        ::= ident ":" type
               | "self"

type         ::= ident [ "<" type { "," type } ">" ]
               | "*" type | "*const" type | "*mut" type
               | "function" "(" [ type { "," type } ] ")" ":" type

block        ::= "{" { stmt } "}"
stmt         ::= let-stmt | var-stmt | if-stmt | while-stmt | match-stmt
               | return-stmt | expr-stmt | block

let-stmt     ::= "let" ident [ ":" type ] "=" expr ";"
var-stmt     ::= "var" ident [ ":" type ] "=" expr ";"
```

---

## 14. Style rules for generated code

LLMs producing Alloy MUST:

1. Use `function`, never `fn`.
2. Put IO syscalls in a sys module behind `#if target`.
3. Talk to the world through `Writer` / `Reader` in application code.
4. Keep raw pointers in library kernels and `extern` signatures.
5. Return `Result<T, IoError>` from fallible IO. Do not throw.
6. Name files `*.al`.
7. Put `main` in `src/main.al`.
8. Not invent generics, async, traits, impl blocks, lifetimes, or macros.
9. Not use `$` (PHP), `->` method calls (PHP), or `func` (Go).
10. Method calls are `obj.method(args)`. Static calls are `Type::name(args)`.

Illegal (do not emit):

```
fn main() {}
func main() {}
function main() { }          # missing return type
$out->write(...)
impl Writer for Fd {}
let x: &str = "hi";
unsafe { *p }
```

There is no `unsafe` keyword. Raw pointers are always available and always raw.

---

## 15. Reference hello world (canonical)

`alloy.toml`

```toml
[package]
name = "hello"
version = "0.1.0"
kind = "bin"
```

`src/main.al`

```
use std.io.{Writer, write_str, register_io};
use std.di.Container;

function main(): i32 {
    let di = Container();
    register_io(di);

    let out: Writer = di.get<Writer>();

    match write_str(out, "Hello, world!\n") {
        Ok(_) => {
            return 0;
        }
        Err(e) => {
            return 1;
        }
    }
}
```

Low-level equivalent (also legal):

```
use std.io.Stdout;

function main(): i32 {
    let out = Stdout::writer();
    let s = "Hello, world!\n";
    match out.write(s.as_ptr(), s.len()) {
        Ok(_)  => { return 0; }
        Err(_) => { return 1; }
    }
}
```

---

## 16. Acceptance checklist

A source tree is valid Alloy v0.1 if:

- [ ] Every function uses `function` and has a return type (except `drop`)
- [ ] Every interface method starts with `self`
- [ ] No borrow-checker syntax appears
- [ ] Pointer operations only use `*`, `*mut`, `*const`, `&`, `&mut`, `as`
- [ ] `main` exists for bins and returns `i32`
- [ ] `use` paths resolve to public items
- [ ] `#if target` blocks parse on all branches
- [ ] DI use only goes through `Container.bind` / `get`
- [ ] Strings used as pointers remain reachable across the call
