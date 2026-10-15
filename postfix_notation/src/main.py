

import argparse

from postfix_notation.stack_lang import ToyLang


def main():
    p = argparse.ArgumentParser(
        prog="stack_lang",
        description="Стековая машина для постфиксной нотации.",
        epilog='Пример: python src/main.py "3 0 4 ~ 2 ~"',
    )
    p.add_argument("expression", nargs="+", help="токены выражения через пробел")
    args = p.parse_args()
    expr = " ".join(args.expression)
    print(f"{expr} = {ToyLang(expr).result}")


if __name__ == "__main__": # pragma: no cover
    main()
