import httpx

from shared.errors import AppError
from shared.http.errors import raise_for_inventory_response


def test_raise_for_inventory_maps_insufficient_stock() -> None:
    response = httpx.Response(
        409,
        json={"code": "insufficient_stock", "message": "Insufficient stock"},
        request=httpx.Request("POST", "http://inventory/api/v1/inventory/consume"),
    )
    try:
        raise_for_inventory_response(response)
        raise AssertionError("expected AppError")
    except AppError as exc:
        assert exc.status_code == 409
        assert exc.code == "insufficient_stock"


def test_raise_for_inventory_maps_5xx_to_502() -> None:
    response = httpx.Response(
        500,
        json={"code": "internal_error", "message": "boom"},
        request=httpx.Request("POST", "http://inventory/x"),
    )
    try:
        raise_for_inventory_response(response)
        raise AssertionError("expected AppError")
    except AppError as exc:
        assert exc.status_code == 502
