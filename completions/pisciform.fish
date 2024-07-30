function __shell_condition
    not __fish_contains_opt bash; and not __fish_contains_opt sh; and not __fish_contains_opt zsh
end
complete --command pisciform -f
complete --command pisciform --exclusive --short v --long verbose --description "Enable verbose mode for the wrapping process and for the wrapped command"
complete --command pisciform --exclusive --short h --long help --description "Print usage info and exit"
complete --command pisciform --long interactive -n 'not __fish_contains_opt interactive' --description "Sets the interactive flag on the subshell environment used to run the wrapped command"
complete --command pisciform --long login -n 'not __fish_contains_opt login' --description "Sets the login flag on the subshell environment used to run the wrapped command"
complete --command pisciform --long zsh --condition __shell_condition --description "Use ZSH as the environment to run the wrapped command"
complete --command pisciform --long bash --condition __shell_condition --description "Use BASH as the environment to run the wrapped command"
complete --command pisciform --long sh --condition __shell_condition --description "Use the system's `sh` as the environment to run the wrapped command"
complete --command pisciform --long file --condition '__fish_contains_opt zsh; and not __fish_contains_opt builtin; and not __fish_contains_opt file' --force-files --description "Loads a ZSH autoload function file"
complete --command pisciform --long builtin --condition 'not __fish_contains_opt file; and not __fish_contains_opt builtin' --description "Indicates that the wrapping target is a shell built-in"
