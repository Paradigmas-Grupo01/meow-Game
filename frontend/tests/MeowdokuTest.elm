module MeowdokuTest exposing (suite)

import Array
import Expect
import Meowdoku exposing (Board, CellMark(..))
import Test exposing (Test, describe, test)


regions6 : List (List Int)
regions6 =
    [ [ 0, 0, 1, 1, 1, 2 ]
    , [ 0, 0, 1, 1, 2, 2 ]
    , [ 0, 3, 3, 1, 2, 2 ]
    , [ 3, 3, 3, 4, 4, 2 ]
    , [ 5, 5, 3, 4, 4, 4 ]
    , [ 5, 5, 5, 5, 4, 4 ]
    ]


solution6 : List ( Int, Int )
solution6 =
    [ ( 0, 5 ), ( 1, 3 ), ( 2, 0 ), ( 3, 2 ), ( 4, 4 ), ( 5, 1 ) ]


regions8 : List (List Int)
regions8 =
    [ [ 0, 0, 0, 0, 1, 1, 1, 1 ]
    , [ 0, 0, 0, 0, 1, 1, 1, 1 ]
    , [ 2, 2, 2, 2, 3, 3, 3, 3 ]
    , [ 2, 2, 2, 2, 3, 3, 3, 3 ]
    , [ 4, 4, 4, 4, 5, 5, 5, 5 ]
    , [ 4, 4, 4, 4, 5, 5, 5, 5 ]
    , [ 6, 6, 6, 6, 7, 7, 7, 7 ]
    , [ 6, 6, 6, 6, 7, 7, 7, 7 ]
    ]


solution8 : List ( Int, Int )
solution8 =
    List.concat
        [ [ ( 0, 1 ), ( 0, 3 ) ]
        , [ ( 1, 5 ), ( 1, 7 ) ]
        , [ ( 2, 1 ), ( 2, 3 ) ]
        , [ ( 3, 5 ), ( 3, 7 ) ]
        , [ ( 4, 0 ), ( 4, 2 ) ]
        , [ ( 5, 4 ), ( 5, 6 ) ]
        , [ ( 6, 0 ), ( 6, 2 ) ]
        , [ ( 7, 4 ), ( 7, 6 ) ]
        ]


regionsWithSpare : List (List Int)
regionsWithSpare =
    [ [ 0, 0, 1, 1 ]
    , [ 0, 0, 1, 4 ]
    , [ 2, 2, 3, 3 ]
    , [ 2, 2, 3, 3 ]
    ]


board6 : Board
board6 =
    Meowdoku.initBoard 6 1 regions6


board8 : Board
board8 =
    Meowdoku.initBoard 8 2 regions8


placeCats : List ( Int, Int ) -> Board -> Board
placeCats positions board =
    List.foldl (\( r, c ) acc -> Meowdoku.setMarkAt r c HasCat acc) board positions


clickTwice : List ( Int, Int ) -> Board -> Board
clickTwice positions board =
    List.foldl (\( r, c ) acc -> acc |> Meowdoku.cycleMarkAt r c |> Meowdoku.cycleMarkAt r c) board positions


fillEmptyWithX : Board -> Board
fillEmptyWithX board =
    Meowdoku.cells board
        |> List.filter (\cell -> cell.mark == Empty)
        |> List.foldl (\cell acc -> Meowdoku.setMarkAt cell.row cell.col MarkedX acc) board


setAllFlags : Bool -> Board -> Board
setAllFlags flag board =
    { board | rows = Array.map (Array.map (\cell -> { cell | hasConflict = flag })) board.rows }


conflicts : Board -> List ( Int, Int )
conflicts board =
    Meowdoku.cells board
        |> List.filter .hasConflict
        |> List.map (\cell -> ( cell.row, cell.col ))


marks : Board -> List CellMark
marks board =
    List.map .mark (Meowdoku.cells board)


suite : Test
suite =
    describe "Meowdoku"
        [ describe "checkConflicts"
            [ test "tabuleiro vazio não tem conflitos" <|
                \_ ->
                    conflicts board6
                        |> Expect.equal []
            , test "um gato sozinho não gera conflito" <|
                \_ ->
                    board6
                        |> placeCats [ ( 2, 3 ) ]
                        |> conflicts
                        |> Expect.equal []
            , test "dois gatos na mesma linha ficam em conflito" <|
                \_ ->
                    board6
                        |> placeCats [ ( 0, 0 ), ( 0, 5 ) ]
                        |> conflicts
                        |> Expect.equal [ ( 0, 0 ), ( 0, 5 ) ]
            , test "dois gatos na mesma coluna ficam em conflito" <|
                \_ ->
                    board6
                        |> placeCats [ ( 0, 0 ), ( 5, 0 ) ]
                        |> conflicts
                        |> Expect.equal [ ( 0, 0 ), ( 5, 0 ) ]
            , test "dois gatos na mesma região ficam em conflito" <|
                \_ ->
                    board6
                        |> placeCats [ ( 0, 5 ), ( 2, 4 ) ]
                        |> conflicts
                        |> Expect.equal [ ( 0, 5 ), ( 2, 4 ) ]
            , test "gatos vizinhos na horizontal ficam em conflito" <|
                \_ ->
                    board8
                        |> placeCats [ ( 0, 0 ), ( 0, 1 ) ]
                        |> conflicts
                        |> Expect.equal [ ( 0, 0 ), ( 0, 1 ) ]
            , test "gatos vizinhos na vertical ficam em conflito" <|
                \_ ->
                    board8
                        |> placeCats [ ( 0, 0 ), ( 1, 0 ) ]
                        |> conflicts
                        |> Expect.equal [ ( 0, 0 ), ( 1, 0 ) ]
            , test "gatos vizinhos na diagonal ficam em conflito" <|
                \_ ->
                    board6
                        |> placeCats [ ( 0, 1 ), ( 1, 2 ) ]
                        |> conflicts
                        |> Expect.equal [ ( 0, 1 ), ( 1, 2 ) ]
            , test "gatos vizinhos na outra diagonal ficam em conflito" <|
                \_ ->
                    board6
                        |> placeCats [ ( 1, 2 ), ( 2, 1 ) ]
                        |> conflicts
                        |> Expect.equal [ ( 1, 2 ), ( 2, 1 ) ]
            , test "gatos afastados, em linha, coluna e região diferentes, não conflitam" <|
                \_ ->
                    board6
                        |> placeCats [ ( 0, 0 ), ( 2, 3 ) ]
                        |> conflicts
                        |> Expect.equal []
            , test "só os gatos envolvidos ficam em conflito" <|
                \_ ->
                    board6
                        |> placeCats [ ( 0, 0 ), ( 0, 5 ), ( 3, 2 ) ]
                        |> conflicts
                        |> Expect.equal [ ( 0, 0 ), ( 0, 5 ) ]
            , test "com K=2, dois gatos na mesma linha e região são permitidos" <|
                \_ ->
                    board8
                        |> placeCats [ ( 0, 0 ), ( 0, 2 ) ]
                        |> conflicts
                        |> Expect.equal []
            , test "com K=2, o terceiro gato na linha põe os três em conflito" <|
                \_ ->
                    board8
                        |> placeCats [ ( 0, 0 ), ( 0, 2 ), ( 0, 5 ) ]
                        |> conflicts
                        |> Expect.equal [ ( 0, 0 ), ( 0, 2 ), ( 0, 5 ) ]
            , test "com K=2, o terceiro gato na coluna põe os três em conflito" <|
                \_ ->
                    board8
                        |> placeCats [ ( 0, 0 ), ( 2, 0 ), ( 4, 0 ) ]
                        |> conflicts
                        |> Expect.equal [ ( 0, 0 ), ( 2, 0 ), ( 4, 0 ) ]
            , test "casas com X não contam como gato" <|
                \_ ->
                    board6
                        |> Meowdoku.setMarkAt 0 0 MarkedX
                        |> placeCats [ ( 0, 5 ) ]
                        |> conflicts
                        |> Expect.equal []
            , test "o conflito some quando um dos gatos é removido" <|
                \_ ->
                    board6
                        |> placeCats [ ( 0, 0 ), ( 0, 5 ) ]
                        |> Meowdoku.setMarkAt 0 0 Empty
                        |> conflicts
                        |> Expect.equal []
            , test "trocar um dos gatos por X desfaz o conflito" <|
                \_ ->
                    board6
                        |> placeCats [ ( 0, 0 ), ( 0, 5 ) ]
                        |> Meowdoku.setMarkAt 0 0 MarkedX
                        |> conflicts
                        |> Expect.equal []
            , test "recalcula marcações de conflito desatualizadas" <|
                \_ ->
                    board6
                        |> placeCats [ ( 0, 0 ), ( 0, 5 ) ]
                        |> setAllFlags False
                        |> Meowdoku.checkConflicts
                        |> conflicts
                        |> Expect.equal [ ( 0, 0 ), ( 0, 5 ) ]
            , test "limpa marcações de conflito que não valem mais" <|
                \_ ->
                    board6
                        |> placeCats [ ( 2, 3 ) ]
                        |> setAllFlags True
                        |> Meowdoku.checkConflicts
                        |> conflicts
                        |> Expect.equal []
            , test "não altera as marcações das casas" <|
                \_ ->
                    let
                        board =
                            board6
                                |> placeCats [ ( 0, 0 ), ( 0, 5 ) ]
                                |> Meowdoku.setMarkAt 3 3 MarkedX
                    in
                    marks (Meowdoku.checkConflicts board)
                        |> Expect.equal (marks board)
            ]
        , describe "isSolved"
            [ test "solução completa do 6x6 vence" <|
                \_ ->
                    Meowdoku.isSolved (placeCats solution6 board6) 1
                        |> Expect.equal True
            , test "solução completa com X nas demais casas vence" <|
                \_ ->
                    Meowdoku.isSolved (board6 |> placeCats solution6 |> fillEmptyWithX) 1
                        |> Expect.equal True
            , test "solução completa do 8x8 com K=2 vence" <|
                \_ ->
                    Meowdoku.isSolved (placeCats solution8 board8) 2
                        |> Expect.equal True
            , test "vitória pelos cliques: vazio, X e gato" <|
                \_ ->
                    Meowdoku.isSolved (clickTwice solution6 board6) 1
                        |> Expect.equal True
            , test "o terceiro clique tira o gato e desfaz a vitória" <|
                \_ ->
                    Meowdoku.isSolved (board6 |> clickTwice solution6 |> Meowdoku.cycleMarkAt 0 5) 1
                        |> Expect.equal False
            , test "tabuleiro vazio não vence" <|
                \_ ->
                    Meowdoku.isSolved board6 1
                        |> Expect.equal False
            , test "tabuleiro sem regiões carregadas não vence" <|
                \_ ->
                    Meowdoku.isSolved (Meowdoku.initBoard 6 1 []) 1
                        |> Expect.equal False
            , test "faltando um gato não vence" <|
                \_ ->
                    Meowdoku.isSolved (placeCats (List.drop 1 solution6) board6) 1
                        |> Expect.equal False
            , test "um gato a mais não vence" <|
                \_ ->
                    Meowdoku.isSolved (placeCats (( 0, 0 ) :: solution6) board6) 1
                        |> Expect.equal False
            , test "gatos se tocando na diagonal não vencem" <|
                \_ ->
                    Meowdoku.isSolved (placeCats (List.map (\i -> ( i, i )) (List.range 0 5)) board6) 1
                        |> Expect.equal False
            , test "região com dois gatos não vence, mesmo com linhas e colunas completas" <|
                \_ ->
                    Meowdoku.isSolved (placeCats [ ( 0, 1 ), ( 1, 3 ), ( 2, 5 ), ( 3, 0 ), ( 4, 2 ), ( 5, 4 ) ] board6) 1
                        |> Expect.equal False
            , test "região sem gato não vence, mesmo sem nenhum conflito" <|
                \_ ->
                    let
                        board =
                            Meowdoku.initBoard 4 1 regionsWithSpare
                                |> placeCats [ ( 0, 1 ), ( 1, 3 ), ( 2, 0 ), ( 3, 2 ) ]
                    in
                    ( conflicts board, Meowdoku.isSolved board 1 )
                        |> Expect.equal ( [], False )
            , test "solução de K=1 não vence quando a meta é 2" <|
                \_ ->
                    Meowdoku.isSolved (placeCats solution6 board6) 2
                        |> Expect.equal False
            , test "solução de K=2 não vence quando a meta é 1" <|
                \_ ->
                    Meowdoku.isSolved (placeCats solution8 board8) 1
                        |> Expect.equal False
            ]
        ]
