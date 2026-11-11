from app.domain import Assembly


class AssemblyStore:
    def __init__(self) -> None:
        self.assemblies: dict[str, Assembly] = {}


store = AssemblyStore()
