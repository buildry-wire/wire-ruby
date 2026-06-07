# Releasing `wirepayment`

This gem publishes to [RubyGems.org](https://rubygems.org) via **OIDC trusted
publishing** from GitHub Actions — there is no long-lived API token stored in
the repository.

## One-time setup (before the FIRST publish)

Because the gem does not exist on RubyGems.org yet, you cannot attach a trusted
publisher to it directly. Do the bootstrap push once, then register OIDC:

1. **Reserve the gem name with a single manual push** (one-time only):
   ```bash
   gem build wirepayment.gemspec
   gem signin                       # log in as the gem owner
   gem push wirepayment-1.0.0.gem   # or use a temporary API key
   ```
   Alternatively, create the gem via the website if you prefer not to push 1.0.0
   manually — but a real published version is required before a trusted
   publisher can be attached.

2. **Register the GitHub Actions trusted publisher** on RubyGems.org:
   - Go to the gem page → **Settings** → **Trusted Publishers** →
     **Add a new trusted publisher** (or
     https://rubygems.org/gems/wirepayment/trusted_publishers).
   - Fill in:
     - **RubyGems gem name:** `wirepayment`
     - **GitHub repository:** `buildry-wire/wire-ruby`
     - **Workflow filename:** `release.yml`
     - **Environment (optional):** `rubygems` (matches `environment:` in the
       workflow; leave blank if you remove that line)

3. (Optional) Create a GitHub Actions **environment** named `rubygems` under
   repo Settings → Environments to add manual approval / protection rules.

## Cutting a release

1. Bump the version in `lib/wire/version.rb`.
2. Update `CHANGELOG.md`.
3. Commit, then tag — the tag (minus the leading `v`) MUST match
   `Wire::VERSION`:
   ```bash
   git commit -am "chore: release v1.0.1"
   git tag v1.0.1
   git push origin main --tags
   ```
4. The `release` workflow runs automatically on the tag: it verifies the
   tag/version match, runs tests, builds the gem, publishes to RubyGems via
   OIDC, and creates a GitHub Release.

No `RUBYGEMS_API_KEY` secret is required once the trusted publisher is set up.
