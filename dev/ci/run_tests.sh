#!/usr/bin/env bash
# Chạy bộ test tự động của project (dùng cho CI và chạy tay tại máy).
# Mỗi dòng trong ci_suite.txt: <đường dẫn scene res://...> [tham số sau --] [@data=<thư mục tương đối>].
# Dòng trống / bắt đầu bằng # bị bỏ qua.
# Một test bị tính FAIL khi: mã thoát khác 0, quá thời gian, log có dòng "FAIL" / "[FAIL]" / "SCRIPT ERROR"
# (được thụt lề), hoặc dòng "failures=N" với N > 0.
# Mỗi test dùng thư mục dữ liệu riêng (user://) nên không đụng save thật trên máy. Test tự kiểm tra thư mục dữ liệu
# phải nằm ở chỗ riêng (ví dụ .godot/shrine_runtime) thì ghi @data=.godot/shrine_runtime trên dòng của nó.
#
# Cách dùng:  GODOT=/đường/dẫn/godot dev/ci/run_tests.sh [ci_suite.txt]
# Biến môi trường: GODOT (mặc định "godot"), TEST_TIMEOUT (giây, mặc định 240), LOG_DIR (mặc định test_logs),
# TEST_FILTER (regex: chỉ chạy dòng khớp, ví dụ "tests/fire/" - workflow hằng đêm chia bộ test chạy song song).

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SUITE="${1:-$ROOT/dev/ci/ci_suite.txt}"
GODOT="${GODOT:-godot}"
TEST_TIMEOUT="${TEST_TIMEOUT:-240}"
LOG_DIR="${LOG_DIR:-$ROOT/test_logs}"
DATA_ROOT="$(mktemp -d)"

# Dòng kết quả các test đang dùng: "PASS ...", "  [PASS] ...", "FAIL ...", "failures=2"...
FAIL_PATTERN='^[[:space:]]*\[?(FAIL|SCRIPT ERROR)|failures=[1-9]|fails=[1-9]'
RESULT_PATTERN='^[[:space:]]*\[?(PASS|FAIL|SCRIPT ERROR)|failures='

mkdir -p "$LOG_DIR"
passed=()
failed=()
# Thư mục dữ liệu tạo trong project (@data=): xoá đúng các thư mục này khi xong
made_dirs=()

while IFS= read -r line || [ -n "$line" ]; do
	line="${line%%$'\r'}"
	[[ -z "${line// }" || "$line" == \#* ]] && continue
	if [ -n "${TEST_FILTER:-}" ] && ! grep -qE "$TEST_FILTER" <<< "$line"; then
		continue
	fi
	read -r scene args <<< "$line"
	name="$(basename "$scene" .tscn)"
	log="$LOG_DIR/$name.log"
	data="$DATA_ROOT/$name"
	if [[ "$args" =~ @data=([^[:space:]]+) ]]; then
		data="$ROOT/${BASH_REMATCH[1]}/ci_$name"
		args="${args/@data=${BASH_REMATCH[1]}/}"
		made_dirs+=("$data")
	fi
	mkdir -p "$data"
	# Chạy trên Windows (Git Bash): Godot cần đường dẫn kiểu Windows, không thì không cách ly được save
	native_data="$data"
	if command -v cygpath > /dev/null 2>&1; then
		native_data="$(cygpath -w "$data")"
	fi
	echo "::group::$scene"
	start=$(date +%s)
	# HOME / XDG_DATA_HOME (Linux) và APPDATA (Windows) trỏ vào thư mục tạm: user:// của test không đụng save thật
	HOME="$data" XDG_DATA_HOME="$data" APPDATA="$native_data" LOCALAPPDATA="$native_data" \
		timeout "$TEST_TIMEOUT" "$GODOT" --headless --path "$ROOT" "$scene" -- $args > "$log" 2>&1
	code=$?
	took=$(( $(date +%s) - start ))
	reason=""
	if [ $code -eq 124 ]; then
		reason="quá ${TEST_TIMEOUT}s"
	elif [ $code -ne 0 ]; then
		reason="mã thoát $code"
	elif grep -qE "$FAIL_PATTERN" "$log"; then
		reason="có dòng FAIL / SCRIPT ERROR"
	fi
	grep -E "$RESULT_PATTERN" "$log" | head -200
	echo "::endgroup::"
	if [ -z "$reason" ]; then
		echo "OK    $scene (${took}s)"
		passed+=("$scene")
	else
		echo "FAIL  $scene (${took}s): $reason - log: $log"
		grep -E "$FAIL_PATTERN|ERROR" "$log" | head -20
		failed+=("$scene")
	fi
done < "$SUITE"

rm -rf "$DATA_ROOT"
for dir in "${made_dirs[@]}"; do
	rm -rf "$dir"
done
echo
echo "Tổng: ${#passed[@]} đạt, ${#failed[@]} hỏng"
for scene in "${failed[@]}"; do
	echo "  hỏng: $scene"
done
[ ${#failed[@]} -eq 0 ]
