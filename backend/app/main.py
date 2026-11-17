"""API HTTP do Sudoku.

Esta camada é só "cola": recebe JSON, valida o formato com Pydantic, chama o
Prolog (via app/prolog.py) e devolve JSON. Nenhuma regra do jogo mora aqui.

Rodar em modo de desenvolvimento (recarrega ao salvar):
    uv run fastapi dev app/main.py

Documentação interativa gerada automaticamente: http://localhost:8000/docs
"""

from typing import Annotated, Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

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


class MeowdokuExampleResponse(BaseModel):
    name: str
    size: int
    cats_per_unit: int
    regions: list[list[int]]


class MeowdokuSolveRequest(BaseModel):
    regions: list[list[int]]
    cats_per_unit: int = 1


class MeowdokuSolveResponse(BaseModel):
    solution: list[list[int]]


class MeowdokuHintRequest(BaseModel):
    regions: list[list[int]]
    board: list[list[int]]
    cats_per_unit: int = 1


class MeowdokuHintResponse(BaseModel):
    row: int
    col: int
    value: int
    reason: str


@app.get("/api/meowdoku/example")
def meowdoku_example(name: str = "classic_6x6") -> MeowdokuExampleResponse:
    data = meowdoku_prolog.get_example(name)
    return MeowdokuExampleResponse(**data)


@app.post("/api/meowdoku/solve")
def meowdoku_solve(request: MeowdokuSolveRequest) -> MeowdokuSolveResponse:
    try:
        sol = meowdoku_prolog.solve(request.regions, request.cats_per_unit)
        return MeowdokuSolveResponse(solution=sol)
    except meowdoku_prolog.NoSolution as e:
        raise HTTPException(status_code=422, detail=str(e)) from None


@app.post("/api/meowdoku/hint")
def meowdoku_hint(request: MeowdokuHintRequest) -> MeowdokuHintResponse:
    try:
        h = meowdoku_prolog.hint(request.regions, request.board, request.cats_per_unit)
        return MeowdokuHintResponse(**h)
    except meowdoku_prolog.BoardComplete:
        raise HTTPException(status_code=422, detail="O tabuleiro ja possui todos os gatos posicionados.") from None
    except meowdoku_prolog.NoSolution:
        raise HTTPException(status_code=422, detail="Nao foi possivel encontrar uma dica para esta configuracao.") from None

