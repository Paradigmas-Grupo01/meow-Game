/*  meowdoku.pl: Resolução, validação e dicas para o jogo Meowdoku (Cat Queens).

    REPRESENTAÇÃO
    -------------
    Um tabuleiro é uma matriz N x N (lista de N listas, cada uma com N inteiros).
    - Variáveis de células: 1 = Gato, 0 = Vazio / Marcado com X.
    - Mapa de regiões (Regions): matriz N x N com identificadores inteiros
      (0 a N-1) indicando o território colorido de cada casa.

    REGRAS DO MEOWDOKU (CSP com CLP/FD)
    -----------------------------------
    1. Linhas: cada linha contém exatamente K gatos (K=1 no clássico, K=2 no Dois Gatinhos).
    2. Colunas: cada coluna contém exatamente K gatos.
    3. Regiões: cada região contígua contém exatamente K gatos.
    4. Não-Adjacência Felina (Vizinhança de Chebyshev):
       Dois gatos nunca podem se tocar, nem horizontalmente, nem verticalmente
       e nem diagonalmente. Para quaisquer células vizinhas A e B: A + B #=< 1.

    COMO TESTAR NO SWIPL
    --------------------
        $ swipl backend/prolog/meowdoku.pl
        ?- example_puzzle(classic_6x6, Size, K, Regions),
           solve(Regions, K, Solution),
           print_grid(Solution).

        ?- example_puzzle(double_8x8, Size, K, Regions),
           solve(Regions, K, Solution),
           print_grid(Solution).
*/

:- module(meowdoku,
          [ solve/3,              % +Regions, +CatsPerUnit, -Solution
            hint/4,               % +Regions, +Board, +CatsPerUnit, -Hint
            valid_solution/3,     % +Regions, +Board, +CatsPerUnit
            has_unique_solution/2,% +Regions, +CatsPerUnit
            example_puzzle/4,     % +Name, -Size, -CatsPerUnit, -Regions
            print_grid/1          % +Grid
          ]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(aggregate)).

% ==============================================================================
% 1. RESOLUÇÃO (SOLVE)
% ==============================================================================

%!  solve(+Regions, +CatsPerUnit, -Solution) is nondet.
%
%   Recebe o mapa de regiões Regions (matriz N x N com os IDs das cores),
%   o número de gatos por linha/coluna/cor CatsPerUnit (1 ou 2),
%   e instancia Solution com uma matriz binária N x N onde 1 indica gato.
solve(Regions, CatsPerUnit, Solution) :-
    length(Regions, N),
    N > 0,
    % 1. Cria a matriz Solution com dimensões N x N e domínio binário 0..1
    length(Solution, N),
    maplist(make_row(N), Solution),
    append(Solution, AllCells),
    AllCells ins 0..1,

    % 2. Restrições de Linhas: soma de cada linha #= CatsPerUnit
    maplist(sum_equals(CatsPerUnit), Solution),

    % 3. Restrições de Colunas: soma de cada coluna #= CatsPerUnit
    clpfd:transpose(Solution, Cols),
    maplist(sum_equals(CatsPerUnit), Cols),

    % 4. Restrições de Regiões: soma de cada região #= CatsPerUnit
    flatten_grid(Regions, FlatRegions),
    max_list(FlatRegions, MaxRegionId),
    enforce_region_constraints(Solution, Regions, 0, MaxRegionId, CatsPerUnit),

    % 5. Restrição de Não-Adjacência Felina (nem ortogonal nem diagonal)
    enforce_no_touch(Solution),

    % 6. Busca de rotulagem: ff = "fail first" (seleciona variável mais restrita)
    labeling([ff, bisect], AllCells).

%!  make_row(+N, -Row) is det.
make_row(N, Row) :-
    length(Row, N).

%!  sum_equals(+Target, +List) is det.
sum_equals(Target, List) :-
    sum(List, #=, Target).

%!  flatten_grid(+Grid, -Flat) is det.
flatten_grid(Grid, Flat) :-
    append(Grid, Flat).

% ==============================================================================
% 2. RESTRIÇÕES DE REGIÕES
% ==============================================================================

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

% ==============================================================================
% 3. RESTRIÇÕES DE NÃO-ADJACÊNCIA (GATOS NÃO SE TOCAM)
% ==============================================================================
% Nota: não usamos forall/2 pois sua semântica de dupla negação reverte
% as restrições CLP(FD) criadas. Usamos recursão determinística sobre índices.

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
    % Vizinho à direita (R, C+1)
    C1 is C + 1,
    ( C1 < N -> get_cell(Grid, R, C1, CellR), CellA + CellR #=< 1 ; true ),
    % Vizinho abaixo (R+1, C)
    R1 is R + 1,
    ( R1 < N -> get_cell(Grid, R1, C, CellD), CellA + CellD #=< 1 ; true ),
    % Diagonal inferior-direita (R+1, C+1)
    ( (R1 < N, C1 < N) -> get_cell(Grid, R1, C1, CellDR), CellA + CellDR #=< 1 ; true ),
    % Diagonal inferior-esquerda (R+1, C-1)
    C0 is C - 1,
    ( (R1 < N, C0 >= 0) -> get_cell(Grid, R1, C0, CellDL), CellA + CellDL #=< 1 ; true ).

get_cell(Grid, R, C, Value) :-
    nth0(R, Grid, Row),
    nth0(C, Row, Value).

% ==============================================================================
% 4. VALIDAÇÃO DE TABULEIRO COMPLETO
% ==============================================================================

%!  valid_solution(+Regions, +Board, +CatsPerUnit) is semidet.
%
%   Verifica deterministicamente se Board satisfaz todas as restrições do Meowdoku.
%   Não usa busca de rotulagem: valida uma matriz preenchida.
valid_solution(Regions, Board, CatsPerUnit) :-
    length(Regions, N),
    length(Board, N),
    % Todas as células devem ser 0 ou 1
    append(Board, Flat),
    maplist(between(0, 1), Flat),
    % Verifica linhas
    maplist(sum_list_equals(CatsPerUnit), Board),
    % Verifica colunas
    clpfd:transpose(Board, Cols),
    maplist(sum_list_equals(CatsPerUnit), Cols),
    % Verifica regiões
    flatten_grid(Regions, FlatRegions),
    max_list(FlatRegions, MaxRegionId),
    check_all_regions(Board, Regions, 0, MaxRegionId, CatsPerUnit),
    % Verifica vizinhança de Chebyshev
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

% ==============================================================================
% 5. VERIFICAÇÃO DE SOLUÇÃO ÚNICA
% ==============================================================================

%!  has_unique_solution(+Regions, +CatsPerUnit) is semidet.
%
%   Tem êxito se e somente se o puzzle tiver exatamente uma solução.
has_unique_solution(Regions, CatsPerUnit) :-
    aggregate_all(count, solve(Regions, CatsPerUnit, _), 1).

% ==============================================================================
% 6. DICA EXPLICATIVA (SMART FELINE HINT)
% ==============================================================================

%!  hint(+Regions, +Board, +CatsPerUnit, -Hint) is det.
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
        "A celula (~w,~w) deve ser descartada. Um gato ja foi colocado em posicao que torna esta invalida por adjacencia ou excesso na unidade.",
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
        "A linha ~w ja possui ~w gato(s) e so resta uma celula valida. O gato deve ir para (~w,~w) no territorio ~w.",
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
        "A coluna ~w ja possui ~w gato(s) e so resta uma celula valida. O gato deve ir para (~w,~w) no territorio ~w.",
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
        "O territorio ~w ja possui ~w gato(s) e so resta uma posicao livre. Posicione o gato em (~w,~w).",
        [RegId, RegSum, R, C]),
    !.

explain_cat_placement(Regions, _Board, _K, R, C, Reason) :-
    nth0(R, Regions, RegRow),
    nth0(C, RegRow, RegId),
    format(string(Reason),
        "Por eliminacao das celulas vizinhas e restricoes de linha/coluna/territorio, a posicao (~w,~w) no territorio ~w e a unica opcao valida restante.",
        [R, C, RegId]).

% ==============================================================================
% 7. TABULEIROS DE EXEMPLO
% ==============================================================================

%!  example_puzzle(+Name, -Size, -CatsPerUnit, -Regions) is semidet.

% Clássico 6x6, K=1 (6 regiões, 1 gato por unidade)
example_puzzle(classic_6x6, 6, 1,
    [ [0, 0, 1, 1, 1, 2],
      [0, 0, 1, 1, 2, 2],
      [0, 3, 3, 1, 2, 2],
      [3, 3, 3, 4, 4, 2],
      [5, 5, 3, 4, 4, 4],
      [5, 5, 5, 5, 4, 4]
    ]).

% Clássico 8x8, K=1 (8 regiões, 1 gato por unidade)
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

% Dois Gatinhos 8x8, K=2 (8 colunas como regiões, 2 gatos por unidade)
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

% ==============================================================================
% 8. UTILITÁRIOS
% ==============================================================================

%!  print_grid(+Grid) is det.
print_grid([]).
print_grid([Row|Rest]) :-
    format("~w~n", [Row]),
    print_grid(Rest).
