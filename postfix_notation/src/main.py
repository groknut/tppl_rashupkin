

import sys

from postfix_notation.stack_lang import ToyLang

if __name__ == "__main__": # pragma: no cover
    expr = " ".join(sys.argv[1:])
    print(f"{expr} = {ToyLang(expr).result}")
