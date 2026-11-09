import sys

import pytest

from main import main
from tokenizer import LexicalError, Tokenizer


def tok(src):
    return Tokenizer(src, 'f').tokenize()


def test_simple():
    assert tok("x = 1 + 2") == [
        ('IDENT', 'x', 1, 1), ('OP', '=', 1, 3),
        ('INT', '1', 1, 5), ('OP', '+', 1, 7), ('INT', '2', 1, 9),
    ]


def test_empty_and_comment():
    assert tok("") == []
    assert tok("# hi\n") == []


def test_keyword_vs_ident():
    assert [t[0] for t in tok("if x")] == ['KEYWORD', 'IDENT']


def test_numbers():
    assert [(t[0], t[1]) for t in tok("42 3.14 .5")] == [
        ('INT', '42'), ('FLOAT', '3.14'), ('FLOAT', '.5'),
    ]


def test_operators_and_seps():
    ts = tok("== <= >= < > = + - * / ( ) { } , ;")
    assert [t[1] for t in ts] == [
        '==', '<=', '>=', '<', '>', '=', '+', '-', '*', '/',
        '(', ')', '{', '}', ',', ';',
    ]


def test_string():
    assert tok('"hi"') == [('STRING', '"hi"', 1, 1)]
    assert tok(r'"a\"b"')[0][0] == 'STRING'


def test_positions():
    assert tok("a\n  b") == [('IDENT', 'a', 1, 1), ('IDENT', 'b', 2, 3)]


def test_bad_char():
    with pytest.raises(LexicalError) as e:
        tok("a @ b")
    assert str(e.value) == "f:1:3: lexical: unexpected character '@'"


def test_unterminated_string():
    with pytest.raises(LexicalError):
        tok('"abc')


def test_main_ok(monkeypatch, capsys, tmp_path):
    f = tmp_path / "in.txt"
    f.write_text("x = 1")
    monkeypatch.setattr(sys, 'argv', ['main.py', str(f)])
    main()
    assert "(IDENT, x, 1:1)" in capsys.readouterr().out


def test_main_no_args(monkeypatch):
    monkeypatch.setattr(sys, 'argv', ['main.py'])
    with pytest.raises(SystemExit) as e:
        main()
    assert e.value.code == 2


def test_main_missing_file(monkeypatch, capsys, tmp_path):
    monkeypatch.setattr(sys, 'argv', ['main.py', str(tmp_path / 'no.txt')])
    with pytest.raises(SystemExit) as e:
        main()
    assert e.value.code == 1
    assert "lexical" in capsys.readouterr().out


def test_main_lexical_error(monkeypatch, capsys, tmp_path):
    f = tmp_path / "in.txt"
    f.write_text("@")
    monkeypatch.setattr(sys, 'argv', ['main.py', str(f)])
    with pytest.raises(SystemExit) as e:
        main()
    assert e.value.code == 1
    assert "unexpected character '@'" in capsys.readouterr().out
