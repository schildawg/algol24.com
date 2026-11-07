# Plan: the site catches up with v0.2.3 and the library

The site describes **v0.1.6** — one processor, no library, and neither of their
references. `OVERVIEW.md` is the feature-level picture of what changed; this is
the order the site changes in, and why that order.

Decisions already taken, so they are not re-litigated mid-way:

| | |
| --- | --- |
| Home page | two new bands — the machine, the library |
| Hero | `v0.2.3 · library v0.1.0 · on Homebrew`, and **no** `pre-1.0` |
| Install | `algol24-vm` first, `algol24` second |
| References | the library **vendored and pinned**, all three pages rendered here |

`pre-1.0` goes because the thing it was waiting for has arrived: a library
written in Algol-24 rather than bolted into the runtime. That was the whole of
what *alpha* meant, and saying it twice after it is done would be a hedge
rather than a fact.

---

## What the investigation found before any of this was written

⚠️ **Every figure the site states has moved, and the sources disagree about
one of them.** `OVERVIEW.md` says 80 opcodes and `vm/REFERENCE.md`'s own prose
says 78. ~~The checker reports 79~~ — **corrected while doing the work: the
checker's `described: 79` is only its first line, and `variable-width: 1` is the
second. The answer is 80, and why is under *Findings* below.** No figure here is
one to copy: the site derives the count, the way `RuleCount` already derives the
rule count. Unit tests and corpus cases get re-measured from the harnesses
rather than read off `OVERVIEW.md`.

⚠️ **The three documents use two different heading conventions**, so the TOC
builder cannot simply be pointed at a new file:

| | groups | entries |
| --- | --- | --- |
| `spec/ALGOL-24.md` | `## 12. Classes and objects` | `### 12.1 Declaration` |
| `vm/REFERENCE.md` | `# Globals` (19) | `## OP_GET_LOCAL — …` (83) |
| library `REFERENCE.md` | — | `## Abs` (154), 4 at `###` |

`Contents` in `gen/Markdown.a24` reads h2 and h3 and ignores h1. Pointed at the
opcode reference it would emit 80 flat mnemonics and **drop all 19 group
headings without saying so**. The levels have to become a parameter.

⚠️ **`vm/REFERENCE.md` cites 65 language rules, and `LinkRules` makes
same-page anchors.** On the opcode page every one of those would be a dead
link, because the rules are on `/reference/`. The citation target has to become
a parameter too — and then the opcode entries become clickable into the
specification, which is better than what either document can do alone.

⚠️ **The pin bump breaks `build.sh` unless it moves too.** `VERSION` left
`compiler/Main.a24` for `compiler/Release.a24` in v0.2.2, when `algvm` learned
`--version` and the two binaries had to read one number. Reading the old path
answers **empty**, which compares unequal to whatever `algc` reports, so the
compiler is rebuilt on every single run — slow rather than wrong, and silent
either way. `deploy.yml` never reads it, because CI always builds fresh.

---

## Phase 1 — the pin, and the trap under it

1. `vendor/algol24` → `v0.2.3`. Confirm the paths under the pin again:
   `bootstrap/build.sh`, `bootstrap/algc`, `spec/ALGOL-24.md`,
   `compiler/Scanner.a24`, and now `vm/REFERENCE.md` and `vm/OpCode.a24`.
2. `vendor/algol24-library` → `v0.1.0`, a second submodule.
3. `build.sh`: read `VERSION` from `compiler/Release.a24`.
4. Re-measure, each from the harness that owns it: unit tests (`./test.sh`),
   corpus cases (`./conform.sh`, the *the language:* line), rules
   (`./spec/spec.sh`), opcodes (`./vm/reference.sh`), library units.

Gates every other phase.

## Phase 2 — validate under `algvm`, before writing copy on top of it

Build the machine and run the generator under it. The site generator is a
2,250-line program that reads 27,000 lines of Markdown and writes three pages —
a better exercise of a processor than any single corpus case, and the first time
anything here has had a third opinion.

The check is a **byte comparison**: the site `algvm` produces against the site
the compiled generator produces. They must be identical. Anything that differs,
raises, or hangs gets cut down to a minimal reproducing program, which is what
`spec/DEFECTS.md` requires of an entry.

⚠️ `vm/build.sh` has **no `--ffi` switch** — a foreign call is a feature of the
language, so a build that cannot find libffi fails rather than producing a
binary that refuses foreign calls. CI would therefore need `libffi-dev` to do
this on every push. Validate locally first; propose the CI step separately, on
what it is actually worth.

This phase runs **before** the page copy, so that a defect in the machine
surfaces before three hundred lines of prose are resting on it.

## Phase 3 — the home page

Two bands above the guarantee, which **flips the tint of the three below it** —
guarantee, name, provenance — as the extension band already did once.

- **The machine.** Three processors that must agree on every case; several
  times the tree-walker — ⚠️ **but not the published 6.9×: measured here with
  the pinned binaries, `Fib (27)` is 1.38s against 6.77s, which is 4.9×. The
  interpreter half agrees within 8%; the machine half does not, so the figure
  stays off the page and goes to the author instead.** It hosts
  `algc` emitting C that is byte-identical to what a native `algc` emits. A
  precise collector under all three: compiling the compiler in 707 MB rather
  than 2952 MB.
- **The library.** Ten units, Turbo Pascal's names as homage rather than as a
  compatibility target. `graph` and `sound` reach SDL2 through the language's
  own foreign function interface, which is the argument for having one: a
  library written in the language can go and get what the language does not
  have. 850 tests, and 119 reference examples that are **run rather than
  quoted**. And this is what *alpha* meant.

Then the corrections, which are not stale but **false**: Linux is bottled, not
built from source; there *is* a Windows package; "under both processors" is
true of nothing now. Install becomes VM-first, two formulae, three bottled
platforms, Windows as a release download with `algvm.bat`.

Nav goes from five links to six — Install · Tour · Reference · Library ·
Opcodes · Source — with Internals demoted to the home-page anchor it already
is.

## Phase 4 — two more rendered pages

`/opcodes/` from the pinned `vm/REFERENCE.md`; `/library/` from the pinned
library's `REFERENCE.md`. One renderer, three pages:

- Generalize `RenderReference` into a parameterized path: source, template,
  output, which heading levels group and which enumerate, and where a rule
  citation points.
- The library's fences are already `algol24` and `console`, the same vocabulary
  the spec uses, so `Highlight` needs nothing. The opcode reference uses plain
  fences only.
- Each page describes the **pinned** thing it documents, which is the whole
  reason for vendoring rather than linking: the page cannot drift from the
  release it describes.

## Phase 5 — what the library can replace

`gen/Strings.a24` and `gen/Template.a24` exist because there was no library.

- `strings` is **pure Algol-24, no FFI**, and covers `Trim`, `Replace` and
  `Split`. `StartsWith`, `IsSpace` and `Escape` have no equivalent and stay.
- `file` overlaps `gen/Template.a24` but needs `libfileffi.so`, and the
  language's built-in `ReadLines` and `WriteFile` already do that job. Expect to
  **reject** this one and record why — a rejected swap is a finding too.

Two gates before any swap lands:

1. ⚠️ **Measure `Split` on the real 352 KB specification.** This project has
   already lost 3.40s to a character index walking a non-ASCII string from the
   start; a library function that reads well and is quadratic is worse than the
   one being replaced.
2. The generator would gain a **build-time dependency**, which CI has to
   resolve from the vendored path or `ALGOL24_LIB` — never from an installed
   brew, because CI has none.

---

## Flagged upstream, not fixed here

Both repositories are the same author's, and these are theirs to take or leave:

- The compiler's `README.md` says *"Five harnesses"* in its table while its own
  Status text names the seventh, `installed.sh`.
- That Status section still closes with *"what comes next is still a library"*,
  which shipped as `algol24-library` v0.1.0.
- `vm/REFERENCE.md` says **78** opcodes where its own checker says **79**.

---

# What happened

All five phases are done. The order held: validating the machine before writing
the page copy was worth it, and the renderer work was larger than the plan
guessed for a reason the plan had not found.

## The figures, each from the harness that owns it

| | | from |
| --- | --- | --- |
| rules | **292** | derived by `RuleCount`, agrees with `spec/spec.sh` |
| unit tests | **247** | `./test.sh` |
| corpus cases | **270** | `./conform.sh`, *the language:* line |
| machine's own tests | **140** | `./test.sh vm/Vm.a24` |
| opcodes | **80** | derived by `OpcodeCount`, one `## OP_` entry each |
| library units | **10** | one file each |
| library tests | **850** | the library's `./test.sh`, the ten units summed |
| library examples | **119** | *119 examples run, 0 wrong* |

## Phase 2: no defects, and here is what was tried

The generator runs clean under the machine and the output does not move:

| | |
| --- | --- |
| compiled to C | **0.08s** |
| bytecode, `algvm` | **3.78s** |
| tree-walking, `algc` | **20.96s** |

All four pages byte-identical across all three processors, and the 89 generator
tests pass under the machine as well as under the interpreter. The collector was
pushed at it deliberately, since a precise collector is new and this program
allocates hard: identical output at `--collect 10000`, at `--collect 100`
(3m46s, 36× slower, every object examined constantly) and at `--collect 0`.
Nothing to report, which is the result worth having.

## Findings worth keeping

⚠️ **`OP_COUNT` is a sentinel, and it is why three sources disagreed.**
`vm/OpCode.a24` declares 81 `const OP_`; the last is the count that ends the
set, not an instruction. So **80** is right — `OVERVIEW.md` had it, and
`vm/REFERENCE.md`'s own opening sentence says **78** in the one document whose
stated discipline is that it never argues with `OpCode.a24`. The checker's
`described: 79` plus `variable-width: 1` is also 80; reading only the first
number is how this nearly went onto the page as 79.

⚠️ **`uses` does not read `ALGOL24_LIB`.** The search path is the program's own
directory, the working directory, `<binary>/lib`, and
`<binary>/../share/algol24/lib`. `ALGOL24_LIB` is the library's *own* variable,
for `graph`'s glyph files. Anything that assumed otherwise would fail only off
an installed tree.

⚠️ **`Strings.a24` and `strings.a24` are one filename on macOS.** Ours and the
library's collide on a case-insensitive filesystem, and `cp` resolves it
silently by clobbering. This cost a confusing error during the benchmark and it
is the hard blocker on adopting the library's unit under its own name.

⚠️ **The vendored `algc` has no foreign calls.** `bootstrap/build.sh` builds
without `--ffi` by design, so any library unit reaching SDL works under `algvm`
and not under the compiler the site builds with. The library's `.so` shims are
gitignored build products and absent from a fresh submodule clone.

## Phase 5: the swap is ADOPTED, after a correction

⚠️ **This section first said rejected, and the reason it gave was wrong.** It
claimed `uses` could not reach a unit under `vendor/`, because the search path
for a bare name is the program's directory, the working directory and two paths
beside the binary. [MOD-001] also provides a **quoted** form, which is a path
resolved beside the importing file — `uses '../vendor/algol24-library/strings';`
works, interpreted and compiled, with nothing copied, symlinked or installed.
The author pointed this out. The extension is still appended, so the path is
written without one.

So the swap was made. Of 58 subprograms across `gen/`, three had a library
equivalent, and all three are now the library's:

| | result | time |
| --- | --- | --- |
| library `strings` | 450000 / 1950000 / 480000 | **2.31s** |
| `gen/Strings.a24` | 450000 / 1950000 / 480000 | **2.21s** |

Identical answers on a trailing separator, a leading one, an absent one, a
doubled one, a whitespace-only trim, a replacement that contains its own
needle, and a needle spanning the whole string. No algorithmic difference —
both walk once with `Pos`'s start index. 5% slower on a build that takes
0.08s.

One deliberate behavioural difference: `Replace (T, '', X)` and
`Split (T, '')` **raise** in the library where ours answered `T` unchanged.
Every needle in this generator is a non-empty literal, so it cannot arise, and
raising is the better answer if it ever could.

**What it cost, and what it bought.** `gen/Strings.a24` became
`gen/Markup.a24` and kept the two the library does not have — `StartsWith`, and
an `Escape` that is about HTML rather than about strings. `IsSpace` went with
`Trim`, having served nothing else. The four pages are **byte-identical** before
and after, under the compiled back end and the machine alike. And because
`--test` is transitive over `uses`, the suite went from **89 to 124**: the
library's 48 string tests now run as part of the site's own.

**And it turned up a defect**, which a rejected swap would not have. Two units
whose names differ only in case break two of the three processors — `D-1` in
`DEFECTS-FOUND.md`, with a reproduction. The rename is the way round it.

`file` is still rejected, on its own terms: `gen/Template.a24`'s three
functions wrap the `TextFile` resource, while the library's `file` unit needs
`libfileffi.so` — a build product that is not in the repository — for behaviour
the generator already has.
