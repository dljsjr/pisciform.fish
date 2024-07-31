function __shell_condition
    not __fish_contains_opt bash; and not __fish_contains_opt sh; and not __fish_contains_opt zsh
end

function __can_set_login
    not __fish_contains_opt sh; and not __fish_contains_opt login
end

function __can_set_interactive
    not __fish_contains_opt interactive
end

function __can_set_bash
    __shell_condition; and not __fish_contains_opt autoload
end

function __can_set_sh
    __shell_condition; and not __fish_contains_opt login; and not __fish_contains_opt autoload
end

function __can_set_autoload
    not __fish_contains_opt bash; and not __fish_contains_opt sh; and not __fish_contains_opt builtin; and not __fish_contains_opt autoload
end

function __can_set_builtin
    not __fish_contains_opt autoload; and not __fish_contains_opt builtin
end

complete --command pisciform -f -r
complete --command pisciform --exclusive --short v --long verbose --description "Enable verbose mode for the wrapping process and for the wrapped command"
complete --command pisciform --exclusive --short h --long help --description "Print usage info and exit"
complete --command pisciform --long interactive --condition __can_set_interactive --description "Sets the interactive flag on the subshell environment used to run the wrapped command"
complete --command pisciform --long login --condition __can_set_login --description "Sets the login flag on the subshell environment used to run the wrapped command"
complete --command pisciform --long zsh --condition __shell_condition --description "Use ZSH as the environment to run the wrapped command"
complete --command pisciform --long bash --condition __can_set_bash --description "Use BASH as the environment to run the wrapped command"
complete --command pisciform --long sh --condition __can_set_sh --description "Use the system's `sh` as the environment to run the wrapped command"
complete --command pisciform --short a --long autoload --condition __can_set_autoload --force-files --description "Loads a ZSH autoload function file"
complete --command pisciform --short b --long builtin --condition __can_set_builtin --description "Indicates that the wrapping target is a shell built-in"
complete --command pisciform --long init-file --force-files -r --description "Provide the path to a file that should be sourced before calling the function."
