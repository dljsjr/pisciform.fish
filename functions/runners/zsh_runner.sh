#!/usr/bin/env zsh
isbuiltin=false
isfunction=false
isfile=false

cd "$1" || exit
dirs -c
currdir="$(/bin/pwd -P)"
shift

outdir="$1"
shift

if whence -w "$1" | grep -q ': builtin'; then
  isbuiltin=true
  funcname="$1"
  :
elif whence -w "$1" | grep -q ': function'; then
  isfunction=true
  funcname="$1"
  :
elif [[ -f "$1" ]]; then
  isfile=true
  funcname="$(basename "$1")"
  funcfile="$(cd "$(realpath "$(dirname "$1")")" && /bin/pwd -P)/${funcname}"
  fpath+=("$(dirname "$funcfile")")
  autoload -U "$funcfile"
fi
shift

mkdir -p "${outdir}/before/"
mkdir -p "${outdir}/after/"

# Capture environment, aliases, functions before execution
for envvar in $(awk 'BEGIN{for(v in ENVIRON) print v}' | sort -h); do
  decl="$(declare -p "$envvar" 2>/dev/null)"
  if [ -n "$decl" ]; then
    echo "$decl" >>"${outdir}/before/${envvar}"
  fi
done
alias | sort -h >"${outdir}/alias.before"
# print -l ${(k)functions} | sort -h >"${outdir}/functions.before"

# Execute the wrapped command
if [ "$isbuiltin" = "true" ]; then
  builtin $funcname "$@"
else
  $funcname "$@"
fi

funcstatus=$?
[ $funcstatus -gt 0 ] && exit $funcstatus

# Capture environment, aliases, functions after execution
for envvar in $(awk 'BEGIN{for(v in ENVIRON) print v}' | sort -h); do
  decl="$(declare -p "$envvar" 2>/dev/null)"
  if [ -n "$decl" ]; then
    echo "$decl" >>"${outdir}/after/${envvar}"
  fi
done

alias | sort -h >"${outdir}/alias.after"
# print -l ${(k)functions} | sort -h >"${outdir}/functions.after"

dirs -pl | nl | sort -nr | cut -f 2- >"${outdir}/dirstack"

env_changes=(${(f)"$(diff -rq "$outdir/before" "$outdir/after")"})
for line in $env_changes; do
  sed -n -e 's/Only in .*\/before: \(.*\)$/delete:\1/p'\
  -e 's/Only in .*\/after: \(.*\)$/upsert:\1/p'\
  -e 's/Files .*\/before\/\([^\s]*\) and .* differ$/upsert:\1/p' <<< "$line" > "$outdir/env.ops"
done

comm -13 ${outdir}/alias.before ${outdir}/alias.after > ${outdir}/alias.to_add

# comm -23 ${outdir}/functions.before ${outdir}/functions.after > ${outdir}/functions.to_delete
# comm -13 ${outdir}/functions.before ${outdir}/functions.after > ${outdir}/functions.to_add
