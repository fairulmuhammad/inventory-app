# TechNova Inventory Management System

## 📋 Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Development](#development)
- [Testing](#testing)
- [Monitoring](#monitoring)
- [Security](#security)
- [Deployment](#deployment)
- [Contributing](#contributing)

## 🎯 Overview

TechNova Inventory Management System adalah aplikasi web berbasis mikroservices untuk mengelola inventaris. Proyek ini mengimplementasikan pipeline DevOps lengkap dengan fokus pada:

- ✅ Otomatisasi CI/CD
- ✅ Pengujian otomatis
- ✅ Keamanan kode (DevSecOps)
- ✅ Monitoring dan logging
- ✅ Kolaborasi tim

## 🏗️ Architecture

### Tech Stack
- **Backend**: Python Flask
- **Containerization**: Docker
- **CI/CD**: GitHub Actions
- **Monitoring**: Prometheus + Grafana
- **Logging**: Loki + Promtail
- **Security**: Bandit, Safety, SonarQube
- **Testing**: PyTest

### Pipeline Architecture
```
Developer → Git Push → GitHub Actions → 
    ├── Unit Tests
    ├── Security Scan
    ├── SonarQube Analysis
    ├── Docker Build
    └── Deploy → Monitoring
```

## 🚀 Getting Started

### Prerequisites
- **Docker & Docker Compose** - Container orchestration
- **Python 3.10+** - Runtime environment
- **Git** - Version control
- **kubectl** (optional) - Kubernetes deployment

### 🎬 Interactive Demo
Run the complete DevOps pipeline demonstration:

```bash
# Interactive demo with all features
chmod +x scripts/demo.sh
./scripts/demo.sh

# Automated demo (no user interaction)  
./scripts/demo.sh auto
```

### 🐳 Docker Deployment (Recommended)
```bash
# Clone repository
git clone <repository-url>
cd inventory-app

# Start complete monitoring stack
docker-compose up -d

# Access applications
# Inventory Service: http://localhost:5001
# Grafana: http://localhost:3000 (admin/admin123)
# Prometheus: http://localhost:9090
# Loki: http://localhost:3100
```

### ☸️ Kubernetes Deployment
```bash
# Deploy to Kubernetes cluster
chmod +x scripts/k8s-deploy.sh
./scripts/k8s-deploy.sh deploy

# Canary deployment
chmod +x scripts/canary-deploy.sh
./scripts/canary-deploy.sh canary technova/inventory-service:v1.1.0

# Auto-scaling demo
./scripts/k8s-deploy.sh load-test 120 20
```

### Environment Setup
```bash
# Install Python dependencies
cd inventory-service
pip install -r requirements.txt

# Run locally
python app.py
```

## 👨‍💻 Development

### Code Quality
```bash
# Run linting
flake8 inventory-service/

# Format code
black inventory-service/

# Security scan
bandit -r inventory-service/

# Dependency check
safety check -r inventory-service/requirements.txt
```

### Pre-commit Hooks
```bash
# Install pre-commit
pip install pre-commit
pre-commit install

# Manual run
pre-commit run --all-files
```

## 🧪 Testing

### Unit Tests
```bash
cd inventory-service
pytest tests/test_app.py -v --cov=.
```

### Integration Tests
```bash
pytest tests/test_integration.py -v
```

### Performance Tests
```bash
pytest tests/test_performance.py -v
```

### Test Coverage
Target: 90%+ coverage
```bash
pytest --cov=. --cov-report=html
```

## 📊 Monitoring

### Metrics
- **Application Metrics**: Request count, latency, errors
- **System Metrics**: CPU, Memory, Disk usage
- **Custom Metrics**: Inventory count, business KPIs

### Dashboards
- **Grafana**: http://localhost:3000
  - Application Performance Dashboard
  - System Metrics Dashboard
  - Business Metrics Dashboard

### Alerts
- Service down
- High error rate (>10%)
- High response time (>1s)
- Resource usage >80%

### Logs
- **Loki**: Centralized logging
- **Promtail**: Log collection
- **Access**: Grafana Explore section

## 🔒 Security

### Security Scanning
- **Bandit**: Python security linter
- **Safety**: Dependency vulnerability scanner
- **SonarQube**: Code quality and security

### Security Practices
- Input validation
- Error handling
- Secure headers
- No sensitive data in logs
- Regular dependency updates

### Vulnerability Management
1. Automated scanning in CI/CD
2. Regular security audits
3. Dependency updates
4. Security training for team

## 🚀 Deployment

### Production Deployment
```bash
# Build and deploy
docker-compose -f docker-compose.prod.yml up -d

# Health check
curl http://localhost:5001/health
```

### Environment Variables
```env
FLASK_ENV=production
PROMETHEUS_ENABLED=true
LOG_LEVEL=INFO
```

### Rollback Strategy
```bash
# Quick rollback
docker-compose down
docker-compose up -d --scale inventory-service=0
# Deploy previous version
```

## 🤝 Contributing

### Workflow
1. Create feature branch
2. Implement changes
3. Write tests
4. Run quality checks
5. Create Pull Request
6. Code review
7. Merge to main

### Branch Strategy
- `main`: Production-ready code
- `develop`: Integration branch
- `feature/*`: Feature development
- `hotfix/*`: Emergency fixes

### Code Review Checklist
- [ ] Tests written and passing
- [ ] Security considerations
- [ ] Performance impact
- [ ] Documentation updated
- [ ] No breaking changes

### Definition of Done
- [ ] Code implemented
- [ ] Tests pass (>90% coverage)
- [ ] Security scan clean
- [ ] Performance acceptable
- [ ] Documentation updated
- [ ] Code reviewed
- [ ] Deployed successfully

## 📈 Metrics and KPIs

### Development Metrics
- **Lead Time**: Time from commit to production
- **Deployment Frequency**: Daily deployments
- **Mean Time to Recovery**: <30 minutes
- **Change Failure Rate**: <5%

### Quality Metrics
- **Test Coverage**: >90%
- **Code Quality**: SonarQube Grade A
- **Security Vulnerabilities**: 0 high/critical
- **Performance**: <200ms response time

## 🆘 Troubleshooting

### Common Issues
1. **Service won't start**
   ```bash
   docker-compose logs inventory-service
   ```

2. **Tests failing**
   ```bash
   pytest -v --tb=short
   ```

3. **Metrics not showing**
   ```bash
   curl http://localhost:5001/metrics
   ```

### Support
- Create GitHub Issue
- Check monitoring dashboards
- Review application logs

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Team
- DevOps Engineer: Pipeline and Infrastructure
- Developer: Application Development
- QA Engineer: Testing and Quality
- Security Engineer: Security Implementation
