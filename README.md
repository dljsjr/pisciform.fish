# Pisciform: create Fish functions out of Bash/Zsh/POSIX shell functions

`pisciform` is a `fish` function that creates other functions. Specifically, it turns a function or built-in from another shell in to a `fish` function.

## Installation

Install with [fisher](https://github.com/jorgebucaran/fisher):

```console
fisher install dljsjr/pisciform.fish
```

## Overview/Motivation

Fish is a terrific shell. I first explored it over 10 years ago. One of the main blockers that prevented me from fully switching, though, was collaboration: If a professional or collaborative environment, you need to be able to share your tools with others easily. Especially as a Staff+ engineer, where part of your role is to be a force multiplier for your team(s).

Over the years, it's become a lot easier to share most stuff:

1. Out of the box, shell *scripts* with a proper shebang were always portable and worked fine
2. Awesome tools like [bass](https://github.com/edc/bass) and [replay](https://github.com/jorgebucaran/replay.fish) already exist and do a pretty good job handling the specific use case of `source`'ing bash scripts. But they have edge cases, are limited in what they do, and they only target bash.

That leaves one last pretty large hole as well, though: Shell functions. Which really sucked for me, because I write a *lot* of shell functions.

***Why shell functions?***

The short answer is that a shell function can mutate the calling shell, unlike a shell script. It's similar to when a script gets sourced. I've been using `zsh` for a very long time, long before macOS made it its new default. And `zsh` has a really awesome facility for [defining and autoloading](https://zsh.sourceforge.io/Doc/Release/Functions.html) user-defined functions, meaning I had accumulated a *lot* of them over the years for automations where I wanted to mutate my shell environment.

## Usage

```console
$ pisciform --help
NAME:
  pisciform - Create a fish function/alias for invoking a Bash/ZSH/Posix shell function and capturing environment changes

USAGE:
  pisciform [-h|--help] [-v|--verbose] [--interactive] [--login] [{-f|--file}|{-b|--builtin}] [--sh|--zsh|--bash] [--source ...] FUNCTION_NAME

OPTIONS:
  -h, --help                print this usage, then return
  -v, --verbose             Sets a "verbose" flag for tracing the wrapped process, and generates a verbose version of the 'runner'
  --interactive             Set the interactive flag on the runner shell
  --login                   Set the login flag on the runner shell.
  --sh, --zsh, --bash       Mutually exclusive. Selects which runner to use. Defaults to `sh`
  -b, --builtin             Instructs the runner that the command being wrapped is a shell built-in instead of a function defined in a file
  -a, --autoload            Only availble when `--zsh` is set. The FUNCTION_NAME positional argument should be replaced with the path to
                            a file that contains an autoloadable function definition. The runner will pass the given file to `autoload -U`.
                            The name of the file becomes the function name, and the containing directory for the file will be appended
                            to the runner's `fpath`.
  --init-file               File to `source` before invoking the command. May be specified more than once to source multiple files.
                            Useful for shells like bash or sh where a user function might be defined in an RC file. Note that these files
                            will be sourced *before* the pre-execution environment is captured, so environment modifications performed by
                            these files will *not* be propagated in to the containing shell; they'll only be made available to the function
                            invocation.

EXAMPLES
  # creates a fish function called `do_something` that invokes the autoloadable ZSH function in the given file
  pisciform --interactive --zsh --file "$HOME/.zfunc/do_something"

  # creates a fish function called `foo` around a bash function called `foo`, where foo is a function defined in the file ~/.bashfuncs, so the file must be sourced first.
  pisciform --interactive --bash --init-file ~/.bashfuncs foo
```

### Real-world example

As I mentioned, part of my motiviation for creating this was that I was coming from ZSH and I had accumulated a lot of functions.

I store all of my function definitions for `autoload` in a directory `$HOME/.zfunc`, with subdirs for things like functions that are specific to work or specific topics.

In ZSH, I autoloaded these via my `.zshrc` as so:

```zsh
# ...snip

# ZSH autoloads functions from an FPATH env var, but this var is derived from an array called
# fpath.
# If the .zfunc dir exists and is not already in the `fpath` array, add it as the first element.
# Then call autoload on all the filenames in the directory
# (those shell expansion parameters are ZSH specific and they pull just the file names from non-dirs in said directory)
[[ ${fpath[(Ie)"$HOME/.zfunc"]} -gt ${#fpath} ]] || fpath=("$HOME/.zfunc" $fpath) && autoload ${fpath[1]}/*(:t)

# I have separate similar lines for the subdirectories.

# ...snip
```

In migrating to `fish`, I'm now able to reuse these existing function definitions to hold me over by using `pisciform` in my
fish configs. I'm using fish's [configuration snippets](https://fishshell.com/docs/3.3/index.html#configuration-files) feature, so I have
a `04-pisciform.fish` file in my `~/.config/fish/conf.d` directory that looks like this:

```fish
function __wrap_zsh_autoload
    set -f funcdir $argv[1]
    set -f args --zsh --autoload
    if status is-interactive
        set -f -a args --interactive
    end
    for funcfile in $funcdir/*
        if test -f "$funcfile"
            pisciform $args "$funcfile"
        else if test -d "$funcfile"
            __wrap_zsh_autoload "$funcfile"
        end
    end
end

__wrap_zsh_autoload $HOME/.zfunc
```

## What Does Pisciform Do?

In a nutshell, it dynamically adds a function to the current `fish` session that wraps the target function in a different shell environment.

Then, when you subsequently call the `fish` version of the function, the following happens:

1. A script called a "runner" is executed as an argument to the appropriate shell (`bash`/`zsh`/`sh`)
2. The runner script will create a tempdir to capture the information it needs
3. The runner will source any init files that were passed to the wrapping call
4. The runner will capture the existing environment variables and alias definitions for the subshell
5. The runner will reset the directory stack so that only the changes from the function are captured.
   1. This only applies to Bash and ZSH, since POSIX doesn't have a concept of a directory stack and doesn't have `pushd`/`popd` commands.
6. The runner will call the wrapped function or built-in
7. The runner will exit early with the command's status if the status is non-zero
8. The runner will capture the environment variables, aliases, and directory stack state from after the command is executed
9. The runner will compute the following deltas and report them to the fish environment:
   1. Environment variables that no longer exist after the command has run; these variables will be erased with `set -e` in the fish environment
   2. Environment variable "upserts"; that is, variables that are new as well as variables that are changed.
      1. Variables that are part of an `export` declaration will be exported in the calling `fish` environment with `set -gx`
      2. Variables that are *not* exported will be set in the calling `fish` environment with `set -g`
   3. Aliases that exist after the script was run but did not exist before it was run will be created with `alias`
10. The fish environment will `pushd` the reversed directory stack from the function execution; in other words, it will start from the bottom so that it ends up with the same final stack order as the subshell had when the function call completed.
    1. This only applies to Bash and ZSH, since POSIX doesn't have a concept of a directory stack and doesn't have `pushd`/`popd` commands.
    2. If the element on the bottom of the stack is the same as the directory the function was originally called from, it'll get skipped.
11. If the final directory from the directory stack following is not the same as the final value of the `PWD` environment variable, we'll `cd` in to the value that's in the ending version of `PWD`

These values are all captured in a temporary directory created using `mktemp -d`. The wrapper function will clean up the `tmpdir` after execution.

## Pisciform vs Bass or Replay

Pisciform is heavily inspired by `bass` and `replay`, with the same basic philosophy: Use the original shell to execute the command, and play back the changes in the calling `fish` shell. But it does a few things differently:

1. Rather than using `pisciform` to execute the desired command, you run `pisciform` to create a function that mirrors the wrapped function. So if you have a ZSH function `foo`, and you use `pisciform foo`, you'll end up with *a fish function called foo* that you can invoke whenever you want, with whatever arguments you want.
2. `pisciform` is a bit more deliberate in capturing environment changes; sometimes shell setup for the foreign shell might create environment variables or aliases that weren't created by the command itself invoked. `bass` and `replay` would pull those in to the fish environment. `pisciform` attempts to *only* pull in changes that are a direct result of the command you run
3. `pisciform` will also mirror changes to the directory stack, not just the PWD.
4. `pisciform` works with interactive commands
5. `pisciform` can be told that a function should be run in an interactive and/or login subshell, allowing it to utilize the profile and shellrc files in place for the subshell, which can be helpful when initially migrating to `fish`.
6. Both `bass` and `replay` only support `bash` as the target for running non-fish shell commands. `pisciform` supports POSIX and ZSH dialects as well.

## Progress

Right now, ZSH is the primary target; it's where I was coming from, and a lot of care was taken to be able to load functions defined as bare bodies in files, the same way one would do with autoload in ZSH. Bash and SH support shouldn't take much longer to do, as most stuff should be pretty similar.

### Implemented Features

- [x] Execute function calls defined in a ZSH-compatible way
  - [x] Support ZSH autoload function files
- [x] Execute function calls defined in a BASH-compatible way
- [x] Execute function calls in POSIX `/bin/sh`
- [x] Support `interactive` subshells
- [x] Support `login` subshells
- [x] Provide a list of files to be `source`'d before calling the function
- [x] Support shell built-ins as well as functions for implemented shells
- [x] Support replaying environment variable add/delete/modification for supported shells
- [x] Support aliases added in supported shells
- [x] Support directory changes in supported shells
- [x] Support replaying changes to the directory stack in supported shells

### Planned Features
- [ ] Immediate execution of commands instead of generating function calls
  - [ ] Immediately invoke a function as a one-off, replaying changes but not creating a Fish function
  - [ ] Support a `source` mode that sources a file instead of trying to execute a command (different from existing init file support)
- [ ] Investigate "shell daemons" to avoid forking overhead
  - [ ] Would need to be able to "reset" shell environments in between command invocations
