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

vendor/algol24/algc gen/Main.a24            # generate directly
vendor/algol24/algc --test gen/Template.a24 # one module's tests
```

There is no per-test filter: the unit is a file.

## Architecture

```
templates/*.html  ──> gen/Main.a24 ──> site/*.html
                        │
                        └── gen/Template.a24   read, substitute, write
```

`vendor/algol24` is a submodule doing **two jobs at once**: its `bootstrap/`
builds `algc`, and its `ALGOL-24.md` and `README.md` are the source text for the
Reference and Tour pages. One pinned commit, so the documentation on the site
cannot drift from the compiler that generated it.

`prototype/index.html` is the hand-written design reference for the **body** —
the artifact-shaped original, with no `<head>` because the artifact host
supplies one. `templates/index.html` is the same markup wrapped in a real
document: doctype, meta, favicons, Open Graph, and the theme bootstrap script in
its proper place before first paint.

So the two are not byte-comparable, and only the body should be diffed when
checking that the generator still reproduces the design.

## The state of it

The generator is a **stub**: one template, one page, `{{PLACEHOLDER}}`
substitution. That is enough to prove the whole chain — `cc` → seed → `algc` →
generator → site → Pages — and that chain works today.

Markdown parsing and `.a24` syntax highlighting are **blocked on the language**,
not on this repository. They need a string library (`Trim`, `Split`, `Replace`,
`StartsWith`, `LowerCase`, and a `Pos` taking a start offset) and `MkDir`. Both
are written up in `WISHLIST-SITEGEN.md` in the working compiler repository.

⚠️ **Two Algol-24 checkouts exist.** `workspace/JPascal` is the working code and
is far ahead; `workspace-copilot/algol24` is the clean public repo. Run any
count or check against `JPascal`.

## Writing Algol-24 here

Beyond the language reference, what bites when writing the generator:

- Semicolons **terminate**; the one before `end` is required.
- `Exit`, not `return`. Arguments are comma-separated and individually typed.
- `Length` and `IsEmpty` are properties on collections, but `Length(s)` is a
  builtin call on a String.
- String indices are **0-based**. `Pos` returns `-1` when not found.
- A one-character literal is a `Char`, never a `String`.
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
- The output directory must already exist. `build.sh` mkdirs first.

## Design

`brand/BRAND.md` is authoritative for colour and the logo. Two points that are
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
toggle wins in both directions. Never declare a colour only inside a media or
`[data-theme]` block.

## Positioning

Algol-24 is **not** a successor to ALGOL 60 and must never be described as one.
The name is for the lineage running through Pascal. **The 24 is a vintage, not a
version** — there will be no Algol-26. The implementation descends from Bob
Nystrom's Lox, which deserves visible credit.

Do not call it a toy language. The honest register is early but serious: state
the engineering plainly and without adjectives, and do not manufacture an
adoption story it does not have yet.
