module Main exposing (main)

import Api exposing (MeowdokuHint, MeowdokuPuzzle)
import Browser
import Browser.Events
import Html exposing (Html, button, div, h2, header, main_, span, text)
import Html.Attributes exposing (class, classList, style)
import Html.Events exposing (onClick)
import Json.Decode as Decode
import Json.Encode as Encode
import Meowdoku exposing (Board, Cell, CellMark(..))
import Svg exposing (Svg)
import Svg.Attributes as SvgAttr


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type alias Flags =
    { darkTheme : Bool
    }


type alias Model =
    { board : Board
    , regions : List (List Int)
    , puzzleName : String
    , darkTheme : Bool
    , loading : Bool
    , error : Maybe String
    , hint : Maybe MeowdokuHint
    , notice : Maybe String
    , playerWon : Bool
    , playerLost : Bool
    , errors : Int
    , solution : Maybe (List (List Int))
    , isDragging : Bool
    , dragStart : Maybe ( Int, Int )
    , dragMark : CellMark
    , hasMovedInDrag : Bool
    , showLevelSelector : Bool
    , showRulesModal : Bool
    , completedPuzzles : List String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { board = Meowdoku.initBoard 6 1 []
      , regions = []
      , puzzleName = "classic_6x6"
      , darkTheme = flags.darkTheme
      , loading = True
      , error = Nothing
      , hint = Nothing
      , notice = Nothing
      , playerWon = False
      , playerLost = False
      , errors = 0
      , solution = Nothing
      , isDragging = False
      , dragStart = Nothing
      , dragMark = Empty
      , hasMovedInDrag = False
      , showLevelSelector = False
      , showRulesModal = False
      , completedPuzzles = []
      }
    , Api.fetchMeowdokuExample "classic_6x6" GotPuzzle
    )


type Msg
    = GotPuzzle (Result String MeowdokuPuzzle)
    | GotHiddenSolution (Result String (List (List Int)))
    | CellClicked Int Int
    | CellDoubleClicked Int Int
    | DragStarted Int Int
    | DragEntered Int Int
    | DragEnded
    | HintRequested
    | GotHint (Result String MeowdokuHint)
    | SolveRequested
    | GotSolution (Result String (List (List Int)))
    | ResetRequested
    | NewGameRequested
    | SelectPuzzle String
    | ThemeToggled Bool
    | ToggleLevelSelector
    | ToggleRulesModal
    | ErrorDismissed


puzzleNames : List String
puzzleNames =
    [ "classic_6x6"
    , "lantern_6x6"
    , "classic_8x8"
    , "lantern_8x8"
    , "double_8x8"
    , "level_501_8x8"
    , "level_502_10x10"
    , "level_503_10x10"
    , "level_504_9x9"
    , "level_506_10x10"
    , "level_507_10x10"
    , "level_508_10x10"
    , "level_510_10x10"
    , "level_513_10x10"
    , "level_514_9x9"
    , "level_515_11x11"
    ]


nextPuzzleName : String -> String
nextPuzzleName current =
    let
        index =
            puzzleNames
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, name ) -> name == current)
                |> List.head
                |> Maybe.map Tuple.first
                |> Maybe.withDefault -1
    in
    puzzleNames
        |> List.drop (modBy (List.length puzzleNames) (index + 1))
        |> List.head
        |> Maybe.withDefault "classic_6x6"


puzzleLabel : String -> String
puzzleLabel name =
    case name of
        "classic_6x6" ->
            "Fase 1: 6x6 Clássico"

        "lantern_6x6" ->
            "Fase 2: 6x6 Lanterna"

        "classic_8x8" ->
            "Fase 3: 8x8 Clássico"

        "lantern_8x8" ->
            "Fase 4: 8x8 Lanterna"

        "double_8x8" ->
            "Fase 5: 8x8 Modo 2 Gatos"

        "level_501_8x8" ->
            "Fase 6: 8x8 Nível 501"

        "level_502_10x10" ->
            "Fase 7: 10x10 Nível 502"

        "level_503_10x10" ->
            "Fase 8: 10x10 Nível 503"

        "level_504_9x9" ->
            "Fase 9: 9x9 Nível 504"

        "level_506_10x10" ->
            "Fase 10: 10x10 Nível 506"

        "level_507_10x10" ->
            "Fase 11: 10x10 Nível 507"

        "level_508_10x10" ->
            "Fase 12: 10x10 Nível 508"

        "level_510_10x10" ->
            "Fase 13: 10x10 Nível 510"

        "level_513_10x10" ->
            "Fase 14: 10x10 Nível 513"

        "level_514_9x9" ->
            "Fase 15: 9x9 Nível 514"

        "level_515_11x11" ->
            "Fase 16: 11x11 Nível 515"

        _ ->
            name


countCatsPlaced : Board -> Int
countCatsPlaced board =
    Meowdoku.cells board
        |> List.filter (\c -> c.mark == HasCat)
        |> List.length


hintText : MeowdokuHint -> String
hintText h =
    let
        action =
            if h.value == 1 then
                "coloque um gato"

            else
                "marque com X"
    in
    "Dica: "
        ++ action
        ++ " na linha "
        ++ String.fromInt (h.row + 1)
        ++ ", coluna "
        ++ String.fromInt (h.col + 1)
        ++ " ("
        ++ h.reason
        ++ ")"


startRequest : Cmd Msg -> Model -> ( Model, Cmd Msg )
startRequest cmd model =
    ( { model
        | loading = True
        , error = Nothing
        , hint = Nothing
        , notice = Nothing
      }
    , cmd
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotPuzzle (Ok puzzle) ->
            let
                newBoard =
                    Meowdoku.initBoard puzzle.size puzzle.catsPerUnit puzzle.regions
            in
            ( { model
                | board = newBoard
                , regions = puzzle.regions
                , puzzleName = puzzle.name
                , loading = False
                , error = Nothing
                , hint = Nothing
                , notice = Nothing
                , playerWon = False
                , playerLost = False
                , errors = 0
                , solution = Nothing
                , showLevelSelector = False
              }
            , Api.solveMeowdoku puzzle.regions puzzle.catsPerUnit GotHiddenSolution
            )

        GotPuzzle (Err err) ->
            ( { model | loading = False, error = Just err }, Cmd.none )

        GotHiddenSolution (Ok sol) ->
            ( { model | solution = Just sol }, Cmd.none )

        GotHiddenSolution (Err _) ->
            ( model, Cmd.none )

        CellClicked r c ->
            if model.playerWon || model.playerLost then
                ( model, Cmd.none )

            else if model.hasMovedInDrag then
                ( { model | hasMovedInDrag = False }, Cmd.none )

            else
                let
                    currentMark =
                        case Meowdoku.getCell r c model.board of
                            Just cell ->
                                cell.mark

                            Nothing ->
                                Empty

                    newMark =
                        case currentMark of
                            Empty ->
                                MarkedX

                            MarkedX ->
                                Empty

                            HasCat ->
                                Empty

                    updatedBoard =
                        Meowdoku.setMarkAt r c newMark model.board

                    completedByPlayer =
                        Meowdoku.isSolved updatedBoard updatedBoard.catsPerUnit
                in
                ( { model
                    | board = updatedBoard
                    , hint = Nothing
                    , notice = Nothing
                    , error = Nothing
                    , playerWon = completedByPlayer
                  }
                , Cmd.none
                )

        CellDoubleClicked r c ->
            if model.playerWon || model.playerLost then
                ( model, Cmd.none )

            else
                let
                    currentMark =
                        case Meowdoku.getCell r c model.board of
                            Just cell ->
                                cell.mark

                            Nothing ->
                                Empty
                in
                if currentMark == HasCat then
                    ( model, Cmd.none )

                else
                    let
                        isCorrect =
                            case model.solution of
                                Just sol ->
                                    sol
                                        |> List.drop r
                                        |> List.head
                                        |> Maybe.andThen (List.drop c >> List.head)
                                        |> Maybe.map (\val -> val == 1)
                                        |> Maybe.withDefault False

                                Nothing ->
                                    True
                    in
                    if isCorrect then
                        let
                            updatedBoard =
                                Meowdoku.setMarkAt r c HasCat model.board

                            completed =
                                Meowdoku.isSolved updatedBoard updatedBoard.catsPerUnit

                            newCompletedList =
                                if completed && not (List.member model.puzzleName model.completedPuzzles) then
                                    model.puzzleName :: model.completedPuzzles

                                else
                                    model.completedPuzzles
                        in
                        ( { model
                            | board = updatedBoard
                            , playerWon = completed
                            , completedPuzzles = newCompletedList
                            , hint = Nothing
                            , notice = Nothing
                            , error = Nothing
                          }
                        , Cmd.none
                        )

                    else
                        let
                            newErrors =
                                model.errors + 1

                            lost =
                                newErrors >= 3

                            updatedBoard =
                                Meowdoku.setMarkAt r c MarkedX model.board
                        in
                        ( { model
                            | board = updatedBoard
                            , errors = newErrors
                            , playerLost = lost
                            , error =
                                if lost then
                                    Nothing

                                else
                                    Just ("Posição incorreta! Erro " ++ String.fromInt newErrors ++ " de 3.")
                          }
                        , Cmd.none
                        )

        DragStarted r c ->
            let
                currentMark =
                    case Meowdoku.getCell r c model.board of
                        Just cell ->
                            cell.mark

                        Nothing ->
                            Empty

                chosenDragMark =
                    case currentMark of
                        Empty ->
                            MarkedX

                        _ ->
                            Empty
            in
            ( { model
                | isDragging = True
                , dragStart = Just ( r, c )
                , dragMark = chosenDragMark
                , hasMovedInDrag = False
              }
            , Cmd.none
            )

        DragEntered r c ->
            if model.isDragging then
                let
                    intermediateBoard =
                        case ( model.hasMovedInDrag, model.dragStart ) of
                            ( False, Just ( startR, startC ) ) ->
                                Meowdoku.setMarkAt startR startC model.dragMark model.board

                            _ ->
                                model.board

                    updatedBoard =
                        Meowdoku.setMarkAt r c model.dragMark intermediateBoard

                    completedByPlayer =
                        Meowdoku.isSolved updatedBoard updatedBoard.catsPerUnit
                in
                ( { model
                    | board = updatedBoard
                    , hasMovedInDrag = True
                    , hint = Nothing
                    , notice = Nothing
                    , error = Nothing
                    , playerWon = completedByPlayer
                  }
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        DragEnded ->
            ( { model | isDragging = False, dragStart = Nothing }, Cmd.none )

        HintRequested ->
            startRequest
                (Api.hintMeowdoku model.regions (Meowdoku.boardToMatrix model.board) model.board.catsPerUnit GotHint)
                model

        GotHint (Ok h) ->
            ( { model | loading = False, hint = Just h }, Cmd.none )

        GotHint (Err err) ->
            ( { model | loading = False, error = Just err }, Cmd.none )

        SolveRequested ->
            startRequest
                (Api.solveMeowdoku model.regions model.board.catsPerUnit GotSolution)
                model

        GotSolution (Ok solutionMatrix) ->
            ( { model
                | board = Meowdoku.setMarksFromMatrix solutionMatrix model.board
                , loading = False
                , playerWon = False
                , playerLost = False
                , hint = Nothing
                , notice =
                    Just "O Prolog preencheu a solução completa. Para vencer jogando, reinicie a fase."
              }
            , Cmd.none
            )

        GotSolution (Err err) ->
            ( { model | loading = False, error = Just err }, Cmd.none )

        NewGameRequested ->
            let
                next =
                    nextPuzzleName model.puzzleName
            in
            ( { model
                | loading = True
                , error = Nothing
                , hint = Nothing
                , notice = Nothing
                , playerWon = False
                , playerLost = False
                , errors = 0
              }
            , Api.fetchMeowdokuExample next GotPuzzle
            )

        SelectPuzzle name ->
            ( { model
                | loading = True
                , error = Nothing
                , hint = Nothing
                , notice = Nothing
                , playerWon = False
                , playerLost = False
                , errors = 0
                , showLevelSelector = False
              }
            , Api.fetchMeowdokuExample name GotPuzzle
            )

        ResetRequested ->
            ( { model
                | board = Meowdoku.initBoard model.board.size model.board.catsPerUnit model.regions
                , hint = Nothing
                , notice = Nothing
                , error = Nothing
                , playerWon = False
                , playerLost = False
                , errors = 0
              }
            , Cmd.none
            )

        ThemeToggled dark ->
            ( { model | darkTheme = dark }, Cmd.none )

        ToggleLevelSelector ->
            ( { model | showLevelSelector = not model.showLevelSelector, showRulesModal = False }, Cmd.none )

        ToggleRulesModal ->
            ( { model | showRulesModal = not model.showRulesModal, showLevelSelector = False }, Cmd.none )

        ErrorDismissed ->
            ( { model | error = Nothing, hint = Nothing, notice = Nothing }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.isDragging then
        Browser.Events.onMouseUp (Decode.succeed DragEnded)

    else
        Sub.none


view : Model -> Html Msg
view model =
    div
        [ classList
            [ ( "game-app", True )
            , ( "dark-theme", model.darkTheme )
            ]
        , Html.Attributes.attribute "data-theme"
            (if model.darkTheme then
                "dark"

             else
                "light"
            )
        ]
        [ viewHeader model
        , main_ [ class "game-main" ]
            [ div [ class "game-board-container" ]
                [ viewBoard model.hint model.board
                , viewBoardControls model
                ]
            ]
        , viewVictoryModal model
        , viewDefeatModal model
        , viewLevelSelectorModal model
        , viewRulesModal model
        ]


viewHeader : Model -> Html Msg
viewHeader model =
    header [ class "game-header" ]
        [ div [ class "header-inner" ]
            [ div [ class "header-left" ]
                [ div [ class "pill-badge pill-badge--cat" ]
                    [ viewCatIcon
                    , span [ class "pill-text" ]
                        [ text (String.fromInt (countCatsPlaced model.board) ++ "/" ++ String.fromInt (model.board.size * model.board.catsPerUnit)) ]
                    ]
                , div [ class "pill-badge pill-badge--lives" ]
                    [ viewHeartIcon (model.errors < 1)
                    , viewHeartIcon (model.errors < 2)
                    , viewHeartIcon (model.errors < 3)
                    , span [ class "pill-text" ] [ text ("Erros: " ++ String.fromInt model.errors ++ "/3") ]
                    ]
                ]
            , div [ class "header-center" ]
                [ div [ class "difficulty-eyebrow" ]
                    [ text
                        (if model.board.catsPerUnit > 1 then
                            "MODO ULTRA (K=2)"

                         else
                            "DIFICULDADE"
                        )
                    ]
                , div [ class "difficulty-selector" ]
                    [ button
                        [ class "pill-tab"
                        , classList [ ( "pill-tab--active", model.board.catsPerUnit == 1 ) ]
                        , onClick (SelectPuzzle "classic_6x6")
                        ]
                        [ text "NORMAL" ]
                    , button
                        [ class "pill-tab"
                        , classList [ ( "pill-tab--active", model.board.catsPerUnit > 1 ) ]
                        , onClick (SelectPuzzle "double_8x8")
                        ]
                        [ text "ULTRA" ]
                    ]
                ]
            , div [ class "header-right" ]
                [ button [ class "icon-btn", onClick ToggleLevelSelector, Html.Attributes.attribute "title" "Selecionar Fases" ]
                    [ viewLevelsGridIcon ]
                , button [ class "icon-btn", onClick HintRequested, Html.Attributes.attribute "title" "Pedir Dica" ]
                    [ viewLightbulbIcon ]
                , button [ class "icon-btn", onClick ResetRequested, Html.Attributes.attribute "title" "Reiniciar Tabuleiro" ]
                    [ viewRestartIcon ]
                , button [ class "icon-btn", onClick ToggleRulesModal, Html.Attributes.attribute "title" "Como Jogar" ]
                    [ viewHelpIcon ]
                , viewThemeToggle model
                ]
            ]
        ]


viewBoard : Maybe MeowdokuHint -> Board -> Html Msg
viewBoard maybeHint board =
    div [ class "meowdoku-board-card" ]
        [ div
            [ class "meowdoku-board"
            , style "display" "grid"
            , style "grid-template-columns" ("repeat(" ++ String.fromInt board.size ++ ", minmax(0, 1fr))")
            , style "gap" "4px"
            ]
            (List.map (viewCell maybeHint) (Meowdoku.cells board))
        ]


viewCell : Maybe MeowdokuHint -> Cell -> Html Msg
viewCell maybeHint cell =
    let
        isHinted =
            case maybeHint of
                Just h ->
                    h.row == cell.row && h.col == cell.col

                Nothing ->
                    False

        hintOutline =
            if isHinted then
                [ style "outline" "3px solid #f59e0b", style "outline-offset" "-3px", style "z-index" "2" ]

            else
                []
    in
    div
        ([ class "meowdoku-cell"
         , classList
            [ ( "cell--conflict", cell.hasConflict )
            , ( "cell--cat", cell.mark == HasCat )
            , ( "cell--blocked", cell.mark == MarkedX )
            , ( "cell--hint", isHinted )
            , ( "region-" ++ String.fromInt cell.regionId, True )
            ]
         , onClick (CellClicked cell.row cell.col)
         , Html.Events.on "dblclick" (Decode.succeed (CellDoubleClicked cell.row cell.col))
         , Html.Events.on "mousedown" (Decode.succeed (DragStarted cell.row cell.col))
         , Html.Events.on "mouseenter" (Decode.succeed (DragEntered cell.row cell.col))
         , Html.Attributes.attribute "draggable" "false"
         , style "aspect-ratio" "1"
         , style "display" "flex"
         , style "align-items" "center"
         , style "justify-content" "center"
         , style "cursor" "pointer"
         , style "border-radius" "8px"
         , style "user-select" "none"
         , style "overflow" "hidden"
         , style "padding" "0"
         ]
            ++ hintOutline
        )
        [ viewCellContent cell.mark ]


viewCellContent : CellMark -> Html Msg
viewCellContent mark =
    case mark of
        Empty ->
            text ""

        MarkedX ->
            span [ class "cell-mark-x" ] [ text "✕" ]

        HasCat ->
            Html.node "video"
                [ Html.Attributes.attribute "src" "/gato.mp4"
                , Html.Attributes.attribute "autoplay" ""
                , Html.Attributes.attribute "muted" ""
                , Html.Attributes.attribute "playsinline" ""
                , Html.Attributes.property "muted" (Encode.bool True)
                , style "width" "100%"
                , style "height" "100%"
                , style "object-fit" "cover"
                , style "pointer-events" "none"
                , style "display" "block"
                ]
                []


viewBoardControls : Model -> Html Msg
viewBoardControls model =
    div [ class "game-controls-bar" ]
        [ case ( model.error, model.hint, model.notice ) of
            ( Just err, _, _ ) ->
                div [ class "game-feedback game-feedback--error" ]
                    [ span [] [ text err ]
                    , button [ class "feedback-close", onClick ErrorDismissed ] [ text "✕" ]
                    ]

            ( _, Just h, _ ) ->
                div [ class "game-feedback game-feedback--hint" ]
                    [ span [] [ text (hintText h) ]
                    , button [ class "feedback-close", onClick ErrorDismissed ] [ text "✕" ]
                    ]

            ( _, _, Just notif ) ->
                div [ class "game-feedback game-feedback--hint" ]
                    [ span [] [ text notif ]
                    , button [ class "feedback-close", onClick ErrorDismissed ] [ text "✕" ]
                    ]

            _ ->
                text ""
        , div [ class "quick-actions-row" ]
            [ button [ class "btn-quick btn-quick--hint", onClick HintRequested ]
                [ viewLightbulbIconSmall, span [] [ text "Pedir Dica" ] ]
            , button [ class "btn-quick btn-quick--solve", onClick SolveRequested ]
                [ text "Resolver com Prolog" ]
            ]
        ]


viewVictoryModal : Model -> Html Msg
viewVictoryModal model =
    if model.playerWon then
        div [ class "modal-overlay" ]
            [ div [ class "modal-card" ]
                [ div [ class "modal-eyebrow" ] [ text "LEVEL COMPLETE" ]
                , h2 [ class "modal-title" ] [ text (puzzleLabel model.puzzleName ++ " vencida.") ]
                , div [ class "modal-subtitle" ]
                    [ text
                        (if model.board.catsPerUnit > 1 then
                            "Cada linha, coluna e região possui exatamente 2 gatos sem se tocar."

                         else
                            "Cada linha, coluna e região possui exatamente um gato."
                        )
                    ]
                , div [ class "modal-badge" ]
                    [ text
                        (if model.errors == 0 then
                            "Perfeito! Concluído com 0 erros"

                         else
                            "Concluído com " ++ String.fromInt model.errors ++ " erro(s)"
                        )
                    ]
                , div [ class "modal-actions" ]
                    [ button [ class "modal-btn modal-btn--primary", onClick NewGameRequested ]
                        [ text "Próxima Fase" ]
                    , button [ class "modal-btn modal-btn--secondary", onClick ResetRequested ]
                        [ text "Jogar Novamente" ]
                    ]
                ]
            ]

    else
        text ""


viewDefeatModal : Model -> Html Msg
viewDefeatModal model =
    if model.playerLost then
        div [ class "modal-overlay" ]
            [ div [ class "modal-card modal-card--defeat" ]
                [ div [ class "modal-eyebrow modal-eyebrow--defeat" ] [ text "FIM DE JOGO" ]
                , h2 [ class "modal-title" ] [ text "Você cometeu 3 erros." ]
                , div [ class "modal-subtitle" ]
                    [ text "Analise as regiões e use o clique simples para marcar com X as casas eliminadas antes de posicionar um gato." ]
                , div [ class "modal-actions" ]
                    [ button [ class "modal-btn modal-btn--primary", onClick ResetRequested ]
                        [ text "Tentar Novamente" ]
                    , button [ class "modal-btn modal-btn--secondary", onClick ToggleLevelSelector ]
                        [ text "Escolher Outra Fase" ]
                    ]
                ]
            ]

    else
        text ""


viewLevelSelectorModal : Model -> Html Msg
viewLevelSelectorModal model =
    if model.showLevelSelector then
        div [ class "modal-overlay" ]
            [ div [ class "modal-card modal-card--levels" ]
                [ div [ class "levels-header" ]
                    [ h2 [ class "modal-title", style "margin" "0" ] [ text "Fases do Jogo" ]
                    , button [ class "icon-btn icon-btn--close", onClick ToggleLevelSelector ] [ text "✕" ]
                    ]
                , div [ class "levels-grid" ]
                    [ viewLevelCard model "classic_6x6" "1" "6x6 Clássico" "Normal"
                    , viewLevelCard model "lantern_6x6" "2" "6x6 Lanterna" "Normal"
                    , viewLevelCard model "classic_8x8" "3" "8x8 Clássico" "Normal"
                    , viewLevelCard model "lantern_8x8" "4" "8x8 Lanterna" "Normal"
                    , viewLevelCard model "double_8x8" "5" "8x8 2 Gatos" "Ultra (K=2)"
                    , viewLevelCard model "level_501_8x8" "6" "8x8 Nível 501" "Normal"
                    , viewLevelCard model "level_502_10x10" "7" "10x10 Nível 502" "Normal"
                    , viewLevelCard model "level_503_10x10" "8" "10x10 Nível 503" "Normal"
                    , viewLevelCard model "level_504_9x9" "9" "9x9 Nível 504" "Normal"
                    , viewLevelCard model "level_506_10x10" "10" "10x10 Nível 506" "Normal"
                    , viewLevelCard model "level_507_10x10" "11" "10x10 Nível 507" "Normal"
                    , viewLevelCard model "level_508_10x10" "12" "10x10 Nível 508" "Normal"
                    , viewLevelCard model "level_510_10x10" "13" "10x10 Nível 510" "Difícil"
                    , viewLevelCard model "level_513_10x10" "14" "10x10 Nível 513" "Normal"
                    , viewLevelCard model "level_514_9x9" "15" "9x9 Nível 514" "Normal"
                    , viewLevelCard model "level_515_11x11" "16" "11x11 Nível 515" "Master"
                    ]
                ]
            ]

    else
        text ""


viewLevelCard : Model -> String -> String -> String -> String -> Html Msg
viewLevelCard model id num label diff =
    let
        isActive =
            model.puzzleName == id

        isCompleted =
            List.member id model.completedPuzzles
    in
    button
        [ class "level-card"
        , classList [ ( "level-card--active", isActive ) ]
        , onClick (SelectPuzzle id)
        ]
        [ div [ class "level-card-top" ]
            [ span [ class "level-num" ] [ text num ]
            , if isCompleted then
                viewCheckIcon

              else
                text ""
            ]
        , span [ class "level-label" ] [ text label ]
        , span [ class "level-diff" ] [ text diff ]
        ]


viewRulesModal : Model -> Html Msg
viewRulesModal model =
    if model.showRulesModal then
        div [ class "modal-overlay" ]
            [ div [ class "modal-card modal-card--rules" ]
                [ div [ class "levels-header" ]
                    [ h2 [ class "modal-title", style "margin" "0" ] [ text "Como Jogar" ]
                    , button [ class "icon-btn icon-btn--close", onClick ToggleRulesModal ] [ text "✕" ]
                    ]
                , div [ class "rules-body" ]
                    [ div [ class "rule-item" ]
                        [ span [ class "rule-badge" ] [ text "1" ]
                        , span [] [ text "Coloque o número exato de gatos em cada linha, coluna e região colorida (1 no Normal, 2 no Ultra)." ]
                        ]
                    , div [ class "rule-item" ]
                        [ span [ class "rule-badge" ] [ text "2" ]
                        , span [] [ text "Dois gatos nunca podem se tocar, nem mesmo na diagonal." ]
                        ]
                    , div [ class "rule-item" ]
                        [ span [ class "rule-badge" ] [ text "3" ]
                        , span [] [ text "1 clique simples: marca a casa com X para eliminá-la. Clique novamente para desmarcar." ]
                        ]
                    , div [ class "rule-item" ]
                        [ span [ class "rule-badge" ] [ text "4" ]
                        , span [] [ text "2 cliques rápidos: posiciona o gato. Se acertar, o gatinho surge! Se errar, conta 1 erro (3 erros encerram o jogo)." ]
                        ]
                    , div [ class "rule-item" ]
                        [ span [ class "rule-badge" ] [ text "5" ]
                        , span [] [ text "Arrastar o mouse: preenche rapidamente uma linha inteira com X." ]
                        ]
                    ]
                ]
            ]

    else
        text ""


viewThemeToggle : Model -> Html Msg
viewThemeToggle model =
    div [ class "theme-toggle" ]
        [ button
            [ class "btn-theme"
            , classList [ ( "btn-theme--active", not model.darkTheme ) ]
            , onClick (ThemeToggled False)
            , Html.Attributes.attribute "type" "button"
            , Html.Attributes.attribute "title" "Tema claro"
            , Html.Attributes.attribute "aria-label" "Tema claro"
            , Html.Attributes.attribute "data-theme-choice" "light"
            ]
            [ Svg.svg
                [ SvgAttr.viewBox "0 0 24 24"
                , SvgAttr.width "18"
                , SvgAttr.height "18"
                , SvgAttr.fill "none"
                , SvgAttr.stroke "currentColor"
                , SvgAttr.strokeWidth "2"
                , SvgAttr.strokeLinecap "round"
                , SvgAttr.strokeLinejoin "round"
                ]
                [ Svg.circle [ SvgAttr.cx "12", SvgAttr.cy "12", SvgAttr.r "5" ] []
                , Svg.line [ SvgAttr.x1 "12", SvgAttr.y1 "1", SvgAttr.x2 "12", SvgAttr.y2 "3" ] []
                , Svg.line [ SvgAttr.x1 "12", SvgAttr.y1 "21", SvgAttr.x2 "12", SvgAttr.y2 "23" ] []
                , Svg.line [ SvgAttr.x1 "4.22", SvgAttr.y1 "4.22", SvgAttr.x2 "5.64", SvgAttr.y2 "5.64" ] []
                , Svg.line [ SvgAttr.x1 "18.36", SvgAttr.y1 "18.36", SvgAttr.x2 "19.78", SvgAttr.y2 "19.78" ] []
                , Svg.line [ SvgAttr.x1 "1", SvgAttr.y1 "12", SvgAttr.x2 "3", SvgAttr.y2 "12" ] []
                , Svg.line [ SvgAttr.x1 "21", SvgAttr.y1 "12", SvgAttr.x2 "23", SvgAttr.y2 "12" ] []
                , Svg.line [ SvgAttr.x1 "4.22", SvgAttr.y1 "19.78", SvgAttr.x2 "5.64", SvgAttr.y2 "18.36" ] []
                , Svg.line [ SvgAttr.x1 "18.36", SvgAttr.y1 "5.64", SvgAttr.x2 "19.78", SvgAttr.y2 "4.22" ] []
                ]
            ]
        , button
            [ class "btn-theme"
            , classList [ ( "btn-theme--active", model.darkTheme ) ]
            , onClick (ThemeToggled True)
            , Html.Attributes.attribute "type" "button"
            , Html.Attributes.attribute "title" "Tema escuro"
            , Html.Attributes.attribute "aria-label" "Tema escuro"
            , Html.Attributes.attribute "data-theme-choice" "dark"
            ]
            [ Svg.svg
                [ SvgAttr.viewBox "0 0 24 24"
                , SvgAttr.width "18"
                , SvgAttr.height "18"
                , SvgAttr.fill "none"
                , SvgAttr.stroke "currentColor"
                , SvgAttr.strokeWidth "2"
                , SvgAttr.strokeLinecap "round"
                , SvgAttr.strokeLinejoin "round"
                ]
                [ Svg.path [ SvgAttr.d "M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" ] []
                ]
            ]
        ]


viewCatIcon : Html Msg
viewCatIcon =
    Svg.svg
        [ SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.width "18"
        , SvgAttr.height "18"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        ]
        [ Svg.path [ SvgAttr.d "M4 6 L4 2 L7 5 M20 6 L20 2 L17 5 M4 11 C4 16 8 19 12 19 C16 19 20 16 20 11 C20 7 16 7 12 7 C8 7 4 7 4 11 Z" ] []
        ]


viewHeartIcon : Bool -> Html Msg
viewHeartIcon active =
    Svg.svg
        [ SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.width "16"
        , SvgAttr.height "16"
        , SvgAttr.fill
            (if active then
                "#ef4444"

             else
                "none"
            )
        , SvgAttr.stroke
            (if active then
                "#ef4444"

             else
                "#94a3b8"
            )
        , SvgAttr.strokeWidth "2"
        ]
        [ Svg.path [ SvgAttr.d "M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z" ] []
        ]


viewLevelsGridIcon : Html Msg
viewLevelsGridIcon =
    Svg.svg
        [ SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.width "18"
        , SvgAttr.height "18"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        ]
        [ Svg.rect [ SvgAttr.x "3", SvgAttr.y "3", SvgAttr.width "7", SvgAttr.height "7", SvgAttr.rx "2" ] []
        , Svg.rect [ SvgAttr.x "14", SvgAttr.y "3", SvgAttr.width "7", SvgAttr.height "7", SvgAttr.rx "2" ] []
        , Svg.rect [ SvgAttr.x "3", SvgAttr.y "14", SvgAttr.width "7", SvgAttr.height "7", SvgAttr.rx "2" ] []
        , Svg.rect [ SvgAttr.x "14", SvgAttr.y "14", SvgAttr.width "7", SvgAttr.height "7", SvgAttr.rx "2" ] []
        ]


viewLightbulbIcon : Html Msg
viewLightbulbIcon =
    Svg.svg
        [ SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.width "18"
        , SvgAttr.height "18"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        ]
        [ Svg.path [ SvgAttr.d "M9 18h6m-4 4h2m-5-8.5a7 7 0 1 1 8 0c-1.5 1.5-2 2.5-2 4.5h-4c0-2-.5-3-2-4.5z" ] []
        ]


viewLightbulbIconSmall : Html Msg
viewLightbulbIconSmall =
    Svg.svg
        [ SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.width "15"
        , SvgAttr.height "15"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        ]
        [ Svg.path [ SvgAttr.d "M9 18h6m-4 4h2m-5-8.5a7 7 0 1 1 8 0c-1.5 1.5-2 2.5-2 4.5h-4c0-2-.5-3-2-4.5z" ] []
        ]


viewRestartIcon : Html Msg
viewRestartIcon =
    Svg.svg
        [ SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.width "18"
        , SvgAttr.height "18"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        ]
        [ Svg.path [ SvgAttr.d "M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" ] []
        , Svg.path [ SvgAttr.d "M3 3v5h5" ] []
        ]


viewHelpIcon : Html Msg
viewHelpIcon =
    Svg.svg
        [ SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.width "18"
        , SvgAttr.height "18"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        ]
        [ Svg.circle [ SvgAttr.cx "12", SvgAttr.cy "12", SvgAttr.r "10" ] []
        , Svg.path [ SvgAttr.d "M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" ] []
        , Svg.line [ SvgAttr.x1 "12", SvgAttr.y1 "17", SvgAttr.x2 "12.01", SvgAttr.y2 "17" ] []
        ]


viewCheckIcon : Html Msg
viewCheckIcon =
    Svg.svg
        [ SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.width "14"
        , SvgAttr.height "14"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "#10b981"
        , SvgAttr.strokeWidth "3"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        ]
        [ Svg.path [ SvgAttr.d "M20 6L9 17l-5-5" ] []
        ]
