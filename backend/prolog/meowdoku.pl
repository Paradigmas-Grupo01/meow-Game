:- module(meowdoku,
          [ solve/3,
            hint/4,
            valid_solution/3,
            has_unique_solution/2,
            example_puzzle/4,
            generate/4,
            print_grid/1
          ]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(random)).

solve(Regions, CatsPerUnit, Solution) :-
    board_constraints(Regions, CatsPerUnit, Solution, Cells),
    labeling([ff, bisect], Cells).

board_constraints(Regions, CatsPerUnit, Solution, Cells) :-
    length(Regions, N),
    N > 0,
    maplist(make_row(N), Regions),
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
    enforce_no_touch(Solution).

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
    unique_solution(Regions, CatsPerUnit, _).

unique_solution(Regions, CatsPerUnit, Solution) :-
    once(findnsols(2, Candidate, solve(Regions, CatsPerUnit, Candidate), Solutions)),
    Solutions = [Solution].

% Board: 0 = vazia, 1 = gato, -1 = X. Na dica, 0 indica marcar X.
hint(Regions, Board, K, Hint) :-
    (   once(board_solution(Regions, Board, K, Solution))
    ->  consistent_hint(Regions, Board, K, Solution, Result)
    ;   Result = unsolvable
    ),
    Hint = Result.

board_solution(Regions, Board, K, Solution) :-
    board_constraints(Regions, K, Solution, Cells),
    maplist(respect_marks, Board, Solution),
    labeling([ff, bisect], Cells).

respect_marks(Marks, Cells) :- maplist(respect_mark, Marks, Cells).
respect_mark(0, _).
respect_mark(1, 1).
respect_mark(-1, 0).

consistent_hint(Regions, Board, K, Solution, Hint) :-
    append(Board, Marks),
    include(=(1), Marks, Cats),
    length(Cats, Placed),
    length(Regions, Size),
    (   Placed =:= Size * K
    ->  Hint = complete
    ;   findall(R-C, get_cell(Board, R, C, 1), PlacedCats),
        findall(Unit, board_unit(Regions, Unit), Units),
        findall(R-C, get_cell(Board, R, C, 0), EmptyCells),
        findall(Cell-Why,
                (member(Cell, EmptyCells), once(discard_reason(Cell, PlacedCats, Units, K, Why))),
                Discards),
        (   once(forced_hint(Units, PlacedCats, EmptyCells, Discards, K, Hint))
        ->  true
        ;   Discards = [(R-C)-Reason|_]
        ->  Hint = hint(R, C, 0, Reason)
        ;   once(contradiction_hint(Regions, Board, K, Solution, EmptyCells, Hint))
        )
    ).

board_unit(Regions, unit(linha, Number, Cells)) :-
    nth0(R, Regions, Row),
    findall(R-C, nth0(C, Row, _), Cells),
    Number is R + 1.
board_unit(Regions, unit(coluna, Number, Cells)) :-
    nth0(C, Regions, _),
    findall(R-C, get_cell(Regions, R, C, _), Cells),
    Number is C + 1.
board_unit(Regions, unit(território, Number, Cells)) :-
    append(Regions, Ids),
    sort(Ids, RegionIds),
    member(Id, RegionIds),
    findall(R-C, get_cell(Regions, R, C, Id), Cells),
    Number is Id + 1.

count_in_unit(Cats, Cells, Count) :-
    include(cell_in(Cells), Cats, InUnit),
    length(InUnit, Count).

cell_in(Cells, Cell) :- memberchk(Cell, Cells).

discard_reason(R-C, Cats, _, _, Reason) :-
    member(CatR-CatC, Cats),
    abs(CatR - R) =< 1,
    abs(CatC - C) =< 1,
    Row is CatR + 1,
    Col is CatC + 1,
    format(string(Reason),
           "A casa é vizinha do gato na linha ~d, coluna ~d. Gatos não podem se tocar, nem na diagonal.",
           [Row, Col]).
discard_reason(Cell, Cats, Units, K, Reason) :-
    member(unit(Type, Number, Cells), Units),
    memberchk(Cell, Cells),
    count_in_unit(Cats, Cells, K),
    format(string(Reason), "Já há ~d gato(s) no máximo permitido para ~w ~d.", [K, Type, Number]).

forced_hint(Units, Cats, EmptyCells, Discards, K, hint(R, C, 1, Reason)) :-
    member(unit(Type, Number, Cells), Units),
    count_in_unit(Cats, Cells, Placed),
    Remaining is K - Placed,
    Remaining > 0,
    include(cell_in(Cells), EmptyCells, EmptyInUnit),
    exclude(discarded(Discards), EmptyInUnit, Candidates),
    length(Candidates, Remaining),
    Candidates = [R-C|_],
    format(string(Reason),
           "Faltam ~d gato(s) em ~w ~d e restam exatamente ~d casa(s) possível(is).",
           [Remaining, Type, Number, Remaining]).

discarded(Discards, Cell) :- memberchk(Cell-_, Discards).

% Uma solução testemunha serve apenas para escolher qual hipótese refutar.
contradiction_hint(Regions, Board, K, Solution, EmptyCells, hint(R, C, Value, Reason)) :-
    member(Value, [1, 0]),
    member(R-C, EmptyCells),
    get_cell(Solution, R, C, Value),
    (   Value =:= 1
    ->  Opposite = -1,
        Reason = "Se esta casa for marcada com X, não haverá como completar o tabuleiro seguindo as regras."
    ;   Opposite = 1,
        Reason = "Se houver um gato nesta casa, não haverá como completar o tabuleiro seguindo as regras."
    ),
    replace_cell(Board, R, C, Opposite, Trial),
    \+ board_solution(Regions, Trial, K, _).

% generate(+Size, +CatsPerUnit, -Regions, -Solution)
% Transfere células de fronteira sem dividir o território de origem.
generate(Size, K, Regions, Solution) :-
    findall(Map, example_puzzle(_, Size, K, Map), Maps),
    Maps = [_|_],
    random_member(Fallback, Maps),
    (   once(unique_partition_variant(Fallback, K, Regions, Solution))
    ->  true
    ;   Regions = Fallback,
        once(solve(Regions, K, Solution))
    ).

unique_partition_variant(Map, K, Regions, Solution) :-
    findall(move(R, C, From, To),
            ( get_cell(Map, R, C, From),
              orthogonal_neighbor(R-C, AdjR-AdjC),
              get_cell(Map, AdjR, AdjC, To),
              From \= To
            ),
            Moves),
    sort(Moves, UniqueMoves),
    random_permutation(UniqueMoves, Shuffled),
    member(move(R, C, From, To), Shuffled),
    replace_cell(Map, R, C, To, Regions),
    region_connected(Regions, From),
    unique_solution(Regions, K, Solution).

replace_cell(Grid, R, C, Value, NewGrid) :-
    nth0(R, Grid, Row, OtherRows),
    nth0(C, Row, _, OtherCells),
    nth0(C, NewRow, Value, OtherCells),
    nth0(R, NewGrid, NewRow, OtherRows).

orthogonal_neighbor(R-C, AdjR-AdjC) :-
    member(DR-DC, [1-0, (-1)-0, 0-1, 0-(-1)]),
    AdjR is R + DR,
    AdjC is C + DC,
    AdjR >= 0,
    AdjC >= 0.

region_connected(Map, Id) :-
    findall(R-C, get_cell(Map, R, C, Id), Cells),
    Cells = [Start|Rest],
    flood_region([Start], Rest).

flood_region([], []).
flood_region([Cell|Queue], Unseen) :-
    partition(orthogonal_neighbor(Cell), Unseen, Neighbors, Remaining),
    append(Neighbors, Queue, Pending),
    flood_region(Pending, Remaining).

example_puzzle(classic_6x6, 6, 1,
    [ [0, 0, 0, 2, 1, 1],
      [0, 0, 2, 2, 1, 1],
      [3, 3, 2, 2, 2, 1],
      [3, 3, 2, 4, 1, 1],
      [3, 3, 4, 4, 4, 1],
      [3, 5, 4, 4, 4, 1]
    ]).

example_puzzle(classic_8x8, 8, 1,
    [ [2, 2, 2, 2, 0, 0, 0, 1],
      [2, 2, 4, 4, 4, 4, 3, 1],
      [2, 2, 4, 4, 4, 4, 3, 1],
      [4, 4, 4, 4, 4, 4, 3, 3],
      [4, 4, 4, 4, 4, 4, 4, 4],
      [6, 6, 5, 4, 4, 4, 4, 4],
      [6, 4, 4, 4, 4, 4, 4, 4],
      [6, 6, 7, 7, 7, 7, 4, 4]
    ]).

example_puzzle(lantern_6x6, 6, 1,
    [ [1, 1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0, 0],
      [3, 0, 0, 2, 0, 0],
      [3, 3, 3, 3, 3, 4],
      [3, 3, 3, 3, 3, 4],
      [3, 3, 5, 5, 4, 4]
    ]).

example_puzzle(lantern_8x8, 8, 1,
    [ [0, 0, 0, 0, 2, 2, 2, 2],
      [1, 1, 2, 0, 2, 2, 2, 2],
      [3, 2, 2, 2, 2, 2, 2, 2],
      [3, 5, 2, 2, 2, 2, 2, 6],
      [5, 5, 5, 2, 2, 4, 4, 6],
      [5, 5, 5, 5, 2, 5, 6, 6],
      [5, 5, 5, 5, 5, 5, 5, 6],
      [5, 5, 5, 5, 5, 7, 5, 6]
    ]).

example_puzzle(double_8x8, 8, 2,
    [ [0, 0, 2, 3, 4, 5, 6, 7],
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
