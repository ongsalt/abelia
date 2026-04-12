extension Result {
    var error: Failure? {
        do {
            try get()
            return nil
        } catch {
            return error as Failure
        }
    }
}
