$spawnerPath = "d:\acy\tst\WithAI_Lua\project\src\enemy\spawner.lua"
$outputPath = "d:\acy\tst\WithAI_Lua\project\src\enemy\boss_draw.lua"

$lines = Get-Content -Path $spawnerPath -Encoding utf8

$startIdx = -1
$endIdx = -1

for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match 'if currentStage < 3 and enemy\.type == "boss" then' -and $startIdx -eq -1) {
        $startIdx = $i
    }
    elseif ($lines[$i] -match 'elseif enemy\.type == "void_anchor" then' -and $startIdx -ne -1 -and $endIdx -eq -1) {
        $endIdx = $i
        break
    }
}

if ($startIdx -eq -1 -or $endIdx -eq -1) {
    Write-Error "Could not find start or end index!"
    exit 1
}

Write-Host "Extracted boss draw block from line $($startIdx + 1) to $($endIdx + 1)"

$bossLines = $lines[$startIdx..($endIdx - 1)]

# Un-indent by 12 spaces (since they start with 12 spaces)
$processedLines = @()
foreach ($line in $bossLines) {
    if ($line.StartsWith("            ")) {
        $line = $line.Substring(12)
    }
    elseif ($line.Trim() -eq "") {
        $line = ""
    }
    $processedLines += $line
}

$header = @(
'-- ============================================================================',
'-- boss_draw.lua — 보스 렌더링 및 비주얼 효과 모듈 (spawner.lua에서 분리)',
'-- ============================================================================',
'',
'local BossDraw = {}',
'',
'local function drawLightningBeam(x1, y1, x2, y2, segments, displacement)',
'    local dx = x2 - x1',
'    local dy = y2 - y1',
'    local totalDist = math.sqrt(dx * dx + dy * dy)',
'    if totalDist == 0 then return end',
'    local dirX, dirY = dx / totalDist, dy / totalDist',
'    local perpX, perpY = -dirY, dirX',
'',
'    local pts = { x1, y1 }',
'    for k = 1, segments - 1 do',
'        local ratio = k / segments',
'        local baseX = x1 + dx * ratio',
'        local baseY = y1 + dy * ratio',
'        local disp = (math.random() - 0.5) * displacement',
'        table.insert(pts, baseX + perpX * disp)',
'        table.insert(pts, baseY + perpY * disp)',
'    end',
'    table.insert(pts, x2)',
'    table.insert(pts, y2)',
'',
'    love.graphics.line(pts)',
'end',
'',
'-- 각 스테이지별 보스 전용 외형 렌더링',
'function BossDraw.draw(game, enemy, currentStage, cx, cy, halfW, pulse, col)',
''
)

$footer = @(
'end',
'',
'return BossDraw'
)

$finalContent = $header + $processedLines + $footer
$finalContent | Out-File -FilePath $outputPath -Encoding utf8
Write-Host "Successfully wrote boss_draw.lua"
