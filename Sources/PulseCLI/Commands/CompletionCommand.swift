//
//  CompletionCommand.swift
//  PulseCLI
//
//  "pulse completion" — generate shell completion scripts.
//

import Foundation

enum CompletionCommand {

    static func run(_ args: [String]) -> Int32 {
        if args.contains("--help") || args.contains("-h") {
            print("Usage: pulse completion <shell>")
            print()
            print("Generate shell completion scripts for Pulse CLI.")
            print()
            print("Supported shells:")
            print("  zsh    Zsh completion script")
            print("  bash   Bash completion script")
            print()
            print("Examples:")
            print("  pulse completion zsh > /usr/local/share/zsh/site-functions/_pulse")
            print("  pulse completion bash > /etc/bash_completion.d/pulse")
            return EXIT_SUCCESS
        }

        guard let shell = args.first else {
            print("Error: Specify a shell type (zsh or bash)")
            print()
            print("Usage: pulse completion <shell>")
            return EXIT_FAILURE
        }

        switch shell {
        case "zsh":
            print(zshCompletion)
            return EXIT_SUCCESS
        case "bash":
            print(bashCompletion)
            return EXIT_SUCCESS
        default:
            print("Error: Unsupported shell '\(shell)'")
            print("Supported shells: zsh, bash")
            return EXIT_FAILURE
        }
    }

    // MARK: - Zsh Completion

    private static let zshCompletion = """
    #compdef pulse

    _pulse() {
        local -a commands
        local -a profiles
        local -a options

        commands=(
            'analyze:Scan for cleanup candidates'
            'clean:Preview or execute cleanup'
            'completion:Generate shell completion scripts'
            'doctor:Verify Pulse installation and environment'
            'help:Show help message'
        )

        profiles=(
            'xcode:Xcode caches'
            'homebrew:Homebrew caches'
            'node:Node.js package manager caches'
        )

        options=(
            '--help:Show help'
            '--version:Show version'
            '--json:Output as JSON'
            '--profile:Target a specific cleanup profile'
            '--dry-run:Preview cleanup without deleting'
            '--apply:Execute cleanup'
        )

        _arguments -C \\
            '1: :->command' \\
            '*: :->rest' && return 0

        case $state in
            command)
                _describe 'command' commands
                ;;
            rest)
                case $words[2] in
                    analyze)
                        _arguments \\
                            '--help[Show help]' \\
                            '--json[Output as JSON]'
                        ;;
                    clean)
                        _arguments \\
                            '--help[Show help]' \\
                            '--json[Output as JSON]' \\
                            '--dry-run[Preview cleanup]' \\
                            '--apply[Execute cleanup]' \\
                            '--profile[Target a specific profile]:profile:(_describe -t profiles "profile" profiles)'
                        ;;
                    completion)
                        _arguments \\
                            '--help[Show help]' \\
                            '1:shell:(zsh bash)'
                        ;;
                    doctor)
                        _arguments \\
                            '--help[Show help]'
                        ;;
                esac
                ;;
        esac
    }

    _pulse "$@"
    """

    // MARK: - Bash Completion

    private static let bashCompletion = """
    _pulse() {
        local cur prev opts commands profiles
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        commands="analyze clean completion doctor help --help --version"
        profiles="xcode homebrew node"
        opts="--help --version --json --profile --dry-run --apply"

        case "${COMP_CWORD}" in
            1)
                COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
                return 0
                ;;
        esac

        case "${prev}" in
            --profile)
                COMPREPLY=( $(compgen -W "${profiles}" -- ${cur}) )
                return 0
                ;;
            completion)
                COMPREPLY=( $(compgen -W "zsh bash" -- ${cur}) )
                return 0
                ;;
        esac

        case "${COMP_WORDS[1]}" in
            analyze)
                COMPREPLY=( $(compgen -W "--help --json" -- ${cur}) )
                return 0
                ;;
            clean)
                COMPREPLY=( $(compgen -W "--help --json --dry-run --apply --profile" -- ${cur}) )
                return 0
                ;;
            doctor)
                COMPREPLY=( $(compgen -W "--help" -- ${cur}) )
                return 0
                ;;
            completion)
                COMPREPLY=( $(compgen -W "zsh bash --help" -- ${cur}) )
                return 0
                ;;
        esac

        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    }

    complete -F _pulse pulse
    """
}
