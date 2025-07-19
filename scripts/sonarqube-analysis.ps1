# TechNova SonarQube Security and Quality Analysis Script (PowerShell)
# Usage: .\sonarqube-analysis.ps1

param(
    [string]$SonarHost = "http://localhost:9000",
    [string]$ProjectKey = "technova-inventory-app"
)

Write-Host "🔍 Starting TechNova SonarQube Security and Quality Analysis..." -ForegroundColor Blue
Write-Host "==================================================" -ForegroundColor Blue

# Step 1: Navigate to project directory
Set-Location "inventory-service"

Write-Host "`n📦 Step 1: Installing Python Dependencies" -ForegroundColor Yellow
try {
    pip install bandit safety coverage pytest pytest-cov pytest-html
    Write-Host "✅ Dependencies installed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install dependencies: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🔐 Step 2: Running Security Analysis with Bandit" -ForegroundColor Yellow
try {
    bandit -r . -f json -o bandit-report-current.json
    bandit -r . -f txt -o bandit-report-current.txt
    Write-Host "✅ Bandit security analysis completed" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Bandit analysis completed with issues" -ForegroundColor Yellow
}

Write-Host "`n🛡️ Step 3: Running Safety Check for Dependencies" -ForegroundColor Yellow
try {
    safety check --json --output safety-report-current.json
    safety check --output safety-report-current.txt
    Write-Host "✅ Safety check completed" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Safety check completed with issues" -ForegroundColor Yellow
}

Write-Host "`n🧪 Step 4: Running Unit Tests with Coverage" -ForegroundColor Yellow
try {
    python -m pytest tests/ --cov=. --cov-report=xml --cov-report=html --junitxml=test-results.xml -v
    Write-Host "✅ Tests and coverage analysis completed" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Tests completed with issues" -ForegroundColor Yellow
}

# Step 5: Generate comprehensive report
Write-Host "`n📊 Step 5: Generating Analysis Summary" -ForegroundColor Yellow

# Check if reports exist and summarize
$banditReport = "bandit-report-current.txt"
$safetyReport = "safety-report-current.txt"
$coverageXml = "coverage.xml"

Write-Host "`n=== SECURITY ANALYSIS SUMMARY ===" -ForegroundColor Cyan

if (Test-Path $banditReport) {
    $banditContent = Get-Content $banditReport -Raw
    Write-Host "🔐 Bandit Security Report Generated" -ForegroundColor Green
    
    # Count issues
    $highSeverity = ([regex]::Matches($banditContent, "High")).Count
    $mediumSeverity = ([regex]::Matches($banditContent, "Medium")).Count
    $lowSeverity = ([regex]::Matches($banditContent, "Low")).Count
    
    Write-Host "   High Severity Issues: $highSeverity" -ForegroundColor $(if($highSeverity -gt 0){"Red"}else{"Green"})
    Write-Host "   Medium Severity Issues: $mediumSeverity" -ForegroundColor $(if($mediumSeverity -gt 0){"Yellow"}else{"Green"})
    Write-Host "   Low Severity Issues: $lowSeverity" -ForegroundColor $(if($lowSeverity -gt 0){"Yellow"}else{"Green"})
}

if (Test-Path $safetyReport) {
    Write-Host "🛡️ Safety Dependency Report Generated" -ForegroundColor Green
    $safetyContent = Get-Content $safetyReport -Raw
    if ($safetyContent -match "No known security vulnerabilities found") {
        Write-Host "   ✅ No vulnerable dependencies found" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ Vulnerable dependencies detected" -ForegroundColor Yellow
    }
}

if (Test-Path $coverageXml) {
    Write-Host "📈 Code Coverage Report Generated" -ForegroundColor Green
    $coverage = [xml](Get-Content $coverageXml)
    $lineRate = [math]::Round([decimal]$coverage.coverage.'line-rate' * 100, 2)
    Write-Host "   Code Coverage: $lineRate%" -ForegroundColor $(if($lineRate -ge 80){"Green"}elseif($lineRate -ge 60){"Yellow"}else{"Red"})
}

# Go back to root directory
Set-Location ".."

Write-Host "`n🎯 Step 6: Manual SonarQube Analysis Instructions" -ForegroundColor Yellow
Write-Host "Since SonarQube Scanner requires Java and specific setup, here are the manual steps:" -ForegroundColor White
Write-Host "1. Access SonarQube at: $SonarHost" -ForegroundColor White
Write-Host "2. Login with: admin/admin" -ForegroundColor White
Write-Host "3. Create project with key: $ProjectKey" -ForegroundColor White
Write-Host "4. Use the generated reports in inventory-service/ folder" -ForegroundColor White

Write-Host "`n✅ Analysis Completed! Check the following files:" -ForegroundColor Green
Write-Host "📄 Security Report: inventory-service/$banditReport" -ForegroundColor White
Write-Host "📄 Safety Report: inventory-service/$safetyReport" -ForegroundColor White
Write-Host "📄 Coverage HTML: inventory-service/htmlcov/index.html" -ForegroundColor White
Write-Host "📄 Coverage XML: inventory-service/coverage.xml" -ForegroundColor White

Write-Host "`n🌐 Access URLs:" -ForegroundColor Cyan
Write-Host "SonarQube Dashboard: $SonarHost" -ForegroundColor White
Write-Host "Coverage Report: file://$(Get-Location)/inventory-service/htmlcov/index.html" -ForegroundColor White
