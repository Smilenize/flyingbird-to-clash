param(
    [string]$OutputDirectory = "$HOME\Desktop\FlyingBird-Export",
    [string]$SyncDirectory = "",
    [switch]$OpenOutputFolder
)

$ErrorActionPreference = "Stop"

# FlyingBird 3.0.3 AES-128-CBC parameters
$keyText = "14f521a32997b257"
$ivText  = "d217125f4b9cc9c8"

function Convert-Base64FlexibleToBytes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $value = $Text -replace "\s+", ""
    $value = $value.Replace("-", "+")
    $value = $value.Replace("_", "/")

    switch ($value.Length % 4) {
        0 { }
        2 { $value += "==" }
        3 { $value += "=" }
        default { throw "Invalid Base64 length" }
    }

    [byte[]]$bytes = [Convert]::FromBase64String($value)
    return ,$bytes
}

function Test-MihomoYaml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    return (
        $Text -match
        "(?im)^\s*(proxies|proxy-groups|proxy-providers|rules|mixed-port|port|socks-port|redir-port|tproxy-port|mode|dns)\s*:"
    )
}

function Test-ShareLinks {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    return (
        $Text -match
        "(?im)^(ss|ssr|vmess|vless|trojan|hysteria|hysteria2|hy2|tuic|socks5?|http|https|anytls|mieru|wireguard)://"
    )
}

function Get-OutputType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    if (Test-MihomoYaml -Text $Text) {
        return "mihomo-yaml"
    }

    if (Test-ShareLinks -Text $Text) {
        return "share-links"
    }

    return "unknown"
}

function Get-ConfigScore {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $score = 0

    if ($Text -match "(?im)^\s*proxies\s*:") { $score += 100 }
    if ($Text -match "(?im)^\s*proxy-groups\s*:") { $score += 80 }
    if ($Text -match "(?im)^\s*rules\s*:") { $score += 60 }
    if ($Text -match "(?im)^\s*dns\s*:") { $score += 20 }
    if ($Text -match "(?im)^\s*mixed-port\s*:") { $score += 10 }

    $score += [Math]::Min([int]($Text.Length / 1000), 50)
    return $score
}

function Invoke-FlyingBirdDecrypt {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputText
    )

    $raw = $InputText.Trim()

    if (Test-MihomoYaml -Text $raw) {
        return @{
            Text = $raw
            Method = "already-plain-yaml"
            InnerBase64 = $false
        }
    }

    if (Test-ShareLinks -Text $raw) {
        return @{
            Text = $raw
            Method = "already-share-links"
            InnerBase64 = $false
        }
    }

    [byte[]]$cipherBytes = Convert-Base64FlexibleToBytes -Text $raw

    if (
        $cipherBytes.Length -eq 0 -or
        ($cipherBytes.Length % 16) -ne 0
    ) {
        throw "Ciphertext byte length $($cipherBytes.Length) is not a positive multiple of 16"
    }

    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.Key = [Text.Encoding]::ASCII.GetBytes($keyText)
    $aes.IV = [Text.Encoding]::ASCII.GetBytes($ivText)

    $decryptor = $null

    try {
        $decryptor = $aes.CreateDecryptor()

        [byte[]]$plainBytes = $decryptor.TransformFinalBlock(
            $cipherBytes,
            0,
            $cipherBytes.Length
        )
    }
    finally {
        if ($null -ne $decryptor) {
            $decryptor.Dispose()
        }

        $aes.Dispose()
    }

    $plainText = [Text.Encoding]::UTF8.GetString($plainBytes).Trim()
    $resultText = $plainText
    $innerBase64 = $false

    # FlyingBird often stores one extra Base64 layer after AES.
    try {
        [byte[]]$innerBytes = Convert-Base64FlexibleToBytes -Text $plainText
        $innerText = [Text.Encoding]::UTF8.GetString($innerBytes).Trim()

        if (
            (Test-MihomoYaml -Text $innerText) -or
            (Test-ShareLinks -Text $innerText)
        ) {
            $resultText = $innerText
            $innerBase64 = $true
        }
    }
    catch {
        # The decrypted text is not another Base64 layer.
    }

    return @{
        Text = $resultText
        Method = "aes-128-cbc"
        InnerBase64 = $innerBase64
    }
}

function Get-SafeRelativeName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FullName
    )

    $name = $FullName
    $name = $name -replace "^[A-Za-z]:\\", ""
    $name = $name -replace "[\\/:*?`"<>|]", "_"
    return $name
}

Write-Host ""
Write-Host "FlyingBird portable profile exporter" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

$sourceRoots = @(
    "$env:APPDATA\FlyingBird",
    "$env:LOCALAPPDATA\FlyingBird"
) | Where-Object {
    Test-Path -LiteralPath $_ -PathType Container
}

if ($sourceRoots.Count -eq 0) {
    throw "FlyingBird data directory was not found under AppData."
}

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$outputDirectoryFull = [IO.Path]::GetFullPath($OutputDirectory)
$backupDirectory = Join-Path $outputDirectoryFull "encrypted-backup"
$decryptedDirectory = Join-Path $outputDirectoryFull "decrypted"

New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $decryptedDirectory -Force | Out-Null

Write-Host "[1/4] Searching FlyingBird YAML files..." -ForegroundColor Yellow

$candidates = @()

foreach ($root in $sourceRoots) {
    $found = Get-ChildItem `
        -LiteralPath $root `
        -Recurse `
        -Force `
        -File `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in @(".yaml", ".yml") -and
            $_.Length -gt 0 -and
            $_.Length -lt 20MB
        }

    $candidates += $found
}

$candidates = $candidates |
    Sort-Object FullName -Unique

if ($candidates.Count -eq 0) {
    throw "No YAML files were found in the FlyingBird data directories."
}

Write-Host "      Found $($candidates.Count) candidate file(s)."

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$manifest = @()
$successful = @()

Write-Host "[2/4] Backing up and decrypting..." -ForegroundColor Yellow

foreach ($file in $candidates) {
    $safeName = Get-SafeRelativeName -FullName $file.FullName
    $backupPath = Join-Path $backupDirectory $safeName

    Copy-Item `
        -LiteralPath $file.FullName `
        -Destination $backupPath `
        -Force

    $entry = [ordered]@{
        source = $file.FullName
        backup = $backupPath
        output = $null
        status = "failed"
        method = $null
        type = $null
        inner_base64 = $false
        score = 0
        error = $null
    }

    try {
        $raw = [IO.File]::ReadAllText($file.FullName)
        $result = Invoke-FlyingBirdDecrypt -InputText $raw
        $text = [string]$result.Text
        $type = Get-OutputType -Text $text

        $outputExtension = ".txt"
        if ($type -eq "mihomo-yaml") {
            $outputExtension = ".yaml"
        }

        $outputName = [IO.Path]::GetFileNameWithoutExtension($safeName) +
            "-decrypted" + $outputExtension
        $outputPath = Join-Path $decryptedDirectory $outputName

        [IO.File]::WriteAllText(
            $outputPath,
            $text,
            $utf8NoBom
        )

        $score = 0
        if ($type -eq "mihomo-yaml") {
            $score = Get-ConfigScore -Text $text
        }

        $entry.output = $outputPath
        $entry.status = "success"
        $entry.method = $result.Method
        $entry.type = $type
        $entry.inner_base64 = [bool]$result.InnerBase64
        $entry.score = $score

        $successful += [pscustomobject]@{
            Path = $outputPath
            Type = $type
            Score = $score
            Source = $file.FullName
        }

        Write-Host "      OK: $($file.FullName)" -ForegroundColor Green
        Write-Host "          type=$type method=$($result.Method) output=$outputPath"
    }
    catch {
        $entry.error = $_.Exception.Message
        Write-Warning "Failed: $($file.FullName)"
        Write-Warning "Reason: $($_.Exception.Message)"
    }

    $manifest += [pscustomobject]$entry
}

Write-Host "[3/4] Selecting the best Clash profile..." -ForegroundColor Yellow

$best = $successful |
    Where-Object { $_.Type -eq "mihomo-yaml" } |
    Sort-Object Score -Descending |
    Select-Object -First 1

$currentProfile = $null

if ($null -ne $best) {
    $currentProfile = Join-Path $outputDirectoryFull "flyingbird-current.yaml"

    Copy-Item `
        -LiteralPath $best.Path `
        -Destination $currentProfile `
        -Force

    Write-Host "      Selected: $($best.Source)" -ForegroundColor Green
    Write-Host "      Exported: $currentProfile" -ForegroundColor Green
}
else {
    Write-Warning "No decrypted mihomo YAML profile was found."
}

$manifestPath = Join-Path $outputDirectoryFull "manifest.json"
$manifest |
    ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "[4/4] Optional cloud-sync copy..." -ForegroundColor Yellow

if (
    $SyncDirectory -and
    $null -ne $currentProfile
) {
    if (-not (Test-Path -LiteralPath $SyncDirectory)) {
        New-Item `
            -ItemType Directory `
            -Path $SyncDirectory `
            -Force |
            Out-Null
    }

    $syncFull = [IO.Path]::GetFullPath($SyncDirectory)
    $syncProfile = Join-Path $syncFull "flyingbird-current.yaml"

    Copy-Item `
        -LiteralPath $currentProfile `
        -Destination $syncProfile `
        -Force

    Write-Host "      Copied to sync folder: $syncProfile" -ForegroundColor Green
}
else {
    Write-Host "      Skipped. Use -SyncDirectory to copy the profile to OneDrive or another sync folder."
}

Write-Host ""
Write-Host "Finished" -ForegroundColor Cyan
Write-Host "Output directory : $outputDirectoryFull"
Write-Host "Manifest         : $manifestPath"

if ($null -ne $currentProfile) {
    Write-Host "Clash profile    : $currentProfile" -ForegroundColor Green
    Write-Host ""
    Write-Host "Import flyingbird-current.yaml into Clash Verge as a local profile."
}

Write-Host ""
Write-Warning "The exported YAML contains node addresses, passwords, UUIDs, and other credentials. Treat it like a password file."

if ($OpenOutputFolder) {
    Start-Process explorer.exe $outputDirectoryFull
}
