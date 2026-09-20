param(
    [Parameter(Mandatory = $true)]
    [string]$Archive,

    [string]$Layouts = "C:\BF6_Dev\BF6_Gamemode_Release_Assets\layouts-v1.2.0",

    [string]$GameDirectory = "C:\Program Files\EA Games\Battlefield 6",

    [string]$CaptureAudit = "$PSScriptRoot\gamemode_capture_audit.exe"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$templateMaps = [ordered]@{
    "MP_Abbasid_CustomConquest.tscn" = "mp_abbasid"
    "MP_Aftermath_Conquest.tscn" = "mp_aftermath"
    "MP_Aftermath_Portal_OperationMetro_Conquest.tscn" = "mp_aftermath_portal"
    "MP_Atoll_Conquest.tscn" = "mp_atoll"
    "MP_Badlands_Conquest.tscn" = "mp_badlands"
    "MP_Battery_CustomConquest.tscn" = "mp_battery"
    "MP_Capstone_Conquest.tscn" = "mp_capstone"
    "MP_Contaminated_Conquest.tscn" = "mp_contaminated"
    "MP_Dumbo_CustomConquest.tscn" = "mp_dumbo"
    "MP_Eastwood_Conquest.tscn" = "mp_eastwood"
    "MP_FireStorm_Conquest.tscn" = "mp_firestorm"
    "MP_GolmudRailway_Conquest.tscn" = "mp_golmudrailway"
    "MP_Isolated_Conquest.tscn" = "mp_isolated"
    "MP_Outskirts_Conquest.tscn" = "mp_outskirts"
    "MP_Plaza_Conquest.tscn" = "mp_plaza"
    "MP_Subsurface_Conquest.tscn" = "mp_subsurface"
    "MP_Tungsten-Conquest.tscn" = "mp_tungsten"
}

function Get-Translation([string]$line) {
    $match = [regex]::Match($line, 'transform\s*=\s*Transform3D\(([^)]*)\)')
    if (-not $match.Success) { return $null }
    $values = @($match.Groups[1].Value.Split(',') | ForEach-Object {
        [double]::Parse($_.Trim(), [Globalization.CultureInfo]::InvariantCulture)
    })
    if ($values.Count -ne 12) { return $null }
    return @($values[9], $values[10], $values[11])
}

function Read-SceneNodes([System.IO.Compression.ZipArchiveEntry]$entry) {
    $reader = [IO.StreamReader]::new($entry.Open())
    try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $nodes = @{}
    $current = $null
    foreach ($line in ($text -split "`r?`n")) {
        $header = [regex]::Match($line, '^\[node name="([^"]+)"(?: type="[^"]+")?(?: parent="([^"]+)")?.*\]$')
        if ($header.Success) {
            $name = $header.Groups[1].Value
            $parent = $header.Groups[2].Value
            $path = if (-not $parent) { "." } elseif ($parent -eq ".") { $name } else { "$parent/$name" }
            $current = [ordered]@{ Name = $name; Parent = $parent; Path = $path; Position = @(0.0, 0.0, 0.0); ObjId = $null; CaptureArea = $null; Area = $null }
            $nodes[$path] = $current
            continue
        }
        if ($null -eq $current) { continue }
        $translation = Get-Translation $line
        if ($null -ne $translation) { $current.Position = $translation; continue }
        $idMatch = [regex]::Match($line, '^ObjId\s*=\s*(-?\d+)')
        if ($idMatch.Success) { $current.ObjId = [int]$idMatch.Groups[1].Value }
        $areaMatch = [regex]::Match($line, '^CaptureArea\s*=\s*NodePath\("([^"]+)"\)')
        if ($areaMatch.Success) { $current.CaptureArea = $areaMatch.Groups[1].Value }
        $pointsMatch = [regex]::Match($line, '^points\s*=\s*PackedVector2Array\(([^)]*)\)')
        if ($pointsMatch.Success) {
            $values = @($pointsMatch.Groups[1].Value.Split(',') | ForEach-Object {
                [double]::Parse($_.Trim(), [Globalization.CultureInfo]::InvariantCulture)
            })
            $twiceArea = 0.0
            $pointCount = [int]($values.Count / 2)
            for ($i = 0; $i -lt $pointCount; ++$i) {
                $j = ($i + 1) % $pointCount
                $twiceArea += $values[$i * 2] * $values[$j * 2 + 1] - $values[$j * 2] * $values[$i * 2 + 1]
            }
            $current.Area = [Math]::Abs($twiceArea) / 2.0
        }
    }
    return $nodes
}

function Get-WorldPosition([hashtable]$nodes, [string]$path) {
    $result = @(0.0, 0.0, 0.0)
    $cursor = $path
    while ($cursor -and $cursor -ne ".") {
        if (-not $nodes.ContainsKey($cursor)) { break }
        $position = $nodes[$cursor].Position
        for ($axis = 0; $axis -lt 3; ++$axis) { $result[$axis] += $position[$axis] }
        $cursor = $nodes[$cursor].Parent
    }
    return $result
}

function Get-Distance($a, $b) {
    $dx = [double]$a[0] - [double]$b[0]
    $dz = [double]$a[2] - [double]$b[2]
    return [Math]::Sqrt($dx * $dx + $dz * $dz)
}

function Read-GameCapturePoints([string]$map) {
    $output = & $CaptureAudit $GameDirectory $map
    $result = [Collections.Generic.List[object]]::new()
    foreach ($line in $output) {
        $match = [regex]::Match($line, '^root=(\d+) instance=(\d+) guid=([^ ]+) at=\(([-0-9.]+) ([-0-9.]+) ([-0-9.]+)\)')
        if (-not $match.Success) { continue }
        $result.Add([pscustomobject]@{
            Root = [int]$match.Groups[1].Value
            Instance = [int]$match.Groups[2].Value
            Guid = $match.Groups[3].Value
            Position = @(
                [double]::Parse($match.Groups[4].Value, [Globalization.CultureInfo]::InvariantCulture),
                [double]::Parse($match.Groups[5].Value, [Globalization.CultureInfo]::InvariantCulture),
                [double]::Parse($match.Groups[6].Value, [Globalization.CultureInfo]::InvariantCulture)
            )
        })
    }
    return $result
}

$archivePath = (Resolve-Path -LiteralPath $Archive).Path
$layoutPath = (Resolve-Path -LiteralPath $Layouts).Path
$zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($pair in $templateMaps.GetEnumerator()) {
        $entry = $zip.Entries | Where-Object { $_.FullName -eq "Custom Conquest/$($pair.Key)" } | Select-Object -First 1
        $manifestFile = Join-Path $layoutPath "$($pair.Value)_conquest.layout.json"
        if ($null -eq $entry -or -not (Test-Path -LiteralPath $manifestFile)) { continue }
        $nodes = Read-SceneNodes $entry
        $manifest = Get-Content -Raw -LiteralPath $manifestFile | ConvertFrom-Json
        $captures = @($manifest.objects | Where-Object { [int]$_.role -eq 2 })
        $gamePoints = @(Read-GameCapturePoints $pair.Value)
        $used = @{}
        $usedRoots = @{}
        foreach ($node in ($nodes.Values | Where-Object { $_.Name -match '^CapturePoint([A-Z])$' } | Sort-Object Name)) {
            $letter = [regex]::Match($node.Name, '^CapturePoint([A-Z])$').Groups[1].Value
            if (-not $node.CaptureArea) { continue }
            $areaPath = "$($node.Path)/$($node.CaptureArea)"
            if (-not $nodes.ContainsKey($areaPath)) { continue }
            $position = Get-WorldPosition $nodes $areaPath
            $capturePointPosition = Get-WorldPosition $nodes $node.Path
            $nearestRoot = $null
            $nearestRootDistance = [double]::PositiveInfinity
            foreach ($gamePoint in $gamePoints) {
                if ($usedRoots.ContainsKey($gamePoint.Root)) { continue }
                $distance = Get-Distance $capturePointPosition $gamePoint.Position
                if ($distance -lt $nearestRootDistance) { $nearestRoot = $gamePoint; $nearestRootDistance = $distance }
            }
            if ($null -ne $nearestRoot) { $usedRoots[$nearestRoot.Root] = $true }
            $nearest = $null
            $nearestDistance = [double]::PositiveInfinity
            foreach ($capture in $captures) {
                $guid = [string]$capture.raw.instance_guid
                if ($used.ContainsKey($guid)) { continue }
                $distance = Get-Distance $position $capture.centre
                if ($distance -lt $nearestDistance) { $nearest = $capture; $nearestDistance = $distance }
            }
            if ($null -ne $nearest) { $used[[string]$nearest.raw.instance_guid] = $true }
            $gameLetter = if ($null -ne $nearest) { [string][char](65 + [int]$nearest.flag) } else { "-" }
            $rows.Add([pscustomobject]@{
                Map = $pair.Value
                AndyFlag = $letter
                GameFlag = $gameLetter
                Distance = if ($null -ne $nearest) { [Math]::Round($nearestDistance, 3) } else { $null }
                AndyArea = if ($null -ne $nodes[$areaPath].Area) { [Math]::Round($nodes[$areaPath].Area, 3) } else { $null }
                GameArea = if ($null -ne $nearest) { [Math]::Round([double]$nearest.area_m2, 3) } else { $null }
                ObjId = $node.ObjId
                Guid = if ($null -ne $nearest) { [string]$nearest.raw.instance_guid } else { $null }
                Root = if ($null -ne $nearestRoot) { $nearestRoot.Root } else { $null }
                RootDistance = if ($null -ne $nearestRoot) { [Math]::Round($nearestRootDistance, 3) } else { $null }
                RootGuid = if ($null -ne $nearestRoot) { $nearestRoot.Guid } else { $null }
                Match = ($null -ne $nearest -and $letter -eq $gameLetter -and $nearestDistance -le 2.0 -and $nearestRootDistance -le 15.0)
            })
        }
    }
    $rows
} finally {
    $zip.Dispose()
}
