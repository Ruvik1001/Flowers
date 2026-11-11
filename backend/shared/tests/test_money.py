from decimal import Decimal

from shared.utils.money import Money, quantize_money


def test_quantize_money_rounds_half_up() -> None:
    assert quantize_money("1.005") == Decimal("1.01")
    assert quantize_money(2) == Decimal("2.00")


def test_money_arithmetic() -> None:
    assert Money("10.00") + Money("2.50") == Money("12.50")
    assert Money("10.00") - Money("0.01") == Money("9.99")
    assert Money("2.00") * 3 == Money("6.00")
