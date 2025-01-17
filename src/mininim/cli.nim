import
    mininim,
    mininim/dic

export
    dic

type
    CommandHook = proc(app: var App): int {. cdecl  .}

class Command of Facet:
    var
        name*: string
        description*: string

    method execute(app: var App): int

shape Command: @[
    Hook(
        call: proc(app: var App): int =
            let command = app.get(Command)

            result = command.execute(app)
    )
]

class Console:
    var
        app: App

    method build*(app: var App): Console {. static .} =
        result = Console.init(app)

    method init*(app: var App): void =
        this.app = app

    method run*(): int =
        result = 0

        let commands = this.app.config.findAll(Command)

        for command in commands:
            if command.name == "":
                result = cast[CommandHook](command.hook)(this.app)


shape Console: @[
    Delegate()
]
