import
    mininim,
    mininim/dic,
    std/parseopt

export
    dic # required since our hook calls `app.get`

type
    Command* = ref object of Facet
        name*: string
        description*: string

    Console* = ref object of Class
        app*: App
        args*: seq[string]
        opts*: Table[string, string]

    CommandHook = proc(console: var Console): int {. cdecl .}

    CommandConcept* = concept x

begin Command:
    method execute(console: var Console): int {. base .} =
        discard

shape Command: @[
    Hook(
        call: proc(console: var Console): int =
            var command = console.app.get(Command)

            doAssert(
                Command is CommandConcept,
                "Failed to implement required fields and methods"
            )

            result = command.execute(console)
    )
]

begin Console:
    method init*(app: var App): void {. base .} =
        this.app = app

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

        if this.args.len > 0:
            let command = this.app.config.findOne(Command, (name: this.args[0]))

            if command != nil:
                result = cast[CommandHook](command.hook)(this)

shape Console: @[
    Shared(),
    Delegate(
        hook: proc(app: var App): Console =
            result = Console.init(app)
    )
]