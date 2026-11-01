param(
    [Parameter(Mandatory = $true)][string]$SigningDirectory,
    [Parameter(Mandatory = $true)][string]$KeytoolPath,
    [string]$Alias = 'barberclub-upload-2026-10-19'
)

# Generates private signing artifacts locally. No secret is embedded in this
# script, printed, or passed in a process command line. Never rerun over a key.
$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$propertiesFile = Join-Path $projectDirectory 'android/key.properties'
$privateDirectory = [IO.Path]::GetFullPath($SigningDirectory)
$keytool = (Get-Command $KeytoolPath -CommandType Application).Source
if ($privateDirectory.Equals($projectDirectory, [StringComparison]::OrdinalIgnoreCase) -or
    $privateDirectory.StartsWith($projectDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Private signing artifacts must be stored outside the project repository.'
}
if (Test-Path -LiteralPath $privateDirectory) { throw 'Refusing to overwrite an existing signing directory.' }
& git -C $projectDirectory check-ignore --quiet -- android/key.properties
if ($LASTEXITCODE -ne 0) { throw 'android/key.properties must be ignored by Git before generating secrets.' }
if (Test-Path -LiteralPath $propertiesFile) {
    $oldConfig = Get-Content -LiteralPath $propertiesFile
    if (-not ($oldConfig -match '^\s*keyAlias\s*=\s*androiddebugkey\s*$')) {
        throw 'Existing non-debug signing configuration detected; refusing to replace it.'
    }
}

$currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
function Set-PrivateAccess {
    param([string]$Path, [switch]$Directory)
    $acl = if ($Directory) { [Security.AccessControl.DirectorySecurity]::new() }
        else { [Security.AccessControl.FileSecurity]::new() }
    $acl.SetOwner($currentSid)
    $acl.SetAccessRuleProtection($true, $false)
    $inheritance = if ($Directory) {
        [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
            [Security.AccessControl.InheritanceFlags]::ObjectInherit
    } else { [Security.AccessControl.InheritanceFlags]::None }
    foreach ($sid in @($currentSid, $systemSid)) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new(
            $sid, [Security.AccessControl.FileSystemRights]::FullControl,
            $inheritance, [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Allow)
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Invoke-Keytool {
    param([string[]]$KeytoolArguments)
    # keytool emits informational messages on stderr even on success.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $messages = & $keytool @KeytoolArguments 2>&1
        $keytoolExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($keytoolExit -ne 0) { throw "Keytool failed: $($messages -join ' ')" }
    $messages | ForEach-Object { Write-Output $_.ToString() }
}

New-Item -ItemType Directory -Path $privateDirectory | Out-Null
Set-PrivateAccess -Path $privateDirectory -Directory
if (Test-Path -LiteralPath $propertiesFile) {
    Copy-Item -LiteralPath $propertiesFile -Destination (Join-Path $privateDirectory 'previous-debug-key.properties')
}
$keystoreFile = Join-Path $privateDirectory 'barberclub-upload.jks'
$certificateFile = Join-Path $privateDirectory 'upload_certificate.pem'
$recoveryFile = Join-Path $privateDirectory 'recovery-key.properties'
$randomBytes = New-Object byte[] 32
$random = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $random.GetBytes($randomBytes) } finally { $random.Dispose() }
$password = [Convert]::ToBase64String($randomBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
[Array]::Clear($randomBytes, 0, $randomBytes.Length)
$configuration = @(
    '# PRIVATE: back up securely; never upload this file or the keystore.',
    "storeFile=$($keystoreFile.Replace('\', '/'))",
    "storePassword=$password", "keyAlias=$Alias", "keyPassword=$password"
) -join [Environment]::NewLine
# Persist recovery material inside the restricted folder before key generation.
[IO.File]::WriteAllText($recoveryFile, $configuration + [Environment]::NewLine, [Text.Encoding]::ASCII)
$oldStoreEnvironment = [Environment]::GetEnvironmentVariable('BARBERCLUB_NEW_STORE_PASSWORD', 'Process')
$oldKeyEnvironment = [Environment]::GetEnvironmentVariable('BARBERCLUB_NEW_KEY_PASSWORD', 'Process')
try {
    $env:BARBERCLUB_NEW_STORE_PASSWORD = $password
    $env:BARBERCLUB_NEW_KEY_PASSWORD = $password
    Invoke-Keytool -KeytoolArguments @(
        '-genkeypair', '-noprompt', '-keystore', $keystoreFile, '-storetype', 'JKS',
        '-alias', $Alias, '-keyalg', 'RSA', '-keysize', '4096', '-sigalg', 'SHA256withRSA',
        '-validity', '10000', '-dname', 'CN=BarberClub Upload 2026-10-19, O=BarberClub',
        '-storepass:env', 'BARBERCLUB_NEW_STORE_PASSWORD',
        '-keypass:env', 'BARBERCLUB_NEW_KEY_PASSWORD'
    )
    Invoke-Keytool -KeytoolArguments @(
        '-exportcert', '-rfc', '-keystore', $keystoreFile, '-alias', $Alias,
        '-file', $certificateFile, '-storepass:env', 'BARBERCLUB_NEW_STORE_PASSWORD'
    )
    Invoke-Keytool -KeytoolArguments @(
        '-list', '-keystore', $keystoreFile, '-alias', $Alias,
        '-storepass:env', 'BARBERCLUB_NEW_STORE_PASSWORD'
    )
    # Configure the existing Gradle release flow only after generation succeeds.
    Copy-Item -LiteralPath $recoveryFile -Destination $propertiesFile -Force
    Set-PrivateAccess -Path $propertiesFile
} finally {
    [Environment]::SetEnvironmentVariable('BARBERCLUB_NEW_STORE_PASSWORD', $oldStoreEnvironment, 'Process')
    [Environment]::SetEnvironmentVariable('BARBERCLUB_NEW_KEY_PASSWORD', $oldKeyEnvironment, 'Process')
    $password = $null
    $configuration = $null
}
Write-Output "Private signing folder: $privateDirectory"
Write-Output "Public certificate for Play reset: $certificateFile"
Write-Output "Alias: $Alias"
Write-Output 'Private folder and Gradle credentials restricted to this Windows user and SYSTEM.'
Write-Warning 'New upload key is NOT registered with Play yet. Submit only the public PEM in an upload-key reset request.'
