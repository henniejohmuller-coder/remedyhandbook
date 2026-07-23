Write-Host "Building web app..." -ForegroundColor Yellow
flutter build web --release

# Fix main.dart imports if stripped
$content = Get-Content "lib\main.dart" -Raw
if ($content -notmatch "import 'config.dart'") {
    $imports = "import 'config.dart';`nimport 'theme/app_theme.dart';`nimport 'services/supabase_service.dart';`nimport 'widgets/shared_widgets.dart';`nimport 'widgets/navigation_guard.dart';`nimport 'screens/login_screen.dart';`nimport 'screens/home_screen.dart';`nimport 'screens/recipes_screen.dart';`nimport 'screens/shop_screen.dart';`nimport 'screens/cart_screen.dart';`nimport 'screens/checkout_screen.dart';`nimport 'screens/order_confirmation_screen.dart';`nimport 'screens/submit_remedy_screen.dart';`nimport 'screens/my_recipes_screen.dart';`nimport 'screens/profile_screen.dart';`n"
    $content = $content -replace "import 'package:supabase_flutter/supabase_flutter.dart';", "import 'package:supabase_flutter/supabase_flutter.dart';`n$imports"
    Set-Content "lib\main.dart" $content
    flutter build web --release
}

# Add version timestamp to flutter_bootstrap.js to bust cache on every deploy
$ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$bootstrap = Get-Content "build\web\flutter_bootstrap.js" -Raw
$bootstrap = "/* v$ts */`n" + $bootstrap
Set-Content "build\web\flutter_bootstrap.js" $bootstrap

# Update index.html to load versioned bootstrap
$index = Get-Content "build\web\index.html" -Raw
$index = $index -replace 'src="flutter_bootstrap\.js"', "src=`"flutter_bootstrap.js?v=$ts`""
Set-Content "build\web\index.html" $index

Write-Host "Deploying to Firebase..." -ForegroundColor Yellow
firebase deploy
Write-Host "Done! Version: $ts" -ForegroundColor Green
