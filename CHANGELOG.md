# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-09

### Added
- Initial release of Voting System API
- Express.js REST API for vote management
- Local JSON file storage instead of MySQL database
- Frontend UI with Create, Read, Update, Delete operations
- Docker containerization with multi-stage build
- GitHub Actions CI/CD pipeline
- Prometheus metrics collection
- Health check endpoints
- API documentation and example responses
- Comprehensive test suite (unit and integration tests)
- Kubernetes deployment manifests
- Horizontal Pod Autoscaler configuration
- Automated release workflow with semantic versioning

### Features
- **Vote Management**: Create, retrieve, update, and delete votes
- **Metrics**: Prometheus endpoint for monitoring
- **Health Checks**: Built-in health check endpoint
- **Static Frontend**: Serve frontend from backend
- **Container Ready**: Docker image built and pushed to GHCR
- **GitOps Ready**: Kubernetes manifests for deployment

---

