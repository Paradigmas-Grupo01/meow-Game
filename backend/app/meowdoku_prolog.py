from pathlib import Path
import json
import shutil
import subprocess
from typing import Any

Grid = list[list[int]]

PROLOG_FILE = Path(__file__).parent.parent / "prolog" / "meowdoku.pl"

try:
    import janus_swi as janus
    janus.query_once("use_module(Arquivo, [])", {"Arquivo": str(PROLOG_FILE)})
    _has_janus = True
except Exception:
    _has_janus = False


class NoSolution(Exception):
    pass


class BoardComplete(Exception):
    pass


class UnknownExample(Exception):
    pass


def _get_swipl_bin() -> str:
    path = shutil.which("swipl")
    if path:
        return path
    default_win = r"C:\Program Files\swipl\bin\swipl.exe"
    if Path(default_win).exists():
        return default_win
    raise RuntimeError("SWI-Prolog (swipl) nao encontrado no sistema.")


def _run_swipl_query(goal: str) -> str:
    swipl = _get_swipl_bin()
    cmd = [
        swipl,
        "-q",
        "-s", str(PROLOG_FILE),
        "-g", goal,
        "-t", "halt"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0 and not res.stdout:
        raise RuntimeError(f"Erro na execucao do Prolog: {res.stderr}")
    return res.stdout.strip()


def list_examples() -> list[str]:
    if _has_janus:
        return janus.query_once("findall(_Nome, meowdoku:example_puzzle(_Nome, _, _, _), Nomes)")["Nomes"]

    out = _run_swipl_query("(meowdoku:example_puzzle(Name, _, _, _), format('~w~n', [Name]), fail ; true)")
    return [line.strip() for line in out.splitlines() if line.strip()]


def get_example(name: str) -> dict[str, Any]:
    if _has_janus:
        result = janus.query_once(
            "atom_string(_Nome, NomeStr), meowdoku:example_puzzle(_Nome, Size, Cats, Regions)",
            {"NomeStr": name},
        )
        if not result["truth"]:
            raise UnknownExample(name)
        return {
            "name": name,
            "size": result["Size"],
            "cats_per_unit": result["Cats"],
            "regions": result["Regions"],
        }

    goal = (
        f"(meowdoku:example_puzzle({name}, Size, Cats, Regions) -> "
        f"format('{{\"size\": ~w, \"cats_per_unit\": ~w, \"regions\": ~w}}~n', [Size, Cats, Regions]) ; "
        f"writeln('UNKNOWN'))"
    )
    out = _run_swipl_query(goal)
    if out == "UNKNOWN" or not out:
        raise UnknownExample(name)
    data = json.loads(out)
    return {
        "name": name,
        "size": data["size"],
        "cats_per_unit": data["cats_per_unit"],
        "regions": data["regions"],
    }


def solve(regions: Grid, cats_per_unit: int) -> Grid:
    if _has_janus:
        result = janus.query_once(
            "meowdoku:solve(Regions, Cats, Solution)",
            {"Regions": regions, "Cats": cats_per_unit},
        )
        if not result["truth"]:
            raise NoSolution
        return result["Solution"]

    goal = f"(meowdoku:solve({regions}, {cats_per_unit}, Sol) -> format('~w~n', [Sol]) ; writeln('NO_SOLUTION'))"
    out = _run_swipl_query(goal)
    if out == "NO_SOLUTION" or not out:
        raise NoSolution
    return json.loads(out)


def hint(regions: Grid, board: Grid, cats_per_unit: int) -> dict[str, Any]:
    if _has_janus:
        result = janus.query_once(
            "meowdoku:hint(Regions, Board, Cats, _Dica), _Dica =.. [Tipo|Args]",
            {"Regions": regions, "Board": board, "Cats": cats_per_unit},
        )
        if not result["truth"]:
            raise NoSolution
        match result["Tipo"], result["Args"]:
            case "hint", [row, col, value, reason]:
                return {"row": row, "col": col, "value": value, "reason": reason}
            case "complete", []:
                raise BoardComplete
            case "unsolvable", []:
                raise NoSolution
        raise RuntimeError(f"resultado inesperado de hint/4: {result['Tipo']}{result['Args']}")

    goal = (
        f"(meowdoku:hint({regions}, {board}, {cats_per_unit}, Dica), Dica =.. [Tipo|Args] -> "
        f"(Tipo == hint -> Args = [R, C, V, M], format('{{\"type\":\"hint\", \"row\":~w, \"col\":~w, \"val\":~w, \"reason\":~q}}~n', [R, C, V, M]) ; "
        f"format('{{\"type\":~q}}~n', [Tipo])) ; "
        f"writeln('NO_SOLUTION'))"
    )
    out = _run_swipl_query(goal)
    if out == "NO_SOLUTION" or not out:
        raise NoSolution
    data = json.loads(out)
    match data.get("type"):
        case "hint":
            return {"row": data["row"], "col": data["col"], "value": data["val"], "reason": data["reason"]}
        case "complete":
            raise BoardComplete
        case "unsolvable":
            raise NoSolution
    raise RuntimeError(f"resultado inesperado de hint/4: {out}")
