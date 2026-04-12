@attached(member, names: overloaded, conformances: Component)
// @attached(member, conformances: Component)
public macro Component() =
        #externalMacro(module: "DSLMacro", type: "ComponentMacro")
