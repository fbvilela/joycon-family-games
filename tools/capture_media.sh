#!/usr/bin/env bash
# Record the menu and each playable round with Godot's movie writer.
# Requires Godot 4.7+ on PATH, xvfb-run, and ffmpeg.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${1:-$ROOT/docs/media}"
mkdir -p "$OUT" /tmp/joyparty

record() {
	local scene="$1"
	local frames="$2"
	local movie="$3"
	shift 3
	echo "Recording $movie ($frames frames)"
	xvfb-run -a -s "-screen 0 1280x720x24 +extension GLX +render -noreset" \
		env LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe "$@" \
		"$GODOT" --display-driver x11 \
		--rendering-method gl_compatibility --rendering-driver opengl3 \
		--audio-driver Dummy --path "$ROOT" "$scene" \
		--write-movie "$movie" --fixed-fps 12 --quit-after "$frames"
}

shot() {
	local movie="$1"
	local seconds="$2"
	local png="$3"
	ffmpeg -y -ss "$seconds" -i "$movie" -frames:v 1 "$png" >/dev/null 2>&1
}

gif_of() {
	local movie="$1"
	local gif="$2"
	ffmpeg -y -i "$movie" -vf "fps=10,scale=640:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=96[p];[s1][p]paletteuse=dither=bayer" "$gif" >/dev/null 2>&1
}

mp4_of() {
	local movie="$1"
	local mp4="$2"
	ffmpeg -y -i "$movie" -an -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$mp4" >/dev/null 2>&1
}

record "res://scenes/main_menu.tscn" 24 /tmp/joyparty/menu.avi
record "res://scenes/balloon_bop.tscn" 96 /tmp/joyparty/balloon.avi JOY_PARTY_DEMO=1
record "res://scenes/shake_tree.tscn" 84 /tmp/joyparty/tree.avi JOY_PARTY_DEMO=1
record "res://scenes/wobbly_wheel.tscn" 96 /tmp/joyparty/wheel.avi JOY_PARTY_DEMO=1

shot /tmp/joyparty/menu.avi 1.0 "$OUT/menu.png"
shot /tmp/joyparty/balloon.avi 1.4 "$OUT/balloon_bop.png"
shot /tmp/joyparty/tree.avi 2.0 "$OUT/shake_tree.png"
shot /tmp/joyparty/wheel.avi 2.0 "$OUT/wobbly_wheel.png"

gif_of /tmp/joyparty/balloon.avi "$OUT/balloon_bop.gif"
gif_of /tmp/joyparty/tree.avi "$OUT/shake_tree.gif"
gif_of /tmp/joyparty/wheel.avi "$OUT/wobbly_wheel.gif"
mp4_of /tmp/joyparty/balloon.avi "$OUT/balloon_bop.mp4"
mp4_of /tmp/joyparty/tree.avi "$OUT/shake_tree.mp4"
mp4_of /tmp/joyparty/wheel.avi "$OUT/wobbly_wheel.mp4"

ls -lh "$OUT"
