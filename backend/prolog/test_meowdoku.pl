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

test(hint_returns_valid_step) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    length(EmptyBoard, 6),
    maplist(=([0,0,0,0,0,0]), EmptyBoard),
    once(hint(Regions, EmptyBoard, 1, hint(R, C, Val, Reason))),
    integer(R), integer(C), Val =:= 1, string(Reason).

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
