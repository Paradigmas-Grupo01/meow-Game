module Meowdoku exposing
    ( Board
    , Cell
    , CellMark(..)
    , boardToMatrix
    , cells
    , checkConflicts
    , countCatsInCol
    , countCatsInRegion
    , countCatsInRow
    , cycleMark
    , cycleMarkAt
    , getCell
    , initBoard
    , isSolved
    , markFromInt
    , markToInt
    , markToString
    , regionsToMatrix
    , setMarkAt
    , setMarksFromMatrix
    )

import Array exposing (Array)


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


cycleMark : CellMark -> CellMark
cycleMark mark =
    case mark of
        Empty ->
            MarkedX

        MarkedX ->
            HasCat

        HasCat ->
            Empty


markToInt : CellMark -> Int
markToInt mark =
    case mark of
        Empty ->
            0

        MarkedX ->
            0

        HasCat ->
            1


markFromInt : Int -> CellMark
markFromInt value =
    if value == 1 then
        HasCat

    else
        Empty


type alias Cell =
    { row : Int
    , col : Int
    , regionId : Int
    , mark : CellMark
    , hasConflict : Bool
    }


type alias Board =
    { size : Int
    , catsPerUnit : Int
    , rows : Array (Array Cell)
    }


initBoard : Int -> Int -> List (List Int) -> Board
initBoard size catsPerUnit regionMatrix =
    let
        newCell r c regId =
            { row = r
            , col = c
            , regionId = regId
            , mark = Empty
            , hasConflict = False
            }

        newRow r regionRow =
            regionRow
                |> List.indexedMap (newCell r)
                |> Array.fromList
    in
    { size = size
    , catsPerUnit = catsPerUnit
    , rows =
        regionMatrix
            |> List.indexedMap newRow
            |> Array.fromList
    }


cells : Board -> List Cell
cells board =
    board.rows
        |> Array.toList
        |> List.concatMap Array.toList


getCell : Int -> Int -> Board -> Maybe Cell
getCell r c board =
    Array.get r board.rows
        |> Maybe.andThen (Array.get c)


setMarkAt : Int -> Int -> CellMark -> Board -> Board
setMarkAt r c newMark board =
    let
        markRow row =
            Array.get c row
                |> Maybe.map (\cell -> Array.set c { cell | mark = newMark } row)
                |> Maybe.withDefault row
    in
    case Array.get r board.rows of
        Just row ->
            checkConflicts { board | rows = Array.set r (markRow row) board.rows }

        Nothing ->
            board


cycleMarkAt : Int -> Int -> Board -> Board
cycleMarkAt r c board =
    case getCell r c board of
        Just cell ->
            setMarkAt r c (cycleMark cell.mark) board

        Nothing ->
            board


countCatsInRow : Int -> Board -> Int
countCatsInRow r board =
    cells board
        |> List.filter (\cell -> cell.row == r && cell.mark == HasCat)
        |> List.length


countCatsInCol : Int -> Board -> Int
countCatsInCol c board =
    cells board
        |> List.filter (\cell -> cell.col == c && cell.mark == HasCat)
        |> List.length


countCatsInRegion : Int -> Board -> Int
countCatsInRegion regId board =
    cells board
        |> List.filter (\cell -> cell.regionId == regId && cell.mark == HasCat)
        |> List.length


checkConflicts : Board -> Board
checkConflicts board =
    let
        catCells =
            List.filter (\cell -> cell.mark == HasCat) (cells board)

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

        withConflict cell =
            { cell | hasConflict = touchesAnotherCat cell || exceedsUnit cell }
    in
    { board | rows = Array.map (Array.map withConflict) board.rows }


isSolved : Board -> Bool
isSolved board =
    let
        allCells =
            cells board

        totalCatsExpected =
            board.size * board.catsPerUnit

        actualCats =
            List.filter (\cell -> cell.mark == HasCat) allCells

        noConflicts =
            List.all (\cell -> not cell.hasConflict) allCells

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
    let
        indexes =
            List.range 0 (board.size - 1)

        valueAt r c =
            getCell r c board
                |> Maybe.map (.mark >> markToInt)
                |> Maybe.withDefault 0
    in
    List.map (\r -> List.map (valueAt r) indexes) indexes


regionsToMatrix : Board -> List (List Int)
regionsToMatrix board =
    board.rows
        |> Array.toList
        |> List.map (Array.toList >> List.map .regionId)


setMarksFromMatrix : List (List Int) -> Board -> Board
setMarksFromMatrix matrix board =
    let
        values =
            matrix
                |> List.map Array.fromList
                |> Array.fromList

        withValue cell =
            Array.get cell.row values
                |> Maybe.andThen (Array.get cell.col)
                |> Maybe.map (\value -> { cell | mark = markFromInt value })
                |> Maybe.withDefault cell
    in
    checkConflicts { board | rows = Array.map (Array.map withValue) board.rows }
