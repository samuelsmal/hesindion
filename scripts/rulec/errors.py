class RulecError(Exception):
    def __init__(self, message: str, file: str | None = None, line: int | None = None):
        self.message, self.file, self.line = message, file, line
        super().__init__(f"{file or '?'}:{line or '?'}: {message}")
