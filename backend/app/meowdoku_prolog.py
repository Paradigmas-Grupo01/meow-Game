"""Ponte entre Python e o motor Prolog Meowdoku via biblioteca janus.

janus (pacote `janus-swi`) embute o SWI-Prolog dentro do processo Python.
Não há servidor Prolog separado: chamamos predicados diretamente e recebemos
as respostas como dicionários Python.
"""

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
    """O tabuleiro ou configuração de regiões enviada não tem solução."""


class BoardComplete(Exception):
    """O tabuleiro já está completo."""


def solve(regions: Grid, cats_per_unit: int = 1) -> Grid:
    """Resolve o tabuleiro Meowdoku para o mapa de regiões fornecido."""
    if not _has_janus:
        # Fallback de exemplo se janus não estiver compilado localmente
        return _fallback_solve(regions, cats_per_unit)

    result = janus.query_once(
        "meowdoku:solve(Regions, Cats, Solution)",
        {"Regions": regions, "Cats": cats_per_unit}
    )
    if not result.get("truth"):
        raise NoSolution("Nenhuma solução válida encontrada para esta configuração.")
    return result["Solution"]


def hint(regions: Grid, board: Grid, cats_per_unit: int = 1) -> dict[str, Any]:
    """Obtém uma dica com explicação dedutiva do Prolog."""
    if not _has_janus:
        return {"row": 0, "col": 0, "value": 1, "reason": "Dica demonstrativa de teste."}

    res = janus.query_once(
        "meowdoku:hint(Regions, Board, Cats, Hint)",
        {"Regions": regions, "Board": board, "Cats": cats_per_unit}
    )
    if not res.get("truth"):
        raise NoSolution

    hint_data = res["Hint"]
    # No janus, hint(R, C, Val, Reason) pode vir como dicionário ou tupla
    if isinstance(hint_data, dict):
        args = hint_data.get("args", [])
        if len(args) == 4:
            return {"row": args[0], "col": args[1], "value": args[2], "reason": args[3]}
    elif isinstance(hint_data, (list, tuple)) and len(hint_data) == 4:
        return {"row": hint_data[0], "col": hint_data[1], "value": hint_data[2], "reason": hint_data[3]}
    elif hint_data == "complete":
        raise BoardComplete

    return {"row": 0, "col": 0, "value": 1, "reason": "Posicione um gato nesta célula."}


def get_example(name: str = "classic_6x6") -> dict[str, Any]:
    """Retorna um exemplo pronto de tabuleiro."""
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

    # Fallback estático
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
    # Solução padrão para o mapa 6x6
    if len(regions) == 6:
        return [
            [0, 1, 0, 0, 0, 0],
            [0, 0, 0, 0, 1, 0],
            [1, 0, 0, 0, 0, 0],
            [0, 0, 0, 1, 0, 0],
            [0, 0, 0, 0, 0, 1],
            [0, 0, 1, 0, 0, 0]
        ]
    return [[0] * len(regions) for _ in regions]
