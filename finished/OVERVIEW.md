# Algol-24 since v0.1.6 — what the site does not say yet

Notes for updating algol24.com, which still describes **v0.1.6**: one processor,
no library, and neither of their references. This is the feature-level picture,
not a change log — the defects fixed along the way are recorded in the
compiler's own `CLAUDE.md` and `spec/HISTORY.md`.

**Current versions:** compiler and machine **v0.2.3**, library **v0.1.0**. The
numbers are independent on purpose: the library is a *user* of the language
rather than part of it, with its own repository, its own releases and its own
record of what it has found wrong.

---

## A third processor: the bytecode machine

`algvm` is a stack machine for Algol-24, **written in Algol-24** and compiled by
`algc` like everything else here. It is a second binary rather than a mode of
the compiler: it imports the compiler's front end, so a program that will not
parse fails the same way whichever of the three processors you reach for.

- **80 opcodes**, numbered as *Crafting Interpreters* numbers them, so the book
  reads alongside the source.
- **About seven times the tree-walking interpreter** — `Fib (27)` is 0.91 s
  against 6.24 s, both native binaries, so that is bytecode against an AST walk.
- **It hosts the compiler.** Run `algc` *on* the machine and ask it to emit C,
  and the C is byte-identical to what a native `algc` emits — the whole front
  end and the whole C back end, running as bytecode, agreeing to the byte.
- **140 tests** of its own, and it answers all **270** corpus cases exactly as
  the interpreter and the compiled back end do.

So the language has three processors now, and all three must agree on every
case. A disagreement is a bug in whichever one is the odd man out, and finding
those is most of what building the third one was for.

The opcodes are documented one entry each in the shape of a 1987 assembler
reference — encoding, stack effect, operation, the rules it satisfies, what it
raises — and a script holds every entry to the machine, so the two cannot drift.

## A precise garbage collector

The runtime previously only ever grew. Collection is now **exact rather than a
guess**: the compiler emits the addresses of a program's module-level variables
and a shadow stack for its locals, so nothing has to ask whether a given word
might be a pointer. The machine's roots come free from the same mechanism,
because its own stacks are module-level variables of a program written in the
language.

On the machine it is **on by default**. Compiling the compiler uses 707 MB
instead of 2952 MB, for about 6% more time.

## A runtime library, written in the language

`algol24-library` **v0.1.0** — ten units, borrowing Turbo Pascal's names as an
homage rather than as a compatibility target:

| | |
| --- | --- |
| `graph` | pixels, shapes, text, windows, viewports |
| `crt` | the text console — colours, cursor, keys |
| `strings` | the operations a String wants |
| `math` | the numeric functions |
| `random` | generators and distributions |
| `sound` | tones and samples |
| `time` | clocks, dates, zones |
| `file` | files, directories, paths |
| `dos` | the environment, disks, process exec |
| `testing` | assertions, for programs that test themselves |

`graph` and `sound` reach SDL2 through the language's own foreign function
interface, which is the argument for having one: a library written in the
language can go and get what the language does not have.

**850 tests**, and **119 reference examples that are run rather than quoted** —
so an example that stops being true fails a build.

This is also what the project meant by calling itself *alpha*. What the language
lacked was never a feature; it was a library written in Algol-24 rather than
bolted into the runtime. That is what this is.

## The language change that makes a library installable

One addition, and it is the one a library needs in order to *be* one: **a `uses`
now finds a unit in an installed library**, not only one beside the program or in
the working directory. Nearer still wins, so installing a library can never
change what an existing program already means by a name.

Everything else since v0.1.6 was *corrections* — places where the processors
agreed with each other and not with the specification, which is the only kind of
bug a second opinion cannot find.

## Packaging: three platforms, two formulae

```sh
brew tap schildawg/algol24
brew trust schildawg/algol24
brew install algol24-vm      # the machine, with the library beside it
brew install algol24         # the compiler
```

The `trust` line is required rather than advisory — Homebrew will not load a
formula from a third-party tap until you have said that you trust it.

**The two formulae coexist**: one installs `algvm`, the other `algc`. Install
whichever you need, or both. Bottled for **arm64_sequoia**, **arm64_tahoe** and
**x86_64_linux**; anywhere else Homebrew builds from source, which needs a C
compiler and takes seconds.

`algol24-vm` installs the library where the compiler looks for it, so a program
says `uses graph;` by name and the installed unit answers — no path written in
the program, and a unit of your own beside it still winning.

**Windows is a release download** rather than a formula, since Homebrew is not a
channel there: unzip it anywhere and run `algvm.bat`. Foreign calls work — an
`external` reaches a DLL through the same declaration a Unix uses.

## Where everything is

| What | Where |
| --- | --- |
| Compiler, machine, specification | `github.com/schildawg/algol24` — v0.2.3 |
| The library | `github.com/schildawg/algol24-library` — v0.1.0 |
| Language specification | `spec/ALGOL-24.md`, rendered at `algol24.com/reference/` |
| Library reference | `REFERENCE.md` in the library repository |
| Opcode reference | `vm/REFERENCE.md` — one entry per opcode |
| Windows download | the v0.2.3 release page |
| Homebrew tap | `github.com/schildawg/homebrew-algol24` |

---

## Notes for whoever updates the site

Three things that are true of the current pages and will bite:

1. **Two claims in the install section are false, not merely stale.** It says
   Linux builds from source — Linux is bottled now. And it says *"There is no
   Windows package"* — there is one.

2. **The corpus figures moved.** The facts block says 245 unit tests and 259
   cases; counted today they are **247** and **270**. "Runs under both
   processors" is no longer true of anything, either: there are three, and a
   case is held to all of them.

3. **Bumping the submodule pin needs one more edit.** `build.sh` reads the
   version from `vendor/algol24/compiler/Main.a24`, and that constant moved to
   `compiler/Release.a24` in v0.2.2, when `algvm` learned `--version` and the two
   binaries had to read one number. Left alone, the read answers empty, compares
   unequal to whatever `algc` reports, and rebuilds the compiler on every run —
   slow rather than wrong, and silent either way. `deploy.yml` does not read it
   at all, because CI always builds fresh.

And one thing worth deciding rather than defaulting: the library reference and
the opcode reference are **Markdown in two repositories**, while the language
specification is a rendered page built from the *pinned* spec — so its rules
describe the compiler the rest of the site describes. Rendering the other two the
same way would need the library as a second submodule, pinned to its own
release. That is a real improvement and more than a link.
