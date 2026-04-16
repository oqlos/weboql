from fastapi.testclient import TestClient

from weboql.main import app


client = TestClient(app)


def test_schema_endpoint_returns_shared_catalog():
    response = client.get("/api/v1/schema")

    assert response.status_code == 200
    payload = response.json()

    assert payload["source"] == "oqlos"
    assert {dialect["id"] for dialect in payload["dialects"]} >= {"cql", "oql"}
    assert "pompa" in payload["objectFunctionMap"]
    assert payload["paramUnitMap"]["ciśnienie"]["units"] == ["mbar", "bar"]


def test_dsl_page_is_served():
    response = client.get("/dsl")

    assert response.status_code == 200
    assert "DSL Client for CQL and OQL" in response.text