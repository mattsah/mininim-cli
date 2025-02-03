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
            let
                command = this.app.config.findOne(Command, (name: this.args[0]))

            if command != nil:
                result = cast[CommandHook](command.hook)(this)

shape Console: @[
    Shared(),
    Delegate(
        hook: proc(app: App): Console =
            result = Console.init(app)
    )
]