/*  test_meowdoku.pl: Suíte de testes unitários com plunit para o Meowdoku.

    Para rodar:
        $ swipl -g run_tests -t halt backend/prolog/test_meowdoku.pl

    Cobertura: 8 testes cobrindo resolução 6x6 e 8x8, contagem de gatos,
    modo avançado K=2, rejeição de adjacências diagonais e ortogonais,
    rejeição de excesso de gatos e geração de dicas com dedução.
*/

:- use_module(meowdoku).
:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(apply)).

:- begin_tests(meowdoku_core).

% -----------------------------------------------------------------------------
% Teste 1: O solver encontra uma solução válida para o tabuleiro 6x6 clássico.
% -----------------------------------------------------------------------------
test(solve_classic_6x6_is_valid) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    once(solve(Regions, 1, Solution)),
    valid_solution(Regions, Solution, 1).

% -----------------------------------------------------------------------------
% Teste 2: A solução tem exatamente N*K gatos no total (N=6, K=1 => 6 gatos).
% -----------------------------------------------------------------------------
test(total_cats_equals_n_times_k) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    once(solve(Regions, 1, Solution)),
    append(Solution, Flat),
    sum_list(Flat, Total),
    Total =:= 6.

% -----------------------------------------------------------------------------
% Teste 3: A solução para o tabuleiro 8x8 clássico também é válida.
% -----------------------------------------------------------------------------
test(solve_classic_8x8_is_valid) :-
    example_puzzle(classic_8x8, 8, 1, Regions),
    once(solve(Regions, 1, Solution)),
    valid_solution(Regions, Solution, 1).

% -----------------------------------------------------------------------------
% Teste 4: Tabuleiro com dois gatos adjacentes diagonalmente falha na validação.
% -----------------------------------------------------------------------------
test(adjacent_diagonal_cats_fail, [fail]) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    Board = [ [1, 0, 0, 0, 0, 0],
              [0, 1, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0] ],
    valid_solution(Regions, Board, 1).

% -----------------------------------------------------------------------------
% Teste 5: Tabuleiro com dois gatos adjacentes ortogonalmente falha.
% -----------------------------------------------------------------------------
test(adjacent_orthogonal_cats_fail, [fail]) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    Board = [ [1, 1, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0] ],
    valid_solution(Regions, Board, 1).

% -----------------------------------------------------------------------------
% Teste 6: Tabuleiro com excesso de gatos em uma linha falha na validação.
% -----------------------------------------------------------------------------
test(excess_cats_in_row_fail, [fail]) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    Board = [ [1, 0, 1, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0] ],
    valid_solution(Regions, Board, 1).

% -----------------------------------------------------------------------------
% Teste 7: O solver resolve o modo Dois Gatinhos (K=2) em tabuleiro 8x8.
%          Resultado: 16 gatos totais e validação completa aprovada.
% -----------------------------------------------------------------------------
test(solve_double_8x8_k2) :-
    example_puzzle(double_8x8, 8, 2, Regions),
    once(solve(Regions, 2, Solution)),
    append(Solution, Flat),
    sum_list(Flat, Total),
    Total =:= 16,
    valid_solution(Regions, Solution, 2).

% -----------------------------------------------------------------------------
% Teste 8: A dica retorna coordenadas inteiras e uma razão textual válidos.
% -----------------------------------------------------------------------------
test(hint_returns_valid_step) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    length(EmptyBoard, 6),
    maplist(=([0,0,0,0,0,0]), EmptyBoard),
    once(hint(Regions, EmptyBoard, 1, hint(R, C, Val, Reason))),
    integer(R), integer(C), Val =:= 1, string(Reason).

% -----------------------------------------------------------------------------
% Teste 9: Tabuleiro com excesso de gatos na mesma região falha na validação.
% -----------------------------------------------------------------------------
test(excess_cats_in_region_fail, [fail]) :-
    example_puzzle(classic_6x6, 6, 1, Regions),
    % Região 0 tem células (0,0), (0,1), (1,0), (1,1), (2,0)
    % Colocando gatos em (0,0) e (2,0) que são da mesma região e não adjacentes
    Board = [ [1, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [1, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0],
              [0, 0, 0, 0, 0, 0] ],
    valid_solution(Regions, Board, 1).

% -----------------------------------------------------------------------------
% Teste 10: Configuração de regiões impossível falha na resolução (sem solução).
% -----------------------------------------------------------------------------
test(unsolvable_puzzle_fails, [fail]) :-
    % Tabuleiro 2x2 com K=1: impossível ter 1 gato por linha sem adjacência
    % (0,0) e (1,1) são diagonais; (0,1) e (1,0) são diagonais.
    UnsolvableRegions = [ [0, 1],
                          [0, 1] ],
    solve(UnsolvableRegions, 1, _).

:- end_tests(meowdoku_core).
