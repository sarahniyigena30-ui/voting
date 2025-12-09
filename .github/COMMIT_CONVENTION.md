# Commit Message Standards

## Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

## Types
- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that don't affect code meaning
- **refactor**: Code refactoring without feature changes
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Build, dependencies, tooling

## Examples
- `feat(votes): add vote filtering by status`
- `fix(db): handle connection pool timeout`
- `test(api): add integration tests for POST /votes`
- `docs(readme): update deployment instructions`

## Rules
- Use lowercase
- Use imperative mood ("add" not "added")
- Don't end with period
- Limit subject to 50 characters
- Reference issues: `Fixes #123`
