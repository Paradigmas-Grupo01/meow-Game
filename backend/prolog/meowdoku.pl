:- module(meowdoku,
          [ solve/3,
            hint/4,
            valid_solution/3,
            has_unique_solution/2,
            example_puzzle/4,
            print_grid/1
          ]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(aggregate)).

solve(Regions, CatsPerUnit, Solution) :-
    length(Regions, N),
    N > 0,
    length(Solution, N),
    maplist(make_row(N), Solution),
    append(Solution, Cells),
    Cells ins 0..1,
    maplist(sum_equals(CatsPerUnit), Solution),
    clpfd:transpose(Solution, Cols),
    maplist(sum_equals(CatsPerUnit), Cols),
    flatten_grid(Regions, FlatRegions),
    max_list(FlatRegions, MaxRegionId),
    enforce_region_constraints(Solution, Regions, 0, MaxRegionId, CatsPerUnit),
    enforce_no_touch(Solution),
    labeling([ff, bisect], Cells).

make_row(N, Row) :-
    length(Row, N).

sum_equals(Target, List) :-
    sum(List, #=, Target).

flatten_grid(Grid, Flat) :-
    append(Grid, Flat).

enforce_region_constraints(_Solution, _Regions, Current, Max, _K) :-
    Current > Max, !.
enforce_region_constraints(Solution, Regions, Current, Max, K) :-
    collect_region_cells(Solution, Regions, Current, RegionCells),
    (   RegionCells \= []
    ->  sum(RegionCells, #=, K)
    ;   true
    ),
    Next is Current + 1,
    enforce_region_constraints(Solution, Regions, Next, Max, K).

collect_region_cells(Solution, Regions, TargetId, Cells) :-
    append(Solution, FlatS),
    append(Regions, FlatR),
    filter_cells_by_region(FlatS, FlatR, TargetId, Cells).

filter_cells_by_region([], [], _, []).
filter_cells_by_region([Cell|RestS], [RegId|RestR], TargetId, [Cell|Result]) :-
    RegId == TargetId, !,
    filter_cells_by_region(RestS, RestR, TargetId, Result).
filter_cells_by_region([_|RestS], [_|RestR], TargetId, Result) :-
    filter_cells_by_region(RestS, RestR, TargetId, Result).

enforce_no_touch(Grid) :-
    length(Grid, N),
    N1 is N - 1,
    numlist(0, N1, RowIndices),
    enforce_rows(RowIndices, RowIndices, Grid, N).

enforce_rows([], _, _, _).
enforce_rows([R|Rs], ColIndices, Grid, N) :-
    enforce_cols(ColIndices, R, Grid, N),
    enforce_rows(Rs, ColIndices, Grid, N).

enforce_cols([], _, _, _).
enforce_cols([C|Cs], R, Grid, N) :-
    constrain_neighbors(Grid, R, C, N),
    enforce_cols(Cs, R, Grid, N).

constrain_neighbors(Grid, R, C, N) :-
    get_cell(Grid, R, C, CellA),
    C1 is C + 1,
    ( C1 < N -> get_cell(Grid, R, C1, CellR), CellA + CellR #=< 1 ; true ),
    R1 is R + 1,
    ( R1 < N -> get_cell(Grid, R1, C, CellD), CellA + CellD #=< 1 ; true ),
    ( (R1 < N, C1 < N) -> get_cell(Grid, R1, C1, CellDR), CellA + CellDR #=< 1 ; true ),
    C0 is C - 1,
    ( (R1 < N, C0 >= 0) -> get_cell(Grid, R1, C0, CellDL), CellA + CellDL #=< 1 ; true ).

get_cell(Grid, R, C, Value) :-
    nth0(R, Grid, Row),
    nth0(C, Row, Value).

valid_solution(Regions, Board, CatsPerUnit) :-
    length(Regions, N),
    length(Board, N),
    append(Board, Flat),
    maplist(between(0, 1), Flat),
    maplist(sum_list_equals(CatsPerUnit), Board),
    clpfd:transpose(Board, Cols),
    maplist(sum_list_equals(CatsPerUnit), Cols),
    flatten_grid(Regions, FlatRegions),
    max_list(FlatRegions, MaxRegionId),
    check_all_regions(Board, Regions, 0, MaxRegionId, CatsPerUnit),
    check_no_touch_strict(Board).

sum_list_equals(Target, List) :-
    sum_list(List, S),
    S =:= Target.

check_all_regions(_Board, _Regions, Current, Max, _K) :-
    Current > Max, !.
check_all_regions(Board, Regions, Current, Max, K) :-
    collect_region_cells(Board, Regions, Current, Cells),
    sum_list(Cells, S),
    S =:= K,
    Next is Current + 1,
    check_all_regions(Board, Regions, Next, Max, K).

check_no_touch_strict(Board) :-
    length(Board, N),
    N1 is N - 1,
    \+ (
        between(0, N1, R1),
        between(0, N1, C1),
        get_cell(Board, R1, C1, 1),
        between(0, N1, R2),
        between(0, N1, C2),
        ( R1 =\= R2 ; C1 =\= C2 ),
        abs(R1 - R2) =< 1,
        abs(C1 - C2) =< 1,
        get_cell(Board, R2, C2, 1)
    ).

has_unique_solution(Regions, CatsPerUnit) :-
    aggregate_all(count, solve(Regions, CatsPerUnit, _), 1).

hint(Regions, Board, CatsPerUnit, hint(R, C, 1, Reason)) :-
    solve(Regions, CatsPerUnit, Solution),
    nth0(R, Solution, SolRow),
    nth0(C, SolRow, 1),
    get_cell(Board, R, C, CurrentVal),
    CurrentVal =\= 1,
    explain_cat_placement(Regions, Board, CatsPerUnit, R, C, Reason),
    !.
hint(Regions, Board, CatsPerUnit, hint(R, C, 0, Reason)) :-
    solve(Regions, CatsPerUnit, Solution),
    nth0(R, Solution, SolRow),
    nth0(C, SolRow, 0),
    get_cell(Board, R, C, CurrentVal),
    CurrentVal =:= 1,
    format(string(Reason),
        "A celula (~w,~w) deve ser descartada por violar as restricoes da partida.",
        [R, C]),
    !.
hint(_, _, _, complete).

explain_cat_placement(Regions, Board, K, R, C, Reason) :-
    nth0(R, Board, BoardRow),
    sum_list(BoardRow, RowSum),
    CatsNeeded is K - RowSum,
    CatsNeeded =:= 1,
    nth0(R, Regions, RegRow),
    nth0(C, RegRow, RegId),
    format(string(Reason),
        "A linha ~w ja possui ~w gato(s). Posicione o proximo em (~w,~w) no territorio ~w.",
        [R, RowSum, R, C, RegId]),
    !.
explain_cat_placement(Regions, Board, K, R, C, Reason) :-
    clpfd:transpose(Board, Cols),
    nth0(C, Cols, ColCells),
    sum_list(ColCells, ColSum),
    CatsNeeded is K - ColSum,
    CatsNeeded =:= 1,
    nth0(R, Regions, RegRow),
    nth0(C, RegRow, RegId),
    format(string(Reason),
        "A coluna ~w ja possui ~w gato(s). Posicione o proximo em (~w,~w) no territorio ~w.",
        [C, ColSum, R, C, RegId]),
    !.
explain_cat_placement(Regions, Board, K, R, C, Reason) :-
    nth0(R, Regions, RegRow),
    nth0(C, RegRow, RegId),
    collect_region_cells(Board, Regions, RegId, RegCells),
    sum_list(RegCells, RegSum),
    CatsNeeded is K - RegSum,
    CatsNeeded =:= 1,
    format(string(Reason),
        "O territorio ~w ja possui ~w gato(s). Posicione o gato em (~w,~w).",
        [RegId, RegSum, R, C]),
    !.
explain_cat_placement(Regions, _Board, _K, R, C, Reason) :-
    nth0(R, Regions, RegRow),
    nth0(C, RegRow, RegId),
    format(string(Reason),
        "A posicao (~w,~w) no territorio ~w e a unica opcao valida restante.",
        [R, C, RegId]).

example_puzzle(classic_6x6, 6, 1,
    [ [0, 0, 1, 1, 1, 2],
      [0, 0, 1, 1, 2, 2],
      [0, 3, 3, 1, 2, 2],
      [3, 3, 3, 4, 4, 2],
      [5, 5, 3, 4, 4, 4],
      [5, 5, 5, 5, 4, 4]
    ]).

example_puzzle(classic_8x8, 8, 1,
    [ [0, 0, 0, 1, 1, 1, 2, 2],
      [0, 0, 0, 1, 1, 1, 2, 2],
      [3, 3, 0, 1, 1, 4, 4, 2],
      [3, 3, 3, 5, 5, 4, 4, 2],
      [3, 3, 3, 5, 5, 4, 4, 2],
      [6, 6, 5, 5, 5, 4, 7, 7],
      [6, 6, 6, 5, 7, 7, 7, 7],
      [6, 6, 6, 6, 7, 7, 7, 7]
    ]).

example_puzzle(double_8x8, 8, 2,
    [ [0, 1, 2, 3, 4, 5, 6, 7],
      [0, 1, 2, 3, 4, 5, 6, 7],
      [0, 1, 2, 3, 4, 5, 6, 7],
      [0, 1, 2, 3, 4, 5, 6, 7],
      [0, 1, 2, 3, 4, 5, 6, 7],
      [0, 1, 2, 3, 4, 5, 6, 7],
      [0, 1, 2, 3, 4, 5, 6, 7],
      [0, 1, 2, 3, 4, 5, 6, 7]
    ]).

print_grid([]).
print_grid([Row|Rest]) :-
    format("~w~n", [Row]),
    print_grid(Rest).
