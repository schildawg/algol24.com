# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

The website for the Algol-24 programming language, published at **algol24.com**.
The generator is **written in Algol-24 and compiled by `algc`** — the language
builds its own front door, as the compiler already builds itself.

⚠️ **The domain is `algol24.com`, not `algol.com`.** `algol.com` belongs to Algol
Group, a Finnish industrial trading company trading since 1894, and is not
obtainable. The confusion is easy to make and has already been made once.

## Commands

```sh
./build.sh                 # -> site/
./build.sh --test          # the generator's own test blocks
brand/build.sh             # svg/ -> brand/dist/  (macOS only; needs qlmanage)

vendor/algol24/bootstrap/algc gen/Main.a24            # generate directly
vendor/algol24/bootstrap/algc --test gen/Markdown.a24 # one module's tests

vendor/algol24/vm/build.sh                            # -> vm/algvm (wants libffi)
vendor/algol24/vm/algvm gen/Main.a24                  # the same site, third processor
vendor/algol24/vm/algvm --test gen/Main.a24           # the suite, on the machine
```

There is no per-test filter: the unit is a file. `--test` is transitive over
`uses`, though, so `--test gen/Main.a24` runs `Template`'s tests too and is the
whole suite — which is what CI runs.

Checking the generator still reproduces the design is one command, and its
output should be empty:

```sh
diff <(sed -n '/<header class="bar">/,/<\/script>/p' prototype/index.html) \
     <(sed -n '/<header class="bar">/,/<\/script>/p' site/index.html)
```

Run against `templates/index.html` instead and the only differences should be
the `{{...}}` placeholder lines. Both hold today.

## Architecture

```
templates/index.html      ──┐                 ┌──> site/index.html
templates/doc.html        ──┤                 │
templates/site.css        ──┤                 ├──> site/reference/index.html
templates/masthead.html   ──┤─> gen/Main.a24 ─┤      (vendor/algol24/spec)
templates/boot.html       ──┤                 │
templates/theme.html      ──┘                 ├──> site/opcodes/index.html
                             │                │      (vendor/algol24/vm)
                             │                │
                             │                └──> site/library/index.html
                             │                       (vendor/algol24-library)
                             ├── gen/Template.a24    read and write
                             ├── gen/Markup.a24      StartsWith and Escape
                             │                      (Trim, Replace, Split come
                             │                       from the pinned library)
                             ├── gen/Markdown.a24    the reader, and all three documents
                             └── gen/Highlight.a24   .a24 and console colouring
```

**The last four templates are partials, and there is one copy of each.** All
four pages need the same palette, masthead, pre-paint script and theme switch,
and a second copy of any of them is a second thing to keep in step. `Shared` in
`Main.a24` substitutes them.

⚠️ **`templates/site.css` is the stylesheet and `prototype/index.html` still
carries a literal copy of it**, because the prototype is the design reference
and has to stand alone. The check is that they are identical:

```sh
diff <(sed -n '/<style>/,/<\/style>/p' prototype/index.html | sed '1d;$d') templates/site.css
```

The reference page is built from the **pinned** specification and the **pinned**
scanner, so the rules it states and the keywords it colours both describe the
compiler the rest of the site describes.

`vendor/algol24` is a submodule doing **two jobs at once**: its `bootstrap/`
builds `algc`, and its `spec/ALGOL-24.md` and `vm/REFERENCE.md` are the source
text for the Reference and Opcodes pages. One pinned commit, so the
documentation on the site cannot drift from the compiler that generated it.

⚠️ **There are TWO submodules now, pinned to two different releases.**
`vendor/algol24-library` is at **v0.2.0** where the compiler is at **v0.4.0**,
and that is not drift: the library is a *user* of the language rather than part
of it, with its own repository and its own releases. Its `REFERENCE.md` is the
source of the Library page, on the same terms — the page describes a library
somebody can actually install.

⚠️ **`VERSION` lives in `compiler/Release.a24`, not `compiler/Main.a24`.** It
moved in v0.2.2, when `algvm` learned `--version` and the two binaries had to
read one number. `build.sh` reads it to decide whether a stale `algc` needs
rebuilding; pointed at the old path it answers **empty**, compares unequal to
whatever `algc` reports, and rebuilds the compiler on every single run. Slow
rather than wrong, and silent either way.

⚠️ **Read `RELEASES.md` first on a bump.** The compiler repository keeps
cumulative release notes now — what changed and why, at the level someone
deciding whether to upgrade needs. It quotes **no counts on purpose**, so the
figures still come from the harnesses, but it is the fastest way to know what a
release actually means for this site. `finished/PLAN-0.2.4.md` there carries
the root cause of every defect that release closed.

⚠️ **Pin to a release tag, because a pin can vanish.** The submodules track
`v0.4.0` and the library's `v0.2.0`. An earlier pin, `01b2778`, was rewritten
out of the compiler repository's history, and from then on `actions/checkout` failed with
`upload-pack: not our ref` before a single build step ran — a green local tree
and a red CI, for a reason that has nothing to do with the site. A tag does not
get garbage-collected; a branch commit can.

⚠️ **The paths under the pin moved, and they move in two files at once.** The
compiler repository was restructured: `build.sh` and `algc` now live under
`bootstrap/`, and `ALGOL-24.md` moved to `spec/`. `build.sh` and `deploy.yml`
each invoke `vendor/algol24/bootstrap/build.sh` and
`vendor/algol24/bootstrap/algc`, so any future bump has to carry both.

⚠️ **A stale `algc` in the submodule hides a bad pin, and `build.sh` now checks
for it.** The submodule moves; the binary inside it does not, so bumping the pin
leaves the previous compiler in place, `build.sh` finds it and skips the build,
and the site is generated by a compiler that is not the pinned one — passing
locally and failing only in CI, where the clone is fresh. `build.sh` therefore
compares `bootstrap/algc --version` against the `VERSION` constant in the pinned
`compiler/Release.a24` — see the note above about where that constant lives —
and rebuilds when they disagree. This cost a green local run and a red CI once
already.

`prototype/index.html` is the hand-written design reference for the **body** —
the artifact-shaped original, with no `<head>` because the artifact host
supplies one. `templates/index.html` is the same markup wrapped in a real
document: doctype, meta, favicons, Open Graph, and the theme bootstrap script in
its proper place before first paint.

So the two are not byte-comparable, and only the body should be diffed when
checking that the generator still reproduces the design.

Three more things that are only visible by reading several files at once:

- ⚠️ **`.github/workflows/deploy.yml` re-implements `build.sh`; it does not
  call it.** The mkdir, the generate, the asset copy and the placeholder check
  all exist twice. A change to the build has to be made in both, or CI publishes
  something other than what you tested.
- ⚠️ **CI has a step `build.sh` does not: *Agree with the other two
  processors*.** It builds `algvm`, runs the 124 tests on it, then regenerates
  the site with the machine **and again with the tree-walking interpreter**,
  and **`diff -r`s each against the compiled site**. Either disagreeing about
  one byte fails the job rather than deploying, because one of the two would
  then be wrong. It is CI-only because it wants `libffi` — `vm/build.sh` has no
  `--ffi` switch, a foreign call being a feature of the language — and the
  local build deliberately needs nothing but a C compiler. Run it by hand on a
  Mac, where the SDK has libffi:

  ```sh
  export ALG_TEXT_CHECK=1
  vendor/algol24/vm/build.sh && vendor/algol24/vm/algvm --test gen/Main.a24
  mv site site-cc && mkdir site && vendor/algol24/vm/algvm gen/Main.a24
  diff -r site-cc site
  rm -rf site && mkdir site && vendor/algol24/bootstrap/algc gen/Main.a24
  diff -r site-cc site && rm -rf site && mv site-cc site
  ```

  ⚠️ **It checked only the machine until v0.2.7, so its name was a promise it
  did not keep.** `D-3` was a wrong answer in the *interpreter* and reached a
  release because nothing here ran that processor; it took a hand-run to find.
  The interpreter costs about 43s locally and is the cheapest insurance
  available against publishing a wrong answer.

  ⚠️ **`ALG_TEXT_CHECK=1` is on for both runs**, at about 18% on the
  interpreter (42.9s to 50.6s here). A byte diff says only that two processors
  disagree; this says why, failing with both the cached length and the
  recomputed one. It is what `D-3` would have tripped.

  ⚠️ The generator writes to `site/` and nowhere else, so the compiled run has
  to be moved aside rather than pointed elsewhere — and the step runs **before**
  the asset copy, so the two trees hold only generated HTML when they are
  compared. `vm/build.sh` also defaults to `-std=c11`, so it gets `CFLAGS` from
  outside like the other three.
- ⚠️ **`-std=gnu11`, never `-std=c11`, and both files say so.** The runtime
  calls `readlink("/proc/self/exe")` for the program's own path, and glibc's
  `unistd.h` declares `readlink` only when `__STRICT_ANSI__` is unset — which
  `-std=c11` sets. macOS declares it either way, so nothing local can see this.
  It was a *warning* on `ubuntu-24.04` and became an error the day
  `ubuntu-latest` moved to `ubuntu-26.04`, whose gcc treats an implicit
  declaration as the error it has been since gcc 14: v0.1.6 failed CI on a seed
  that had built green four days earlier, with the same call in the same place.
  Three `cc` invocations need the dialect — `build.sh`'s own, `deploy.yml`'s,
  and the compiler's `bootstrap/build.sh`, which still defaults to `c11` and so
  is given `CFLAGS` from outside rather than trusted. The emitted C needs it
  too: `algc --compile` copies `algol.c` into the output directory, so the
  generator's own compile links the same runtime.
  **The durable fix is upstream** — a feature-test macro in the compiler's
  runtime, or `gnu11` as its default — and until then this is a trap for anyone
  building `algc` on Linux, not only for this site.
- **Both builds fail on an unrendered `{{`.** A placeholder added to a template
  with no matching `Replace` in `gen/Main.a24` exits 70 locally and fails the
  job in CI. Page constants live at the top of `Main.a24`; add the substitution
  in the same commit as the template. The grep is `-I` so binaries are skipped —
  `og-image.png` really did contain `{{`.
- ⚠️ **`brand/dist/` is generated and checked in on purpose** — the same
  argument as the compiler checking in `bootstrap/`. `brand/build.sh` needs
  macOS's `qlmanage` and CI is Linux, so the build that consumes the assets must
  not need the tools that made them. Never add it to `.gitignore`; regenerate on
  a Mac and commit the PNGs.

## Three documents, one renderer

⚠️ **The pages are built from three Markdown documents that do not share a
convention, and `gen/Markdown.a24` had to be parameterized for each.** Pointing
the renderer at a new document and hoping is how headings vanish silently.

| | groups | entries | links | rule citations |
| --- | --- | --- | --- | --- |
| `spec/ALGOL-24.md` | `##` chapters | `###` sections | 0 | declares them |
| `vm/REFERENCE.md` | `#` (19) | `##` (80 opcodes) | 0 | cites 65 it lacks |
| library `REFERENCE.md` | none | `##` (156) | **855** | cites 3 it lacks |

- `ContentsOf(Lines, Group, Entry)` takes the levels. `Contents` keeps the
  specification's 2-and-3 for the tests. Read as 2-and-3, the opcode reference
  lists 80 flat mnemonics and **drops all 19 group names without a word**.
- `LinkRulesTo(Base)` says where a citation points. Empty for the
  specification, which declares its own rules and wants same-page anchors;
  `/reference/` for the other two, whose citations are checked against
  `RuleTargets` of the **pinned spec**, so a citation of a rule that does not
  exist stays plain text rather than linking to nothing.
- ⚠️ **`Links` exists because the library reference has 855 of them and the
  other two have zero.** The reader went three releases without Markdown link
  syntax and nothing noticed. It runs *after* `LinkRules` — a rule citation is
  `[EXP-017]` with no parentheses after it, so neither pass can take a bracket
  the other wants.
- ⚠️ `.ref h1:not(:first-of-type)` is what keeps the opcode page's 19 group
  headings from being sized as page titles. The other two documents have one
  h1 each, so the rule does nothing to them.

**`templates/doc.html` is one template for all three pages.** Same chrome, same
contents list, same pre-paint script; only `{{TITLE}}`, `{{DESC}}` and
`{{URL}}` differ. It used to be `templates/reference.html`, back when there was
one document.

## The state of it

The generator builds **four pages**: the home page by placeholder
substitution, and three rendered documents — the language reference from the
pinned `spec/ALGOL-24.md`, the opcode reference from the pinned
`vm/REFERENCE.md`, and the library reference from the pinned library's
`REFERENCE.md` — all three through `gen/Markdown.a24`, coloured by
`gen/Highlight.a24` whose keyword set is read out of the pinned `Scanner.a24`.
The whole chain — `cc` → seed → `algc` → generator → site → Pages — works
today.

The Markdown reader was unblocked by v0.1.2's `Pos` start index,
`ToUpper`/`ToLower` and the directory built-ins. `Trim`, `Replace` and `Split`
come from the pinned library's `strings` now; `gen/Markup.a24` keeps the two it
does not have, `StartsWith` and an `Escape` that is about HTML.

⚠️ **Every figure on the page is derived, and the one that was written down was
wrong.** `RuleCount` in `Main.a24` counts `**[XXX-000]**` openers in the spec —
but **000 is reserved in every namespace** for the format illustration in §1.3
and is never a real rule, so the count was one too high from the start. Nothing
disagreed until v0.1.3 shipped `spec/spec.sh`, which excludes it and is the
authority. The two now agree at 303. **`OpcodeCount` is the second derived
figure** and was added for the same reason: three sources said 78, 80 and 81,
and the entries in the document being rendered are the only count that cannot
drift from the page a reader is looking at. The remaining literals in the
template are unit tests (247) and cases (286). Re-check both on a bump — and
the second one has a trap of its own.

⚠️ **The machine runs 283 of the 286, and the page says so precisely.** The
corpus is `conformance/` (217) plus `refusals/` (66) plus `defects/` (3);
`vm/conform.sh` walks the first two and not the third, so *every case under all
three processors* was an over-claim. 283 is the machine's own figure, from its
own harness, and both numbers move on a bump.

⚠️ **`OP_COUNT` is a sentinel, which is why the opcode count once had three
answers.** `vm/OpCode.a24` declares 81 `const OP_`; the last ends the set and is
not an instruction, so there are **80**. `vm/REFERENCE.md` used to open by
saying 78 — in the one document whose stated discipline is that it never argues
with `OpCode.a24` — and `./vm/reference.sh` printed `described: 79` on one line
with `variable-width: 1` on the next, so reading only the first is how 79 nearly
reached the page. Both were fixed in v0.2.4 as `D-2`: the count is gone from the
prose entirely and the script opens with *80 entries, 80 opcodes*. `OpcodeCount`
derives it here anyway, which is what found the discrepancy.

The unit tests are what `./test.sh` prints in the compiler repository (*All 247
tests passed*). The machine has its own suite and its own root: `./test.sh
vm/Vm.a24` reports 140, and `algc --test vm/run.a24` is **not** the way to it —
that raises `Reset failed: no file has been assigned.`, because `run.a24` is the
program and expects a file to run.

**Cases is the whole corpus, defects included** — `conformance/` plus
`refusals/` plus the checked-in `defects/`, which is exactly the figure
`./conform.sh` reports as *the language: 286 passed*. Read it off that line
rather than counting two directories and forgetting the third.

⚠️ **`conformance/` and `refusals/` are GENERATED and git-ignored.** They are
extracted from `spec/ALGOL-24.md` by the compiler repository's `./conform.sh`,
which deletes and rewrites both directories every run; each case lives in the
specification under the rule it demonstrates, so a case and its rule are the
same text and cannot drift. `defects/` is the exception and is checked in.

So **counting those directories without extracting first counts the previous
release's corpus** — exactly the stale-`algc` shape, since a fresh `git checkout`
of a new tag does not regenerate an ignored artifact. Bumping to v0.1.3 left
v0.1.2's 241 files in place and the page duly said 241; the real figure is 243.
Run `./conform.sh` in the submodule, then count. For the same reason, `spec.sh`
reporting that a rule *cites a conformance program that does not exist* means
the tree is stale, **not** that the case is missing — do not report it as one.

⚠️ **`ToUpper` and `ToLower` are ASCII only** — `[RT-025]` says so, and `café`
folds to `CAFé`. Anchors derived from a non-Latin heading keep their case.

⚠️ **`Pos` raises when its start is past the end**, rather than answering -1,
and reports an empty part as found at **0** rather than absent. A scan loop that
trusts either one runs forever or dies; `Strings.Replace` guards both.

⚠️ **Two Algol-24 checkouts exist, and this note used to name the wrong one.**
`workspace-copilot/algol24` is the live repository — it is what `vendor/algol24`
pins, what Homebrew packages, and where `spec/`, `packaging/`, `conformance/`
and the releases live. Run every count and check there. `workspace/JPascal` is
the older tree; do not reach for it for anything that ships.

## Publishing

Actions builds and deploys to Pages on every push to `main`; there is nothing to
run by hand and no manual deploy step.

**The custom domain is done and live.** `https://algol24.com/` serves the
generated page, `www` 301s to the apex, and the certificate covers both. Pages
is on `build_type: workflow`, so the domain is held in the repository's Pages
settings and **there is no `CNAME` file in the repo** — `static/` is empty, and
adding one is not a step anybody needs to take.

## Speed, and where it actually goes

⚠️ **A character index into a string holding any non-ASCII character walks from
the start.** Text is measured in characters and stored as UTF-8, so there is a
fast path only while every character is one byte. `spec/ALGOL-24.md` is full of
warning signs and em-dashes, so it never gets that path, and taking twelve
thousand indexes into one 352 KB document is quadratic. `Split` costs **3.40s**
there against **0.11s** on ASCII text of the same size.

⚠️ **Read files with `Template.ReadLines`, not `ReadFile` followed by `Split`.**
The giant string is what costs; reading straight into a list of lines never
builds it. Same twelve thousand lines, **3.40s against 0.006s**.

⚠️ **The generator is compiled, not interpreted** — `build.sh` emits C and runs
`cc` before running it. The order those two facts were found in matters, because
compiling looked worthless at first: while the time sat in the C runtime it
bought **1.25x**, and only once the quadratic term was gone did it start buying
**40x**. Measured end to end on this generator:

| | interpreted | compiled |
| --- | --- | --- |
| `ReadFile` + `Split` | 4.19s | 3.36s |
| `ReadLines` | 0.44s | 0.01s |

Both changes, or neither is worth much. The emitted C goes to `build/`, which is
ignored, and is emitted fresh each run because the directory is built with
`cc *.c` and a renamed module would otherwise leave its old `.c` behind.

⚠️ **The page quotes no checksum of itself, and the first version did.** A
band showed `md5 -q site/index.html` with the digest beneath it — which cannot
be right, because writing the digest into the page changes the page. It shipped
wrong and stayed wrong until v0.2.4. The block shows `diff -r` against a second
tree instead, which is what CI actually does and has no fixed point to chase.

⚠️ `build.sh --test` still runs the tests **interpreted**, so nothing compares
the back ends here. The guard that would catch a divergence is the
prototype-to-site byte comparison, not the test run.

**There are three processors now, and the generator agrees with itself under
all of them.** Measured on this machine at v0.4.0, building all four pages —
time, and peak resident memory against the same run under v0.2.5, before text
became collectable:

| | time | peak RSS | RSS at v0.2.5 |
| --- | --- | --- | --- |
| compiled to C | **0.18s** | **36 MB** | 84 MB |
| bytecode, `algvm gen/Main.a24` | **4.26s** | **63 MB** | 321 MB |
| bytecode, `--algol-loop` | **6.97s** | | |
| tree-walking, `algc gen/Main.a24` | **46.2s** | **520 MB** | 1302 MB |

⚠️ **Those are up about 4% on v0.2.7 and nothing regressed** — the input grew
with the releases, from 27,875 lines of Markdown to **28,940**, which is most of
it. Check the input size before chasing a time.

⚠️ **RE-MEASURE THE WHOLE TABLE OR NONE OF IT, in one sitting.** These numbers
are machine- and session-relative, and comparing a fresh one against an old one
invents regressions. The table read 0.08 / 3.78 / 20.96 at v0.2.3, and at v0.2.5
the compiled figure looked like an 88% regression — until v0.2.3's and v0.2.4's
own binaries were rebuilt and run against the same documents and answered
**0.15s each**. Three binaries agreeing means nothing regressed; the earlier
session's machine was simply faster.

Two movements since are real, and each is a release doing what it said. v0.2.4's
collector for the tree-walker cost it 18% on a workload that allocates this hard
against the ~9% its notes measured elsewhere — 35.9s to 42.5s. And v0.2.6 made
**text collectable**, which costs the machine 15% here (3.52s to 4.06s, against
the ~13% claimed) and buys the memory column above: a String used to come from
an arena that never freed, so every `Str` and every `+` was permanent.

`--algol-loop` turns off the hand-written C dispatch loop v0.2.5 introduced, so
the pair above measures it: **1.61×** here, against the 1.51× that release
claims. Worth keeping as an independent check of someone else's headline figure
— and note it moved with v0.2.6, the loop being where the new write barrier
falls.

Byte-identical output from the compiled back end and the machine, and the tests
pass under `algvm --test` as well. Worth re-running on a pin bump, because this
is a far better exercise of a processor than any single corpus case: 2,250 lines
of Algol-24 reading 27,000 lines of Markdown. `--collect 100` — collecting every
hundred instructions — also produces identical output, which is the collector
check worth having.

⚠️ **The tree-walker was the odd one out at v0.2.6, by two characters, and
v0.2.7 was the fix.** It truncated one line of 27,875 — `D-3` in
`DEFECTS-FOUND.md`, reported from here and now closed. The cause was a cache
remembering a string's **character** count keyed on **where its bytes were**,
which v0.2.6 broke by giving text a heap that recycles: a 41-byte ASCII line
landed on a freed 41-byte block that had held 39 characters, and was told 39.
**It cannot show in text that is entirely ASCII**, which is why every gate
upstream passed and a half-megabyte render of mixed text found it.

`ALG_TEXT_CHECK=1` is the v0.2.7 diagnostic for this, and worth a run on a pin
bump: it recomputes every cached length where the cache answers it and fails
naming both. All three processors pass it over the full build.

**CI compares the interpreter too, as of v0.2.7** — the machine *and* the
tree-walker, each against the compiled site, both under `ALG_TEXT_CHECK=1`.
That is the gap D-3 went through, closed.

## Two traps this project has already hit

⚠️ **`uses` brings a unit's names in unqualified, and a constant loses to an
imported function.** `Main.a24` had `const Source` while `Highlight` has a
`Source` function; the interpreter only *warned* about the clash, and the C back
end emitted a reference to the function where the constant belonged and would
not compile. It is now `Repo`. A name declared here has to be one no imported
unit uses — and `--test` will not catch it, because the interpreter runs.

⚠️ **The bands alternate tint, so inserting one flips every band below it.**
`.band.tint` is the only difference between the two, and the page reads as stripes
only while they alternate. v0.1.5's extension-functions band went in above the
guarantee and the three bands under it — guarantee, name, provenance — each had
to swap. The check that would catch getting it wrong is your eyes; nothing in the
build looks at it.

⚠️ **`extension` is not a keyword, and the home page's code block leaves it
uncolored on purpose.** `Scanner.a24` says so in as many words: `unit`, `test`,
`on` and `extension` are deliberately absent, being identifiers recognized by
position. The reference page colors from that scanner and so leaves it plain, and
the hand-written block matches it rather than the eye. Coloring it would make the
two pages disagree about the language.

⚠️ **A closed `<details>` hides its children in a way CSS cannot override.**
`display: block` on the contents does not bring them back, so a table of
contents cannot be collapsed by default and opened by a media query. The
reference ships it **open** and closes it by script below 1180px, which also
means the no-script failure shows the whole list rather than none of it.

## Writing Algol-24 here

Beyond the language reference, what bites when writing the generator:

- Semicolons **terminate**; the one before `end` is required.
- `Exit`, not `return`. Arguments are comma-separated and individually typed.
- `Length` and `IsEmpty` are properties on collections, but `Length(s)` is a
  builtin call on a String.
- String indices are **0-based**. `Pos` returns `-1` when not found.
- ⚠️ **`Entries (Path)` lists a directory** — `[RT-026]`, new in v0.4.0, and the
  fifth directory built-in. Names only, never paths, without `.` or `..`, in the
  filesystem's order, which is neither sorted nor stable between runs. Sort it
  before putting anything derived from it on a page, or the build stops being
  reproducible. The library's `file` unit has had an `Entries` since 0.1.6 with
  the same surface, and a `uses file` reaches that one; the generator uses
  neither.
- **Reflection is six built-ins and a type value** — `[RT-031]` to `[RT-035]`,
  new in v0.3.1. `Fields`, `TypeOf`, `Member`, `Invoke`, `New`, `SetMember`, and
  `T.Name`/`T.Parent`/`T.Fields`/`T.Methods`/`T.Properties`/`T.Accepts (X)`. No
  new syntax, no metaclasses, and nothing alters a class at run time. The
  generator uses none of it — the page describes it, which is a different thing,
  and the band's example is **run** before it goes on the page.
  ⚠️ A computed name reaches a `private` member; that is `[DCL-011]` and
  deliberate.
- A one-character literal is a `Char`, never a `String` — **but it now
  EQUALS the one-character String of the same text** `[VAL-010]`, as of
  v0.3.0, and membership follows `[VAL-013]`. The types stay distinct:
  `'a' is String` is still false, a Char still widens to a String and never
  the reverse, and nothing converts. ⚠️ **This is the first release that
  changes what an existing program means** — a comparison that was false is
  now true — which is why the minor version moved.

  Before it, writing a type annotation silently changed an answer:
  `var F : String := 'x';` then `F = 'x'` was **false**, where without the
  annotation both sides are Chars and it was true. Two `Str (…)` wrappers in
  this generator's own tests existed for that and are gone; a third, around a
  concatenation, was redundant either way. Any remaining `Str (…)` on a
  comparison is now noise rather than a fix.

  ⚠️ **The one shape that could break is a collection deliberately holding
  both a Char and a one-character String as distinct keys.** Those are one key
  now. Nothing here does it, and the upstream sweep found it in none of seven
  codebases.
- ⚠️ **`/` is real division and always answers a `Double`** — `7 / 2` is 3.5 and
  even `4 / 2` is `2.0`. `div` and `mod` are the Integer pair, they refuse a
  `Double` rather than truncating it, and they are the only operators that raise
  on a zero divisor (`7 / 0` is `Infinity`). There is no `Mod` built-in any more.
  This changed in v0.1.3, still the only release that alters what a *working*
  program means. The generator divides nowhere, so nothing here needed
  migrating — but anything written from memory of the old rule will be wrong.
- ⚠️ **Declaring a built-in's name takes over only the argument counts you
  declare** — `[RT-027]`, new in v0.1.4. The built-in keeps every other count,
  so a `WriteLn (A, B, C)` of your own leaves `WriteLn ('x')` still reaching
  standard output, and the mismatch shows up at run time rather than at the
  declaration. `System.Length` and friends always reach the built-in whatever
  has been declared. Two methods of one signature in a class are now refused
  outright rather than silently running the first.
- ⚠️ **An `extension` is visible only where it is imported** — `[MOD-015]`, new
  in v0.1.5. A top-level subprogram marked `extension` may also be called as a
  method on its first parameter, which must have a written type; the permission
  is found among the extensions the *compiling file* imports, and `uses` is not
  transitive, so a unit reaching `Strings` for itself does not hand `S.Trim ()`
  to its own importers. A member of the name always wins, with a `[WARN]` naming
  the class that took it. Nothing in `gen/` declares one; the library's
  `strings` is all extensions, and this generator calls them prefix-style.
- ⚠️ **`and` is not `&`, and the compiler now says so** — `[EXP-023]`/`[EXP-024]`,
  new in v0.1.6. `&`, `|`, `^`, `~`, `<<` and `>>` combine the bits of Integers
  and evaluate both sides; `and`, `or` and `not` test truthiness, yield an
  *operand* and short-circuit. Writing one where the other was meant raises a
  `[WARN]` rather than quietly doing the other thing. Every Integer is two's
  complement extended infinitely to the left, so `~0` is -1, `-1 & 5` is 5 and
  `1 << 70` grows; a `Double` is refused rather than reinterpreted. `>>` floors
  where `div` truncates, so they disagree on a negative value: `-7 >> 1` is -4
  and `-7 div 2` is -3.
- **`Str` takes a precision** — `[RT-028]`, new in v0.1.6. `Str (X, Decimals)`
  renders a Double with exactly that many places and never in exponent form, and
  `Str (X, Width, Decimals)` right-aligns it. Correctly rounded from the value,
  so `Str (2.675, 2)` is `2.67`; ties go to even. It takes a Double only — an
  Integer is refused, because one arity would otherwise mean a precision for one
  type and a width for another.
- Build strings with a `Buffer`, never `+` in a loop — a page is tens of
  kilobytes and concatenation is the cliff `Buffer` exists to answer.
- ⚠️ **Never use a `Set` for membership. Use a `Map` with dummy values.** Under
  `algc` a `Set` is not hash-backed — it is the same `ObjSeq` as a `List`, and
  `Add` is a linear `Contains` before an append, so **building one is
  quadratic**. Measured at N=32000: `Set` 1.80s, `List` + `Contains` 1.81s
  (identical, because `Set.Add` *is* that), `Map` 0.15s. A `Map` is the only
  genuinely hashed membership structure in the language.

  ⚠️ This is not an interpreted-versus-compiled split. `algc`'s interpreter is
  itself C running on the same runtime, so **both of `algc`'s modes are
  quadratic**; the fast one is JPascal. Recorded as `D5` by the tester.
- ⚠️ Collection iteration is **insertion order** for `Map` and `Set`, verified
  on all four paths and stable across runs, so a page built by walking one is
  deterministic. But insertion order means *most recent* insertion: `Remove`
  followed by re-`Add` moves the element to the **end**. `ALGOL-24.md` §5 claims
  order is unspecified and is wrong — §7 is correct.
- `uses` is not transitive; every file declares its own dependencies.
- ⚠️ **A quoted `uses` IS A PATH** — `[MOD-001]`. A bare identifier names a
  file of that name with `.a24` appended; a quoted string is a path, resolved
  **beside the importing file first**, then the working directory, then an
  installed library. So `uses '../vendor/algol24-library/strings';` from `gen/`
  reaches the pinned submodule, and `gen/Markup.a24` and the three callers all
  do exactly that. **The extension is still appended**, so the path is written
  without one: `'.../strings'`, never `'.../strings.a24'` — which answers
  `no .../strings.a24.a24`.
- ⚠️ **`uses` does not read `ALGOL24_LIB`.** For a *bare* name the search path
  is the program's own directory, the working directory, `<binary>/lib` and
  `<binary>/../share/algol24/lib`. `ALGOL24_LIB` belongs to the *library* and
  names where `graph` finds its glyph files. This is why the library is reached
  by path here and not by name — not, as this file briefly claimed, because it
  could not be reached at all.
- ⚠️ **`ReadFile`, `ReadLines` and `WriteFile` are OURS, in
  `gen/Template.a24`** — not built-ins. File I/O in the language is the
  `TextFile` resource; those three wrap it. A program that calls them without
  `uses Template` fails with `Undefined variable 'ReadFile'`.
- ⚠️ **TWO UNITS WHOSE NAMES DIFFER ONLY IN CASE ARE REFUSED** — in all three
  processors, as of v0.2.4. A unit name is an identifier and identifiers fold
  `[SRC-011]`, so `Strings` and `strings` are one name; the refusal names both
  files. This was `D-1`, reported from here and fixed there: before v0.2.4 the
  interpreter was correct, `algvm` lost the second unit, and `algc --compile`
  named each emitted C file after its unit so `strings.c` overwrote
  `Strings.c`. `gen/Markup.a24` is the rename that got round it and stays,
  because a unit named for what it does beats one named for a collision. A
  case-insensitive filesystem still cannot hold both files in one directory,
  and `cp` resolves that by silently clobbering one with the other.
- ⚠️ **The vendored `algc` has no foreign calls.** `bootstrap/build.sh` builds
  without `--ffi` on purpose, so a library unit reaching SDL runs under `algvm`
  and not under the compiler the site builds with — `Foreign calls are not
  available in this build`. The library's `.so` shims are gitignored build
  products and are absent from a fresh submodule clone until its `build.sh`
  runs.
- There is no range form in a `for`: `for var I in 1 .. 20 do` is
  `Expect 'do' after 'for ... in' clause.` Walk a collection, or use `while`.
- The output directory must already exist. `build.sh` mkdirs first.
- `ReadFile` joins lines with `#10` between them and never after the last, so
  `WriteFile` closes with `WriteLn`, not `Write`, to put the file's final
  newline back. A project whose compiler reproduces itself byte for byte does
  not lose a byte here either.

## Design

`brand/BRAND.md` is authoritative for color and the logo. Two points that are
easy to get wrong:

- ⚠️ **Orange is never body text on white** — `#F5901E` is 2.36:1 there. Light
  theme leads with the blue `#1264C7`; dark theme leads with the orange, which
  is 7.57:1 on the ink navy. The theme toggle shows both stars and lights
  whichever leads.
- ⚠️ **Inline the logo SVG; never `<img src>` it.** An `<img>`-referenced SVG is
  a separate document that cannot see `data-theme`, so it would follow the
  operating system instead of the site's toggle.

Theme CSS is token-level: `:root` carries the complete light palette,
`@media (prefers-color-scheme: dark)` guarded as `:root:not([data-theme="light"])`
redefines the tokens, and `:root[data-theme="dark"]` redefines them again so the
toggle wins in both directions. Never declare a color only inside a media or
`[data-theme]` block.

## Positioning

Algol-24 is **not** a successor to ALGOL 60 and must never be described as one.
The name is for the lineage running through Pascal. **The 24 is a vintage, not a
version** — there will be no Algol-26. The implementation descends from Bob
Nystrom's Lox, which deserves visible credit.

⚠️ **Never "Pascal-flavored".** The compiler repository's own `CLAUDE.md`
forbids the phrase: it sells the language as a derivative of an old thing, when
the old-looking surface is the deliberate part and the capability behind it is
the point. Pascal may be named as the lineage of the *syntax*, never as the
language's identity. The register is **retro-modern** — classic Pascal syntax
over unbounded integers, full Unicode, gradual types, closures, extension
functions, bitwise operators and a foreign function interface. The site said
"Pascal-flavoured" in four places, including both meta descriptions, until
v0.1.1.

⚠️ **American spelling throughout**, matching the compiler repository, which
settled it in the commit *"Retro-modern, not Pascal-flavored — and American
spelling throughout."* This site was written in British spelling and was swept.

⚠️ **"Stable, not closed" — never "closed".** The site said the language was
"deliberately closed" and "opened once, and once only" from v0.1.5 until v0.1.6
made both false in one release, with three changes. The compiler repository
settled the wording in *"v0.1.6, and the language is stable rather than
closed"*: it changes **only on measured demand from a project using it, and the
measurement goes in the proposal**. Write the rule, not a count of exceptions to
it — a count is a hostage to the next release.

⚠️ **`pre-1.0` is off the page, and *alpha* is spent.** Both meant one thing:
a library written in Algol-24 rather than bolted into the runtime. It shipped as
`algol24-library` v0.1.0, so the hero reads `v0.2.7 · library v0.1.0 · on
Homebrew` and the library band says in as many words that this is what alpha
meant. Do not reintroduce a hedge for something that has arrived.

Do not call it a toy language. State the engineering plainly and without
adjectives, and do not manufacture an adoption story it does not have yet.

⚠️ **The site states no performance multiple for the machine**, and the reason
it does not is that the figure keeps moving. The compiler repository publishes
6.9× the tree-walker for `Fib (27)`; measured here it was 4.9× at v0.2.3 and
v0.2.4, **9.5×** at v0.2.5 once the C dispatch loop landed, and **8.6×** at
v0.2.6 once a collectable String cost the machine its write barrier. Three
different right answers in four releases. The page uses the figures it measured
about **itself** — the three-processor table above — and `DEFECTS-FOUND.md`
keeps the `Fib` series, every row of it measured in one sitting.
