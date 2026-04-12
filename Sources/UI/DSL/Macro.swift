@attached(member, names: arbitrary)
// @attached(member, conformances: Component)
// TODO: think of better name
public macro Autobind() =
        #externalMacro(module: "DSLMacro", type: "ComponentMacro")
