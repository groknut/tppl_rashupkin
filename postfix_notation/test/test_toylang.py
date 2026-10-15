# test_toy_lang.py
import pytest

from src.postfix_notation.stack_lang import ToyLang


def calc(expr: str) -> float:
    return ToyLang(expr).result


@pytest.mark.parametrize("expr, expected", [
    ("2 3 +", 5),
    ("2 3 -", -1),
    ("2 3 *", 6),
    ("6 3 /", 2),
    ("2 3 + 4 -", 1),
    ("2 2 + 4 - 4 ~ 2 3 * +", 22),
    ("3 0 4 ~ 2 ~", 47),
    ("0 0 ~", 0),
    ("5 0 ~", 25),
])
def test_expressions(expr, expected):
    assert calc(expr) == expected


def test_division_by_zero():
    with pytest.raises(ZeroDivisionError):
        calc("1 0 /")


def test_unknown_token():
    with pytest.raises(ValueError, match="unknown token"):
        calc("2 3 @")


def test_not_enough_operands():
    with pytest.raises(ValueError):
        calc("2 +")
