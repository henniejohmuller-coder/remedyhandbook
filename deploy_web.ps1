# Remedy Handbook — Web Deploy Script
Write-Host "Building web app..." -ForegroundColor Yellow
flutter build web --release

Write-Host "Deploying to Firebase..." -ForegroundColor Yellow
firebase deploy

Write-Host "Done!" -ForegroundColor Green
