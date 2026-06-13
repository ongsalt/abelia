@attached(member, names: arbitrary)
// @attached(member, conformances: Component)
public macro Autobind() =
        #externalMacro(module: "DSLMacro", type: "AutobindMacro")

@attached(peer, names: overloaded)
public macro Component() =
        #externalMacro(module: "DSLMacro", type: "AutobindMacro")
