$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Analysis failed' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed' }
    Push-Location android
    try {
        ./gradlew.bat :app:testDebugUnitTest
        if ($LASTEXITCODE -ne 0) { throw 'Android backup regression tests failed' }
    } finally { Pop-Location }
    flutter build apk --release --split-per-abi
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed' }
} finally { Pop-Location }
