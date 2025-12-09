# Release Process Documentation

## Overview

The Voting System uses automated versioning and release workflows to manage versions, create tags, and generate Docker images.

## Versioning Strategy

This project follows **Semantic Versioning (SemVer)** as defined in https://semver.org/

Format: `MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]`

- **MAJOR**: Increment for incompatible API changes
- **MINOR**: Increment for backwards-compatible new features
- **PATCH**: Increment for backwards-compatible bug fixes
- **PRERELEASE**: Optional pre-release versions (alpha, beta, rc)

## Release Methods

### Method 1: Automated Script (Recommended)

Use the provided release script to automate version bumping and tagging:

```bash
# Patch release (bug fixes)
./scripts/release.sh patch

# Minor release (new features)
./scripts/release.sh minor

# Major release (breaking changes)
./scripts/release.sh major
```

The script will:
1. Update version in `package.json` and `frontend/package.json`
2. Update `CHANGELOG.md` with new version entry
3. Create a Git commit with the version bump
4. Create an annotated Git tag
5. Show next steps for pushing

### Method 2: Manual GitHub Actions Workflow

Trigger the release workflow manually:

```bash
gh workflow run release.yml -f version=1.0.1
```

Or use the GitHub UI:
1. Go to Actions → Release Pipeline
2. Click "Run workflow"
3. Enter the version (e.g., `1.0.1`)
4. Click "Run workflow"

### Method 3: Git Tag Push

Push a new tag to trigger automatic release:

```bash
# Create and push a version tag
git tag -a v1.0.1 -m "Release v1.0.1"
git push origin v1.0.1
```

## Workflow Steps

### 1. Validate Release

The workflow validates:
- Version format (must match SemVer)
- Git tag existence
- Version consistency

### 2. Build

Builds and pushes Docker image to GitHub Container Registry:
- Tags: `v1.0.1` and `latest`
- Includes build metadata (version, date, commit hash)
- Uses GitHub Actions cache for faster builds

### 3. Generate Changelog

Automatically generates changelog from commits:
- Parses conventional commits (feat, fix, docs, etc.)
- Groups changes by type
- Generates markdown with version info

### 4. Create Release

Creates a GitHub Release with:
- Generated changelog as description
- Link to repository
- Release artifacts

### 5. Notify

Logs release information including:
- Version number
- Docker image URLs
- Release notes link

## Accessing Released Artifacts

### Docker Image

Pull the released Docker image:

```bash
# Latest version
docker pull ghcr.io/sarahdevelopdev-art/voting/voting-system:latest

# Specific version
docker pull ghcr.io/sarahdevelopdev-art/voting/voting-system:v1.0.1
```

Run the container:

```bash
docker run -p 3000:3000 ghcr.io/sarahdevelopdev-art/voting/voting-system:latest
```

### Release Notes

View release notes:
- GitHub: https://github.com/sarahdevelopdev-art/voting/releases
- CHANGELOG: See `CHANGELOG.md` in repository

## Commit Message Format

To ensure proper changelog generation, follow conventional commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring without feature changes
- `perf`: Performance improvements
- `test`: Test additions/modifications
- `chore`: Build process, dependencies, etc.

**Examples:**

```
feat(votes): add vote filtering by date range

fix(api): handle null content in vote creation

docs(readme): update installation instructions

chore: update dependencies
```

## Pre-Release Versions

For beta/alpha releases:

```bash
# Using the script (creates beta tag)
git tag -a v1.0.0-beta.1 -m "Beta release"
git push origin v1.0.0-beta.1

# Or manually trigger workflow with version
gh workflow run release.yml -f version=1.0.0-beta.1
```

## Workflow Permissions

The release workflow requires GitHub permissions:
- `contents: write` - Create releases and tags
- `packages: write` - Push Docker images to GHCR

These are automatically configured in `.github/workflows/release.yml`

## Troubleshooting

### Release Failed: "denied: installation not allowed"

**Solution**: Ensure `packages: write` permission is set on the release job.

### Invalid Version Format

**Solution**: Use valid SemVer format: `MAJOR.MINOR.PATCH`

### Tag Already Exists

**Solution**: Delete the tag and recreate:
```bash
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0
./scripts/release.sh patch  # Re-run release script
```

### Docker Push Failed

**Solution**: Verify GitHub token permissions and registry authentication.

## Best Practices

1. **Always use conventional commits** for proper changelog generation
2. **Test before release** - Ensure all tests pass before creating release
3. **Update documentation** - Update README and other docs when needed
4. **Review changes** - Check `git diff` before pushing tag
5. **Use meaningful messages** - Release tags should have descriptive messages
6. **One release at a time** - Don't create multiple releases simultaneously
7. **Backup before major releases** - Especially when doing major version bumps

## CI/CD Integration

The release workflow integrates with:
- **GitHub Actions**: Automated build, test, and deployment
- **Container Registry**: GHCR for Docker images
- **Git**: Automatic tagging and release creation

All workflows are defined in `.github/workflows/` directory.
