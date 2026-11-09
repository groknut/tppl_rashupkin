import re

KEYWORDS = {
    'if', 'else', 'while', 'return', 'for', 'def'
}

class LexicalError(Exception):
    def __init__(self, filename, line, col, message):
        super().__init__(f"{filename}:{line}:{col}: lexical: {message}")
        self.filename, self.line, self.col, self.message = filename, line, col, message

class Tokenizer:
    __TOKEN_RE = re.compile(r'''
        (?P<COMMENT>\#[^\n]*)
      | (?P<WS>\s+)
      | (?P<FLOAT>\d+\.\d*|\.\d+)
      | (?P<INT>\d+)
      | (?P<IDENT>[A-Za-z_]\w*)
      | (?P<STRING>"(?:\\[\s\S]|[^"\\\n])*")
      | (?P<OP>==|<=|>=|[-+*/=<>])
      | (?P<SEP>[(){},;])
    ''', re.VERBOSE)

    def __init__(self, source: str, filename: str = '<input>') -> None:
        self.source = source
        self.filename = filename

    def _error(self, line: int, col: int, ch: str):
        msg = ('unterminated string literal' if ch == '"'
                else f"unexpected character '{ch}'")
        raise LexicalError(self.filename, line, col, msg)

    def tokenize(self):
        tokens, pos, line, col = [], 0, 1, 1
        for m in self.__TOKEN_RE.finditer(self.source):
            if m.start() != pos:
                self._error(line, col, self.source[pos])

            kind, text = m.lastgroup, m.group()

            if kind not in ('COMMENT', 'WS'):
                typ = 'KEYWORD' if kind == 'IDENT' and text in KEYWORDS else kind
                tokens.append((typ, text, line, col))

            nl = text.count('\n')
            line += nl
            col = len(text) - text.rfind('\n') if nl else col + len(text)
            pos = m.end()

        if pos < len(self.source):
            self._error(line, col, self.source[pos])
        return tokens
