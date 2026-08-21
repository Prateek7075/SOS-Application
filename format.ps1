Write-Host "Formatting Laravel..."
Set-Location backend
./vendor/bin/pint

Write-Host "Formatting Flutter..."
Set-Location ../mobile
dart format lib test

Set-Location ..

Write-Host "Formatting completed."