"""Ponte entre a API e o motor do Meowdoku em Prolog (backend/prolog/meowdoku.pl).

O janus-swi embute o SWI-Prolog no próprio processo Python: não há
subprocesso nem rede, cada consulta é uma chamada de função em memória.
Toda regra do jogo mora no Prolog; aqui só montamos consultas e traduzimos
os resultados.

Como o janus converte os dados:
- Python -> Prolog: int vira inteiro, list vira lista, str vira string.
- Prolog -> Python: inteiro vira int, lista vira list, átomo e string viram str.
- Termos compostos como hint(R, C, V, Motivo) NÃO têm conversão automática
  (a consulta lança PrologError). Por isso decompomos o termo dentro da
  própria consulta com =.. e devolvemos só inteiros e textos.
- Numa consulta bem-sucedida, toda variável nomeada é convertida; variáveis
  que começam com _ ficam de fora. Usamos _Termo para o que não deve voltar.
"""

from pathlib import Path
from typing import Any

import janus_swi as janus

Grid = list[list[int]]

PROLOG_FILE = Path(__file__).parent.parent / "prolog" / "meowdoku.pl"

# Sem fallback: se o Prolog não carregar, a API não deve subir fingindo que funciona.
# use_module(Arquivo, []) carrega o módulo sem importar nada para `user`
# (sudoku.pl também exporta print_grid/1); por isso as consultas usam meowdoku:.
janus.query_once("use_module(Arquivo, [])", {"Arquivo": str(PROLOG_FILE)})


class NoSolution(Exception):
    pass


class BoardComplete(Exception):
    pass


class UnknownExample(Exception):
    pass


def list_examples() -> list[str]:
    return janus.query_once("findall(_Nome, meowdoku:example_puzzle(_Nome, _, _, _), Nomes)")["Nomes"]


def get_example(name: str) -> dict[str, Any]:
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


def solve(regions: Grid, cats_per_unit: int) -> Grid:
    result = janus.query_once(
        "meowdoku:solve(Regions, Cats, Solution)",
        {"Regions": regions, "Cats": cats_per_unit},
    )
    if not result["truth"]:
        raise NoSolution
    return result["Solution"]


def hint(regions: Grid, board: Grid, cats_per_unit: int) -> dict[str, Any]:
    # hint/4 devolve hint(Linha, Coluna, Valor, Motivo) ou o átomo complete.
    # `_Dica =.. [Tipo|Args]` separa o nome do termo dos seus argumentos.
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
