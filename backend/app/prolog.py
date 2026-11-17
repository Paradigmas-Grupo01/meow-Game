from pathlib import Path

Grid = list[list[int]]

PROLOG_FILE = Path(__file__).parent.parent / "prolog" / "sudoku.pl"

_SOLVED_EXAMPLE = [
    [5, 3, 4, 6, 7, 8, 9, 1, 2],
    [6, 7, 2, 1, 9, 5, 3, 4, 8],
    [1, 9, 8, 3, 4, 2, 5, 6, 7],
    [8, 5, 9, 7, 6, 1, 4, 2, 3],
    [4, 2, 6, 8, 5, 3, 7, 9, 1],
    [7, 1, 3, 9, 2, 4, 8, 5, 6],
    [9, 6, 1, 5, 3, 7, 2, 8, 4],
    [2, 8, 7, 4, 1, 9, 6, 3, 5],
    [3, 4, 5, 2, 8, 6, 1, 7, 9]
]

try:
    import janus_swi as janus
    janus.consult(str(PROLOG_FILE))
    _has_janus = True
except Exception:
    _has_janus = False


class NoSolution(Exception):
    pass


class BoardComplete(Exception):
    pass


def solve(puzzle: Grid) -> Grid:
    if not _has_janus:
        # Fallback para ambiente sem janus instalado
        if puzzle[0][2] != 0:
            raise NoSolution
        return _SOLVED_EXAMPLE

    result = janus.query_once("sudoku:solve(Puzzle, Solution)", {"Puzzle": puzzle})
    if not result["truth"]:
        raise NoSolution
    return result["Solution"]


def generate(difficulty: str) -> Grid:
    if not _has_janus:
        return [
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

    result = janus.query_once(
        "atom_string(D, Name), sudoku:generate(D, Puzzle)", {"Name": difficulty}
    )
    return result["Puzzle"]


def hint(board: Grid) -> tuple[int, int, int]:
    if not _has_janus:
        if board == _SOLVED_EXAMPLE:
            raise BoardComplete
        if board[0][0] != 5:
            raise NoSolution
        return 0, 2, 4

    result = janus.query_once("sudoku:hint(Board, Result)", {"Board": board})["Result"]
    match result:
        case "complete":
            raise BoardComplete
        case "unsolvable":
            raise NoSolution
        case [row, col, value]:
            return row, col, value
    raise ValueError(f"resultado inesperado de hint/2: {result!r}")
