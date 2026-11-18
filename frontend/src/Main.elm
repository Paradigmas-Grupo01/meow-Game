module Main exposing (main)

import Api exposing (MeowdokuHint, MeowdokuPuzzle)
import Browser
import Html exposing (Html, aside, button, div, footer, h1, h2, header, input, label, main_, span, text)
import Html.Attributes exposing (checked, class, classList, disabled, style, type_)
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
    , hint : Maybe MeowdokuHint
    , notice : Maybe String
    , playerWon : Bool
    }


puzzleNames : List String
puzzleNames =
    [ "classic_6x6", "lantern_6x6", "classic_8x8", "lantern_8x8", "double_8x8" ]


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
      }
    , Api.fetchMeowdokuExample "classic_6x6" GotPuzzle
    )


type Msg
    = NewGameRequested String
    | GotPuzzle (Result String MeowdokuPuzzle)
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
        NewGameRequested name ->
            if model.loading then
                ( model, Cmd.none )

            else
                ( { model
                    | loading = True
                    , error = Nothing
                    , hint = Nothing
                    , notice = Nothing
                    , playerWon = False
                  }
                , Api.fetchMeowdokuExample name GotPuzzle
                )

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
                , hint = Nothing
                , notice = Nothing
                , error = Nothing
                , playerWon = completedByPlayer
              }
            , Cmd.none
            )

        HintRequested ->
            startRequest
                (Api.hintMeowdoku model.regions (Meowdoku.boardToMatrix model.board) model.board.catsPerUnit GotHint)
                model

        GotHint (Ok hint) ->
            ( { model | loading = False, hint = Just hint }, Cmd.none )

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
                , hint = Nothing
                , notice =
                    Just "O Prolog encontrou uma solução válida e preencheu o tabuleiro. Para vencer jogando, limpe o tabuleiro e complete as casas manualmente."
              }
            , Cmd.none
            )

        GotSolution (Err err) ->
            ( { model | loading = False, error = Just err }, Cmd.none )

        ResetRequested ->
            ( { model
                | board = Meowdoku.initBoard model.board.size model.board.catsPerUnit model.regions
                , hint = Nothing
                , notice = Nothing
                , error = Nothing
                , playerWon = False
              }
            , Cmd.none
            )

        ThemeToggled dark ->
            ( { model | darkTheme = dark }, Cmd.none )

        ErrorDismissed ->
            ( { model | error = Nothing }, Cmd.none )


startRequest : Cmd Msg -> Model -> ( Model, Cmd Msg )
startRequest request model =
    if model.loading then
        ( model, Cmd.none )

    else if List.isEmpty model.regions then
        ( { model | error = Just "Nenhum tabuleiro carregado. Use Novo Jogo para tentar novamente." }
        , Cmd.none
        )

    else
        ( { model | loading = True, error = Nothing, hint = Nothing, notice = Nothing }
        , request
        )


hintText : MeowdokuHint -> String
hintText hint =
    let
        position =
            "linha " ++ String.fromInt (hint.row + 1) ++ ", coluna " ++ String.fromInt (hint.col + 1)

        action =
            if hint.value == 1 then
                "Dica: coloque um gato na "

            else
                "Dica: remova o gato da "
    in
    action ++ position ++ " (" ++ hint.reason ++ ")"


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
                [ viewBoard model.hint model.board
                , aside [ class "side-panel" ]
                    [ div [ class "panel-heading" ]
                        [ span [ class "eyebrow" ] [ text "PAINEL DO JOGO" ]
                        , h2 [] [ text "Sua partida" ]
                        ]
                    , div [ class "message-area" ] [ viewMessages model ]
                    , viewStats model.puzzleName model.board
                    , viewInstructions
                    , div [ class "controls-section" ]
                        [ span [ class "section-label" ] [ text "CONTROLES" ]
                        , button [ class "btn btn-hint", disabled model.loading, onClick HintRequested ] [ text "Pedir Dica" ]
                        , button [ class "btn btn-solve", disabled model.loading, onClick SolveRequested ] [ text "Resolver com Prolog" ]
                        , button [ class "btn btn-reset", disabled model.loading, onClick ResetRequested ] [ text "Limpar Tabuleiro" ]
                        , button [ class "btn btn-reset", disabled model.loading, onClick (NewGameRequested (nextPuzzleName model.puzzleName)) ] [ text "Novo Jogo" ]
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


viewStats : String -> Board -> Html Msg
viewStats puzzleName board =
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
        [ span [] [ text ("Mapa: " ++ puzzleName) ]
        , span [] [ text ("Gatos colocados: " ++ String.fromInt totalPlaced ++ " / " ++ String.fromInt totalExpected) ]
        , span [] [ text ("Meta por linha/coluna/região: " ++ String.fromInt board.catsPerUnit) ]
        , if conflictCount > 0 then
            span [ style "color" "#ef4444", style "font-weight" "bold" ]
                [ text ("Conflitos ativos: " ++ String.fromInt conflictCount) ]

          else
            text ""
        ]


viewBoard : Maybe MeowdokuHint -> Board -> Html Msg
viewBoard hint board =
    div
        [ class "meowdoku-board"
        , style "display" "grid"
        , style "grid-template-columns" ("repeat(" ++ String.fromInt board.size ++ ", minmax(0, 1fr))")
        , style "gap" "4px"
        , style "padding" "1rem"
        , style "background" "rgba(0,0,0,0.05)"
        , style "border-radius" "0.5rem"
        ]
        (List.map (viewCell hint) (Meowdoku.cells board))


viewCell : Maybe MeowdokuHint -> Cell -> Html Msg
viewCell hint cell =
    let
        isHinted =
            case hint of
                Just h ->
                    h.row == cell.row && h.col == cell.col

                Nothing ->
                    False

        hintStyle =
            if isHinted then
                [ style "outline" "3px solid #f59e0b", style "outline-offset" "-3px" ]

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
            ++ hintStyle
        )
        [ span [ class "cell-content" ] [ text (Meowdoku.markToString cell.mark) ] ]


viewMessages : Model -> Html Msg
viewMessages model =
    case ( model.error, model.loading ) of
        ( Just err, _ ) ->
            div [ class "message message--error" ]
                [ span [] [ text err ]
                , button [ class "message-close", onClick ErrorDismissed ] [ text "✕" ]
                ]

        ( _, True ) ->
            div [ class "message message--loading" ] [ text "Carregando..." ]

        _ ->
            case ( model.hint, model.notice ) of
                ( Just hint, _ ) ->
                    div [ class "message message--hint" ] [ text (hintText hint) ]

                ( _, Just notice ) ->
                    div [ class "message message--hint" ] [ text notice ]

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
