$spawnerPath = "d:\acy\tst\WithAI_Lua\project\src\enemy\spawner.lua"
$outputPath = "d:\acy\tst\WithAI_Lua\project\src\enemy\boss_update.lua"

$lines = Get-Content -Path $spawnerPath -Encoding utf8

$startIdx = -1
$endIdx = -1

for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match 'elseif enemy\.type == "boss" then' -and $startIdx -eq -1) {
        $startIdx = $i
    }
    elseif ($lines[$i] -match 'elseif enemy\.type == "charger" then' -and $startIdx -ne -1 -and $endIdx -eq -1) {
        $endIdx = $i
        break
    }
}

if ($startIdx -eq -1 -or $endIdx -eq -1) {
    Write-Error "Could not find start or end index!"
    exit 1
}

Write-Host "Extracted boss update block from line $($startIdx + 1) to $($endIdx + 1)"

$bossLines = $lines[($startIdx + 1)..($endIdx - 1)]

# Replace checkLineCircleCollision with Collision.checkLineCircle
# Also un-indent by 8 spaces (since they start with 8 spaces)
$processedLines = @()
foreach ($line in $bossLines) {
    $line = $line -replace 'checkLineCircleCollision', 'Collision.checkLineCircle'
    if ($line.StartsWith("        ")) {
        $line = $line.Substring(8)
    }
    elseif ($line.Trim() -eq "") {
        $line = ""
    }
    $processedLines += $line
}

$header = @(
"-- ============================================================================",
"-- boss_update.lua — 보스 AI 상태 업데이트 모듈 (spawner.lua에서 분리)",
"-- ============================================================================",
"",
'local Collision = require("combat.collision")',
"",
"local BossUpdate = {}",
"",
"-- 각 스테이지별 보스 업데이트 패턴 실행",
"function BossUpdate.update(game, enemy, dt, dx, dy, dist, player)",
"    local targetVelX = 0",
"    local targetVelY = 0",
""
)

$footer = @(
"",
"    return targetVelX, targetVelY",
"end",
"",
"return BossUpdate"
)

$finalContent = $header + $processedLines + $footer
$finalContent | Out-File -FilePath $outputPath -Encoding utf8
Write-Host "Successfully wrote boss_update.lua"
