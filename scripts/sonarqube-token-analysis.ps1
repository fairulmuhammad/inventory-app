# TechNova SonarQube Integration with Token Authentication
# Project: technova-inventory-app
# Token: Provided via environment variable for security

param(
    [string]$SonarHost = "http://localhost:9000",
    [string]$ProjectKey = "technova-inventory-app",
    [string]$SonarToken = $env:SONAR_TOKEN
)

Write-Host "🔍 TechNova SonarQube Analysis with Authentication Token" -ForegroundColor Blue
Write-Host "==========================================================" -ForegroundColor Blue

# Step 1: Download SonarQube Scanner if not exists
$scannerPath = "sonar-scanner"
if (-not (Test-Path "$scannerPath\bin\sonar-scanner.bat")) {
    Write-Host "`n📥 Downloading SonarQube Scanner..." -ForegroundColor Yellow
    
    $scannerUrl = "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-windows.zip"
    $zipFile = "sonar-scanner.zip"
    
    try {
        Invoke-WebRequest -Uri $scannerUrl -OutFile $zipFile
        Expand-Archive -Path $zipFile -DestinationPath "." -Force
        Rename-Item "sonar-scanner-4.8.0.2856-windows" $scannerPath
        Remove-Item $zipFile
        Write-Host "✅ SonarQube Scanner downloaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Failed to download scanner, using manual approach" -ForegroundColor Yellow
    }
}

# Step 2: Prepare analysis reports
Write-Host "`n📊 Preparing Analysis Reports..." -ForegroundColor Yellow

Set-Location "inventory-service"

# Run security and quality analysis
try {
    Write-Host "🔐 Running Bandit security analysis..."
    bandit -r . -f json -o bandit-report.json 2>$null
    
    Write-Host "🛡️ Running Safety dependency check..."
    safety check --json --output safety-report.json 2>$null
    
    Write-Host "🧪 Running tests with coverage..."
    python -m pytest tests/ --cov=. --cov-report=xml --cov-report=html --junitxml=test-results.xml -v --quiet
    
    Write-Host "✅ All reports generated successfully" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Some analysis tools completed with warnings" -ForegroundColor Yellow
}

Set-Location ".."

# Step 3: Run SonarQube Scanner with Token Authentication
Write-Host "`n🎯 Running SonarQube Scanner with Token Authentication..." -ForegroundColor Yellow

$sonarProperties = @"
# TechNova SonarQube Analysis Configuration
sonar.projectKey=$ProjectKey
sonar.projectName=TechNova Inventory Management System
sonar.projectVersion=1.0.0
sonar.host.url=$SonarHost
sonar.login=$SonarToken

# Source configuration
sonar.sources=inventory-service
sonar.exclusions=**/tests/**,**/venv/**,**/__pycache__/**,**/htmlcov/**,**/.pytest_cache/**,**/sonar-scanner/**

# Test configuration
sonar.tests=inventory-service/tests
sonar.test.inclusions=**/test_*.py
sonar.python.coverage.reportPaths=inventory-service/coverage.xml
sonar.python.xunit.reportPath=inventory-service/test-results.xml

# Security analysis
sonar.python.bandit.reportPaths=inventory-service/bandit-report.json

# Language settings
sonar.sourceEncoding=UTF-8
sonar.python.version=3.11

# Quality gate
sonar.qualitygate.wait=true
"@

$sonarProperties | Out-File -FilePath "sonar-project.properties" -Encoding UTF8

if (Test-Path "$scannerPath\bin\sonar-scanner.bat") {
    Write-Host "🚀 Executing SonarQube analysis..." -ForegroundColor Cyan
    
    try {
        & "$scannerPath\bin\sonar-scanner.bat" 2>&1 | Tee-Object -FilePath "sonar-analysis.log"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✅ SonarQube Analysis Completed Successfully!" -ForegroundColor Green
        } else {
            Write-Host "`n⚠️ SonarQube Analysis completed with warnings" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "`n❌ SonarQube Analysis failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`n📋 Manual SonarQube Analysis Command:" -ForegroundColor Yellow
    Write-Host "sonar-scanner.bat" -ForegroundColor White
    Write-Host "Or upload the generated reports manually to SonarQube dashboard" -ForegroundColor White
}

# Step 4: Generate Summary Report
Write-Host "`n📈 Analysis Summary:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

# Parse coverage information
if (Test-Path "inventory-service/coverage.xml") {
    $coverage = [xml](Get-Content "inventory-service/coverage.xml")
    $lineRate = [math]::Round([decimal]$coverage.coverage.'line-rate' * 100, 2)
    Write-Host "📊 Code Coverage: $lineRate%" -ForegroundColor $(if($lineRate -ge 90){"Green"}elseif($lineRate -ge 80){"Yellow"}else{"Red"})
}

# Check security reports
if (Test-Path "inventory-service/bandit-report.json") {
    $banditReport = Get-Content "inventory-service/bandit-report.json" | ConvertFrom-Json
    $totalIssues = $banditReport.metrics._totals.'SEVERITY.HIGH' + $banditReport.metrics._totals.'SEVERITY.MEDIUM' + $banditReport.metrics._totals.'SEVERITY.LOW'
    Write-Host "🔐 Security Issues Found: $totalIssues" -ForegroundColor $(if($totalIssues -eq 0){"Green"}elseif($totalIssues -le 2){"Yellow"}else{"Red"})
}

# Test results
if (Test-Path "inventory-service/test-results.xml") {
    Write-Host "🧪 Unit Tests: Available in test-results.xml" -ForegroundColor Green
}

Write-Host "`n🌐 Access Your Analysis:" -ForegroundColor Cyan
Write-Host "SonarQube Dashboard: $SonarHost/dashboard?id=$ProjectKey" -ForegroundColor White
Write-Host "Project Key: $ProjectKey" -ForegroundColor White
Write-Host "Authentication: Token-based (configured)" -ForegroundColor Green

Write-Host "`n📁 Generated Reports:" -ForegroundColor Yellow
Write-Host "• Security: inventory-service/bandit-report.json" -ForegroundColor White
Write-Host "• Dependencies: inventory-service/safety-report.json" -ForegroundColor White
Write-Host "• Coverage: inventory-service/coverage.xml" -ForegroundColor White
Write-Host "• Test Results: inventory-service/test-results.xml" -ForegroundColor White
Write-Host "• SonarQube Config: sonar-project.properties" -ForegroundColor White

Write-Host "`n✨ Analysis Complete! Check SonarQube dashboard for detailed results." -ForegroundColor Green
