import os
import re

spawner_path = r"d:\acy\tst\WithAI_Lua\project\src\enemy\spawner.lua"
output_path = r"d:\acy\tst\WithAI_Lua\project\src\enemy\boss_update.lua"

with open(spawner_path, "r", encoding="utf-8-sig") as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1

for idx, line in enumerate(lines):
    if 'elseif enemy.type == "boss" then' in line and start_idx == -1:
        start_idx = idx
    elif 'elseif enemy.type == "charger" then' in line and start_idx != -1 and end_idx == -1:
        end_idx = idx
        break

if start_idx == -1 or end_idx == -1:
    print(f"Error: Could not find start ({start_idx}) or end ({end_idx}) index!")
    exit(1)

print(f"Extracted boss update block from line {start_idx + 1} to {end_idx + 1}")

boss_code_lines = lines[start_idx+1:end_idx]

# Check for any "Enemy." references in the block
enemy_refs = []
for idx, line in enumerate(boss_code_lines):
    matches = re.findall(r'\bEnemy\.\w+', line)
    if matches:
        enemy_refs.append((idx + start_idx + 2, line.strip(), matches))

print(f"Found {len(enemy_refs)} references to 'Enemy.':")
for ref in enemy_refs:
    print(f"  Line {ref[0]}: {ref[1]} -> {ref[2]}")

# Construct the new boss_update.lua file
boss_code = "".join(boss_code_lines)

# Replace checkLineCircleCollision with Collision.checkLineCircle
boss_code = boss_code.replace("checkLineCircleCollision", "Collision.checkLineCircle")

# We need to un-indent the code by 8 spaces (since it was inside a nested elseif block)
unindented_lines = []
for line in boss_code.split("\n"):
    if line.startswith("        "):
        unindented_lines.append(line[8:])
    elif line.strip() == "":
        unindented_lines.append("")
    else:
        unindented_lines.append(line)

boss_code_unindented = "\n".join(unindented_lines)

boss_update_content = f"""-- ============================================================================
-- boss_update.lua — 보스 AI 상태 업데이트 모듈 (spawner.lua에서 분리)
-- ============================================================================

local Collision = require("combat.collision")

local BossUpdate = {{}}

-- 각 스테이지별 보스 업데이트 패턴 실행
function BossUpdate.update(game, enemy, dt, dx, dy, dist, player)
    local targetVelX = 0
    local targetVelY = 0

{boss_code_unindented}

    return targetVelX, targetVelY
end

return BossUpdate
"""

with open(output_path, "w", encoding="utf-8") as f:
    f.write(boss_update_content)

print("Successfully wrote boss_update.lua")
