module Meowdoku exposing
    ( Board
    , Cell
    , CellMark(..)
    , boardToMatrix
    , checkConflicts
    , countCatsInCol
    , countCatsInRegion
    , countCatsInRow
    , cycleMark
    , getCell
    , initBoard
    , isSolved
    , markToString
    , setMark
    )

{-| Meowdoku: Regras puras e modelagem funcional do jogo de gatos (Star Battle / Queens).
    Este módulo não faz chamadas HTTP e não renderiza HTML: é 100% puro e testável.
-}


{-| Estado de marcação de uma célula na grade.
-}
type CellMark
    = Empty
    | MarkedX
    | HasCat


markToString : CellMark -> String
markToString mark =
    case mark of
        Empty ->
            ""

        MarkedX ->
            "✕"

        HasCat ->
            "🐱"


type alias Cell =
    { row : Int
    , col : Int
    , regionId : Int
    , mark : CellMark
    , hasConflict : Bool
    }


type alias Board =
    { size : Int
    , cells : List Cell
    , catsPerUnit : Int
    }


{-| Inicializa um tabuleiro a partir do tamanho, gatos por unidade e matriz de IDs de regiões.
-}
initBoard : Int -> Int -> List (List Int) -> Board
initBoard size catsPerUnit regionMatrix =
    let
        createdCells =
            regionMatrix
                |> List.indexedMap
                    (\r rowList ->
                        rowList
                            |> List.indexedMap
                                (\c regId ->
                                    { row = r
                                    , col = c
                                    , regionId = regId
                                    , mark = Empty
                                    , hasConflict = False
                                    }
                                )
                    )
                |> List.concat
    in
    { size = size
    , cells = createdCells
    , catsPerUnit = catsPerUnit
    }


{-| Recupera uma célula com base na linha e coluna.
-}
getCell : Int -> Int -> Board -> Maybe Cell
getCell r c board =
    board.cells
        |> List.filter (\cell -> cell.row == r && cell.col == c)
        |> List.head


{-| Alterna o estado de marcação: Vazio -> X -> Gato -> Vazio.
-}
cycleMark : Int -> Int -> Board -> Board
cycleMark r c board =
    let
        nextMark current =
            case current of
                Empty ->
                    MarkedX

                MarkedX ->
                    HasCat

                HasCat ->
                    Empty

        updatedCells =
            List.map
                (\cell ->
                    if cell.row == r && cell.col == c then
                        { cell | mark = nextMark cell.mark }

                    else
                        cell
                )
                board.cells
    in
    checkConflicts { board | cells = updatedCells }


{-| Define explicitamente a marcação de uma célula.
-}
setMark : Int -> Int -> CellMark -> Board -> Board
setMark r c newMark board =
    let
        updatedCells =
            List.map
                (\cell ->
                    if cell.row == r && cell.col == c then
                        { cell | mark = newMark }

                    else
                        cell
                )
                board.cells
    in
    checkConflicts { board | cells = updatedCells }


{-| Conta quantos gatos existem em uma determinada linha.
-}
countCatsInRow : Int -> Board -> Int
countCatsInRow r board =
    board.cells
        |> List.filter (\cell -> cell.row == r && cell.mark == HasCat)
        |> List.length


{-| Conta quantos gatos existem em uma determinada coluna.
-}
countCatsInCol : Int -> Board -> Int
countCatsInCol c board =
    board.cells
        |> List.filter (\cell -> cell.col == c && cell.mark == HasCat)
        |> List.length


{-| Conta quantos gatos existem em uma determinada região.
-}
countCatsInRegion : Int -> Board -> Int
countCatsInRegion regId board =
    board.cells
        |> List.filter (\cell -> cell.regionId == regId && cell.mark == HasCat)
        |> List.length


{-| Validação instantânea puramente funcional de conflitos:
    Marca `hasConflict = True` se:
    1. A célula tem um gato que toca em outro gato (ortogonal ou diagonal).
    2. A linha, coluna ou região excedeu o número permitido de gatos.
-}
checkConflicts : Board -> Board
checkConflicts board =
    let
        catCells =
            List.filter (\cell -> cell.mark == HasCat) board.cells

        touchesAnotherCat cell =
            if cell.mark /= HasCat then
                False

            else
                catCells
                    |> List.any
                        (\other ->
                            (cell.row /= other.row || cell.col /= other.col)
                                && (abs (cell.row - other.row) <= 1)
                                && (abs (cell.col - other.col) <= 1)
                        )

        exceedsUnit cell =
            if cell.mark /= HasCat then
                False

            else
                (countCatsInRow cell.row board > board.catsPerUnit)
                    || (countCatsInCol cell.col board > board.catsPerUnit)
                    || (countCatsInRegion cell.regionId board > board.catsPerUnit)

        updatedCells =
            List.map
                (\cell ->
                    { cell | hasConflict = touchesAnotherCat cell || exceedsUnit cell }
                )
                board.cells
    in
    { board | cells = updatedCells }


{-| Verifica se o tabuleiro está completamente resolvido de acordo com as regras:
    - Quantidade correta de gatos em cada linha, coluna e região.
    - Nenhum conflito ativo de vizinhança.
-}
isSolved : Board -> Bool
isSolved board =
    let
        totalCatsExpected =
            board.size * board.catsPerUnit

        actualCats =
            List.filter (\cell -> cell.mark == HasCat) board.cells

        noConflicts =
            List.all (\cell -> not cell.hasConflict) board.cells

        rowsOk =
            List.range 0 (board.size - 1)
                |> List.all (\r -> countCatsInRow r board == board.catsPerUnit)

        colsOk =
            List.range 0 (board.size - 1)
                |> List.all (\c -> countCatsInCol c board == board.catsPerUnit)
    in
    (List.length actualCats == totalCatsExpected) && noConflicts && rowsOk && colsOk


{-| Converte o estado do tabuleiro em matriz binária (1 = Gato, 0 = Vazio/X)
    para envio nas requisições da API.
-}
boardToMatrix : Board -> List (List Int)
boardToMatrix board =
    List.range 0 (board.size - 1)
        |> List.map
            (\r ->
                List.range 0 (board.size - 1)
                    |> List.map
                        (\c ->
                            case getCell r c board of
                                Just cell ->
                                    if cell.mark == HasCat then
                                        1

                                    else
                                        0

                                Nothing ->
                                    0
                        )
            )

