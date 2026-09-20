param(
    [string]$AssetDirectory = 'C:\BF6_Dev\BF6_Gamemode_Release_Assets\layouts-v1.1.0',
    [string]$Output = 'C:\BF6_Dev\BF6_Godot_Gamemode_Setup\gamemode_index.json'
)

$ErrorActionPreference = 'Stop'
$modes = [ordered]@{
    mp_atoll = @('breakthrough', 'conquest', 'domination', 'escalation', 'kingofthehill',
        'koth', 'payload', 'rush', 'sabotage', 'squaddeathmatch', 'strikepoint', 'teamdeathmatch')
    mp_isolated = @('breakthrough', 'carrierstrike', 'conquest', 'domination', 'escalation',
        'gauntlet', 'koth', 'rush', 'sabotage', 'squaddeathmatch', 'strikepoint', 'teamdeathmatch')
}
$mapNames = @{ mp_atoll = 'Wake Island'; mp_isolated = 'Tsuru Reef' }
$modeNames = @{
    breakthrough = 'Breakthrough'; carrierstrike = 'Carrier Strike'; conquest = 'Conquest'
    domination = 'Domination'; escalation = 'Escalation'; gauntlet = 'Gauntlet'
    kingofthehill = 'King of the Hill Zones'; koth = 'King of the Hill'
    payload = 'Payload'; rush = 'Rush'; sabotage = 'Sabotage'
    squaddeathmatch = 'Squad Deathmatch'; strikepoint = 'Strikepoint'
    teamdeathmatch = 'Team Deathmatch'
}
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
foreach ($level in $modes.Keys) {
    foreach ($mode in $modes[$level]) {
        $key = "$level/$mode"
        $manifest = "${level}_${mode}.layout.json"
        $files = @((File-Record $manifest))
        $entry = [ordered]@{
            name = "$($mapNames[$level]) - $($modeNames[$mode])"
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

$document = [ordered]@{ format = 2; release_tag = 'layouts-v1.1.0'; layouts = $layouts }
$json = $document | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($Output, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
Write-Host "Wrote $($layouts.Count) layouts to $Output"
