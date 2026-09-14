
$lines = Get-Content "lib\screens\admin_csv_upload_screen.dart"

# Find key lines dynamically
$csvFormatLine = -1
$filePickerLine = -1
$filePickerEnd = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "const Text\('CSV Format'") { $csvFormatLine = $i }
    if ($lines[$i] -match "// .* File picker") { $filePickerLine = $i }
}

Write-Host "CSV Format at line $($csvFormatLine+1)"
Write-Host "File picker comment at line $($filePickerLine+1)"

# Find end of file picker (GestureDetector) by looking for 'remedies ready' text which is inside it
$remediesReadyLine = -1
for ($i = $filePickerLine; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "remedies ready") { $remediesReadyLine = $i; break }
}
# File picker ends a few lines after 'remedies ready'
$filePickerEnd = $remediesReadyLine + 4  # ]), ), ),
Write-Host "File picker ends around line $($filePickerEnd+1)"
Write-Host "Line $($filePickerEnd+1): $($lines[$filePickerEnd])"

# 1. Rename CSV Format
$lines[$csvFormatLine] = "                const Text('CSV Format - Remedies', style: AppTextStyles.heading3),"

# Find the closing ]), of the Wrap inside remedies block (just before file picker)
$wrapCloseBeforeFilePicker = $filePickerLine - 4
Write-Host "Wrap close at line $($wrapCloseBeforeFilePicker+1): $($lines[$wrapCloseBeforeFilePicker])"

# Extract file picker lines
$pickerLines = $lines[($filePickerLine+1)..($filePickerEnd)]

# Find original closing brackets of remedies container (after wrap close, before file picker)
$remediesClose1 = $filePickerLine - 3  # ]),
$remediesClose2 = $filePickerLine - 2  # ),
$remediesClose3 = $filePickerLine - 1  # const SizedBox

Write-Host "Remedies close lines: $($remediesClose1+1), $($remediesClose2+1), $($remediesClose3+1)"

$shopBlock = @(
"            const SizedBox(height: 16),",
"            Container(",
"              padding: const EdgeInsets.all(14),",
"              decoration: BoxDecoration(",
"                color: AppColors.lightYellow,",
"                borderRadius: BorderRadius.circular(12),",
"                border: Border.all(color: AppColors.primary),",
"              ),",
"              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [",
"                const Text('CSV Format - Shop Items', style: AppTextStyles.heading3),",
"                const SizedBox(height: 6),",
"                const Text(",
"                  'Each row = one shop item. id required for updates.\nColumns: id, name, type, description, price, cost_price, stock, delivery_cost, active, image_url',",
"                  style: AppTextStyles.caption,",
"                ),",
"                const SizedBox(height: 10),",
"                Wrap(spacing: 8, runSpacing: 8, children: [",
"                  _SmallButton(",
"                    icon: _shopExporting ? Icons.hourglass_top : Icons.download_outlined,",
"                    label: _shopExporting ? 'Exporting...' : 'Export Shop CSV',",
"                    onTap: _shopExporting ? () {} : _exportShopCsv,",
"                  ),",
"                  _SmallButton(",
"                    icon: _shopImporting ? Icons.hourglass_top : Icons.upload_outlined,",
"                    label: _shopImporting ? 'Importing...' : 'Import Shop CSV',",
"                    onTap: _shopImporting ? () {} : _importShopCsv,",
"                    bgColor: AppColors.lightGreen,",
"                  ),",
"                ]),",
"              ]),",
"            ),"
)

# Build: everything before wrap close + SizedBox + picker + remedies close + shop block + rest
$newLines = $lines[0..($wrapCloseBeforeFilePicker-1)] + @("                const SizedBox(height: 16),") + $pickerLines + $lines[$remediesClose1..$remediesClose2] + $shopBlock + $lines[($filePickerEnd+1)..($lines.Count-1)]
$newLines | Set-Content "lib\screens\admin_csv_upload_screen.dart"
Write-Host "Done. Lines: $($newLines.Count)"
