# Defects found while updating the site for v0.2.3

Found by building algol24.com against the pinned compiler, machine and library,
and by running the generator under all three processors. Written here rather
than in `spec/DEFECTS.md` because that file wants an entry the compiler
repository owns; these are reports, with reproductions, for whoever takes them.

Versions: compiler and machine **v0.2.3** (tag `1fe0171`), library **v0.1.0**
(tag `a1791e0`). macOS 14, APFS, case-insensitive.

---

## D-1 — Two units whose names differ only in case: two processors, two wrong answers

**Severity.** The interpreter is right and the other two are wrong, differently.
It is silent in the sense that matters: nothing says *these two units collide*.

**What happens.** A program imports two units whose names differ only in case,
from two directories — which is the only way to have both, since one directory
on a case-insensitive filesystem cannot hold `Alpha.a24` and `alpha.a24`.

| | |
| --- | --- |
| interpreted, `algc` | **correct** — prints both lines |
| bytecode, `algvm` | `Uncaught: Undefined variable 'FromLower'.` |
| compiled, `algc --compile` | emits one `.c` for the two units; the C does not build |

Compiled, the emitter names each file after its unit, so `alpha.c` and
`Alpha.c` are one path and the second write wins. The surviving file holds one
unit's body while `Main.c` calls into the other, and `cc` reports a handful of
implicitly-declared functions — `init_Alpha`, `f_fromupper` — that nothing
emitted.

`algvm`'s failure looks like a module registry keyed case-insensitively, or one
that takes the second import for an already-loaded unit and skips it. That
would be wrong on a case-**sensitive** filesystem too, where the compiled half
presumably works, so the two halves may not have one cause.

**Reproduction.** Three files, two directories.

```
repro/a/Alpha.a24     unit Alpha;  function FromUpper () : String; ... 'from Alpha'
repro/b/alpha.a24     unit alpha;  function FromLower () : String; ... 'from alpha'
repro/Main.a24        uses 'a/Alpha';
                      uses 'b/alpha';
                      WriteLn (FromUpper ());
                      WriteLn (FromLower ());
```

```console
$ algc repro/Main.a24
from Alpha
from alpha

$ algvm repro/Main.a24
Uncaught: Undefined variable 'FromLower'.
from Alpha

$ algc --compile --out=out repro/Main.a24 && cc -std=gnu11 -O2 -o out/prog out/*.c
out/Main.c:10:5: error: call to undeclared function 'init_Alpha'
out/Main.c:12:24: error: call to undeclared function 'f_fromupper'
```

**Where it was met for real.** `gen/Strings.a24` (`unit Strings`) beside the
library's `strings.a24` (`unit strings`), reached by path. Five errors from
`cc`, about `init_strings` against `init_Strings`.

**What the specification says.** [MOD-002] already states that a module *name*
is matched by the filesystem, case-insensitively on macOS and Windows, and that
this is stated rather than fixed because the language does not own the
filesystem. Fair. But that rule is about **finding** a unit by name, and both
units here are found — by explicit path, which [MOD-001] provides. What goes
wrong afterwards is a unit **registry** and an output **filename**, both of
which the language does own.

**Worth considering.** Refusing the program outright would be a defensible
answer and better than either present behaviour: *two units whose names differ
only in case* is a diagnostic a reader could act on. Emitting a C filename
derived from the unit's path rather than its name would fix the compiled half
without a diagnostic, but would leave `algvm` wrong.

**How the site works around it.** `gen/Strings.a24` is now `gen/Markup.a24`,
holding the two functions the library does not have. A rename, not a fix.

---

## D-2 — `vm/REFERENCE.md` states 78 opcodes where `vm/OpCode.a24` has 80

Documentation, not behaviour, but in the one document whose stated discipline is
that it never argues with `OpCode.a24`:

> ⚠️ **`vm/OpCode.a24` is the authority and this file never argues with it.**

`OpCode.a24` declares 81 `const OP_`; the last is `OP_COUNT`, the sentinel that
ends the set and is not an instruction. So there are **80**, and the reference
carries exactly 80 `## OP_` entries — its own body disagrees with its own
opening sentence. `OVERVIEW.md` says 80 and is right.

`./vm/reference.sh` reports it in two lines that are easy to read as one:

```
described       : 79
variable-width  : 1
```

Taking the first for the total is how this nearly reached the website as 79.
A single stated total would be harder to misread.

---

## Not defects, but worth writing down

- **`algc --test vm/run.a24` raises** `Reset failed: no file has been
  assigned.` `run.a24` is the machine's entry point and expects a file to run,
  so its tests are reached as `./test.sh vm/Vm.a24` (140). Correct behaviour,
  surprising route.
- **The published 6.9× does not reproduce here.** `Fib (27)` with the pinned
  binaries on this machine is **1.38s** under `algvm` against **6.77s**
  interpreted — 4.9×, stable across runs, 1.34s with `--collect 0`. The
  interpreter half is within 8% of the published 6.24s; the machine half is 52%
  off the published 0.91s, which suggests a differently-built `algvm` rather
  than noise.
- **The library's `.so` shims are gitignored build products**, so a fresh
  submodule clone cannot run any FFI-backed unit until `./build.sh` runs in it.
  Combined with `bootstrap/build.sh` defaulting to no `--ffi`, a `uses graph`
  program works under `algvm` and not under the compiler the site builds with.

## Checked and clean

The site generator — 2,250 lines reading 27,000 lines of Markdown — produces
**byte-identical** output under all three processors, and its tests pass under
the interpreter and the machine alike. The precise collector was pushed at it
deliberately: identical output at `--collect 10000`, `--collect 100` (36×
slower, collecting constantly) and `--collect 0`. The library's audited `Circle`
example runs under `algvm` against the pinned library and prints what
`REFERENCE.md` claims.
