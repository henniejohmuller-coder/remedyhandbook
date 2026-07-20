# Remedy Handbook — Web Deploy Script
# Run this instead of 'firebase deploy' for all web updates

Write-Host "Building web app..." -ForegroundColor Yellow
flutter build web --release

Write-Host "Disabling service worker..." -ForegroundColor Yellow
# Disable Flutter's service worker so browser always fetches fresh files
$bootstrap = Get-Content "build\web\flutter_bootstrap.js" -Raw
$bootstrap = $bootstrap -replace '"serviceWorker"', '"serviceWorkerDisabled"'
$bootstrap = $bootstrap -replace "'serviceWorker'", "'serviceWorkerDisabled'"
Set-Content "build\web\flutter_bootstrap.js" $bootstrap

# Add no-cache headers to index.html
$index = Get-Content "build\web\index.html" -Raw
if ($index -notmatch "no-store") {
    $index = $index -replace "<head>", "<head>`n  <meta http-equiv=""Cache-Control"" content=""no-cache, no-store, must-revalidate"">`n  <meta http-equiv=""Pragma"" content=""no-cache"">`n  <meta http-equiv=""Expires"" content=""0"">"
    Set-Content "build\web\index.html" $index
}

Write-Host "Deploying to Firebase..." -ForegroundColor Yellow
firebase deploy

Write-Host "Done! Web app deployed with no-cache." -ForegroundColor Green
