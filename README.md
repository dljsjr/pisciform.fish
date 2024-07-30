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
2. Awesome tools like [bass](https://github.com/edc/bass) and [replay](https://github.com/jorgebucaran/replay.fish) already exist and do a pretty good job handling the `source` story for scripts targeting other shells, though they have some edge cases

That left one hole, though: Shell functions. Which really sucked for me, because I write a *lot* of shell functions.

***Why shell functions?***

The short answer is that a shell function can mutate the calling shell, unlike a shell script. It's similar to when a script gets sourced. I've been using `zsh` for a very long time, long before macOS made it its new default. And `zsh` has a really awesome facility for [defining and autoloading](https://zsh.sourceforge.io/Doc/Release/Functions.html) user-defined functions, meaning I had accumulated a *lot* of them over the years for automations where I wanted to mutate my shell environment.

## Usage

```console
$ pisciform --help
NAME:
  pisciform - Create a fish function/alias for invoking a Bash/ZSH/Posix shell function and capturing environment changes

USAGE:
  pisciform [-h|--help] [-v|--verbose] [--interactive] [--login] [{-f|--file}|{-b|--builtin}] [--sh|--zsh|--bash] FUNCTION_NAME

OPTIONS:
  -h, --help                print this usage, then return
  -v, --verbose             Sets a "verbose" flag for tracing the wrapped process, and generates a verbose version of the 'runner'
  --interactive             Set the interactive flag on the runner shell
  --login                   Set the login flag on the runner shell.
  --sh, --zsh, --bash       Mutually exclusive. Selects which runner to use. Defaults to `sh`
  -b, --builtin             Instructs the runner that the command being wrapped is a shell built-in instead of a function defined in a file
  -f, --file                Only availble when `--zsh` is set. Instructs the runner to pass the given file to `autoload -U`. Treats the file name as the function name, and adds its containing directory to the runner's `fpath`.

EXAMPLES
  # creates a fish function called `do_something` that invokes the autoloadable ZSH function in the given file
  pisciform --interactive --zsh --file "$HOME/.zfunc/do_something"
```

## What Does Pisciform Do?

In a nutshell, it dynamically adds a function to the current `fish` session that wraps the target function in a different shell environment.

Then, when you subsequently call the `fish` version of the function, the following happens:

1. A script called a "runner" is executed as an argument to the appropriate shell (`bash`/`zsh`/`sh`)
2. The runner script will create a tempdir to capture information it needs
3. The runner will capture the existing environment variables and alias definitions for the subshell
4. The runner will reset the directory stack so that only the changes from the function are captured.
5. The runner will call the wrapped function or built-in
6. The runner will exit early with the command's status if the status is non-zero
7. The runner will capture the environment variables, aliases, and directory  state from after the command is executed
8. The runner will compute the following deltas and report them to the fish environment:
   1. Environment variables that no longer exist after the command has run; these variables will be erased with `set -e` in the fish environment
   2. Environment variable "upserts"; that is, variables that are new as well as variables that are changed.
      1. Variables that are part of an `export` declaration will be exported in the calling `fish` environment with `set -gx`
      2. Variables that are *not* exported will be set in the calling `fish` environment with `set -g`
   3. Aliases that exist after the script was run but did not exist before it was run will be created with `alias`
9. The fish environment will `pushd` the reversed directory stack from the function execution; in other words, it will start from the bottom so that it ends up with the same final stack order as the subshell had when the function call completed.
   1. If the element on the bottom of the stack is the same as the directory the function was originally called from, it'll get skipped.
10. If the final directory from the directory stack following is not the same as the final value of the `PWD` environment variable, we'll `cd` in to the value that's in the ending version of `PWD`

These values are all captured in a temporary directory created using `mktemp -d`. The wrapper function will clean up the `tmpdir` after execution.

## Pisciform vs Bass or Replay

Pisciform is heavily inspired by `bass` and `replay`, with the same basic philosophy: Use the original shell to execute the command, and play back the changes in the calling `fish` shell. But it does a few things differently:

1. Rather than using `pisciform` to execute the desired command, you run `pisciform` to create a function that mirrors the wrapped function. So if you have a ZSH function `foo`, and you use `pisciform foo`, you'll end up with *a fish function called foo* that you can invoke whenever you want, with whatever arguments you want.
2. `pisciform` is a bit more deliberate in capturing environment changes; sometimes shell setup for the foreign shell might create environment variables or aliases that weren't created by the command itself invoked. `bass` and `replay` would pull those in to the fish environment. `pisciform` attempts to *only* pull in changes that are a direct result of the command you run
3. `pisciform` will also mirror changes to the directory stack, not just the PWD.
4. `pisciform` works with interactive commands
5. `pisciform` can be told that a function should be run in an interactive and/or login subshell, allowing it to utilize the profile and shellrc files in place for the subshell, which can be helpful when initially migrating to `fish`.

## Progress

Right now, ZSH is the primary target; it's where I was coming from, and a lot of care was taken to be able to load functions defined as bare bodies in files, the same way one would do with autoload in ZSH. Bash and SH support shouldn't take much longer to do, as most stuff should be pretty similar.

### Supported "Foreign" Shells

- [x] zsh
- [ ] bash
- [ ] POSIX sh
