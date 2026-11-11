# SkirlField app — one-time project setup on Windows (PowerShell).
# Run from this folder:   powershell -ExecutionPolicy Bypass -File .\setup.ps1
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "1/4  Checking Flutter..." -ForegroundColor Cyan
flutter --version
if ($LASTEXITCODE -ne 0) { throw "Flutter is not on PATH. Follow INSTALL.md step 2 first." }

if (-not (Test-Path "android")) {
  Write-Host "2/4  Creating Android and iOS project files..." -ForegroundColor Cyan
  # existing lib/, pubspec.yaml and test/ are kept; only the missing platform folders are generated
  flutter create --org in.softskirl --project-name skirlfield_app --platforms android,ios .
  if ($LASTEXITCODE -ne 0) { throw "flutter create failed" }
} else {
  Write-Host "2/4  android/ already exists, skipping flutter create" -ForegroundColor Yellow
}

Write-Host "3/4  Adding GPS permissions to AndroidManifest.xml..." -ForegroundColor Cyan
$m = Join-Path $PSScriptRoot "android\app\src\main\AndroidManifest.xml"
$x = [IO.File]::ReadAllText($m)
if ($x -notmatch "ACCESS_FINE_LOCATION") {
  $perms = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "platform\android-permissions.xml"))
  $x = [regex]::Replace($x, "(<manifest[^>]*>)", "`$1`r`n$perms")
}
if ($x -notmatch "android.intent.action.DIAL") {
  $q = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "platform\android-queries.xml"))
  $x = $x.Replace("</manifest>", "$q`r`n</manifest>")
}
$x = [regex]::Replace($x, 'android:label="[^"]*"', 'android:label="SkirlField"')
[IO.File]::WriteAllText($m, $x)

Write-Host "4/4  Downloading packages..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

Write-Host ""
Write-Host "Done. Connect your phone (USB debugging on) and run:" -ForegroundColor Green
Write-Host "   flutter run --release"
Write-Host "Build an APK to share:"
Write-Host "   flutter build apk --release"
