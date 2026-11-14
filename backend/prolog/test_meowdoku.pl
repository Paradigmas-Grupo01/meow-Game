/*  test_meowdoku.pl: Testes unitários com plunit para o jogo Meowdoku.

    Para rodar no SWI-Prolog:
        $ swipl -g run_tests -t halt backend/prolog/test_meowdoku.pl
*/

:- use_module(meowdoku).
:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(apply)).

:- begin_tests(meowdoku_core).

test(solve_classic_6x6, true(valid_solution(Regions, Solution, 1))) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    solve(Regions, 1, Solution).

test(cats_count_is_correct, true(TotalCats == 6)) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    solve(Regions, 1, Solution),
    append(Solution, Flat),
    sum_list(Flat, TotalCats).

test(no_adjacent_cats_in_solution) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    solve(Regions, 1, Solution),
    % Verifica que a solução passa na checagem estrita de não-adjacência
    valid_solution(Regions, Solution, 1).

test(adjacent_cats_fail_validation, fail) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    % Tabuleiro com dois gatos adjacentes na diagonal: (0,0) e (1,1)
    Board = [ [1, 0, 0, 0, 0, 0],
              [0, 1, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0] ],
    valid_solution(Regions, Board, 1).

test(hint_provides_valid_step, true(Val == 1)) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    % Tabuleiro totalmente vazio
    length(EmptyBoard, 6),
    maplist(=([0,0,0,0,0,0]), EmptyBoard),
    hint(Regions, EmptyBoard, 1, hint(R, C, Val, Reason)),
    integer(R), integer(C), string(Reason).

:- end_tests(meowdoku_core).

