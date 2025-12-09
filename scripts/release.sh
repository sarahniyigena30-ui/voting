#!/bin/bash

# Release script for automated versioning and tagging
# Usage: ./scripts/release.sh [major|minor|patch]

set -e

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
NC='\033[0m' # No Color

# Get current version from package.json
CURRENT_VERSION=$(grep '"version"' package.json | head -1 | awk -F'"' '{print $4}')

echo -e "${COLOR_YELLOW}Current version: $CURRENT_VERSION${NC}"

# Determine bump type
BUMP_TYPE=${1:-patch}

if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
  echo -e "${COLOR_RED}Error: Invalid bump type. Use: major, minor, or patch${NC}"
  exit 1
fi

# Parse version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Bump version
case $BUMP_TYPE in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo -e "${COLOR_YELLOW}New version: $NEW_VERSION${NC}"

# Update package.json
sed -i "s/\"version\": \"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/" package.json

# Update frontend package.json if it exists
if [ -f "frontend/package.json" ]; then
  sed -i "s/\"version\": \"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/" frontend/package.json
fi

# Update CHANGELOG.md
CHANGELOG_ENTRY="## [$NEW_VERSION] - $(date +%Y-%m-%d)

### Added
- New features go here

### Changed
- Changes go here

### Fixed
- Fixes go here

---

"

# Insert at the beginning (after the title)
sed -i "/^# Changelog/a\\
$CHANGELOG_ENTRY" CHANGELOG.md

# Git operations
git add package.json frontend/package.json CHANGELOG.md
git commit -m "chore: bump version to $NEW_VERSION"

# Create and push tag
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"

echo -e "${COLOR_GREEN}✓ Version bumped to $NEW_VERSION${NC}"
echo -e "${COLOR_GREEN}✓ Git tag created: v$NEW_VERSION${NC}"
echo ""
echo -e "${COLOR_YELLOW}Next steps:${NC}"
echo "1. Review the changes:"
echo "   git show HEAD"
echo ""
echo "2. Push the changes and tag:"
echo "   git push origin main --tags"
echo ""
echo "3. The release workflow will automatically:"
echo "   - Build and push Docker image"
echo "   - Create a GitHub release"
echo "   - Generate changelog"
