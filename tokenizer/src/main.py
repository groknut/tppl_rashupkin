
import sys

from tokenizer import LexicalError, Tokenizer


def main():
    if len(sys.argv) != 2:
        print("Usage: python main.py <file>", file=sys.stderr)
        sys.exit(2)
    path = sys.argv[1]
    try:
        with open(path, encoding='utf-8') as f:
            source = f.read()
    except (OSError, UnicodeDecodeError) as e:
        print(f"{path}:1:1: lexical: {e}")
        sys.exit(1)
    try:
        tokens = Tokenizer(source, path).tokenize()
    except LexicalError as e:
        print(e)
        sys.exit(1)
    for typ, val, ln, cl in tokens:
        print(f"({typ}, {val}, {ln}:{cl})")


if __name__ == '__main__': # pragma: no cover
    main()
