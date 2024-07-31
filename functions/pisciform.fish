
function pisciform --description "Create a fish function/alias for invoking a Bash/ZSH/Posix shell function and capturing environment changes"
    #--- Init Default Configuration
    set -f scriptdir (dirname (readlink -f (status --current-filename)))
    set -f verbose false
    set -f runner_shell sh
    set -f is_interactive false
    set -f is_login false
    set -f runner_mode function

    # inspired by bass.fish: https://github.com/edc/bass/blob/79b62958ecf4e87334f24d6743e5766475bcf4d0/functions/__bass.py#L22
    set -f ENV_VAR_IGNORE_REGEX '^[^:]*:(PWD|SHLVL|history|pipestatus|status|version|FISH_VERSION|fish_pid|hostname|_|fish_private_mode|PS1|XPC_SERVICE_NAME)'

    #--- BEGIN: Private Functions
    function _pisciform_make_posix_wrapper -V scriptdir -V ENV_VAR_IGNORE_REGEX
        set -f verbose $argv[1]
        set -f is_interactive $argv[2]
        set -f is_login $argv[3]
        set -f runner_mode $argv[4]
        set -f funcname $argv[5]
        set -f init_files $argv[6..]

        if $verbose
            echo "make POSIX shell wrapper for func $funcname"
        end

        echo "not yet implemented"
        return 1
    end

    function _pisciform_make_bash_wrapper -V scriptdir -V ENV_VAR_IGNORE_REGEX
        set -f verbose $argv[1]
        set -f is_interactive $argv[2]
        set -f is_login $argv[3]
        set -f runner_mode $argv[4]
        set -f funcname $argv[5]
        set -f init_files $argv[6..]

        if $verbose
            echo "make bash wrapper for func $funcname"
        end

        # inspired by replay.fish: https://github.com/jorgebucaran/replay.fish/
        function $funcname -V init_files -V is_interactive -V is_login -V runner_mode -V verbose -V funcsource -V funcname -V scriptdir -V ENV_VAR_IGNORE_REGEX --description "Fish wrapper for Bash function $funcname"
            if $verbose
                echo "funcsource: $funcsource"
                echo "funcname: $funcname"
                echo "scriptdir: $scriptdir"
            end
            set -f shell_args
            if $is_interactive
                set -a -f shell_args -i
            end
            if $is_login
                set -a -f shell_args -l
            end
            set -f currdir (builtin pwd -P)
            set -f outdir (mktemp -d)
            command bash $shell_args -- "$scriptdir/runners/bash_runner.sh" $currdir $outdir $funcname $init_files -- $argv || return

            string replace --all -- \\n \n (
              for line in (cat "$outdir/env.ops" | grep -vE "$ENV_VAR_IGNORE_REGEX")
                  set -l operation (echo "$line" | cut -d ':' -f 1)
                  set -l varname (echo "$line" | cut -d ':' -f 2-)
                  switch $operation
                      case delete
                          echo set -e $varname
                      case upsert
                          set -l vardecl (cat "$outdir/after/$varname")
                          set -l decltype (echo "$vardecl" | cut -d ' ' -f 2)
                          set -l varval (string escape --no-quoted (string trim -c "\"" (string trim -c "'" (echo "$vardecl" | cut -d '=' -f 2-))))
                          if string match -q -r -- '^-.*x.*$' "$decltype"
                              echo set -g -x $varname $varval
                          else
                              echo set -g $varname $varval
                          end
                  end
              end

              for line in (cat "$outdir/alias.to_add")
                  echo "$line"
              end

              set -l dirstack (cat "$outdir/dirstack")
              if test (builtin realpath $dirstack[1]) = (builtin pwd -P)
                  set -e dirstack[1]
              end
              for dir_to_push in $dirstack
                  echo pushd $dir_to_push
              end

              if test -f "$outdir/after/PWD"
                  set -l finaldir (builtin realpath (string trim -c "\"" (cat "$outdir/after/PWD" | cut -d '=' -f 2-)))
                  if not test (builtin realpath $finaldir) = (builtin pwd -P)
                      echo cd "$finaldir"
                  end
              end
            ) | source
            rm -rf "$outdir"
        end
    end

    function _pisciform_make_zsh_wrapper -V scriptdir -V ENV_VAR_IGNORE_REGEX
        set -f verbose $argv[1]
        set -f is_interactive $argv[2]
        set -f is_login $argv[3]
        set -f runner_mode $argv[4]
        set -f funcsource $argv[5]
        set -f init_files $argv[6..]

        if test -f "$funcsource"; or $runner_mode = autoload
            set -f funcsource (realpath $funcsource)
            set -f funcname (basename (realpath $funcsource))
        else
            set -f funcname "$funcsource"
        end
        if $verbose
            echo "make zsh wrapper for func $funcname"
        end

        # inspired by replay.fish: https://github.com/jorgebucaran/replay.fish/
        function $funcname -V init_files -V is_interactive -V is_login -V runner_mode -V verbose -V funcsource -V funcname -V scriptdir -V ENV_VAR_IGNORE_REGEX --description "Fish wrapper for ZSH function $funcname"
            if $verbose
                echo "funcsource: $funcsource"
                echo "funcname: $funcname"
                echo "scriptdir: $scriptdir"
            end
            set -f shell_args
            if $is_interactive
                set -a -f shell_args --interactive
            end
            if $is_login
                set -a -f shell_args --login
            end
            set -f currdir (builtin pwd -P)
            set -f outdir (mktemp -d)
            command zsh $shell_args -- "$scriptdir/runners/zsh_runner.sh" $currdir $outdir $funcsource $init_files -- $argv || return
            string replace --all -- \\n \n (
              for line in (cat "$outdir/env.ops" | grep -vE "$ENV_VAR_IGNORE_REGEX")
                  set -l operation (echo "$line" | cut -d ':' -f 1)
                  set -l varname (echo "$line" | cut -d ':' -f 2-)
                  switch $operation
                      case delete
                          echo set -e $varname
                      case upsert
                          set -l vardecl (cat "$outdir/after/$varname")
                          set -l decltype (echo "$vardecl" | cut -d ' ' -f 1)
                          set -l varval (string escape --no-quoted (string trim -c "'" (echo "$vardecl" | cut -d '=' -f 2-)))
                          switch "$decltype"
                              case typeset
                                  echo set -g $varname $varval
                              case export
                                  echo set -g -x $varname $varval
                          end
                  end
              end

              for line in (cat "$outdir/alias.to_add")
                  echo "alias $line"
              end

              set -l dirstack (cat "$outdir/dirstack")
              if test (builtin realpath $dirstack[1]) = (builtin pwd -P)
                  set -e dirstack[1]
              end
              for dir_to_push in $dirstack
                echo pushd $dir_to_push
              end

              if test -f "$outdir/after/PWD"
                  set -l finaldir (builtin realpath (cat "$outdir/after/PWD" | cut -d '=' -f 2-))
                  if not test (builtin realpath $finaldir) = (builtin pwd -P)
                    echo cd "$finaldir"
                  end
              end
            ) | source
            rm -rf "$outdir"
        end
    end

    function _pisciform_short_usage
        echo "
NAME:
  pisciform - Create a fish function/alias for invoking a Bash/ZSH/Posix shell function and capturing environment changes

USAGE:
  pisciform [-h|--help] [-v|--verbose] [--interactive] [--login] [{-f|--file}|{-b|--builtin}] [--sh|--zsh|--bash] [--source ...] FUNCTION_NAME
"
    end

    function _pisciform_usage
        _pisciform_short_usage
        echo "

OPTIONS:
  -h, --help                print this usage, then return
  -v, --verbose             Sets a \"verbose\" flag for tracing the wrapped process, and generates a verbose version of the 'runner'
  --interactive             Set the interactive flag on the runner shell
  --login                   Set the login flag on the runner shell.
  --sh, --zsh, --bash       Mutually exclusive. Selects which runner to use. Defaults to `sh`
  -b, --builtin             Instructs the runner that the command being wrapped is a shell built-in instead of a function defined in a file
  -a, --autoload            Only availble when `--zsh` is set. The FUNCTION_NAME positional argument should be replaced with the path to
                            a file that contains an autoloadable function definition. The runner will pass the given file to `autoload -U`.
                            The name of the file becomes the function name, and the containing directory for the file will be appended
                            to the runner's `fpath`.
  --init-file               File to `source` before invoking the command. May be specified more than once to source multiple files.
                            Useful for shells like bash or sh where a user function might be defined in an RC file.

EXAMPLES
  # creates a fish function called `do_something` that invokes the autoloadable ZSH function in the given file
  pisciform --interactive --zsh --file \"$HOME/.zfunc/do_something\"

  # creates a fish function called `foo` around a bash function called `foo`, where foo is a function defined in the file ~/.bashfuncs, so the file must be sourced first.
  pisciform --interactive --bash --init-file ~/.bashfuncs foo
"
    end
    #--- END: Private Functions

    argparse -x autoload,builtin -x zsh,bash,sh --name=pisciform h/help v/verbose interactive login a/autoload b/builtin zsh bash sh init-file=+ -- $argv
    or begin
        _pisciform_short_usage
        return 1
    end

    if set -ql _flag_help
        _pisciform_usage
        return 0
    end

    if [ (count $argv) -ne 1 ]
        _pisciform_short_usage
        return 1
    end

    if set -ql _flag_verbose
        set -f verbose true
    end

    if set -ql _flag_zsh
        set -f runner_shell zsh
    end

    if set -ql _flag_bash
        set -f runner_shell bash
    end

    if set -ql _flag_sh
        set -f runner_shell sh
    end

    if set -ql _flag_autoload
        set -f runner_mode autoload
    end

    if set -ql _flag_builtin
        set -f runner_mode builtin
    end

    if set -ql _flag_interactive
        set -f is_interactive true
    end

    if set -ql _flag_login
        set -f is_login true
    end

    if set -ql _flag_init_file
        for init_file in $_flag_init_file
            set -a -f init_files (builtin realpath $init_file)
        end
    end

    if $verbose
        echo "creating function wrapper for $argv[1] (mode: $runner_mode) for $runner_shell shell."\n\t"interactive? $is_interactive"\n\t"login? $is_login"
    end

    switch "$runner_shell"
        case sh
            _pisciform_make_posix_wrapper $verbose $is_interactive $is_login $runner_mode $argv $init_files
        case zsh
            _pisciform_make_zsh_wrapper $verbose $is_interactive $is_login $runner_mode $argv $init_files
        case bash
            _pisciform_make_bash_wrapper $verbose $is_interactive $is_login $runner_mode $argv $init_files
    end
end
