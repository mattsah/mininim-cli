import
    mininim,
    mininim/dic,
    std/parseopt

export
    dic

type
    CommandHook = proc(app: var App): int {. cdecl .}
    CommandConcept* = concept x
        x.execute(var App) is int

#[
## Command
]#
class Command of Facet:
    var
        name*: string
        description*: string

    method execute(app: var App): int

shape Command: @[
    Hook(
        call: proc(app: var App): int =
            let command = app.get(Command)

            doAssert(
                Command is CommandConcept,
                "Failed to implement required fields and methods"
            )

            result = command.execute(app)
    )
]

#[
## Console
]#
class Console:
    var
        app*: App
        args*: seq[string]
        opts*: Table[string, string]

    method build*(app: var App): Console {. static .} =
        result = Console.init(app)

    method init*(app: var App): void =
        this.app = app

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

        if this.args.len > 0:
            let command = this.app.config.findOne(Command, (name: this.args[0]))

            if command != nil:
                result = cast[CommandHook](command.hook)(this.app)

shape Console: @[
#    Shared(),
    Delegate()
]
