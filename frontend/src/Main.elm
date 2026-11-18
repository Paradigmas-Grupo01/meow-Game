module Main exposing (main)

import Api exposing (MeowdokuHint, MeowdokuPuzzle)
import Browser
import Browser.Events
import Html exposing (Html, aside, button, div, footer, h1, h2, header, main_, span, text)
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
    , hintMessage : Maybe String
    , playerWon : Bool
    , isDragging : Bool
    , dragStart : Maybe ( Int, Int )
    , dragMark : CellMark
    , hasMovedInDrag : Bool
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { board = Meowdoku.initBoard 6 1 []
      , regions = []
      , puzzleName = "classic_6x6"
      , darkTheme = flags.darkTheme
      , loading = True
      , error = Nothing
      , hintMessage = Nothing
      , playerWon = False
      , isDragging = False
      , dragStart = Nothing
      , dragMark = Empty
      , hasMovedInDrag = False
      }
    , Api.fetchMeowdokuExample "classic_6x6" GotPuzzle
    )


type Msg
    = GotPuzzle (Result String MeowdokuPuzzle)
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
    | ErrorDismissed


nextPuzzleName : String -> String
nextPuzzleName current =
    case current of
        "classic_6x6" ->
            "lantern_6x6"

        "lantern_6x6" ->
            "classic_8x8"

        "classic_8x8" ->
            "lantern_8x8"

        "lantern_8x8" ->
            "double_8x8"

        _ ->
            "classic_6x6"


puzzleLabel : String -> String
puzzleLabel name =
    case name of
        "classic_6x6" ->
            "6x6 Clássico"

        "lantern_6x6" ->
            "6x6 Lanterna"

        "classic_8x8" ->
            "8x8 Clássico"

        "lantern_8x8" ->
            "8x8 Lanterna"

        "double_8x8" ->
            "8x8 Modo 2 Gatos"

        _ ->
            name


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
                , hintMessage = Nothing
                , playerWon = False
              }
            , Cmd.none
            )

        GotPuzzle (Err err) ->
            ( { model | loading = False, error = Just err }, Cmd.none )

        CellClicked r c ->
            if model.hasMovedInDrag then
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
                    , hintMessage = Nothing
                    , error = Nothing
                    , playerWon = completedByPlayer
                  }
                , Cmd.none
                )

        CellDoubleClicked r c ->
            let
                updatedBoard =
                    Meowdoku.setMarkAt r c HasCat model.board

                completedByPlayer =
                    Meowdoku.isSolved updatedBoard updatedBoard.catsPerUnit
            in
            ( { model
                | board = updatedBoard
                , hintMessage = Nothing
                , error = Nothing
                , playerWon = completedByPlayer
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
                    , hintMessage = Nothing
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
            ( { model | loading = True, error = Nothing, hintMessage = Nothing }
            , Api.hintMeowdoku model.regions (Meowdoku.boardToMatrix model.board) model.board.catsPerUnit GotHint
            )

        GotHint (Ok hint) ->
            ( { model
                | loading = False
                , hintMessage =
                    Just
                        ("Dica: coloque um gato na linha "
                            ++ String.fromInt (hint.row + 1)
                            ++ ", coluna "
                            ++ String.fromInt (hint.col + 1)
                            ++ " ("
                            ++ hint.reason
                            ++ ")"
                        )
              }
            , Cmd.none
            )

        GotHint (Err err) ->
            ( { model | loading = False, error = Just err }, Cmd.none )

        SolveRequested ->
            ( { model
                | loading = True
                , error = Nothing
                , hintMessage = Nothing
                , playerWon = False
              }
            , Api.solveMeowdoku model.regions model.board.catsPerUnit GotSolution
            )

        GotSolution (Ok solutionMatrix) ->
            let
                applySolution board =
                    solutionMatrix
                        |> List.indexedMap
                            (\r rowList ->
                                List.indexedMap
                                    (\c val ->
                                        if val == 1 then
                                            ( r, c, HasCat )

                                        else
                                            ( r, c, MarkedX )
                                    )
                                    rowList
                            )
                        |> List.concat
                        |> List.foldl (\( r, c, mark ) acc -> Meowdoku.setMarkAt r c mark acc) board
            in
            ( { model
                | board = applySolution model.board
                , loading = False
                , playerWon = False
                , hintMessage =
                    Just "O Prolog encontrou uma solução válida e preencheu o tabuleiro. Para vencer jogando, reinicie e complete as casas manualmente."
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
                , hintMessage = Nothing
                , playerWon = False
              }
            , Api.fetchMeowdokuExample next GotPuzzle
            )

        SelectPuzzle name ->
            ( { model
                | loading = True
                , error = Nothing
                , hintMessage = Nothing
                , playerWon = False
              }
            , Api.fetchMeowdokuExample name GotPuzzle
            )

        ResetRequested ->
            ( { model
                | board = Meowdoku.initBoard model.board.size model.board.catsPerUnit model.regions
                , hintMessage = Nothing
                , error = Nothing
                , playerWon = False
              }
            , Cmd.none
            )

        ThemeToggled dark ->
            ( { model | darkTheme = dark }, Cmd.none )

        ErrorDismissed ->
            ( { model | error = Nothing }, Cmd.none )


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
            [ ( "app", True )
            , ( "dark-theme", model.darkTheme )
            ]
        , Html.Attributes.attribute "data-theme"
            (if model.darkTheme then
                "dark"

             else
                "light"
            )
        ]
        [ header [ class "app-header" ]
            [ div [ class "app-container app-header-content" ]
                [ div [ class "brand" ]
                    [ div [ class "brand-icon" ] [ text "M" ]
                    , div []
                        [ h1 [ class "app-title" ] [ text "Meowdoku" ]
                        , span [ class "app-subtitle" ]
                            [ text "O desafio das regiões felinas" ]
                        ]
                    ]
                , viewThemeToggle model
                ]
            ]
        , main_ [ class "app-main" ]
            [ div [ class "app-container game" ]
                [ viewBoard model.board
                , aside [ class "side-panel" ]
                    [ div [ class "panel-heading" ]
                        [ span [ class "eyebrow" ] [ text ("FASE ATUAL: " ++ puzzleLabel model.puzzleName) ]
                        , h2 [] [ text "Sua partida" ]
                        ]
                    , div [ class "message-area" ] [ viewMessages model ]
                    , viewStats model.board
                    , div [ class "controls-section" ]
                        [ Html.node "details"
                            [ class "collapsible" ]
                            [ Html.node "summary"
                                [ class "collapsible-trigger" ]
                                [ text "Fases" ]
                            , div [ class "phase-selector", style "display" "flex", style "flex-wrap" "wrap", style "gap" "0.35rem", style "margin-top" "0.5rem", style "margin-bottom" "0.6rem" ]
                                [ viewPhaseButton model "classic_6x6" "6x6"
                                , viewPhaseButton model "lantern_6x6" "6x6 (L)"
                                , viewPhaseButton model "classic_8x8" "8x8"
                                , viewPhaseButton model "lantern_8x8" "8x8 (L)"
                                , viewPhaseButton model "double_8x8" "8x8 (K=2)"
                                ]
                            ]
                        , span [ class "section-label" ] [ text "ACOES" ]
                        , button [ class "btn btn-hint", onClick HintRequested ] [ text "Pedir Dica" ]
                        , button [ class "btn btn-solve", onClick SolveRequested ] [ text "Resolver com Prolog" ]
                        , button [ class "btn btn-reset", onClick NewGameRequested ] [ text "Novo Jogo (Avançar)" ]
                        , button [ class "btn btn-clear", onClick ResetRequested ] [ text "Limpar Tabuleiro" ]
                        ]
                    , viewInstructions
                    ]
                ]
            ]
        , footer [ class "app-footer" ]
            [ text "Clique nas células para alternar entre Vazio, X e Gato." ]
        ]


viewInstructions : Html Msg
viewInstructions =
    Html.node "details"
        [ class "collapsible" ]
        [ Html.node "summary"
            [ class "collapsible-trigger" ]
            [ text "Como jogar?" ]
        , div [ class "instructions" ]
            [ div [ class "instructions-intro" ]
                [ text "Seu objetivo é posicionar os gatos sem desrespeitar as regras do tabuleiro." ]
            , div [ class "instructions-rule" ]
                [ span [ class "instructions-number" ] [ text "1" ]
                , span [] [ text "Coloque exatamente um gato em cada linha." ]
                ]
            , div [ class "instructions-rule" ]
                [ span [ class "instructions-number" ] [ text "2" ]
                , span [] [ text "Coloque exatamente um gato em cada coluna." ]
                ]
            , div [ class "instructions-rule" ]
                [ span [ class "instructions-number" ] [ text "3" ]
                , span [] [ text "Cada região colorida deve conter exatamente um gato." ]
                ]
            , div [ class "instructions-rule" ]
                [ span [ class "instructions-number" ] [ text "4" ]
                , span [] [ text "Dois gatos não podem ficar em células vizinhas, nem na diagonal." ]
                ]
            , div [ class "instructions-tools" ]
                [ h2 [] [ text "Ferramentas do jogo" ]
                , pLike "Pedir Dica: solicita ao sistema uma sugestão de posição para ajudar você a continuar."
                , pLike "Resolver com Prolog: usa o mecanismo lógico Prolog para buscar uma solução completa do desafio."
                , pLike "Vitória: acontece quando o tabuleiro está completo e todas as regras são respeitadas."
                ]
            ]
        ]


pLike : String -> Html Msg
pLike content =
    div [] [ text content ]


viewStats : Board -> Html Msg
viewStats board =
    let
        totalPlaced =
            Meowdoku.cells board
                |> List.filter (\c -> c.mark == HasCat)
                |> List.length

        totalExpected =
            board.size * board.catsPerUnit

        conflictCount =
            Meowdoku.cells board
                |> List.filter .hasConflict
                |> List.length
    in
    div
        [ class "stats-box"
        , style "padding" "0.75rem"
        , style "border-radius" "0.5rem"
        , style "background" "rgba(0,0,0,0.04)"
        , style "display" "flex"
        , style "flex-direction" "column"
        , style "gap" "0.25rem"
        ]
        [ span [] [ text ("Gatos colocados: " ++ String.fromInt totalPlaced ++ " / " ++ String.fromInt totalExpected) ]
        , span [] [ text ("Meta por linha/coluna/região: " ++ String.fromInt board.catsPerUnit) ]
        , if conflictCount > 0 then
            span [ style "color" "#ef4444", style "font-weight" "bold" ]
                [ text ("Conflitos ativos: " ++ String.fromInt conflictCount) ]

          else
            text ""
        ]


viewBoard : Board -> Html Msg
viewBoard board =
    div
        [ class "meowdoku-board"
        , style "display" "grid"
        , style "grid-template-columns" ("repeat(" ++ String.fromInt board.size ++ ", minmax(0, 1fr))")
        , style "gap" "4px"
        , style "padding" "1rem"
        , style "background" "rgba(0,0,0,0.05)"
        , style "border-radius" "0.5rem"
        ]
        (List.map viewCell (Meowdoku.cells board))


viewCell : Cell -> Html Msg
viewCell cell =
    div
        [ class "meowdoku-cell"
        , classList
            [ ( "cell--conflict", cell.hasConflict )
            , ( "cell--cat", cell.mark == HasCat )
            , ( "cell--blocked", cell.mark == MarkedX )
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
        , style "font-size" "1.8rem"
        , style "cursor" "pointer"
        , style "border-radius" "0.375rem"
        , style "user-select" "none"
        , style "border" "1px solid rgba(0,0,0,0.15)"
        , style "overflow" "hidden"
        , style "padding" "0"
        ]
        [ viewCellContent cell.mark ]


viewCellContent : CellMark -> Html Msg
viewCellContent mark =
    case mark of
        Empty ->
            text ""

        MarkedX ->
            span [ class "cell-content", class "cell-content--x" ] [ text "X" ]

        HasCat ->
            Html.node "video"
                [ Html.Attributes.attribute "src" "/pinguim.mp4"
                , Html.Attributes.attribute "autoplay" ""
                , Html.Attributes.attribute "loop" ""
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


viewMessages : Model -> Html Msg
viewMessages model =
    case ( model.error, model.loading, model.hintMessage ) of
        ( Just err, _, _ ) ->
            div [ class "message message--error" ]
                [ span [] [ text err ]
                , button [ class "message-close", onClick ErrorDismissed ] [ text "✕" ]
                ]

        ( _, True, _ ) ->
            div [ class "message message--loading" ] [ text "Carregando..." ]

        ( _, _, Just hint ) ->
            div [ class "message message--hint" ] [ text hint ]

        _ ->
            if model.playerWon then
                div [ class "message message--success" ]
                    [ div []
                        [ h2 [] [ text "Parabéns! Você venceu!" ]
                        , span [] [ text "Você completou o desafio respeitando todas as regras." ]
                        ]
                    , button [ class "btn btn-reset", onClick NewGameRequested, style "margin-top" "0.5rem" ]
                        [ text "Jogar Próxima Fase" ]
                    ]

            else
                text ""


viewPhaseButton : Model -> String -> String -> Html Msg
viewPhaseButton model id label =
    button
        [ class "btn btn-phase"
        , style "font-size" "0.75rem"
        , style "padding" "0.35rem 0.55rem"
        , style "background"
            (if model.puzzleName == id then
                "var(--primary, #7763d8)"

             else
                "rgba(0,0,0,0.06)"
            )
        , style "color"
            (if model.puzzleName == id then
                "#ffffff"

             else
                "inherit"
            )
        , style "border-radius" "0.375rem"
        , style "border" "none"
        , style "cursor" "pointer"
        , onClick (SelectPuzzle id)
        ]
        [ text label ]


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
                , SvgAttr.width "20"
                , SvgAttr.height "20"
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
                , SvgAttr.width "20"
                , SvgAttr.height "20"
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
