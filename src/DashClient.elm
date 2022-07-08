port module DashClient exposing (DashClient, Dpns, buildDpns, dashClient, decodeDashClient, decodeDashClientCmd, getDashClient, viewDashName)

import Dict exposing (Dict)
import Json.Decode exposing (Decoder, bool, decodeValue, field, float, int, list, string, succeed)
import Json.Decode.Pipeline exposing (optional, required, requiredAt)


viewDashName : String -> Dict String Dpns -> String
viewDashName identityId dpns =
    case Dict.get identityId dpns of
        Just dpnsDoc ->
            dpnsDoc.label

        Nothing ->
            "#" ++ String.slice 0 6 identityId



---- DashClient


type alias DashClient =
    { cmd : DashCmd
    , payload : List String
    }


type alias DashCmd =
    String


port dashClient : DashClient -> Cmd msg


port getDashClient : (Json.Decode.Value -> msg) -> Sub msg



-- type Msg
--     = GotDashClient Json.Decode.Value


decodeDashClientCmd : Json.Decode.Value -> Result Json.Decode.Error DashCmd
decodeDashClientCmd result =
    decodeValue (field "cmd" string) result



-- decodeDashClient : { a | dpns : Dict String Dpns } -> Json.Decode.Value -> { a | dpns : Dict String Dpns }
-- decodeDashClient : { a | newTransactionForm : { b | addressIsValid : Bool }, dpns : Dict String Dpns } -> Json.Decode.Value -> { c | newTransactionForm : { b | addressIsValid : Json.Decode.Value } }
-- decodeDashClient : { a | newTransactionForm : { b | addressIsValid : Bool }, dpns : Dict String Dpns } -> Json.Decode.Value -> { c | newTransactionForm : { b | addressIsValid : Result Json.Decode.Error Bool } }
-- decodeDashClient : { a | newTransactionForm : { b | addressIsValid : Bool }, dpns : Dict String Dpns } -> Json.Decode.Value -> { c | newTransactionForm : { b | addressIsValid : Bool } }


decodeDashClient model result =
    case decodeDashClientCmd result of
        Ok "address.isValid" ->
            let
                isValid =
                    Debug.log "isValid" (Result.withDefault False (decodeValue (field "result" bool) result))

                newTransactionForm =
                    model.newTransactionForm

                updatedTransactionForm =
                    { newTransactionForm | addressIsValid = isValid }
            in
            { model | newTransactionForm = updatedTransactionForm }

        Ok "resolveIdentities" ->
            let
                dpnsDoc =
                    Result.withDefault (buildDpns "" "" "" "") (Debug.log "result cmd" (decodeValue (field "result" dpnsDecoder) result))
            in
            { model | dpns = Dict.insert dpnsDoc.ownerId dpnsDoc model.dpns }

        _ ->
            Debug.todo "todo"



---- DPNS


type alias Dpns =
    { id : String
    , label : String
    , normalizedLabel : String
    , ownerId : String
    }


buildDpns : String -> String -> String -> String -> Dpns
buildDpns id ownerId label normalizedLabel =
    { id = id
    , ownerId = ownerId
    , label = label
    , normalizedLabel = normalizedLabel
    }


dpnsDecoder : Decoder Dpns
dpnsDecoder =
    succeed buildDpns
        |> required "$id" string
        |> required "$ownerId" string
        |> required "label" string
        |> required "normalizedLabel" string
