module Api exposing
    ( MeowdokuHint
    , MeowdokuPuzzle
    , encodeBoard
    , encodeRegions
    , fetchMeowdokuExample
    , hintMeowdoku
    , httpErrorToString
    , meowdokuHintDecoder
    , meowdokuPuzzleDecoder
    , solveMeowdoku
    )

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Url


type alias MeowdokuPuzzle =
    { name : String
    , size : Int
    , catsPerUnit : Int
    , regions : List (List Int)
    }


type alias MeowdokuHint =
    { row : Int
    , col : Int
    , value : Int
    , reason : String
    }


type ApiError
    = Transport Http.Error
    | Rejected Int String


fetchMeowdokuExample : String -> (Result String MeowdokuPuzzle -> msg) -> Cmd msg
fetchMeowdokuExample name toMsg =
    Http.get
        { url = "/api/meowdoku/example?name=" ++ Url.percentEncode name
        , expect = expectJson toMsg meowdokuPuzzleDecoder
        }


solveMeowdoku : List (List Int) -> Int -> (Result String (List (List Int)) -> msg) -> Cmd msg
solveMeowdoku regions catsPerUnit toMsg =
    Http.post
        { url = "/api/meowdoku/solve"
        , body = Http.jsonBody (encodeRegions regions catsPerUnit)
        , expect = expectJson toMsg solutionDecoder
        }


hintMeowdoku : List (List Int) -> List (List Int) -> Int -> (Result String MeowdokuHint -> msg) -> Cmd msg
hintMeowdoku regions board catsPerUnit toMsg =
    Http.post
        { url = "/api/meowdoku/hint"
        , body = Http.jsonBody (encodeBoard regions board catsPerUnit)
        , expect = expectJson toMsg meowdokuHintDecoder
        }


encodeMatrix : List (List Int) -> Encode.Value
encodeMatrix =
    Encode.list (Encode.list Encode.int)


encodeRegions : List (List Int) -> Int -> Encode.Value
encodeRegions regions catsPerUnit =
    Encode.object
        [ ( "regions", encodeMatrix regions )
        , ( "cats_per_unit", Encode.int catsPerUnit )
        ]


encodeBoard : List (List Int) -> List (List Int) -> Int -> Encode.Value
encodeBoard regions board catsPerUnit =
    Encode.object
        [ ( "regions", encodeMatrix regions )
        , ( "board", encodeMatrix board )
        , ( "cats_per_unit", Encode.int catsPerUnit )
        ]


meowdokuPuzzleDecoder : Decoder MeowdokuPuzzle
meowdokuPuzzleDecoder =
    Decode.map4 MeowdokuPuzzle
        (Decode.field "name" Decode.string)
        (Decode.field "size" Decode.int)
        (Decode.field "cats_per_unit" Decode.int)
        (Decode.field "regions" matrixDecoder)
        |> Decode.andThen validatePuzzle


meowdokuHintDecoder : Decoder MeowdokuHint
meowdokuHintDecoder =
    Decode.map4 MeowdokuHint
        (Decode.field "row" Decode.int)
        (Decode.field "col" Decode.int)
        (Decode.field "value" Decode.int)
        (Decode.field "reason" Decode.string)


solutionDecoder : Decoder (List (List Int))
solutionDecoder =
    Decode.field "solution" matrixDecoder


matrixDecoder : Decoder (List (List Int))
matrixDecoder =
    Decode.list (Decode.list Decode.int)


validatePuzzle : MeowdokuPuzzle -> Decoder MeowdokuPuzzle
validatePuzzle puzzle =
    let
        isSquare =
            List.length puzzle.regions
                == puzzle.size
                && List.all (\row -> List.length row == puzzle.size) puzzle.regions
    in
    if puzzle.size < 1 || puzzle.catsPerUnit < 1 then
        Decode.fail "Tamanho do tabuleiro ou quantidade de gatos inválidos."

    else if not isSquare then
        Decode.fail "A matriz de regiões não corresponde ao tamanho do tabuleiro."

    else
        Decode.succeed puzzle


expectJson : (Result String a -> msg) -> Decoder a -> Http.Expect msg
expectJson toMsg decoder =
    Http.expectStringResponse (Result.mapError apiErrorToString >> toMsg) (responseToResult decoder)


responseToResult : Decoder a -> Http.Response String -> Result ApiError a
responseToResult decoder response =
    case response of
        Http.BadUrl_ url ->
            Err (Transport (Http.BadUrl url))

        Http.Timeout_ ->
            Err (Transport Http.Timeout)

        Http.NetworkError_ ->
            Err (Transport Http.NetworkError)

        Http.BadStatus_ metadata body ->
            Err (Rejected metadata.statusCode body)

        Http.GoodStatus_ _ body ->
            Decode.decodeString decoder body
                |> Result.mapError (Decode.errorToString >> Http.BadBody >> Transport)


apiErrorToString : ApiError -> String
apiErrorToString error =
    case error of
        Transport httpError ->
            httpErrorToString httpError

        Rejected status body ->
            clientDetail status body
                |> Maybe.withDefault (httpErrorToString (Http.BadStatus status))


clientDetail : Int -> String -> Maybe String
clientDetail status body =
    if status >= 400 && status < 500 then
        Decode.decodeString detailDecoder body
            |> Result.toMaybe

    else
        Nothing


detailDecoder : Decoder String
detailDecoder =
    Decode.field "detail" Decode.string
        |> Decode.andThen
            (\detail ->
                if String.isEmpty (String.trim detail) then
                    Decode.fail "detalhe vazio"

                else
                    Decode.succeed detail
            )


httpErrorToString : Http.Error -> String
httpErrorToString error =
    case error of
        Http.BadUrl url ->
            "Endereço inválido: " ++ url

        Http.Timeout ->
            "O servidor demorou demais para responder."

        Http.NetworkError ->
            "Não foi possível falar com o servidor. O backend está rodando?"

        Http.BadStatus status ->
            statusToString status

        Http.BadBody _ ->
            "Resposta inesperada do servidor."


statusToString : Int -> String
statusToString status =
    if status == 404 then
        "Recurso não encontrado no servidor."

    else if status == 422 then
        "O servidor recusou os dados enviados."

    else if status >= 500 then
        "Erro interno do servidor (código " ++ String.fromInt status ++ ")."

    else
        "Erro na requisição (código " ++ String.fromInt status ++ ")."
