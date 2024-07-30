
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
    function _pisciform_make_posix_wrapper -V scriptdir
        set -f verbose $argv[1]
        set -f is_interactive $argv[2]
        set -f is_login $argv[3]
        set -f runner_mode $argv[4]
        set -f funcsource $argv[5]

        if test -f "$funcsource"; or $runner_mode = file
            set -f funcsource (realpath $funcsource)
            set -f funcname (basename (realpath $funcsource))
        else
            set -f funcname "$funcsource"
        end
        if $verbose
            echo "make POSIX shell wrapper for func $funcname"
        end

        echo "not yet implemented"
        return 1
    end

    function _pisciform_make_bash_wrapper
        set -f verbose $argv[1]
        set -f is_interactive $argv[2]
        set -f is_login $argv[3]
        set -f runner_mode $argv[4]
        set -f funcsource $argv[5]

        if test -f "$funcsource"; or $runner_mode = file
            set -f funcsource (realpath $funcsource)
            set -f funcname (basename (realpath $funcsource))
        else
            set -f funcname "$funcsource"
        end
        if $verbose
            echo "make bash wrapper for func $funcname"
        end

        echo "not yet implemented"
        return 1
        # adapted from replay.fish: https://github.com/jorgebucaran/replay.fish/
        # function $funcname --description "Fish wrapper for ZSH function $funcname"
        #     set -f funcname (status current-function)
        #     set --local env
        #     set --local sep @$fish_pid(random)(command date +%s)
        #     set --local argv (string escape -- $argv)

        #     set --local out (command bash -c "
        #         $argv
        #         status=\$?
        #         [ \$status -gt 0 ] && exit \$status

        #         command compgen -e | command awk -v sep=$sep '{
        #             gsub(/\n/, \"\\\n\", ENVIRON[\$0])
        #             print \$0 sep ENVIRON[\$0]
        #         }' && alias
        #     ") || return

        #     string replace --all -- \\n \n (
        #         for line in $out
        #             if string split -- $sep $line | read --local --line name value
        #                 set --append env $name

        #                 contains -- $name SHLVL PS1 BASH_FUNC || test "$$name" = "$value" && continue

        #                 if test "$name" = PATH
        #                     echo set PATH (string split -- : $value | string replace --regex --all -- '(^.*$)' '"$1"')
        #                 else if test "$name" = PWD
        #                     echo builtin cd "\"$value\""
        #                 else
        #                     echo "set --global --export $name "(string escape -- $value)
        #                 end
        #             else
        #                 set --query env[1] && string match --entire --regex -- "^alias" $line || echo "echo \"$line\""
        #             end
        #         end | string replace --all -- \$ \\\$
        #         for name in (set --export --names)
        #             contains -- $name $env || echo "set --erase $name"
        #         end
        #     ) | source
        # end
    end

    function _pisciform_make_zsh_wrapper -V scriptdir -V ENV_VAR_IGNORE_REGEX
        set -f verbose $argv[1]
        set -f is_interactive $argv[2]
        set -f is_login $argv[3]
        set -f runner_mode $argv[4]
        set -f funcsource $argv[5]

        if test -f "$funcsource"; or $runner_mode = file
            set -f funcsource (realpath $funcsource)
            set -f funcname (basename (realpath $funcsource))
        else
            set -f funcname "$funcsource"
        end
        if $verbose
            echo "make zsh wrapper for func $funcname"
        end

        # inspired by replay.fish: https://github.com/jorgebucaran/replay.fish/
        function $funcname -V is_interactive -V is_login -V runner_mode -V verbose -V funcsource -V funcname -V scriptdir -V ENV_VAR_IGNORE_REGEX --description "Fish wrapper for ZSH function $funcname"
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
            command zsh $shell_args "$scriptdir/runners/zsh_runner.sh" $currdir $outdir $funcsource $argv || return
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
                                echo set -g $varname (string trim -c "'" $varval)
                            case export
                                echo set -g -x $varname (string trim -c "'" $varval)
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

    function _pisciform_usage
        echo "
NAME:
  pisciform - Create a fish function/alias for invoking a Bash/ZSH/Posix shell function and capturing environment changes

USAGE:
  pisciform [-h|--help] [-v|--verbose] [--interactive] [--login] [{-f|--file}|{-b|--builtin}] [--sh|--zsh|--bash] FUNCTION_NAME

OPTIONS:
  -h, --help                print this usage, then return
  -v, --verbose             Sets a \"verbose\" flag for tracing the wrapped process, and generates a verbose version of the 'runner'
  --interactive             Set the interactive flag on the runner shell
  --login                   Set the login flag on the runner shell.
  --sh, --zsh, --bash       Mutually exclusive. Selects which runner to use. Defaults to `sh`
  -b, --builtin             Instructs the runner that the command being wrapped is a shell built-in instead of a function defined in a file
  -f, --file                Only availble when `--zsh` is set. Instructs the runner to pass the given file to `autoload -U`. Treats the file name as the function name, and adds its containing directory to the runner's `fpath`.

EXAMPLES
  # creates a fish function called `do_something` that invokes the autoloadable ZSH function in the given file
  pisciform --interactive --zsh --file \"$HOME/.zfunc/do_something\"
"
    end
    #--- END: Private Functions

    argparse -x file,builtin -x zsh,bash,sh --name=pisciform h/help v/verbose interactive login f/file b/builtin zsh bash sh -- $argv
    or begin
        _pisciform_usage
        return 1
    end

    if set -ql _flag_help
        _pisciform_usage
        return 0
    end

    if [ (count $argv) -ne 1 ]
        _pisciform_usage
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

    if set -ql _flag_file
        set -f runner_mode file
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

    if $verbose
        echo "creating function wrapper for $argv[1] (mode: $runner_mode) for $runner_shell shell."\n\t"interactive? $is_interactive"\n\t"login? $is_login"
    end

    switch "$runner_shell"
        case sh
            _pisciform_make_posix_wrapper $verbose $is_interactive $is_login $runner_mode $argv
        case zsh
            _pisciform_make_zsh_wrapper $verbose $is_interactive $is_login $runner_mode $argv
        case bash
            _pisciform_make_bash_wrapper $verbose $is_interactive $is_login $runner_mode $argv
    end
end
