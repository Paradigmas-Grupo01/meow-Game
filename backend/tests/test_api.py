"""Testes da API HTTP (pytest).

Usamos o TestClient do FastAPI: ele chama a aplicação diretamente, sem subir
um servidor nem abrir porta. Cada função `test_*` é um teste; o pytest as
encontra sozinho.

Rodar: `uv run pytest` (na pasta backend) ou `make test-backend` (na raiz).

As regras do Sudoku são testadas em Prolog (prolog/test_sudoku.pl). Aqui
conferimos só a "cola": rotas, formato do JSON e códigos de status.
"""

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


def test_meowdoku_example_route():
    response = client.get("/api/meowdoku/example?name=classic_6x6")
    assert response.status_code == 200
    data = response.json()
    assert data["size"] == 6
    assert data["cats_per_unit"] == 1
    assert len(data["regions"]) == 6


def test_meowdoku_solve_route():
    example_res = client.get("/api/meowdoku/example?name=classic_6x6")
    regions = example_res.json()["regions"]
    response = client.post(
        "/api/meowdoku/solve",
        json={"regions": regions, "cats_per_unit": 1}
    )
    assert response.status_code == 200
    data = response.json()
    assert "solution" in data
    assert len(data["solution"]) == 6


def test_meowdoku_hint_route():
    example_res = client.get("/api/meowdoku/example?name=classic_6x6")
    regions = example_res.json()["regions"]
    board = [[0] * 6 for _ in range(6)]
    board[0] = [-1, -1, -1, -1, -1, 0]
    response = client.post(
        "/api/meowdoku/hint",
        json={"regions": regions, "board": board, "cats_per_unit": 1}
    )
    assert response.status_code == 200
    hint_data = response.json()
    assert hint_data["row"] == 0
    assert hint_data["col"] == 5
    assert "linha" in hint_data["reason"]
    assert hint_data["value"] == 1



def test_meowdoku_example_unknown_name():
    response = client.get("/api/meowdoku/example?name=nao_existe")
    assert response.status_code == 404
    assert "classic_6x6" in response.json()["detail"]


def test_meowdoku_solve_respects_cats_per_unit():
    example = client.get("/api/meowdoku/example?name=double_8x8").json()
    response = client.post(
        "/api/meowdoku/solve",
        json={"regions": example["regions"], "cats_per_unit": example["cats_per_unit"]},
    )
    assert response.status_code == 200
    solution = response.json()["solution"]
    assert all(sum(row) == 2 for row in solution)
    assert all(sum(col) == 2 for col in zip(*solution))


def test_meowdoku_solve_without_solution():
    response = client.post(
        "/api/meowdoku/solve", json={"regions": [[0, 0], [0, 0]], "cats_per_unit": 1}
    )
    assert response.status_code == 400
