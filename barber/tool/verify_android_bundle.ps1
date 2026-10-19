param(
    [Parameter(Mandatory = $true)][string]$BundlePath,
    [Parameter(Mandatory = $true)][string]$BundletoolPath,
    [string]$JavaPath = 'java',
    [switch]$AllowUnsigned
)

$ErrorActionPreference = 'Stop'
$bundleFile = (Resolve-Path -LiteralPath $BundlePath).Path
$bundletoolFile = (Resolve-Path -LiteralPath $BundletoolPath).Path
$javaCommand = Get-Command $JavaPath -CommandType Application

function Invoke-Bundletool {
    param([string[]]$Commands)
    $output = & $javaCommand.Source -jar $bundletoolFile @Commands
    if ($LASTEXITCODE -ne 0) { throw "Bundletool failed: $($Commands[0])" }
    return ($output -join "`n")
}

# Read the source version instead of silently accepting stale release artifacts.
$versionLine = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../pubspec.yaml') |
    Where-Object { $_ -match '^version:\s*(\S+)\+(\d+)\s*$' }
if ($versionLine -notmatch '^version:\s*(\S+)\+(\d+)\s*$') { throw 'Missing source version' }
$expectedName = $Matches[1]
$expectedCode = $Matches[2]
$null = Invoke-Bundletool -Commands @('validate', "--bundle=$bundleFile")
[xml]$manifest = Invoke-Bundletool -Commands @('dump', 'manifest', "--bundle=$bundleFile", '--module=base')
$androidNs = 'http://schemas.android.com/apk/res/android'
$package = $manifest.manifest.GetAttribute('package')
$versionName = $manifest.manifest.GetAttribute('versionName', $androidNs)
$versionCode = $manifest.manifest.GetAttribute('versionCode', $androidNs)
$targetSdk = [int]$manifest.manifest.'uses-sdk'.GetAttribute('targetSdkVersion', $androidNs)
if ($package -ne 'fr.barberclubgrenoble.app') { throw "Unexpected package: $package" }
if ($versionName -ne $expectedName -or $versionCode -ne $expectedCode) {
    throw "Bundle version $versionName+$versionCode does not match $expectedName+$expectedCode"
}
if ($targetSdk -lt 36) { throw "Target SDK $targetSdk is below the checked Play requirement" }
if ($manifest.manifest.application.GetAttribute('debuggable', $androidNs) -eq 'true') {
    throw 'This is a debuggable build, not a release bundle'
}
$config = Invoke-Bundletool -Commands @('dump', 'config', "--bundle=$bundleFile")
if ($config -notmatch 'PAGE_ALIGNMENT_16K') { throw 'Bundle does not request 16 KB ZIP alignment' }

function Get-ElfLoadAlignment {
    param($Entry)
    $inputStream = $Entry.Open()
    $buffer = New-Object System.IO.MemoryStream
    try {
        $inputStream.CopyTo($buffer)
        $bytes = $buffer.ToArray()
    } finally {
        $inputStream.Dispose()
        $buffer.Dispose()
    }
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x7f -or
        $bytes[1] -ne 0x45 -or $bytes[2] -ne 0x4c -or $bytes[3] -ne 0x46 -or
        $bytes[5] -ne 1) { throw "Not a little-endian ELF library: $($Entry.FullName)" }
    $is64 = $bytes[4] -eq 2
    if ($is64) {
        $headersOffset = [BitConverter]::ToUInt64($bytes, 32)
        $headerSize = [BitConverter]::ToUInt16($bytes, 54)
        $headerCount = [BitConverter]::ToUInt16($bytes, 56)
    } elseif ($bytes[4] -eq 1) {
        $headersOffset = [BitConverter]::ToUInt32($bytes, 28)
        $headerSize = [BitConverter]::ToUInt16($bytes, 42)
        $headerCount = [BitConverter]::ToUInt16($bytes, 44)
    } else { throw "Unsupported ELF class: $($Entry.FullName)" }
    if ($headersOffset + $headerSize * $headerCount -gt $bytes.Length) {
        throw "Invalid ELF header range: $($Entry.FullName)"
    }
    [uint64]$minimum = [uint64]::MaxValue
    for ($index = 0; $index -lt $headerCount; $index++) {
        $offset = [int]($headersOffset + $index * $headerSize)
        if ([BitConverter]::ToUInt32($bytes, $offset) -ne 1) { continue }
        $alignment = if ($is64) { [BitConverter]::ToUInt64($bytes, $offset + 48) }
            else { [BitConverter]::ToUInt32($bytes, $offset + 28) }
        if ($alignment -lt $minimum) { $minimum = $alignment }
    }
    if ($minimum -eq [uint64]::MaxValue) { throw "No ELF LOAD segments: $($Entry.FullName)" }
    return $minimum
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($bundleFile)
try {
    $nativeLibraries = @($archive.Entries | Where-Object { $_.FullName -match '^base/lib/[^/]+/[^/]+\.so$' })
    $abis = @($nativeLibraries | ForEach-Object { $_.FullName.Split('/')[2] } | Sort-Object -Unique)
    foreach ($requiredAbi in @('armeabi-v7a', 'arm64-v8a', 'x86_64')) {
        if ($requiredAbi -notin $abis) { throw "Expected ABI missing: $requiredAbi" }
    }
    foreach ($entry in $nativeLibraries) {
        $alignment = Get-ElfLoadAlignment -Entry $entry
        if ($entry.FullName -match '/(arm64-v8a|x86_64)/' -and $alignment -lt 16384) {
            throw "64-bit native library is not 16 KB aligned: $($entry.FullName) ($alignment)"
        }
    }
    $signed = @($archive.Entries | Where-Object { $_.FullName -match '^META-INF/[^/]+\.(RSA|DSA|EC)$' }).Count -gt 0
} finally { $archive.Dispose() }
if (-not $signed -and -not $AllowUnsigned) { throw 'Bundle is UNSIGNED and cannot be uploaded to Play' }
if ($signed) {
    $javaBin = Split-Path -Parent $javaCommand.Source
    $signatureOutput = & (Join-Path $javaBin 'jarsigner.exe') -verify $bundleFile
    if ($LASTEXITCODE -ne 0) { throw 'JAR signature verification failed' }
    $certificateOutput = & (Join-Path $javaBin 'keytool.exe') -printcert -jarfile $bundleFile
    if ($LASTEXITCODE -ne 0 -or ($certificateOutput -join "`n") -match 'CN=Android Debug') {
        throw 'Invalid or Android-debug signing certificate'
    }
}
Write-Output "Package: $package"
Write-Output "Version: $versionName ($versionCode); target SDK: $targetSdk; debuggable: false"
Write-Output "ABIs: $($abis -join ', '); native libraries: $($nativeLibraries.Count)"
Write-Output '16 KB ZIP alignment and all 64-bit ELF LOAD alignments: PASS'
Write-Output "Signature present: $signed"
if (-not $signed) { Write-Warning 'UNSIGNED HANDOFF ONLY - do not upload this file to Play.' }
Write-Output "SHA256: $((Get-FileHash -LiteralPath $bundleFile -Algorithm SHA256).Hash)"
