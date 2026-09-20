param(
    [string]$AssetDirectory = 'C:\BF6_Dev\BF6_Gamemode_Release_Assets\layouts-v1.2.0',
    [string]$Catalog = 'C:\BF6_Dev\BF6_Godot_Gamemode_Setup\data\layout_catalog.json',
    [string]$Output = 'C:\BF6_Dev\BF6_Godot_Gamemode_Setup\gamemode_index.json',
    [string]$ReleaseTag = 'layouts-v1.2.0'
)

$ErrorActionPreference = 'Stop'
$catalogData = Get-Content -LiteralPath $Catalog -Raw | ConvertFrom-Json
$carrierAssets = @{
    'mp_isolated/carrierstrike' = 'mp_isolated_carrierstrike_carriers.glb'
    'mp_atoll/breakthrough' = 'mp_atoll_breakthrough_carriers.glb'
    'mp_atoll/conquest' = 'mp_atoll_conquest_carriers.glb'
    'mp_atoll/escalation' = 'mp_atoll_escalation_carriers.glb'
}

function File-Record([string]$Name) {
    $path = Join-Path $AssetDirectory $Name
    $item = Get-Item -LiteralPath $path
    [ordered]@{
        name = $Name
        bytes = $item.Length
        sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$layouts = [ordered]@{}
foreach ($mapProperty in $catalogData.maps.PSObject.Properties) {
    $level = $mapProperty.Name
    $map = $mapProperty.Value
    foreach ($mode in $map.modes) {
        $key = "$level/$mode"
        $manifest = "${level}_${mode}.layout.json"
        $files = @((File-Record $manifest))
        $modeName = [string]$catalogData.mode_names.$mode
        if ($mode -eq 'kingofthehill' -and @($map.modes) -contains 'koth') {
            $modeName = 'King of the Hill Zones'
        }
        $entry = [ordered]@{
            name = "$($map.name) - $modeName"
            level = $level
            mode = $mode
            maturity = 'review'
            manifest = $manifest
        }
        if ($carrierAssets.ContainsKey($key)) {
            $entry.carriers = $carrierAssets[$key]
            $files += File-Record $carrierAssets[$key]
        }
        $entry.files = $files
        $layouts[$key] = $entry
    }
}

$document = [ordered]@{ format = 2; release_tag = $ReleaseTag; layouts = $layouts }
$json = $document | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($Output, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
Write-Host "Wrote $($layouts.Count) layouts to $Output"
