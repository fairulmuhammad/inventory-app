#!/bin/bash
# TechNova SonarQube Security and Quality Analysis Script
# Usage: ./sonarqube-analysis.sh

set -e

echo "🔍 Starting TechNova SonarQube Security and Quality Analysis..."
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_KEY="technova-inventory-app"
SONAR_HOST="http://localhost:9000"
SONAR_TOKEN=${SONAR_TOKEN:-"admin"}
SONAR_LOGIN=${SONAR_LOGIN:-"admin"}

echo -e "${BLUE}Step 1: Installing Dependencies${NC}"
cd inventory-service

# Install Python dependencies for analysis
pip install bandit safety coverage pytest pytest-cov pytest-html

echo -e "${BLUE}Step 2: Running Security Analysis with Bandit${NC}"
# Run Bandit security analysis
bandit -r . -f json -o bandit-report.json || true
bandit -r . -f txt -o bandit-report.txt || true

echo -e "${BLUE}Step 3: Running Safety Check for Dependencies${NC}"
# Check for known security vulnerabilities in dependencies
safety check --json --output safety-report.json || true
safety check --output safety-report.txt || true

echo -e "${BLUE}Step 4: Running Unit Tests with Coverage${NC}"
# Run tests with coverage
python -m pytest tests/ --cov=. --cov-report=xml --cov-report=html --junitxml=test-results.xml -v

echo -e "${BLUE}Step 5: Running SonarQube Scanner${NC}"
cd ..

# Download SonarQube Scanner if not exists
if [ ! -f "sonar-scanner/bin/sonar-scanner" ]; then
    echo "Downloading SonarQube Scanner..."
    wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-linux.zip
    unzip -q sonar-scanner-cli-4.8.0.2856-linux.zip
    mv sonar-scanner-4.8.0.2856-linux sonar-scanner
    rm sonar-scanner-cli-4.8.0.2856-linux.zip
fi

# Run SonarQube analysis
export PATH="$PATH:$(pwd)/sonar-scanner/bin"
sonar-scanner \
  -Dsonar.projectKey=$PROJECT_KEY \
  -Dsonar.sources=inventory-service \
  -Dsonar.host.url=$SONAR_HOST \
  -Dsonar.login=admin \
  -Dsonar.password=admin \
  -Dsonar.python.coverage.reportPaths=inventory-service/coverage.xml \
  -Dsonar.python.xunit.reportPath=inventory-service/test-results.xml \
  -Dsonar.python.bandit.reportPaths=inventory-service/bandit-report.json

echo -e "${GREEN}✅ SonarQube Analysis Completed!${NC}"
echo -e "${YELLOW}📊 View results at: ${SONAR_HOST}/dashboard?id=${PROJECT_KEY}${NC}"
echo -e "${YELLOW}🔐 Security Report: inventory-service/bandit-report.txt${NC}"
echo -e "${YELLOW}📦 Safety Report: inventory-service/safety-report.txt${NC}"
echo -e "${YELLOW}📈 Coverage Report: inventory-service/htmlcov/index.html${NC}"
