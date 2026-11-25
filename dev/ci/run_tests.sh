#!/usr/bin/env bash
# Chạy bộ test tự động của project (dùng cho CI và chạy tay tại máy).
# Mỗi dòng trong ci_suite.txt: <đường dẫn scene res://...> [tham số sau --]. Dòng trống / bắt đầu bằng # bị bỏ qua.
# Một test bị tính FAIL khi: mã thoát khác 0, quá thời gian, log có dòng bắt đầu bằng "FAIL" hoặc "SCRIPT ERROR",
# hoặc không có dòng "PASS" nào (test không chạy tới phần kiểm tra).
# Mỗi test dùng thư mục dữ liệu riêng (user://) nên không đụng save thật trên máy.
#
# Cách dùng:  GODOT=/đường/dẫn/godot dev/ci/run_tests.sh [ci_suite.txt]
# Biến môi trường: GODOT (mặc định "godot"), TEST_TIMEOUT (giây, mặc định 240), LOG_DIR (mặc định test_logs).

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SUITE="${1:-$ROOT/dev/ci/ci_suite.txt}"
GODOT="${GODOT:-godot}"
TEST_TIMEOUT="${TEST_TIMEOUT:-240}"
LOG_DIR="${LOG_DIR:-$ROOT/test_logs}"
DATA_ROOT="$(mktemp -d)"

mkdir -p "$LOG_DIR"
passed=()
failed=()

while IFS= read -r line || [ -n "$line" ]; do
	line="${line%%$'\r'}"
	[[ -z "${line// }" || "$line" == \#* ]] && continue
	read -r scene args <<< "$line"
	name="$(basename "$scene" .tscn)"
	log="$LOG_DIR/$name.log"
	data="$DATA_ROOT/$name"
	mkdir -p "$data"
	echo "::group::$scene"
	start=$(date +%s)
	# HOME / XDG_DATA_HOME (Linux) và APPDATA (Windows) trỏ vào thư mục tạm: user:// của test không đụng save thật
	HOME="$data" XDG_DATA_HOME="$data" APPDATA="$data" \
		timeout "$TEST_TIMEOUT" "$GODOT" --headless --path "$ROOT" "$scene" -- $args > "$log" 2>&1
	code=$?
	took=$(( $(date +%s) - start ))
	reason=""
	if [ $code -eq 124 ]; then
		reason="quá ${TEST_TIMEOUT}s"
	elif [ $code -ne 0 ]; then
		reason="mã thoát $code"
	elif grep -qE '^(FAIL|SCRIPT ERROR)' "$log"; then
		reason="có dòng FAIL / SCRIPT ERROR"
	elif ! grep -qE '^PASS' "$log"; then
		reason="không có dòng PASS nào"
	fi
	grep -E '^(PASS|FAIL|SCRIPT ERROR)' "$log" | head -200
	echo "::endgroup::"
	if [ -z "$reason" ]; then
		echo "OK    $scene (${took}s)"
		passed+=("$scene")
	else
		echo "FAIL  $scene (${took}s): $reason - log: $log"
		grep -E '^(FAIL|SCRIPT ERROR)|ERROR' "$log" | head -20
		failed+=("$scene")
	fi
done < "$SUITE"

rm -rf "$DATA_ROOT"
echo
echo "Tổng: ${#passed[@]} đạt, ${#failed[@]} hỏng"
for scene in "${failed[@]}"; do
	echo "  hỏng: $scene"
done
[ ${#failed[@]} -eq 0 ]
