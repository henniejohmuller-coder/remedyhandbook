Write-Host "Building web app..." -ForegroundColor Yellow
flutter build web --release
$content = Get-Content "lib\main.dart" -Raw
if ($content -notmatch "import 'config.dart'") {
    flutter build web --release
}
$idx = Get-Content 'build\web\index.html' -Raw
if ($idx -notmatch 'install-bar') {
    $banner = "<style>#install-bar{position:fixed;top:0;left:0;right:0;height:44px;background:#2C1A00;color:#F5C518;padding:0 12px;display:flex;align-items:center;justify-content:space-between;font-family:sans-serif;font-size:12px;z-index:999999;}#install-bar.hidden{display:none;}flt-glass-pane{top:44px!important;height:calc(100% - 44px)!important;}flt-glass-pane.no-bar{top:0!important;height:100%!important;}</style><div id='install-bar'><span>Get the app for the best experience</span><div style='display:flex;align-items:center'><a href='https://remedy-handbook.web.app/download' target='_blank' style='background:#F5C518;color:#2C1A00;padding:6px 14px;border-radius:20px;font-weight:700;font-size:12px;text-decoration:none;margin-left:8px;'>Install App</a><button onclick='closeBanner()' style='background:none;border:none;color:#F5C518;font-size:20px;cursor:pointer;padding:0 8px;'>&#x2715;</button></div></div><script>var K='rhInstallDismiss';function hideBanner(){document.getElementById('install-bar').classList.add('hidden');document.querySelectorAll('flt-glass-pane').forEach(function(p){p.classList.add('no-bar');});}function closeBanner(){var m=new Date();m.setHours(24,0,0,0);localStorage.setItem(K,m.getTime());hideBanner();}var u=localStorage.getItem(K);if(u&&Date.now()<parseInt(u)){hideBanner();}if(window.matchMedia('(display-mode: standalone)').matches){hideBanner();}<\/script>"
    $idx = $idx -replace "<body>", "<body>`n$banner"
    Set-Content 'build\web\index.html' $idx
}
$ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$bootstrap = Get-Content "build\web\flutter_bootstrap.js" -Raw
$bootstrap = "/* v$ts */`n" + $bootstrap
Set-Content "build\web\flutter_bootstrap.js" $bootstrap
$index = Get-Content "build\web\index.html" -Raw
$index = $index -replace 'src="flutter_bootstrap\.js"', "src=`"flutter_bootstrap.js?v=$ts`""
Set-Content "build\web\index.html" $index
Write-Host "Deploying to Firebase..." -ForegroundColor Yellow
firebase deploy
Write-Host "Done! Version: $ts" -ForegroundColor Green
