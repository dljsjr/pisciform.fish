#!/usr/bin/env bash
isbuiltin=false

cd "$1" || exit
dirs -c
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
    source "$1"
    shift
    ;;
  esac
done

if type -t "$funcarg" | grep -q 'builtin'; then
  isbuiltin=true
  funcname="$funcarg"
  :
elif type -t "$funcarg" | grep -q 'function'; then
  funcname="$funcarg"
  :
fi

mkdir -p "${outdir}/before/"
mkdir -p "${outdir}/after/"

# Capture environment, aliases, functions before execution
while IFS= read -r envvar; do
  decl="$(declare -p "$envvar" 2>/dev/null)"
  if [ -n "$decl" ]; then
    echo "$decl" >>"${outdir}/before/${envvar}"
  fi
done < <(awk 'BEGIN{for(v in ENVIRON) print v}' | sort -h)
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
while IFS= read -r envvar; do
  decl="$(declare -p "$envvar" 2>/dev/null)"
  if [ -n "$decl" ]; then
    echo "$decl" >>"${outdir}/after/${envvar}"
  fi
done < <(awk 'BEGIN{for(v in ENVIRON) print v}' | sort -h)

alias | sort -h >"${outdir}/alias.after"

dirs -p -l | nl | sort -nr | cut -f 2- >"${outdir}/dirstack"

touch "$outdir/env.ops"
while IFS= read -r line; do
  sed -n -e 's/Only in .*\/before: \(.*\)$/delete:\1/p' \
    -e 's/Only in .*\/after: \(.*\)$/upsert:\1/p' \
    -e 's/Files .*\/before\/\([^\s]*\) and .* differ$/upsert:\1/p' <<<"$line" >"$outdir/env.ops"
done < <(diff -rq "$outdir/before" "$outdir/after")

comm -13 "${outdir}/alias.before" "${outdir}/alias.after" >"${outdir}/alias.to_add"
