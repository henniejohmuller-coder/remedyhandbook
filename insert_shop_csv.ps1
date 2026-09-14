# Read files
$lines = Get-Content "lib\screens\admin_csv_upload_screen.dart"

# Add state variables after _dbDownloading line
$dbIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "bool _dbDownloading") { $dbIdx = $i; break }
}
Write-Host "_dbDownloading at line $($dbIdx+1)"

# Find _downloadDatabase end
$startIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "Future.*_downloadDatabase") { $startIdx = $i; break }
}
$endIdx = -1
$depth = 0
for ($i = $startIdx; $i -lt $lines.Count; $i++) {
    $depth += ($lines[$i].ToCharArray() | Where-Object {$_ -eq '{'}).Count
    $depth -= ($lines[$i].ToCharArray() | Where-Object {$_ -eq '}'}).Count
    if ($depth -le 0 -and $i -gt $startIdx) { $endIdx = $i; break }
}
Write-Host "_downloadDatabase ends at line $($endIdx+1)"

# Add state variables
$lines2 = $lines[0..$dbIdx] + "  bool _shopExporting = false;" + "  bool _shopImporting = false;" + $lines[($dbIdx+1)..($lines.Count-1)]

# Find new end index (offset by 2)
$newEndIdx = $endIdx + 2

# Insert methods after _downloadDatabase
$methods = Get-Content "shop_csv_methods.txt"
$final = $lines2[0..$newEndIdx] + $methods + $lines2[($newEndIdx+1)..($lines2.Count-1)]
$final | Set-Content "lib\screens\admin_csv_upload_screen.dart"
Write-Host "Done. Lines: $($final.Count)"
