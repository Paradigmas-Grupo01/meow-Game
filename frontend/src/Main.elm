module Main exposing (main)

import Api exposing (MeowdokuHint, MeowdokuPuzzle)
import Browser
import Html exposing (Html, aside, button, div, footer, h1, h2, header, input, label, main_, span, text)
import Html.Attributes exposing (checked, class, classList, style, type_)
import Html.Events exposing (onCheck, onClick)
import Meowdoku exposing (Board, Cell, CellMark(..))


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
      }
    , Api.fetchMeowdokuExample "classic_6x6" GotPuzzle
    )


type Msg
    = GotPuzzle (Result String MeowdokuPuzzle)
    | CellClicked Int Int
    | HintRequested
    | GotHint (Result String MeowdokuHint)
    | SolveRequested
    | GotSolution (Result String (List (List Int)))
    | ResetRequested
    | ThemeToggled Bool
    | ErrorDismissed


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
            let
                updatedBoard =
                    Meowdoku.cycleMarkAt r c model.board

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
subscriptions _ =
    Sub.none


view : Model -> Html Msg
view model =
    div
        [ classList
            [ ( "app", True )
            , ( "dark-theme", model.darkTheme )
            ]
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
                        [ span [ class "eyebrow" ] [ text "PAINEL DO JOGO" ]
                        , h2 [] [ text "Sua partida" ]
                        ]
                    , div [ class "message-area" ] [ viewMessages model ]
                    , viewStats model.board
                    , viewInstructions
                    , div [ class "controls-section" ]
                        [ span [ class "section-label" ] [ text "CONTROLES" ]
                        , button [ class "btn btn-hint", onClick HintRequested ] [ text "Pedir Dica" ]
                        , button [ class "btn btn-solve", onClick SolveRequested ] [ text "Resolver com Prolog" ]
                        , button [ class "btn btn-reset", onClick ResetRequested ] [ text "Novo Jogo" ]
                        ]
                    ]
                ]
            ]
        , footer [ class "app-footer" ]
            [ text "Clique nas células para alternar entre Vazio, X e Gato." ]
        ]


viewInstructions : Html Msg
viewInstructions =
    div [ class "instructions" ]
        [ div [ class "instructions-heading" ]
            [ span [ class "eyebrow" ] [ text "ENTENDA O DESAFIO" ]
            , h2 [] [ text "Como jogar?" ]
            ]
        , div [ class "instructions-intro" ]
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
        , style "aspect-ratio" "1"
        , style "display" "flex"
        , style "align-items" "center"
        , style "justify-content" "center"
        , style "font-size" "1.8rem"
        , style "cursor" "pointer"
        , style "border-radius" "0.375rem"
        , style "user-select" "none"
        , style "border" "1px solid rgba(0,0,0,0.15)"
        ]
        [ span [ class "cell-content" ] [ text (Meowdoku.markToString cell.mark) ] ]


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
                        , span [] [ text "Você completou o desafio respeitando todas as regras. Que tal jogar novamente?" ]
                        ]
                    ]

            else
                text ""


viewThemeToggle : Model -> Html Msg
viewThemeToggle model =
    label [ class "theme-toggle" ]
        [ input
            [ type_ "checkbox"
            , class "theme-controller"
            , checked model.darkTheme
            , onCheck ThemeToggled
            ]
            []
        , span []
            [ text
                (if model.darkTheme then
                    "Tema escuro"

                 else
                    "Tema claro"
                )
            ]
        ]
