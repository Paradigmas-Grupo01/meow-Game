"""Testes da API HTTP (pytest).

Usamos o TestClient do FastAPI: ele chama a aplicação diretamente, sem subir
um servidor nem abrir porta. Cada função `test_*` é um teste; o pytest as
encontra sozinho.

Rodar: `uv run pytest` (na pasta backend) ou `make test-backend` (na raiz).

As regras do Sudoku são testadas em Prolog (prolog/test_sudoku.pl). Aqui
conferimos só a "cola": rotas, formato do JSON e códigos de status.
"""

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

# O mesmo puzzle de example_puzzle/1 em sudoku.pl.
EXAMPLE = [
    [5, 3, 0, 0, 7, 0, 0, 0, 0],
    [6, 0, 0, 1, 9, 5, 0, 0, 0],
    [0, 9, 8, 0, 0, 0, 0, 6, 0],
    [8, 0, 0, 0, 6, 0, 0, 0, 3],
    [4, 0, 0, 8, 0, 3, 0, 0, 1],
    [7, 0, 0, 0, 2, 0, 0, 0, 6],
    [0, 6, 0, 0, 0, 0, 2, 8, 0],
    [0, 0, 0, 4, 1, 9, 0, 0, 5],
    [0, 0, 0, 0, 8, 0, 0, 7, 9],
]


def solved_example() -> list[list[int]]:
    """A solução do puzzle de exemplo, obtida pela própria API."""
    return client.post("/api/solve", json={"board": EXAMPLE}).json()["board"]


def test_solve():
    response = client.post("/api/solve", json={"board": EXAMPLE})
    assert response.status_code == 200
    assert response.json()["board"][0] == [5, 3, 4, 6, 7, 8, 9, 1, 2]


def test_solve_without_solution():
    board = [row[:] for row in EXAMPLE]  # cópia, para não alterar EXAMPLE
    board[0][2] = 5  # dois 5 na primeira linha
    response = client.post("/api/solve", json={"board": board})
    assert response.status_code == 422


def test_solve_rejects_malformed_board():
    # Quem rejeita aqui é o Pydantic, antes de o Prolog ser chamado.
    response = client.post("/api/solve", json={"board": [[1, 2, 3]]})
    assert response.status_code == 422


def test_generate():
    response = client.post("/api/generate", json={"difficulty": "easy"})
    assert response.status_code == 200
    board = response.json()["board"]
    assert len(board) == 9 and all(len(row) == 9 for row in board)
    assert 0 in sum(board, [])  # sum(..., []) concatena as linhas: há casa vazia


def test_hint():
    response = client.post("/api/hint", json={"board": EXAMPLE})
    assert response.status_code == 200
    hint = response.json()
    assert EXAMPLE[hint["row"]][hint["col"]] == 0  # a dica é para uma casa vazia


def test_hint_on_complete_board():
    response = client.post("/api/hint", json={"board": solved_example()})
    assert response.status_code == 422
    assert response.json()["detail"] == "O tabuleiro já está completo."


def test_hint_on_full_board_with_errors():
    board = solved_example()
    board[0][0], board[0][1] = board[0][1], board[0][0]  # troca dois números
    response = client.post("/api/hint", json={"board": board})
    assert response.status_code == 422
    assert "não tem solução" in response.json()["detail"]


# ---------------------------------------------------------------- Meowdoku
#
# As regras são testadas em plunit (prolog/test_meowdoku.pl). Aqui conferimos
# a ponte: rotas, validação do Pydantic e códigos de status.

# Território 0 e 1 têm uma casa cada, vizinhas entre si: não há solução.
UNSOLVABLE_REGIONS = [[0, 1, 2, 2], [2, 2, 2, 2], [3, 3, 3, 3], [3, 3, 3, 3]]


def meowdoku_example(name: str = "classic_6x6") -> dict:
    return client.get("/api/meowdoku/example", params={"name": name}).json()


def meowdoku_solution(example: dict) -> list[list[int]]:
    payload = {"regions": example["regions"], "cats_per_unit": example["cats_per_unit"]}
    return client.post("/api/meowdoku/solve", json=payload).json()["solution"]


def post_hint(example: dict, board: list[list[int]]):
    payload = {"regions": example["regions"], "board": board, "cats_per_unit": example["cats_per_unit"]}
    return client.post("/api/meowdoku/hint", json=payload)


def test_meowdoku_example_route():
    response = client.get("/api/meowdoku/example?name=classic_6x6")
    assert response.status_code == 200
    data = response.json()
    assert data["size"] == 6
    assert data["cats_per_unit"] == 1
    assert len(data["regions"]) == 6


def test_meowdoku_example_unknown_name():
    response = client.get("/api/meowdoku/example?name=nao_existe")
    assert response.status_code == 404
    assert "classic_6x6" in response.json()["detail"]


@pytest.mark.parametrize("name", ["classic_6x6", "lantern_8x8", "double_8x8"])
def test_meowdoku_solve_respects_units(name):
    example = meowdoku_example(name)
    solution = meowdoku_solution(example)
    k, regions = example["cats_per_unit"], example["regions"]
    assert all(sum(row) == k for row in solution)
    assert all(sum(col) == k for col in zip(*solution))
    for region_id in range(example["size"]):
        cells = [solution[r][c] for r, row in enumerate(regions) for c, rid in enumerate(row) if rid == region_id]
        assert sum(cells) == k


def test_meowdoku_solve_without_solution():
    response = client.post("/api/meowdoku/solve", json={"regions": UNSOLVABLE_REGIONS})
    assert response.status_code == 400
    assert "não tem solução" in response.json()["detail"]


@pytest.mark.parametrize(
    "payload",
    [
        {"regions": [[0, 1, 2, 3], [0, 1, 2, 3], [0, 1, 2, 3]]},  # não é quadrada
        {"regions": [[0, 1, 2, 9]] * 4},  # id de território fora de 0..N-1
        {"regions": [[0, 0], [1, 1]]},  # menor que 4 x 4
        {"regions": UNSOLVABLE_REGIONS, "cats_per_unit": 3},
        {"regions": "abc"},
    ],
)
def test_meowdoku_solve_rejects_malformed_payload(payload):
    assert client.post("/api/meowdoku/solve", json=payload).status_code == 422


def test_meowdoku_hint_route():
    example = meowdoku_example()
    board = [[0] * 6 for _ in range(6)]
    response = post_hint(example, board)
    assert response.status_code == 200
    hint = response.json()
    assert 0 <= hint["row"] < 6 and 0 <= hint["col"] < 6
    assert hint["value"] in (0, 1)
    assert board[hint["row"]][hint["col"]] != hint["value"]  # sugere uma mudança
    assert hint["reason"]


def test_meowdoku_hint_points_to_the_solution():
    example = meowdoku_example("lantern_6x6")  # solução única
    solution = meowdoku_solution(example)
    hint = post_hint(example, [[0] * 6 for _ in range(6)]).json()
    assert solution[hint["row"]][hint["col"]] == hint["value"]


def test_meowdoku_hint_on_complete_board():
    example = meowdoku_example("lantern_6x6")
    response = post_hint(example, meowdoku_solution(example))
    assert response.status_code == 400
    assert "todos os gatos" in response.json()["detail"]


@pytest.mark.xfail(reason="hint/4 ainda não detecta tabuleiro inconsistente (issue #2)")
def test_meowdoku_hint_on_inconsistent_board():
    example = meowdoku_example("lantern_6x6")
    board = [[0] * 6 for _ in range(6)]
    board[0][0] = board[0][1] = 1  # dois gatos vizinhos
    response = post_hint(example, board)
    assert response.status_code == 400
    assert "nenhuma solução" in response.json()["detail"]


@pytest.mark.parametrize(
    "board",
    [
        [[0] * 5 for _ in range(6)],  # tamanho diferente de regions
        [[2] * 6 for _ in range(6)],  # valor de casa fora de -1..1
    ],
)
def test_meowdoku_hint_rejects_malformed_board(board):
    assert post_hint(meowdoku_example(), board).status_code == 422


def test_meowdoku_hint_accepts_x_marks():
    board = [[-1] * 6 for _ in range(6)]
    board[0] = [0] * 6
    assert post_hint(meowdoku_example(), board).status_code != 422


def test_swagger_docs():
    assert client.get("/docs").status_code == 200
    paths = client.get("/openapi.json").json()["paths"]
    assert {"/api/meowdoku/example", "/api/meowdoku/solve", "/api/meowdoku/hint"} <= paths.keys()
