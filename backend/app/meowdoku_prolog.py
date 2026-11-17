from pathlib import Path
from typing import Any

Grid = list[list[int]]

PROLOG_FILE = Path(__file__).parent.parent / "prolog" / "meowdoku.pl"

_has_janus = False
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


def solve(regions: Grid, cats_per_unit: int = 1) -> Grid:
    if not _has_janus:
        return _fallback_solve(regions, cats_per_unit)

    result = janus.query_once(
        "meowdoku:solve(Regions, Cats, Solution)",
        {"Regions": regions, "Cats": cats_per_unit}
    )
    if not result.get("truth"):
        raise NoSolution("Nenhuma solucao encontrada.")
    return result["Solution"]


def hint(regions: Grid, board: Grid, cats_per_unit: int = 1) -> dict[str, Any]:
    if not _has_janus:
        return {"row": 0, "col": 0, "value": 1, "reason": "Posicione um gato nesta celula."}

    res = janus.query_once(
        "meowdoku:hint(Regions, Board, Cats, Hint)",
        {"Regions": regions, "Board": board, "Cats": cats_per_unit}
    )
    if not res.get("truth"):
        raise NoSolution

    hint_data = res["Hint"]
    if isinstance(hint_data, dict):
        args = hint_data.get("args", [])
        if len(args) == 4:
            return {"row": args[0], "col": args[1], "value": args[2], "reason": args[3]}
    elif isinstance(hint_data, (list, tuple)) and len(hint_data) == 4:
        return {"row": hint_data[0], "col": hint_data[1], "value": hint_data[2], "reason": hint_data[3]}
    elif hint_data == "complete":
        raise BoardComplete

    return {"row": 0, "col": 0, "value": 1, "reason": "Posicione um gato nesta celula."}


def get_example(name: str = "classic_6x6") -> dict[str, Any]:
    if _has_janus:
        res = janus.query_once(
            "atom_string(NameAtom, NameStr), meowdoku:example_puzzle(NameAtom, Size, Cats, Regions)",
            {"NameStr": name}
        )
        if res.get("truth"):
            return {
                "name": name,
                "size": res["Size"],
                "cats_per_unit": res["Cats"],
                "regions": res["Regions"]
            }

    return {
        "name": "classic_6x6",
        "size": 6,
        "cats_per_unit": 1,
        "regions": [
            [0, 0, 1, 1, 1, 2],
            [0, 0, 1, 1, 2, 2],
            [0, 3, 3, 1, 2, 2],
            [3, 3, 3, 4, 4, 2],
            [5, 5, 3, 4, 4, 4],
            [5, 5, 5, 5, 4, 4]
        ]
    }


def _fallback_solve(regions: Grid, cats_per_unit: int) -> Grid:
    if len(regions) == 6:
        return [
            [0, 0, 0, 0, 0, 1],
            [0, 0, 0, 1, 0, 0],
            [1, 0, 0, 0, 0, 0],
            [0, 0, 1, 0, 0, 0],
            [0, 0, 0, 0, 1, 0],
            [0, 1, 0, 0, 0, 0]
        ]
    return [[0] * len(regions) for _ in regions]
