"""API HTTP do Meowdoku (e do Sudoku herdado do template).

Esta camada é só "cola": recebe JSON, valida o formato com Pydantic, chama o
Prolog (via app/prolog.py) e devolve JSON. Nenhuma regra do jogo mora aqui.

Rodar em modo de desenvolvimento (recarrega ao salvar):
    uv run fastapi dev app/main.py

Documentação interativa gerada automaticamente: http://localhost:8000/docs
"""

from typing import Annotated, Literal, Self

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field, model_validator

from app import prolog, meowdoku_prolog

app = FastAPI(title="Meowdoku (Prolog + Elm)")

# Uma linha tem exatamente 9 inteiros de 0 a 9; um tabuleiro tem 9 linhas.
# O Pydantic rejeita automaticamente (erro 422) qualquer coisa fora disso.
Cell = Annotated[int, Field(ge=0, le=9)]
Row = Annotated[list[Cell], Field(min_length=9, max_length=9)]
Grid = Annotated[list[Row], Field(min_length=9, max_length=9)]


class GenerateRequest(BaseModel):
    difficulty: Literal["easy", "medium", "hard"] = "medium"


class BoardRequest(BaseModel):
    board: Grid


class BoardResponse(BaseModel):
    board: Grid


class HintResponse(BaseModel):
    row: int
    col: int
    value: int


# Mensagens que o Elm mostra na tela quando a resposta é 422.
NO_SOLUTION = "Este tabuleiro não tem solução. Confira os números preenchidos."
BOARD_COMPLETE = "O tabuleiro já está completo."


@app.post("/api/generate")
def generate(request: GenerateRequest) -> BoardResponse:
    return BoardResponse(board=prolog.generate(request.difficulty))


@app.post("/api/solve")
def solve(request: BoardRequest) -> BoardResponse:
    try:
        return BoardResponse(board=prolog.solve(request.board))
    except prolog.NoSolution:
        # `from None` diz que a HTTPException SUBSTITUI a exceção original,
        # em vez de ser "causada" por ela; o traceback fica mais limpo.
        raise HTTPException(status_code=422, detail=NO_SOLUTION) from None


@app.post("/api/hint")
def hint(request: BoardRequest) -> HintResponse:
    try:
        row, col, value = prolog.hint(request.board)
    except prolog.NoSolution:
        raise HTTPException(status_code=422, detail=NO_SOLUTION) from None
    except prolog.BoardComplete:
        raise HTTPException(status_code=422, detail=BOARD_COMPLETE) from None
    return HintResponse(row=row, col=col, value=value)


# Mensagens que o Elm mostra quando a resposta é 400.
MEOWDOKU_NO_SOLUTION = "Este mapa de territórios não tem solução."
MEOWDOKU_INCONSISTENT = (
    "Os gatos posicionados não levam a nenhuma solução. Remova algum e tente de novo."
)
MEOWDOKU_COMPLETE = "O tabuleiro já possui todos os gatos posicionados."

# Validação só de FORMATO; as regras do jogo continuam no Prolog.
CatsPerUnit = Annotated[int, Field(ge=1, le=2, description="Gatos por linha, coluna e território.")]
Cell = Annotated[int, Field(ge=-1, le=1, description="-1 = marcada com X, 0 = vazia, 1 = gato.")]
Regions = Annotated[
    list[list[Annotated[int, Field(ge=0)]]],
    Field(min_length=4, max_length=10, description="Id do território de cada casa (N x N, ids 0..N-1)."),
]

EXAMPLE_REGIONS = [
    [0, 0, 1, 1, 1, 2],
    [0, 0, 1, 1, 2, 2],
    [0, 3, 3, 1, 2, 2],
    [3, 3, 3, 4, 4, 2],
    [5, 5, 3, 4, 4, 4],
    [5, 5, 5, 5, 4, 4],
]


class MeowdokuExampleResponse(BaseModel):
    name: str
    size: int
    cats_per_unit: int
    regions: list[list[int]]


class MeowdokuSolveRequest(BaseModel):
    model_config = {"json_schema_extra": {"examples": [{"regions": EXAMPLE_REGIONS, "cats_per_unit": 1}]}}

    regions: Regions
    cats_per_unit: CatsPerUnit = 1

    @model_validator(mode="after")
    def check_regions(self) -> Self:
        size = len(self.regions)
        if any(len(row) != size for row in self.regions):
            raise ValueError("regions deve ser uma grade quadrada N x N.")
        if {cell for row in self.regions for cell in row} != set(range(size)):
            raise ValueError(f"regions deve ter exatamente {size} territórios, com ids de 0 a {size - 1}.")
        return self


class MeowdokuSolveResponse(BaseModel):
    solution: list[list[int]] = Field(description="1 = gato, 0 = casa vazia.")


class MeowdokuHintRequest(MeowdokuSolveRequest):
    model_config = {
        "json_schema_extra": {
            "examples": [{"regions": EXAMPLE_REGIONS, "board": [[0] * 6] * 6, "cats_per_unit": 1}]
        }
    }

    board: list[list[Cell]] = Field(description="Estado atual do jogador, mesmo tamanho de regions.")

    @model_validator(mode="after")
    def check_board(self) -> Self:
        size = len(self.regions)
        if len(self.board) != size or any(len(row) != size for row in self.board):
            raise ValueError(f"board deve ter o mesmo tamanho de regions ({size} x {size}).")
        return self


class MeowdokuHintResponse(BaseModel):
    row: int = Field(description="Linha da casa sugerida (a partir de 0).")
    col: int = Field(description="Coluna da casa sugerida (a partir de 0).")
    value: int = Field(description="1 = colocar gato, 0 = a casa não pode ter gato.")
    reason: str = Field(description="Explicação da dedução, gerada pelo Prolog.")


class ErrorResponse(BaseModel):
    detail: str


@app.get(
    "/api/meowdoku/example",
    responses={404: {"model": ErrorResponse, "description": "Exemplo inexistente."}},
)
def meowdoku_example(name: str = "classic_6x6") -> MeowdokuExampleResponse:
    """Devolve um mapa de territórios pré-definido no Prolog."""
    try:
        return MeowdokuExampleResponse(**meowdoku_prolog.get_example(name))
    except meowdoku_prolog.UnknownExample:
        available = ", ".join(meowdoku_prolog.list_examples())
        raise HTTPException(
            status_code=404, detail=f"Exemplo '{name}' não existe. Disponíveis: {available}."
        ) from None


@app.post(
    "/api/meowdoku/solve",
    responses={400: {"model": ErrorResponse, "description": "O mapa não tem solução."}},
)
def meowdoku_solve(request: MeowdokuSolveRequest) -> MeowdokuSolveResponse:
    """Resolve o mapa inteiro com CLP(FD)."""
    try:
        solution = meowdoku_prolog.solve(request.regions, request.cats_per_unit)
    except meowdoku_prolog.NoSolution:
        raise HTTPException(status_code=400, detail=MEOWDOKU_NO_SOLUTION) from None
    return MeowdokuSolveResponse(solution=solution)


@app.post(
    "/api/meowdoku/hint",
    responses={400: {"model": ErrorResponse, "description": "Tabuleiro completo ou sem solução."}},
)
def meowdoku_hint(request: MeowdokuHintRequest) -> MeowdokuHintResponse:
    """Sugere a próxima jogada a partir do estado do jogador, com a justificativa."""
    try:
        hint = meowdoku_prolog.hint(request.regions, request.board, request.cats_per_unit)
    except meowdoku_prolog.BoardComplete:
        raise HTTPException(status_code=400, detail=MEOWDOKU_COMPLETE) from None
    except meowdoku_prolog.NoSolution:
        raise HTTPException(status_code=400, detail=MEOWDOKU_INCONSISTENT) from None
    return MeowdokuHintResponse(**hint)
