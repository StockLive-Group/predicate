# Releasing predicate-rb

Every shippable change gets a full release — version, changelog, tag, gem.
Don't stop at committing.

The gem is published as **`predicate-rb`** (the RubyGems name `predicate`
belongs to an unrelated project). The library, its require path and the
`Predicate` constant stay `predicate`.

## 1. Bump the version

- `lib/predicate/version.rb` — `VERSION = 'x.y.z'`
- `CHANGELOG.md` — a `## [x.y.z]` entry describing what changed

Both are enforced in CI. A tag whose version disagrees with
`Predicate::VERSION` fails the release, and so does a version with no
changelog entry — a release nobody can read is not a release.

### What counts as which bump

This gem is past `1.0.0`: a breaking change is a major version bump. The
public contract is wider than the method signatures. Treat these as
**breaking** even though they look small:

- renaming or changing the arity of a **DSL or validation helper** (as
  `present?` → `is_present?` did in 1.2.0)
- changing how **cache keys** are computed or when cached results expire
- changing which file **model integration** loads by convention, or when
- changing a **combinator**'s short-circuit or truthiness rules

## 2. Verify locally

```bash
bundle exec rake                 # boundary check, workflows, then the suite — must be green
gem build predicate.gemspec      # builds predicate-rb-x.y.z.gem
```

## 3. Commit, tag, push — straight to main

> **No pull request for a release.** A release is mechanical: the version,
> the changelog, the tag. PRs are for **code and contracts** — anything that
> changes behaviour, an API, or a guarantee.

```bash
git add -A
git commit -m "release: vX.Y.Z"
git tag -a vX.Y.Z -m "predicate-rb X.Y.Z"
git push origin main
git push origin vX.Y.Z
```

Pushing the `v*` tag triggers `.github/workflows/release.yml`, which verifies
the tag against `Predicate::VERSION`, verifies the changelog entry, runs the
gate, builds, checks the package holds only the allowlisted paths, and
**pushes to RubyGems** through trusted publishing.

**Do not `gem push` by hand** — it collides with the CI push, which then fails
because the version already exists.

No RubyGems API key exists for this gem: CI exchanges its GitHub OIDC token for
a short-lived credential. The trusted publisher on rubygems.org binds the
`StockLive-Group` owner, the `predicate` repository and the `release.yml`
workflow; renaming the workflow breaks publishing until that binding is updated.

## 4. Confirm

```bash
gem info predicate-rb --remote    # the new version is listed
```

Then bump any host that pins a git `ref:` — hosts resolving this gem from the
repository by SHA do not move themselves.
