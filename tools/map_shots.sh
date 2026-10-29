#!/usr/bin/env bash
# Top-down and gameplay screenshots of every skirmish and campaign map. Usage: tools/map_shots.sh <out-dir> [godot]
set -u
OUT="${1:?out dir}"
GODOT="${2:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
shot() {
	"$GODOT" --path . --resolution 1280x720 -s res://tools/map_shot.gd -- --out "$OUT/$1" "${@:2}" 2>&1 | grep "^saved" || echo "failed $1"
}
shot skirmish-burma-road --scene res://game/burma_road.tscn
shot skirmish-ten-degree-atolls --scene res://game/ten_degree_atolls.tscn
shot skirmish-mekong-delta --scene res://game/mekong_delta.tscn
shot skirmish-chiang-rai --scene res://game/chiang_rai.tscn
shot skirmish-golden-confluence --scene res://game/showcase.tscn
shot campaign-phillips-channel --scene res://game/phillips_channel.tscn
shot campaign-sop-ruak --scene res://game/sop_ruak.tscn
shot campaign-kokang --scene res://game/mission_kokang.tscn --mission kokang
shot campaign-tachileik --scene res://game/campaign_mission.tscn --mission tachileik
shot campaign-operation-1027 --scene res://game/campaign_mission.tscn --mission operation_1027
