#!/bin/bash

echo '> Cleaning previous mutants'
rm -f mutants.log
rm -rf mutants/

MAJOR_HOME=../major/
gassert_subject=$1
subject_sources=$2
target_file=$3
driver_base=$4
build_dir=$subject_sources/build/classes/java/main
source_dir=$subject_sources/src/main/java/
setup_output_dir=experiments/$gassert_subject/setup-files

echo 'Build dir: '$build_dir
echo 'Source dir: '$source_dir
echo '> Generating mutants with Major for file: '$target_file
$MAJOR_HOME/bin/javac -cp $build_dir:$subject_sources/libs/* -nowarn -J-Dmajor.export.mutants=true -XMutator:ALL -d $build_dir $source_dir$target_file
echo '> Mutants generated!'
mutants_dir=$setup_output_dir/mutants
mkdir -p $mutants_dir
mv mutants.log $mutants_dir/$driver_base'Driver-mutants.log'
echo ''

cp_with_tests="$build_dir:$subject_sources/build/classes/java/test:$subject_sources/libs/*"

TIMEOUT="${TIMEOUT:-1800}"
KILL_AFTER="${KILL_AFTER:-10}"
TIMEOUT_IMPL="${TIMEOUT_IMPL:-auto}"

run_with_timeout() {
	local duration="$1"
	local kill_after="$2"
	shift 2

	if [ -z "$duration" ] || [ "$duration" = "0" ]; then
		"$@"
		return $?
	fi

	local impl="$TIMEOUT_IMPL"
	if [ "$impl" = "auto" ]; then
		if command -v timeout >/dev/null 2>&1; then
			impl="timeout"
		else
			impl="python"
		fi
	fi

	if [ "$impl" = "timeout" ]; then
		timeout --foreground --kill-after="$kill_after" "$duration" "$@"
		return $?
	fi

	python3 - "$duration" "$kill_after" "$@" <<'PY'
import subprocess
import sys

duration = float(sys.argv[1])
kill_after = float(sys.argv[2])
cmd = sys.argv[3:]

if duration <= 0:
    raise SystemExit(subprocess.call(cmd))

with subprocess.Popen(cmd) as proc:
    try:
        proc.wait(timeout=duration)
        raise SystemExit(proc.returncode)
    except subprocess.TimeoutExpired:
        proc.terminate()
        try:
            proc.wait(timeout=kill_after)
            raise SystemExit(124)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            raise SystemExit(137)
PY
}

echo '> Processing mutants'
for dir in mutants/*/; do # list directories in the form "/tmp/dirname/"
	echo '> Processing mutant: '$dir$target_file
	echo '> Compiling mutant'
	javac -cp $build_dir:$subject_sources/libs/* -g $dir$target_file -d $build_dir
	echo '> Mutant compiled'
	echo ''

	echo '> Generating traces with Chicory from mutant'
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Chicory for mutant"
	dir2=${dir%*/}
	number=${dir2##*/}
	run_with_timeout "$TIMEOUT" "$KILL_AFTER" java -cp lib/daikon.jar:$cp_with_tests daikon.Chicory --output-dir=$mutants_dir --comparability-file=$setup_output_dir/$driver_base'Driver.decls-DynComp' --ppt-omit-pattern=$driver_base'.*' --ppt-omit-pattern='org.junit.*' --dtrace-file=$driver_base'Driver-m'$number'.dtrace.gz' testers.$driver_base'Driver' $mutants_dir/$driver_base'Driver-m'$number'-objects.xml'
	exit_code=$?
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Chicory finished with exit code: $exit_code"
	if [ $exit_code -eq 124 ]; then
		echo "WARNING: Timeout for mutant $number after $TIMEOUT seconds (SIGTERM)"
	elif [ $exit_code -eq 137 ]; then
		echo "WARNING: Mutant $number killed with SIGKILL after not responding to timeout"
	elif [ $exit_code -ne 0 ]; then
		echo "ERROR: Chicory failed for mutant $number with exit code $exit_code" >&2
	fi
done

echo '> Done!'
