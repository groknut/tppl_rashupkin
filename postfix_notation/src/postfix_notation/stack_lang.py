from collections.abc import Callable


class ToyLang:
    def __init__(self, line: str):
        self._stack: list[float] = []
        self._ops: dict[str, Callable[[float, float], float]] = {
            '+': lambda a, b: a + b,
            '-': lambda a, b: a - b,
            '*': lambda a, b: a * b,
            '/': lambda a, b: a / b if b else (_ for _ in ()).throw(ZeroDivisionError("division by zero")),
            '~': self._tilda,
        }
        for tok in line.split():
            if tok in self._ops and len(self._stack) >= 2:
                b, a = self._stack.pop(), self._stack.pop()
                self._stack.append(self._ops[tok](a, b))
            else:
                try:
                    self._stack.append(float(tok))
                except ValueError:
                    raise ValueError(f"unknown token: {tok}") from None
            print(f"{tok}:>  →  {self._stack}")

    def _tilda(self, a: float, b: float) -> float:
        return abs(a - b) if a and b else (sum(self._stack) + a + b) ** 2

    @property
    def result(self) -> float:
        return self._stack[-1]
