import
    mininim,
    std/marshal,
    mininim/dic

class Command of Facet:
    var
        name*: string
        description*: string

shape Command: @[
    Hook(
        call: "execute"
    )
]

class Console:
    var
        app: App

    method init*(app: var App): void =
        this.app = app

    method run*(): int =
        let command = this.app.config.findAll(Command)

        result = 0

shape Console: @[
    Delegate(
        builder: proc(app: var App): Console =
            result = Console.init(app)
    )
]
