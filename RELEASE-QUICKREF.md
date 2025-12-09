# Release Quick Reference

## Quick Start

### Create a Release (3 ways)

**Option 1: Using the release script (Recommended)**
```bash
./scripts/release.sh patch    # for bug fixes
./scripts/release.sh minor    # for new features
./scripts/release.sh major    # for breaking changes
git push origin main --tags
```

**Option 2: GitHub Actions UI**
1. Go to Actions → Release Pipeline
2. Click "Run workflow"
3. Enter version (e.g., `1.0.1`)
4. Click "Run workflow"

**Option 3: Git tag**
```bash
git tag -a v1.0.1 -m "Release v1.0.1"
git push origin v1.0.1
```

## What Happens After Push

✅ **Automatic Actions:**
- Validates version format
- Builds Docker image
- Generates changelog from commits
- Creates GitHub Release
- Pushes to GHCR: `ghcr.io/sarahdevelopdev-art/voting/voting-system:v1.0.1`
- Shows release summary

## Version Format

```
MAJOR.MINOR.PATCH[-PRERELEASE]
1.0.0           ✅ Production release
1.0.1           ✅ Patch (bug fix)
1.1.0           ✅ Minor (new feature)
2.0.0           ✅ Major (breaking change)
1.0.0-beta.1    ✅ Pre-release
```

## Commit Message Format

Use conventional commits for automatic changelog:

```
feat: add new feature
fix: resolve bug
docs: update documentation
perf: improve performance
refactor: reorganize code
test: add tests
chore: update deps
```

## Workflow Status

Check release status:
- GitHub: https://github.com/sarahdevelopdev-art/voting/actions
- Releases: https://github.com/sarahdevelopdev-art/voting/releases

## Use Released Image

```bash
# Pull latest version
docker pull ghcr.io/sarahdevelopdev-art/voting/voting-system:latest

# Pull specific version
docker pull ghcr.io/sarahdevelopdev-art/voting/voting-system:v1.0.0

# Run it
docker run -p 3000:3000 ghcr.io/sarahdevelopdev-art/voting/voting-system:v1.0.0
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Invalid version format" | Use SemVer: `MAJOR.MINOR.PATCH` |
| "Tag already exists" | Delete old tag: `git tag -d v1.0.0 && git push origin :v1.0.0` |
| "Release failed" | Check Actions tab for logs |
| "Docker push failed" | Verify GITHUB_TOKEN has `packages: write` permission |

## More Info

- Full guide: See `RELEASE.md`
- Changelog: See `CHANGELOG.md`
- Release script: See `scripts/release.sh`
