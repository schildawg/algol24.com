# Defects found while updating the site

Found by building algol24.com against the pinned compiler, machine and library,
and by running the generator under all three processors. Written here rather
than in `spec/DEFECTS.md` because that file wants an entry the compiler
repository owns; these are reports, with reproductions, for whoever takes them.

**One report is open: `D-3`, found at v0.2.6.** `D-1` and `D-2` were reported
against v0.2.3, accepted, and fixed in **v0.2.4** — where they carry the
numbering this file gave them. Each is verified below against the pinned
binaries rather than taken on trust, which is the only reason a closed report is
worth keeping.

The compiler repository's `finished/PLAN-0.2.4.md` carries the root cause for
each of those, and `./defects.sh` is the harness that holds all sixteen closed.

---

## D-1 — ✅ FIXED in v0.2.4 — Two units whose names differ only in case

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

**How the site worked around it.** `gen/Strings.a24` became `gen/Markup.a24`,
holding the two functions the library does not have. A rename, not a fix — and
it stays, because a unit named for what it does is better than one named for a
collision that no longer happens.

### Verified fixed

v0.2.4 took the first of the two options above: **fold the comparison and
refuse the program**, everywhere. A unit name is an identifier and identifiers
fold [SRC-011]; the one comparison in the compiler that did not know it now
does, and [MOD-002] gained a sentence saying the registry folds where the
*lookup* does not — which is the part that makes it a decision rather than an
edit, since on Linux the two units were legitimately distinct.

The same three-file reproduction, run against the pinned v0.2.4 binaries, now
answers identically under all three processors:

```console
$ algc repro/Main.a24
[ERROR] repro/Main.a24: Two units whose names differ only in case:
        'repro/a/Alpha.a24' and 'repro/b/alpha.a24'.
        A unit name is matched without regard to case.
[ERROR] 2 | uses 'b/alpha';
        |      ^^^^^^^^^
```

`algvm` and `algc --compile` print the same thing — including the file, the
line and the caret, which is the v0.2.4 diagnostic work showing. The refusal
names **both** files, which is what a reader needs: the collision is never
visible in one of them alone.

---

## D-2 — ✅ FIXED in v0.2.4 — an opcode count its own body contradicted

Documentation, not behaviour, but in the one document whose stated discipline is
that it never argues with `OpCode.a24`:

> ⚠️ **`vm/OpCode.a24` is the authority and this file never argues with it.**

`OpCode.a24` declares 81 `const OP_`; the last is `OP_COUNT`, the sentinel that
ends the set and is not an instruction. So there are **80**, and the reference
carries exactly 80 `## OP_` entries — its own body disagrees with its own
opening sentence. `finished/OVERVIEW.md` says 80 and is right.

`./vm/reference.sh` reports it in two lines that are easy to read as one:

```
described       : 79
variable-width  : 1
```

Taking the first for the total is how this nearly reached the website as 79.
A single stated total would be harder to misread.

### Verified fixed, and further than asked

The count is **gone from the prose entirely** rather than corrected, which is
the better answer and not the one this report proposed:

> ⚠️ **NO OPCODE COUNT IS WRITTEN IN THIS FILE, and that is deliberate.** […]
> `./vm/reference.sh` prints the figure, having counted it; a number in prose
> is a claim nothing checks.

And the script now opens with one unambiguous line where two could be read as
one:

```console
$ ./vm/reference.sh
REFERENCE.md — 80 entries, 80 opcodes
...
opcodes declared by OpCode.a24 : 80
```

The site derives its own figure from the entries regardless, which is the
discipline that found the discrepancy.

---

## D-3 — 🔴 OPEN at v0.2.6 — the tree-walker loses two characters of one string

**Severity.** The published site is **not affected** and nothing is at risk
today: the site is built by the compiled back end, which is correct, and CI
compares the bytecode machine against it — the two agree to the byte. Only the
**tree-walking interpreter** diverges, and only when its collector is on. But it
is a wrong answer rather than a crash, in the processor the other two are
measured against, and it was found by the only thing here that renders half a
megabyte of text in one run.

**What happens.** Building all four pages with `algc gen/Main.a24` produces one
line that differs from what the other two processors produce, out of 27,875
lines of input:

```diff
- <p>Sets the color a viewport's pen draws in.</p>
+ <p>Sets the color a viewport's pen draws i</p>
```

The last two characters are gone. The source line is 41 characters of plain
ASCII, in the library reference. It is **deterministic**: the same line, the
same truncation, on every run.

**It is the collector, and the release's own switches say so.**

| | |
| --- | --- |
| `algc gen/Main.a24` | one line truncated |
| `ALG_COLLECT_EVERY=0 algc gen/Main.a24` | **byte-identical** |
| `ALG_POISON=1 algc gen/Main.a24` | **byte-identical** |
| `algvm gen/Main.a24` | byte-identical |
| compiled to C | byte-identical (the baseline) |

Poison **withholds** a released block rather than handing it back out, and that
is the half that makes this read as *a block freed while still live and then
reused*, rather than a renderer fault. v0.2.6's notes say that split was the
whole diagnosis four times over; this is a fifth.

**What has been ruled out**, so the search can start below the renderer:

- **`ReadLines` is not it.** A probe printing the length of all 10,386 lines of
  the library reference answers identically under the interpreter and the
  machine. The input is read correctly.
- **The line alone is not it.** `Render` of a one-element list holding that
  exact line is correct under both.
- **The document alone is not it.** Rendering the whole library reference —
  with its real keyword table, its real rule targets and `/reference/` as the
  citation base — is correct under both, 494,177 bytes agreeing exactly.
- **Two documents are not enough.** Rendering the 15,142-line specification
  first and the library second, in one process, is correct under both.

So it needs the whole program: four pages, the templates read and substituted,
and two 500 KB-plus strings written out. That is allocation history, which is
what a collector bug would want.

**Reproduction.** In `algol24.com` at this pin:

```console
$ ./build.sh                       # the compiled site, which is correct
$ mv site site-cc && mkdir site
$ vendor/algol24/bootstrap/algc gen/Main.a24
$ diff -r site-cc site
4931c4931
< <p>Sets the color a viewport's pen draws in.</p>
> <p>Sets the color a viewport's pen draws i</p>
```

`ALG_MEM_REPORT=1` on that run reports the text heap at 13 chunks, 6.8 MB used,
2.3 MB live, **398 sweeps** — so the collector runs often enough during the run
for one sweep in four hundred to be the one that matters.

**Why the site did not catch this before shipping.** CI compares the compiled
site against the machine's and not against the interpreter's. Adding the third
comparison costs about 42 seconds a push and would have caught it. Worth
deciding on rather than assuming.

---

## Not defects, but worth writing down

- **`algc --test vm/run.a24` raises** `Reset failed: no file has been
  assigned.` `run.a24` is the machine's entry point and expects a file to run,
  so its tests are reached as `./test.sh vm/Vm.a24` (140). Correct behaviour,
  surprising route.
- **The published 6.9× now reproduces, and then some.** This note recorded for
  two releases that it did not, and v0.2.5 settled it. `Fib (27)` with the
  pinned binaries on this machine, every row measured in one sitting:

  | | v0.2.3 | v0.2.4 | v0.2.5 | v0.2.6 |
  | --- | --- | --- | --- | --- |
  | `algvm` | 1.33s | 1.33s | 0.69s | **0.77s** |
  | `algc`, interpreted | 6.55s | 6.60s | 6.53s | **6.64s** |
  | the ratio | 4.9× | 5.0× | 9.5× | **8.6×** |

  ⚠️ Every row above was measured in **one sitting**, against binaries built
  from each tag, because the first draft of this table mixed a fresh row with
  two from an earlier session — which is the mistake it exists to document.

  The machine halved at v0.2.5 exactly as those notes say, and gave 11% of it
  back at v0.2.6 for a collector that reaches text; the interpreter has not
  moved across four releases. So the discrepancy was never a measurement fault
  here: the published 0.91s belonged to a machine that had already had work the
  pinned v0.2.3 and v0.2.4 binaries had not. The site still states no multiple,
  because this one is the site's own and will move again.

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
