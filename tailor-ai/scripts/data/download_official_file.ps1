<#
.SYNOPSIS
Safely downloads or resumes one known official file using bounded HTTP ranges.

.DESCRIPTION
The caller must provide the expected object size and ETag observed from the official source.
Existing partial content is preserved. Each range is downloaded to a sidecar, length-checked,
then appended using binary streams. The script stops after the configured failure count.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][long]$ExpectedBytes,
    [Parameter(Mandatory = $true)][string]$ExpectedETag,
    [ValidateRange(1, 512)][int]$ChunkMiB = 64,
    [ValidateRange(1, 3)][int]$MaxFailures = 3,
    [ValidateRange(100, 10000)][long]$MinimumFreeGiB = 100,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$destinationPath = [IO.Path]::GetFullPath($Destination)
$destinationDirectory = [IO.Path]::GetDirectoryName($destinationPath)
$partialPath = "$destinationPath.range.part"
$chunkBytes = [long]$ChunkMiB * 1MB

if (-not (Test-Path -LiteralPath $destinationDirectory)) {
    if ($DryRun) {
        Write-Output "DRY-RUN create directory: $destinationDirectory"
    } else {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }
}

$head = (& curl.exe --fail --silent --show-error --location --head --max-redirs 5 `
    --connect-timeout 20 --max-time 60 $Url) -join "`n"
if ($LASTEXITCODE -ne 0) {
    throw "Official-object HEAD request failed with curl exit code $LASTEXITCODE"
}
$lengthMatch = [regex]::Match($head, '(?im)^content-length:\s*(\d+)\s*$')
$etagMatch = [regex]::Match($head, '(?im)^etag:\s*"?([^"\r\n]+)"?\s*$')
$rangeMatch = [regex]::Match($head, '(?im)^accept-ranges:\s*bytes\s*$')
if (-not $lengthMatch.Success -or [long]$lengthMatch.Groups[1].Value -ne $ExpectedBytes) {
    throw "Remote Content-Length does not match expected $ExpectedBytes"
}
if (-not $etagMatch.Success -or $etagMatch.Groups[1].Value.Trim() -ne $ExpectedETag.Trim('"')) {
    throw "Remote ETag does not match expected $ExpectedETag"
}
if (-not $rangeMatch.Success) {
    throw 'Official host does not advertise byte-range support'
}

$currentBytes = if (Test-Path -LiteralPath $destinationPath) {
    (Get-Item -LiteralPath $destinationPath).Length
} else {
    0L
}
if ($currentBytes -gt $ExpectedBytes) {
    throw "Existing destination is larger than expected: $currentBytes > $ExpectedBytes"
}

$drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($destinationPath))
if (($drive.AvailableFreeSpace - ($ExpectedBytes - $currentBytes)) -lt ($MinimumFreeGiB * 1GB)) {
    throw "Free-space guard would fall below $MinimumFreeGiB GiB"
}

Write-Output "URL=$Url"
Write-Output "Destination=$destinationPath"
Write-Output "ExpectedBytes=$ExpectedBytes"
Write-Output "ETag=$ExpectedETag"
Write-Output "StartingBytes=$currentBytes"
Write-Output "ChunkBytes=$chunkBytes"

if ($DryRun) {
    Write-Output "DRY-RUN remaining bytes: $($ExpectedBytes - $currentBytes)"
    exit 0
}

$failures = 0
$segments = 0
$timer = [Diagnostics.Stopwatch]::StartNew()
while ($currentBytes -lt $ExpectedBytes) {
    $end = [Math]::Min($ExpectedBytes - 1, $currentBytes + $chunkBytes - 1)
    $expectedChunk = $end - $currentBytes + 1
    & curl.exe --fail --silent --show-error --location --max-redirs 5 --connect-timeout 30 `
        --max-time 300 --range "$currentBytes-$end" --output $partialPath $Url
    if ($LASTEXITCODE -ne 0) {
        $failures++
        Write-Warning "Range $currentBytes-$end failed; failure $failures of $MaxFailures"
        if ($failures -ge $MaxFailures) {
            throw "Failure limit reached; partial destination and range sidecar preserved"
        }
        continue
    }
    $actualChunk = (Get-Item -LiteralPath $partialPath).Length
    if ($actualChunk -ne $expectedChunk) {
        throw "Range length mismatch for $currentBytes-${end}: $actualChunk != $expectedChunk"
    }
    $source = [IO.File]::OpenRead($partialPath)
    try {
        $target = [IO.File]::Open($destinationPath, [IO.FileMode]::Append, [IO.FileAccess]::Write)
        try {
            $source.CopyTo($target)
        } finally {
            $target.Dispose()
        }
    } finally {
        $source.Dispose()
    }
    Remove-Item -LiteralPath $partialPath
    $currentBytes = (Get-Item -LiteralPath $destinationPath).Length
    $segments++
    Write-Output "Appended range through byte $end ($currentBytes/$ExpectedBytes)"
}
$timer.Stop()
$hash = Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256
[pscustomobject]@{
    Result = 'complete'
    Bytes = $currentBytes
    SHA256 = $hash.Hash
    Segments = $segments
    Failures = $failures
    Seconds = [Math]::Round($timer.Elapsed.TotalSeconds, 3)
    Destination = $destinationPath
} | Format-List
