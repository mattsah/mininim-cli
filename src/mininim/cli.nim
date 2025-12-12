import
    mininim,
    mininim/dic,
    std/parseopt

export
    dic

type
    Arg* = object
        name*: string
        require*: bool = false
        description*: string = "No description available"

    Opt* = object
        name*: string
        flag*: string
        values*: seq[string]
        default*: string
        description*: string = "No description available"

    Command* = ref object of Facet
        name*: string
        description*: string
        args*: seq[Arg]
        opts*: seq[Opt]

    CommandHook* = proc(console: Console): int

    Process* = ref object of Class

    Console* = ref object of Class
        name: string
        args*: seq[string]
        opts*: Table[string, string]
        command: Command

begin Command:
    discard

shape Command: @[
    Hook(
        call: CommandHook as (
            block:
                let
                    command = this.app.get(shape)

                result = command.execute(console)
        )
    )
]

begin Process:
    method execute(console: Console): int =
        result = 0

shape Process: @[
]

begin Console:
    #[
        Constructor
    ]#
    method init*(): void =
        this.name = os.getAppFilename().split({'/', '\\'})[^1]

    #[
        Get the general help message
    ]#
    method help() =
        var
            commands = this.app.config.findall(Command)

        echo unindent(
            fmt """

                usage: {this.name} [command]

                {"-h, --help".alignLeft(20)} Get help for the command
            """
        )

        if commands.len > 0:
            echo unindent(
                fmt """
                    commands:
                """
            )
        else:
            echo unindent(
                fmt """
                    No commands available.
                """
            )

        commands.sort(
            proc(a: Command, b: Command): int =
                result = cmp(a.name, b.name)
        )

        for command in commands:
            echo fmt """{command.name.alignLeft(20)} {command.description}"""

        echo ""

    #[
        Get the help for an individual command
    ]#
    method help(command: Command): void =
        var
            defs: seq[string]
            optDef: string

        for opt in command.opts:
            optDef = ""

            if not bool opt.default.len:
                if bool opt.flag.len:
                    optDef = fmt """-{opt.flag}"""
                else:
                    optDef = fmt """--{opt.name}"""

                if bool opt.values.len:
                    optDef.add(":")
                    optDef.add(opt.values[0])

                defs.add(optDef)

        for arg in command.args:
            if arg.require:
                defs.add(fmt "[{arg.name}]")

        echo unindent(
            fmt """

                usage: {this.name} {command.name} {defs.join(" ")}
            """
        )

        echo fmt """{"-h, --help".alignLeft(20)} Get help for the command"""

        for opt in command.opts:
            optDef = ""

            if bool opt.flag.len:
                optDef.add(fmt "-{opt.flag}")

                if bool opt.name.len:
                    optDef.add(", ")
            else:
                optDef.add("    ")

            if bool opt.name.len:
                optDef.add(fmt "--{opt.name}")

            echo fmt """{optDef.alignLeft(20)} {opt.description}"""

        echo ""

    #[
        Gets an argument that was passed as it relates to a given command
    ]#
    method getArg(command: Command, name: string, default: string = ""): string =
        result = default

        for i, arg in command.args:
            if arg.name == name:
                if this.args.len > (i + 1):
                    result = this.args[i + 1]
                    break

    #[
        Gets an argument that was passed as it relates to the current command
    ]#
    method getArg*(name: string, default: string = ""): string =
        return this.getArg(this.command, name, default)

    #[
        Get an option that was passed as it relates to a given command
    ]#
    method getOpt(command: Command, names: varargs[string]): string =
        result = ""

        for name in names:
            if this.opts.hasKey(name):
                if bool this.opts[name].len:
                    result = this.opts[name]
                else:
                    result = $true
                break

            else:
                for opt in command.opts:
                    if name == opt.flag or name == opt.name:
                        result = opt.default
                        break

    #[
        Get an option that was passed as it relates to a given command
    ]#
    method getOpt*(names: varargs[string]): string =
        return this.getOpt(this.command, names)

    #[
        Check whether or not an argument was passed as it relates to a given command
    ]#
    method hasArg(command: Command, name: string): bool =
        result = false

        for i, arg in command.args:
            if arg.name == name:
                result = this.args.len > (i + 1)
                break

    #[
        Check whether or not an option was passed as it relates to a given command
    ]#
    method hasOpt(command: Command, names: varargs[string]): bool =
        result = false

        for name in names:
            if this.opts.hasKey(name):
                result = true
                break

    #[
        Check whether or not the console call is valid for a given command
    ]#
    method isValid(command: Command): bool =
        var
            errors = 0
            value: string

        for arg in command.args:
            if arg.require and not this.hasArg(command, arg.name):
                inc errors
                echo fmt """Argument [{arg.name}] is required, but was not provided."""

        for opt in command.opts:
            if not (bool opt.default.len) and not this.hasOpt(command, opt.flag, opt.name):
                inc errors
                echo fmt """Option [{opt.name}] requires a value, but none was provided."""

            if (bool opt.values.len) and this.hasOpt(command, opt.flag, opt.name):
                value = this.getOpt(command, opt.flag, opt.name)

                if not (value in opt.values):
                    inc errors
                    echo fmt """Option [{opt.name}] value of '{value}' is invalid, options: {opt.values.join(", ")}"""

        if bool errors:
            result = false
        else:
            result = true


    #[
        Run the console
    ]#
    method run*(): int =
        result = 0

        for kind, key, val in getopt():
            case kind
                of cmdArgument:
                    this.args.add(key)
                of cmdLongOption, cmdShortOption:
                    this.opts[key] = val
                of cmdEnd:
                    discard

        if bool this.args.len:
            let
                command = this.app.config.findOne(Command, (name: this.args[0]))

            if command != nil:
                if this.hasOpt(command, "h", "help") or not this.isValid(command):
                    this.help(command)
                else:
                    this.command = command

                    result = command[CommandHook](this)
            else:
                result = 1
                echo fmt "Unknown command {this.args[0]}, use --help to list commands."
        else:
            this.help()

shape Console: @[
    Shared(),
    Delegate(
        call: DelegateHook as (
            block:
                result = shape.init()
        )
    )
]
