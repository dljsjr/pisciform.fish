#!/usr/bin/env sh
isbuiltin=false

cd "$1" || exit
shift

outdir="$1"
shift

funcarg="$1"
shift

while test $# -gt 0; do
  case "$1" in
  "--")
    shift
    break
    ;;
  *)
    . "$1"
    shift
    ;;
  esac
done

if command -V "$funcarg" | grep -q 'is a shell builtin'; then
  isbuiltin=true
  funcname="$funcarg"
  :
elif command -V "$funcarg" | grep -q 'is a shell function'; then
  funcname="$funcarg"
  :
fi

mkdir -p "${outdir}/before/"
mkdir -p "${outdir}/after/"

# Capture environment, aliases, functions before execution
mkfifo exportpipe
export -p | cut -d ' ' -f 2- | cut -d '=' -f 1 | sort -h >exportpipe &
while IFS= read -r envvar; do
  echo "$envvar" >>"$outdir/before/exports"
done <exportpipe
rm exportpipe

mkfifo envpipe
awk 'BEGIN{for(v in ENVIRON) print v}' | sort -h >envpipe &
while IFS= read -r envvar; do
  varval="$(eval "echo \"\$$envvar\"")"
  if grep -q "$envvar" "$outdir/before/exports"; then
    echo "declare -x $envvar=$varval" >>"${outdir}/before/${envvar}"
  else
    echo "declare -- $envvar=$varval" >>"${outdir}/before/${envvar}"
  fi
done <envpipe
rm envpipe
alias | sort -h >"${outdir}/alias.before"

# Execute the wrapped command
if [ "$isbuiltin" = "true" ]; then
  builtin $funcname "$@"
else
  $funcname "$@"
fi

funcstatus=$?
[ $funcstatus -gt 0 ] && exit $funcstatus

# Capture environment, aliases, functions after execution
mkfifo exportpipe
export -p | cut -d ' ' -f 2- | cut -d '=' -f 1 | sort -h >exportpipe &
while IFS= read -r envvar; do
  echo "$envvar" >>"$outdir/after/exports"
done <exportpipe
rm exportpipe

mkfifo envpipe
awk 'BEGIN{for(v in ENVIRON) print v}' | sort -h >envpipe &
while IFS= read -r envvar; do
  varval="$(eval "echo \"\$$envvar\"")"
  if grep -q "$envvar" "$outdir/after/exports"; then
    echo "declare -x $envvar=$varval" >>"${outdir}/after/${envvar}"
  else
    echo "declare -- $envvar=$varval" >>"${outdir}/after/${envvar}"
  fi
done <envpipe
rm envpipe

alias | sort -h >"${outdir}/alias.after"

touch "$outdir/env.ops"
mkfifo envopspipe
diff -rq "$outdir/before" "$outdir/after" >envopspipe &
while IFS= read -r line; do
  sed -n -e 's/Only in .*\/before: \(.*\)$/delete:\1/p' \
    -e 's/Only in .*\/after: \(.*\)$/upsert:\1/p' \
    -e 's/Files .*\/before\/\([^\s]*\) and .* differ$/upsert:\1/p' >"$outdir/env.ops" <<EOF
$line
EOF
done <envopspipe
rm envopspipe

comm -13 "${outdir}/alias.before" "${outdir}/alias.after" >"${outdir}/alias.to_add"
