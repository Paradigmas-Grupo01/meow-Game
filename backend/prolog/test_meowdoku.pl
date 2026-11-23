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

test(uniqueness_rejects_multiple_solutions, [fail]) :-
    ambiguous_regions(6, Regions),
    has_unique_solution(Regions, 1).

test(uniqueness_rejects_no_solution, [fail]) :-
    has_unique_solution([[0,1],[0,1]], 1).

test(four_classic_fallbacks_are_connected_and_unique) :-
    ClassicNames = [classic_6x6, lantern_6x6, classic_8x8, lantern_8x8],
    findall(Size, (member(Name, ClassicNames), example_puzzle(Name, Size, 1, _)), Sizes),
    msort(Sizes, [6,6,8,8]),
    forall(example_puzzle(_, Size, K, Regions),
           (connected_partition(Regions, Size), has_unique_solution(Regions, K))).

test(generation_preserves_partition_and_solution,
     [forall(member(Size-K, [6-1, 8-1, 8-2]))]) :-
    generate(Size, K, Regions, Solution),
    connected_partition(Regions, Size),
    valid_solution(Regions, Solution, K),
    has_unique_solution(Regions, K).

ambiguous_regions(Size, Regions) :-
    Max is Size - 1,
    numlist(0, Max, Ids),
    length(Regions, Size),
    maplist(=(Ids), Regions).

connected_partition(Regions, Size) :-
    length(Regions, Size),
    maplist(same_length(Regions), Regions),
    append(Regions, Cells),
    sort(Cells, Ids),
    Max is Size - 1,
    numlist(0, Max, Ids),
    forall(member(Id, Ids), meowdoku:region_connected(Regions, Id)).

:- end_tests(meowdoku_core).
