:- use_module(meowdoku).
:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(apply)).

:- begin_tests(meowdoku_core).

test(solve_classic_6x6_is_valid) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    once(solve(Regions, 1, Solution)),
    valid_solution(Regions, Solution, 1).

test(total_cats_equals_n_times_k) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    once(solve(Regions, 1, Solution)),
    append(Solution, Flat),
    sum_list(Flat, Total),
    Total =:= 6.

test(solve_classic_8x8_is_valid) :-
    example_puzzle(classic_8x8, 8, 1, Regions),
    once(solve(Regions, 1, Solution)),
    valid_solution(Regions, Solution, 1).

test(adjacent_diagonal_cats_fail, [fail]) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    Board = [ [1, 0, 0, 0, 0, 0],
              [0, 1, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0] ],
    valid_solution(Regions, Board, 1).

test(adjacent_orthogonal_cats_fail, [fail]) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    Board = [ [1, 1, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0] ],
    valid_solution(Regions, Board, 1).

test(excess_cats_in_row_fail, [fail]) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    Board = [ [1, 0, 1, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0] ],
    valid_solution(Regions, Board, 1).

test(solve_double_8x8_k2) :-
    example_puzzle(double_8x8, 8, 2, Regions),
    once(solve(Regions, 2, Solution)),
    append(Solution, Flat),
    sum_list(Flat, Total),
    Total =:= 16,
    valid_solution(Regions, Solution, 2).

test(hint_places_cat_in_singleton_region) :-
    Regions = [[0,1,2,3],[0,0,2,3],[0,0,2,3],[0,0,2,3]],
    length(Board, 4),
    maplist(=([0,0,0,0]), Board),
    hint(Regions, Board, 1, hint(0, 1, 1, Reason)),
    once(sub_string(Reason, _, _, _, "território")).

test(hint_respects_player_discard_marks_in_row) :-
    column_regions(6, Regions),
    Board = [[0,-1,-1,-1,-1,-1]|Rows],
    length(Rows, 5),
    maplist(=([0,0,0,0,0,0]), Rows),
    hint(Regions, Board, 1, hint(0, 0, 1, Reason)),
    once(sub_string(Reason, _, _, _, "linha")).

test(hint_respects_player_discard_marks_in_column) :-
    column_regions(6, Regions),
    Board = [[0,0,0,0,0,0]|Rows],
    length(Rows, 5),
    maplist(=([-1,0,0,0,0,0]), Rows),
    hint(Regions, Board, 1, hint(0, 0, 1, Reason)),
    once(sub_string(Reason, _, _, _, "coluna")).

test(hint_discards_cell_near_cat) :-
    column_regions(6, Regions),
    Board = [[1,0,0,0,0,0]|Rows],
    length(Rows, 5),
    maplist(=([0,0,0,0,0,0]), Rows),
    hint(Regions, Board, 1, hint(0, 1, 0, Reason)),
    once(sub_string(Reason, _, _, _, "vizinha")).

test(hint_reports_inconsistent_marks) :-
    column_regions(6, Regions),
    Board = [[-1,-1,-1,-1,-1,-1]|Rows],
    length(Rows, 5),
    maplist(=([0,0,0,0,0,0]), Rows),
    hint(Regions, Board, 1, unsolvable).

test(hint_reports_complete_with_discards) :-
    column_regions(6, Regions),
    once(solve(Regions, 1, Solution)),
    maplist(maplist(mark_as_played), Solution, Board),
    hint(Regions, Board, 1, complete).

test(no_arbitrary_hint_for_ambiguous_board, [fail]) :-
    column_regions(6, Regions),
    length(Board, 6),
    maplist(=([0,0,0,0,0,0]), Board),
    hint(Regions, Board, 1, _).

column_regions(Size, Regions) :-
    Max is Size - 1,
    numlist(0, Max, Ids),
    length(Regions, Size),
    maplist(=(Ids), Regions).

mark_as_played(0, -1).
mark_as_played(1, 1).

test(excess_cats_in_region_fail, [fail]) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    Board = [ [1, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [1, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0] ],
    valid_solution(Regions, Board, 1).

test(unsolvable_puzzle_fails, [fail]) :-
    UnsolvableRegions = [ [0, 1],
                          [0, 1] ],
    solve(UnsolvableRegions, 1, _).

:- end_tests(meowdoku_core).
