param(
    [Parameter(Mandatory = $true)]
    [string]$SourceScene,
    [Parameter(Mandatory = $true)]
    [string]$CarrierLayout,
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

$sceneName = 'mp_isolated_conquest.tscn'
$carrierName = 'mp_isolated_conquest_carriers.glb'
$sceneOutput = Join-Path $OutputDirectory $sceneName
$carrierOutput = Join-Path $OutputDirectory $carrierName

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $SourceScene))
$blocks = [Text.RegularExpressions.Regex]::Split($text, '(?m)(?=^\[node )')

$header = $blocks[0]
$unusedResources = @(
    'WaterPlane/WaterPlane.tscn',
    'static/MP_Isolated_Assets.tscn',
    'static/MP_Isolated_Terrain.tscn',
    'architecture/FiringRange_Floor_01.tscn',
    'props/MannequinRotation_01.tscn',
    'Common/InteractPoint.tscn'
)
foreach ($resource in $unusedResources) {
    $escaped = [Text.RegularExpressions.Regex]::Escape($resource)
    $header = [Text.RegularExpressions.Regex]::Replace(
        $header,
        "(?m)^\[ext_resource[^\r\n]*$escaped[^\r\n]*\]\r?\n",
        ''
    )
}

$kept = [Collections.Generic.List[string]]::new()
$kept.Add($header)
for ($index = 1; $index -lt $blocks.Count; $index++) {
    $block = $blocks[$index]
    $firstLine = ($block -split "`r?`n", 2)[0]
    $exclude =
        $firstLine -match '^\[node name="Static" ' -or
        $firstLine -match 'parent="Static(?:/|\")' -or
        $firstLine -match 'name="FiringRange_Floor_01"' -or
        $firstLine -match 'name="TeamSwitcher"' -or
        $firstLine -match 'parent="Prefab/TeamSwitcher(?:/|\")'
    if (-not $exclude) {
        $kept.Add($block)
    }
}

$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($sceneOutput, ($kept -join ''), $utf8)
Copy-Item -LiteralPath $CarrierLayout -Destination $carrierOutput -Force

$files = foreach ($path in @($sceneOutput, $carrierOutput)) {
    $item = Get-Item -LiteralPath $path
    [ordered]@{
        name = $item.Name
        bytes = $item.Length
        sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$files | ConvertTo-Json

