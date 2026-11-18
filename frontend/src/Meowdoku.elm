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
            "X"

        HasCat ->
            "G"


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


getCell : Int -> Int -> Board -> Maybe Cell
getCell r c board =
    board.cells
        |> List.filter (\cell -> cell.row == r && cell.col == c)
        |> List.head


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


countCatsInRow : Int -> Board -> Int
countCatsInRow r board =
    board.cells
        |> List.filter (\cell -> cell.row == r && cell.mark == HasCat)
        |> List.length


countCatsInCol : Int -> Board -> Int
countCatsInCol c board =
    board.cells
        |> List.filter (\cell -> cell.col == c && cell.mark == HasCat)
        |> List.length


countCatsInRegion : Int -> Board -> Int
countCatsInRegion regId board =
    board.cells
        |> List.filter (\cell -> cell.regionId == regId && cell.mark == HasCat)
        |> List.length


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
                                    case cell.mark of
                                        HasCat ->
                                            1

                                        MarkedX ->
                                            -1

                                        Empty ->
                                            0

                                Nothing ->
                                    0
                        )
            )
