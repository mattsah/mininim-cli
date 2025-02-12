import
    mininim,
    mininim/dic,
    std/parseopt

export
    dic # required since our hook calls `app.get`

type
    Arg* = object
        name*: string
        require*: bool = false
        description*: string = "No description available"

    Opt* = object
        long*: string
        short*: string
        values*: seq[string]
        require*: bool = false
        description*: string = "No description available"

    Command* = ref object of Facet
        name*: string
        description*: string
        args*: seq[Arg]
        opts*: seq[Opt]

    Process* = ref object of Class

    Console* = ref object of Class
        app*: App
        args*: seq[string]
        opts*: Table[string, string]

    CommandHook = proc(console: Console): int {. nimcall .}
    CommandConcept* = concept x

begin Process:
    method execute(console: Console): int {. base .} =
        discard

shape Command: @[
    Hook(
        swap: Process,
        call: proc(console: Console): int =
            let process = console.app.get(Process)

            doAssert(
                Command is CommandConcept,
                "Failed to implement required fields and methods"
            )

            result = process.execute(console)
    )
]

begin Console:
    method init*(app: App): void {. base, mutator .} =
        this.app = app

    method help() {. base .} =
        echo unindent(
            fmt """

                Welcome to mininim.

                usage: mininim [command]

                {"-h, --help".alignLeft(20)} Get help for the command

                commands:
            """
        )

        var
            commands = this.app.config.findall(Command)

        commands.sort(
            proc(a: Command, b: Command): int =
                result = cmp(a.name, b.name)
        )

        for command in commands:
            echo fmt """{command.name.alignLeft(20)} {command.description}"""

        echo ""

    method help(command: Command): void {. base .} =
        var
            defs: seq[string]
            optDef: string

        for opt in command.opts:
            optDef = ""

            if opt.require:
                if bool opt.short.len:
                    optDef = fmt "-{opt.short}"
                else:
                    optDef = fmt "--{opt.long}"

                if bool opt.values.len:
                    optDef.add(":")
                    optDef.add(opt.values[0])

                defs.add(optDef)

        for arg in command.args:
            if arg.require:
                defs.add(fmt "[{arg.name}]")

        echo unindent(
            fmt """

                usage: mininim {command.name} {defs.join(" ")}

            """
        )

        echo fmt """{"-h, --help".alignLeft(20)} Get help for the command"""

        for opt in command.opts:
            optDef = ""

            if bool opt.short.len:
                optDef.add(fmt "-{opt.short}")

                if bool opt.long.len:
                    optDef.add(", ")
            else:
                optDef.add("    ")

            if bool opt.long.len:
                optDef.add(fmt "--{opt.long}")

            echo fmt """{optDef.alignLeft(20)} {opt.description}"""

        echo ""

    #[
        Check whether or not an option was passed
    ]#
    method hasOpt(names: varargs[string]): bool {. base .} =
        result = false

        for name in names:
            if this.opts.hasKey(name):
                return true

    #[
        Run the console
    ]#
    method run*(): int {. base .} =
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
                if this.hasOpt("h", "help"):
                    this.help(command)
                else:
                    result = cast[CommandHook](command.hook)(this)
            else:
                result = 1
                echo fmt "Unknown command {this.args[0]}, use --help to list commands."
        else:
            this.help()


shape Console: @[
    Shared(),
    Delegate(
        hook: proc(app: App): Console =
            result = Console.init(app)
    )
]