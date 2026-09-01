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
templates/*.html  ──> gen/Main.a24 ──> site/*.html
                        │
                        └── gen/Template.a24   read, substitute, write
```

`vendor/algol24` is a submodule doing **two jobs at once**: its `bootstrap/`
builds `algc`, and its `ALGOL-24.md` and `README.md` are the source text for the
Reference and Tour pages. One pinned commit, so the documentation on the site
cannot drift from the compiler that generated it.

⚠️ **The pin is on the old layout, and bumping it will break the build.** The
compiler repository has since been restructured: `build.sh` and `compile.sh` are
gone from the root, `algc` is built to `bootstrap/algc`, and `ALGOL-24.md` moved
to `spec/`. Both `build.sh` and `deploy.yml` run `vendor/algol24/build.sh` and
then `vendor/algol24/algc`, so a naive submodule bump fails on the first step.
Updating the pin means updating those two invocations in the same commit.

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
- **Both builds fail on an unrendered `{{`.** A placeholder added to a template
  with no matching `Substitute` in `gen/Main.a24` exits 70 locally and fails the
  job in CI. Page constants live at the top of `Main.a24`; add the substitution
  in the same commit as the template. The grep is `-I` so binaries are skipped —
  `og-image.png` really did contain `{{`.
- ⚠️ **`brand/dist/` is generated and checked in on purpose** — the same
  argument as the compiler checking in `bootstrap/`. `brand/build.sh` needs
  macOS's `qlmanage` and CI is Linux, so the build that consumes the assets must
  not need the tools that made them. Never add it to `.gitignore`; regenerate on
  a Mac and commit the PNGs.

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

## Publishing

Actions builds and deploys to Pages on every push to `main`; there is nothing to
run by hand and no manual deploy step.

**The custom domain is done and live.** `https://algol24.com/` serves the
generated page, `www` 301s to the apex, and the certificate covers both. Pages
is on `build_type: workflow`, so the domain is held in the repository's Pages
settings and **there is no `CNAME` file in the repo** — `static/` is empty.
README.md still describes the domain as a pending step and is out of date on
that point.

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
over unbounded integers, full Unicode, gradual types, closures and a foreign
function interface. The site said "Pascal-flavoured" in four places, including
both meta descriptions, until v0.1.1.

⚠️ **American spelling throughout**, matching the compiler repository, which
settled it in the commit *"Retro-modern, not Pascal-flavored — and American
spelling throughout."* This site was written in British spelling and was swept.

Do not call it a toy language. **v0.1.x is the feature-complete alpha**: the
language is done, and *alpha* means only that the library written in Algol-24 is
still to come. State the engineering plainly and without adjectives, and do not
manufacture an adoption story it does not have yet.
