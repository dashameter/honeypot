port module Main exposing (..)

import Browser
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events exposing (onClick)
import Element.Font as Font exposing (semiBold)
import Element.Input as Input
import Element.Region as Region
import Helpers exposing (..)
import Html exposing (Html)
import Http
import Json.Decode exposing (Decoder, decodeValue, field, float, int, list, string, succeed)
import Json.Decode.Pipeline exposing (optional, required, requiredAt)
import Platform.Cmd exposing (Cmd)
import TimeFormat exposing (prettyTime)
import TransactionList exposing (transactionListView)



---- Ports ----


type alias CreateVaultArgs =
    { threshold : Int
    , identityIds : List String
    }


port createVault : CreateVaultArgs -> Cmd msg


type alias CreateTransactionArgs =
    { vault : Vault
    , utxos : List UTXO
    , output : Output
    }


port createTransaction : CreateTransactionArgs -> Cmd msg


type alias FetchTransactionsArgs =
    { vaultId : String }


port fetchTransactions : FetchTransactionsArgs -> Cmd msg


type alias SignTransactionArgs =
    { transactionId : String }


port signTransaction : SignTransactionArgs -> Cmd msg


type alias ExecuteTransactionArgs =
    { transactionId : String }


port executeTransaction : ExecuteTransactionArgs -> Cmd msg


port searchDashNames : String -> Cmd msg


port getdashNameResults : (Json.Decode.Value -> msg) -> Sub msg


port getVaults : (Json.Decode.Value -> msg) -> Sub msg


port getTransactionList : (Json.Decode.Value -> msg) -> Sub msg


port getSignatures : (Json.Decode.Value -> msg) -> Sub msg


port getCreatedVaultId : (String -> msg) -> Sub msg



---- Subscriptions ----


subscriptions _ =
    Sub.batch
        [ getVaults GotVaults
        , getdashNameResults GotdashNameResults
        , getCreatedVaultId ClickedSelectVault
        , getTransactionList GotTransactionList
        , getSignatures GotSignatures
        ]



------ Decoders


type alias TransactionListItem =
    { id : String
    , vaultId : String
    , amount : Int
    , address : String
    }


type alias Signature =
    { id : String
    , transactionId : String
    , inputIndex : Int
    , outputIndex : Int
    , prevTxId : String
    , publicKey : String
    , signature : String
    , sigtype : Int
    }


signatureDecoder : Decoder Signature
signatureDecoder =
    succeed Signature
        |> required "id" string
        |> required "transactionId" string
        |> requiredAt [ "signature", "inputIndex" ] int
        |> requiredAt [ "signature", "outputIndex" ] int
        |> requiredAt [ "signature", "prevTxId" ] string
        |> requiredAt [ "signature", "publicKey" ] string
        |> requiredAt [ "signature", "signature" ] string
        |> requiredAt [ "signature", "sigtype" ] int


type alias UTXO =
    { address : String
    , txid : String
    , vout : Int
    , scriptPubKey : String
    , satoshis : Int
    , height : Int
    , confirmations : Int
    , ts : Int
    }


utxoDecoder : Decoder UTXO
utxoDecoder =
    succeed UTXO
        |> required "address" string
        |> required "txid" string
        |> required "vout" int
        |> required "scriptPubKey" string
        |> required "satoshis" int
        |> optional "height" int 0
        |> required "confirmations" int
        |> optional "ts" int 0


transactionListDecoder : Decoder TransactionListItem
transactionListDecoder =
    succeed TransactionListItem
        |> required "id" string
        |> required "vaultId" string
        |> requiredAt [ "output", "amount" ] int
        |> requiredAt [ "output", "address" ] string


type alias Vault =
    { threshold : Int
    , vaultAddress : String
    , publicKeys : List String
    , identityIds : List String
    , id : String
    }


vaultDecoder : Decoder Vault
vaultDecoder =
    succeed Vault
        |> required "threshold" int
        |> required "vaultAddress" string
        |> required "publicKeys" (list string)
        |> required "identityIds" (list string)
        |> required "id" string


type alias ResultDashName =
    { name : String
    , identityId : String
    }


resultDashNameDecoder : Decoder ResultDashName
resultDashNameDecoder =
    succeed ResultDashName
        |> required "name" string
        |> required "identityId" string



---- MODEL ----


type alias Model =
    { selectedTx : Int
    , selectedVaultId : Maybe String
    , vaults : List Vault
    , newVaultIdentityIds : String
    , newVaultDashNames : List ResultDashName
    , newVaultThreshold : String
    , searchDashName : String
    , dashNameResults : List ResultDashName
    , newTransactionForm : TransactionForm
    , transactionList : List TransactionListItem
    , signatures : List Signature
    , utxoStatus : Status (List UTXO)
    , txHistory : List TxHistoryItem
    , txHistoryStatus : Status (List TxHistoryItem)
    }


initialModel : Model
initialModel =
    { selectedTx = -1
    , vaults = []
    , newVaultThreshold = "2"
    , newVaultIdentityIds = "hi\nho"
    , newVaultDashNames = []
    , searchDashName = ""
    , dashNameResults = []
    , selectedVaultId = Nothing
    , newTransactionForm =
        { output =
            { address = "yWmaDGGSz1hFxXkVUR6n69E3FqfpQ5qgQn"
            , amount = "100000"
            }
        }
    , transactionList = []
    , signatures = []
    , utxoStatus = Loading
    , txHistory = []
    , txHistoryStatus = Loading
    }


type alias Input =
    { txId : String
    , outputIndex : String
    , satoshis : String
    }


type alias Output =
    { address : String
    , amount : String
    }


type alias TransactionForm =
    { output : Output
    }



---- Helpers ----


filteredDashNameResults : Model -> List ResultDashName
filteredDashNameResults model =
    List.filter (\name -> not (List.member name model.newVaultDashNames)) model.dashNameResults



---- UPDATE ----


type Msg
    = ClickedSearchDashName ResultDashName
    | ClickedSelectVault String
    | ClickedNewVaultDashName ResultDashName
    | GotVaults Json.Decode.Value
    | GotdashNameResults Json.Decode.Value
    | GotTransactionList Json.Decode.Value
    | GotSignatures Json.Decode.Value
    | NewVaultIdentityIdsChanged String
    | NewVaultThresholdChanged String
    | CreateVaultPressed
    | SearchDashNameChanged String
    | PressedAddAnotherVault
    | ChangedNewTransactionFormOutputAmount String
    | PressedNewTransactionFormCreateTransaction
    | ChangedNewTransactionFormOutputAddress String
    | PressedSignTransaction String
    | PressedExecuteTransaction String
    | GotUtxos (Result Http.Error (List UTXO))
    | GotTxHistory (Result Http.Error (List TxHistoryItem))


digitsOnly : String -> String
digitsOnly =
    String.filter Char.isDigit


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotTxHistory (Ok txs) ->
            ( { model | txHistoryStatus = Loaded (List.sortWith descendingTxHistoryTime txs) }, Cmd.none )

        GotTxHistory (Err httpError) ->
            ( { model | txHistoryStatus = Errored "Insight API Error!" }, Cmd.none )

        GotUtxos (Ok utxos) ->
            ( { model | utxoStatus = Loaded (List.sortWith descendingUtxo utxos) }, Cmd.none )

        GotUtxos (Err httpError) ->
            ( { model | utxoStatus = Errored "Insight API Error!" }, Cmd.none )

        PressedExecuteTransaction transactionId ->
            let
                cmd =
                    executeTransaction { transactionId = transactionId }
            in
            ( model
            , cmd
            )

        PressedSignTransaction transactionId ->
            let
                cmd =
                    signTransaction { transactionId = transactionId }
            in
            ( model
            , cmd
            )

        GotSignatures signatures ->
            let
                newModel =
                    { model | signatures = Result.withDefault [] (decodeValue (list signatureDecoder) signatures) }
            in
            ( newModel, Cmd.none )

        GotTransactionList transactionList ->
            let
                newModel =
                    { model | transactionList = Result.withDefault [] (decodeValue (list transactionListDecoder) transactionList) }
            in
            ( newModel, Cmd.none )

        PressedNewTransactionFormCreateTransaction ->
            let
                selectEnoughUtxos : Int -> List UTXO -> Int -> List UTXO -> List UTXO
                selectEnoughUtxos startAmount startUtxos accAmount accUtxos =
                    if accAmount <= startAmount then
                        let
                            nextUtxo =
                                Maybe.withDefault
                                    { address = ""
                                    , txid = ""
                                    , vout = 0
                                    , scriptPubKey = ""
                                    , satoshis = 0
                                    , height = 0
                                    , confirmations = 0
                                    , ts = 0
                                    }
                                    (List.head
                                        startUtxos
                                    )

                            newAccumulator =
                                accAmount + nextUtxo.satoshis

                            newUtxos =
                                accUtxos ++ List.take 1 startUtxos
                        in
                        selectEnoughUtxos startAmount
                            (List.drop 1 startUtxos)
                            newAccumulator
                            newUtxos

                    else
                        accUtxos

                selectedUtxos =
                    case model.utxoStatus of
                        Loaded utxos ->
                            selectEnoughUtxos (Maybe.withDefault 0 (String.toInt model.newTransactionForm.output.amount)) utxos 0 []

                        _ ->
                            Debug.todo "todo"

                cmd =
                    createTransaction
                        { vault = selectedVault model
                        , utxos = selectedUtxos
                        , output = model.newTransactionForm.output
                        }
            in
            ( model
            , cmd
            )

        ChangedNewTransactionFormOutputAddress address ->
            let
                oldNewTransactionForm =
                    model.newTransactionForm

                oldOutput =
                    oldNewTransactionForm.output

                output =
                    { oldOutput | address = address }

                newTransactionForm =
                    { oldNewTransactionForm | output = output }
            in
            ( { model
                | newTransactionForm = newTransactionForm
              }
            , Cmd.none
            )

        ChangedNewTransactionFormOutputAmount amount ->
            let
                oldNewTransactionForm =
                    model.newTransactionForm

                oldOutput =
                    oldNewTransactionForm.output

                output =
                    { oldOutput | amount = digitsOnly amount }

                newTransactionForm =
                    { oldNewTransactionForm | output = output }
            in
            ( { model
                | newTransactionForm = newTransactionForm
              }
            , Cmd.none
            )

        PressedAddAnotherVault ->
            ( { model | selectedVaultId = Nothing }, Cmd.none )

        SearchDashNameChanged searchDashName ->
            let
                cmd =
                    searchDashNames searchDashName
            in
            ( { model | searchDashName = searchDashName, signatures = [] }, cmd )

        CreateVaultPressed ->
            let
                cmd =
                    createVault { threshold = Maybe.withDefault -1 (String.toInt model.newVaultThreshold), identityIds = List.map (\name -> name.identityId) model.newVaultDashNames }
            in
            ( model, cmd )

        NewVaultIdentityIdsChanged newVaultIdentityIds ->
            ( { model
                | newVaultIdentityIds = newVaultIdentityIds
              }
            , Cmd.none
            )

        NewVaultThresholdChanged newVaultThreshold ->
            ( { model
                | newVaultThreshold = digitsOnly newVaultThreshold
              }
            , Cmd.none
            )

        GotVaults vaults ->
            ( { model
                | vaults = Result.withDefault [] (decodeValue (list vaultDecoder) vaults)
              }
            , Cmd.none
            )

        GotdashNameResults dashNameResults ->
            ( { model
                | dashNameResults = Result.withDefault [] (decodeValue (list resultDashNameDecoder) dashNameResults)
              }
            , Cmd.none
            )

        ClickedSearchDashName dashName ->
            ( { model | newVaultDashNames = model.newVaultDashNames ++ [ dashName ] }, Cmd.none )

        ClickedNewVaultDashName dashName ->
            let
                newVaultDashNames =
                    List.filter (\name -> not (name == dashName)) model.newVaultDashNames
            in
            ( { model | newVaultDashNames = newVaultDashNames }, Cmd.none )

        ClickedSelectVault vaultId ->
            let
                cmdFetchTransactions =
                    fetchTransactions
                        { vaultId = vaultId
                        }

                newModel =
                    { model | selectedVaultId = Just vaultId, signatures = [] }

                vault =
                    Debug.log "selectedVault" (selectedVault newModel)

                cmdFetchUtxos =
                    Http.get
                        -- TODO "enable dynamic vault address once dashcore-lib produces testnet addresses"
                        -- { url = Debug.log "url " "https://testnet-insight.dashevo.org/insight-api/addr/" ++ vault.vaultAddress ++ "/utxo"
                        { url = Debug.log "url " "https://testnet-insight.dashevo.org/insight-api/addr/" ++ vault.vaultAddress ++ "/utxo"
                        , expect = Http.expectJson GotUtxos (list utxoDecoder)
                        }
            in
            ( newModel, Cmd.batch [ cmdFetchTransactions, cmdFetchUtxos, cmdFetchTxs vault.vaultAddress ] )



---- VIEW ----


view : Model -> Html Msg
view model =
    layout [ Font.size 12, width fill, height fill ] <|
        column [ width fill, height fill, spacing -1, clip ] [ topBar, mainContent model ]


menuBackground =
    rgb255 246 247 248


topBar =
    row
        [ width fill
        , paddingXY 4 4
        ]
        [ Element.paragraph
            [ Element.height Element.shrink
            , Element.width Element.fill
            , Region.heading 2
            , Font.bold
            , Font.color (Element.rgba255 240 251 255 1)
            , Font.size 28
            , Font.shadow
                { offset = ( 0, 2 )
                , blur = 10
                , color = Element.rgba255 24 195 251 1
                }
            ]
            [ Element.text "HoneyPot" ]
        , el
            [ width fill
            ]
            none
        , toolbarButton "Connect Wallet"
        ]


toolbarButton label =
    el
        [ Border.shadow
            { offset = ( 0, 4 )
            , size = 0.1
            , blur = 6
            , color = rgb255 200 200 200
            }
        , paddingXY 12 8
        , pointer
        , Border.width 1
        , Border.rounded 5
        , mouseOver [ Background.color (rgb255 246 247 248) ]
        ]
        (text label)


mainContent model =
    row [ width fill, height fill, scrollbars, Background.color (rgb255 246 247 248) ] [ leftMenu model, content model ]


leftMenu model =
    let
        attrs vault =
            [ Border.shadow
                { offset = ( 0, 5 )
                , size = 0
                , blur = 15
                , color = Element.rgba255 23 126 161 1
                }
            , Background.color (Element.rgba255 221 246 248 1)
            , Font.color (Element.rgba255 46 52 54 1)
            , Element.spacingXY 0 12
            , Element.height Element.shrink
            , Element.width Element.fill
            , Element.paddingXY 8 8
            , Border.rounded 8
            , Border.color (Element.rgba255 23 126 161 1)
            , pointer
            , mouseOver [ Border.color (Element.rgba255 223 226 161 1) ]
            , Border.solid
            , Border.widthXY 4 4
            , onClick (ClickedSelectVault vault.id)
            ]

        vaultRow vaults =
            List.map
                (\vault ->
                    Element.column
                        (attrs vault)
                        [ Element.el
                            [ Font.color (Element.rgba255 0 103 138 1)
                            , Font.size 24
                            , Element.height Element.shrink
                            , Element.width Element.shrink
                            , Font.semiBold
                            ]
                            (text <|
                                String.fromInt vault.threshold
                                    ++ "/"
                                    ++ String.fromInt
                                        (List.length
                                            vault.identityIds
                                        )
                                    ++ " "
                                    ++ String.slice 0 16 vault.vaultAddress
                                    ++ ".."
                            )
                        , Element.wrappedRow
                            [ Element.spacingXY 12 12
                            , Element.height Element.shrink
                            , Element.width Element.fill
                            ]
                            (List.map
                                (\name ->
                                    el
                                        [ Border.shadow
                                            { offset = ( 0, 5 )
                                            , size = 0
                                            , blur = 15
                                            , color = Element.rgba255 186 189 182 1
                                            }
                                        , Background.color (Element.rgba255 214 214 214 1)
                                        , Element.height Element.shrink
                                        , Element.width Element.shrink
                                        , Element.paddingXY 5 5
                                        , Border.rounded 5
                                        , Border.color (Element.rgba255 179 236 255 1)
                                        , Border.dashed
                                        , Border.widthXY 5 5
                                        ]
                                        (Element.text <| String.slice 0 6 name)
                                )
                                vault.identityIds
                            )
                        ]
                )
                vaults
    in
    column [ height fill, Border.width 1, spacing 20, paddingXY 12 20, width (px 350) ]
        ([ Element.paragraph
            [ Font.bold
            , Font.color (Element.rgba255 46 52 54 1)
            , Font.size 24
            , Element.height Element.shrink
            , Element.width Element.fill
            , Region.heading 2
            ]
            [ Element.text "Vaults" ]
         ]
            ++ vaultRow model.vaults
        )


searchDashNameInput model =
    Element.column
        [ Font.color (Element.rgba255 46 52 54 1)
        , Font.family
            [ Font.typeface "system-ui"
            , Font.typeface "-apple-system"
            , Font.typeface "sans-serif"
            ]
        , Font.size 16
        , Element.centerY
        , spacingXY 8 8
        , paddingXY 8 8
        , width fill
        ]
        [ Element.paragraph
            [ Font.bold
            , Font.color (Element.rgba255 46 52 54 1)
            , Font.size 24
            , Element.height Element.shrink
            , Element.width Element.fill
            , Region.heading 2
            ]
            [ Element.text "Search Co-Signers:" ]
        , Input.text
            [ Border.shadow
                { offset = ( 0, 2 )
                , size = 0
                , blur = 5
                , color = Element.rgba255 24 195 251 1
                }
            , Background.color (Element.rgba255 240 251 255 1)
            , Font.family [ Font.typeface "Rubik" ]
            , Element.paddingEach
                { top = 8, right = 8, bottom = 8, left = 8 }
            , Border.rounded 2
            , Border.color (Element.rgba255 24 195 251 1)
            , Border.dashed
            , Font.size 20
            , Font.semiBold
            , Font.color (Element.rgba255 24 195 251 1)
            , Border.widthXY 1 1
            , spacingXY 8 0
            , centerX
            ]
            { onChange = SearchDashNameChanged
            , text = model.searchDashName
            , placeholder = Nothing
            , label = Input.labelAbove [] (Element.text "")
            }
        , Element.textColumn
            [ Element.centerX
            , Element.height Element.shrink
            , Element.width Element.shrink
            , spacingXY 8 8
            ]
            (List.map
                (\dashNameResult ->
                    Element.el
                        [ Border.shadow
                            { offset = ( 0, 5 )
                            , size = 0
                            , blur = 10
                            , color = Element.rgba255 186 189 182 1
                            }
                        , Background.color (Element.rgba255 214 214 214 1)
                        , Element.height Element.shrink
                        , Element.width Element.shrink
                        , Element.paddingXY 5 5
                        , Border.rounded 5
                        , Border.color (Element.rgba255 179 236 255 1)
                        , Border.dashed
                        , Border.widthXY 5 5
                        , pointer
                        , mouseOver
                            [ Background.color (Element.rgba255 179 236 255 1)
                            , Border.shadow
                                { offset = ( 0, 5 )
                                , size = 0
                                , blur = 15
                                , color = Element.rgba255 179 236 255 1
                                }
                            ]
                        , onClick (ClickedSearchDashName dashNameResult)
                        ]
                        (Element.text dashNameResult.name)
                )
                (filteredDashNameResults model)
            )
        ]


resultDashNameOutput model =
    column [ paddingXY 0 24 ]
        [ row [ width (px 250), paddingXY 8 8 ]
            [ Element.paragraph
                [ Font.bold
                , Font.color (Element.rgba255 46 52 54 1)
                , Font.size 24
                , Element.height Element.shrink
                , Element.width Element.fill
                , Region.heading 2
                ]
                [ Element.text ("Signers: " ++ String.fromInt (List.length model.newVaultDashNames)) ]
            ]
        , wrappedRow [ width (px 250), centerX, spacingXY 12 12, paddingXY 12 12 ]
            (List.map
                (\dashName ->
                    Element.el
                        [ Border.shadow
                            { offset = ( 0, 5 )
                            , size = 0
                            , blur = 15
                            , color = Element.rgba255 186 189 182 1
                            }
                        , Background.color (Element.rgba255 214 214 214 1)
                        , Element.height Element.shrink
                        , Element.width Element.shrink
                        , Element.paddingXY 5 5
                        , Border.rounded 5
                        , Border.color (Element.rgba255 179 236 255 1)
                        , Border.dashed
                        , Border.widthXY 5 5
                        , mouseOver [ Background.color (Element.rgba255 179 236 255 1) ]
                        , Element.centerX
                        , Element.centerY
                        , onClick (ClickedNewVaultDashName dashName)
                        , pointer
                        ]
                        (Element.text dashName.name)
                )
                model.newVaultDashNames
            )
        ]


content model =
    row [ width fill, height fill ]
        [ case model.selectedVaultId of
            Just vaultId ->
                transactionCards model

            Nothing ->
                newVaultCard model
        ]


newVaultCard model =
    column
        [ height fill
        , width fill
        , Border.width 1
        , scrollbars
        ]
        [ row [ width fill ]
            [ Element.column
                [ Font.color (Element.rgba255 46 52 54 1)
                , Font.size 16
                , centerX
                , spacingXY 0 12
                ]
                [ Element.column
                    []
                    [ Element.paragraph
                        [ Font.bold
                        , Font.color (Element.rgba255 46 52 54 1)
                        , Font.family [ Font.typeface "Rubik" ]
                        , Font.size 36
                        , Element.height Element.shrink
                        , Element.width Element.fill
                        , Element.paddingEach
                            { top = 20, right = 0, bottom = 50, left = 0 }
                        , Region.heading 1
                        ]
                        [ Element.text "Create new vault" ]
                    , searchDashNameInput model
                    , resultDashNameOutput model
                    , row [ width (px 250), paddingXY 8 8 ]
                        [ Element.paragraph
                            [ Font.bold
                            , Font.color (Element.rgba255 46 52 54 1)
                            , Font.size 24
                            , Element.height Element.shrink
                            , Element.width Element.fill
                            , Region.heading 2
                            ]
                            [ Element.text "Threshold:" ]
                        ]
                    , Input.text
                        [ Border.shadow
                            { offset = ( 0, 2 )
                            , size = 0
                            , blur = 5
                            , color = Element.rgba255 24 195 251 1
                            }
                        , Background.color (Element.rgba255 240 251 255 1)
                        , Font.family [ Font.typeface "Rubik" ]
                        , Element.paddingEach
                            { top = 8, right = 8, bottom = 8, left = 8 }
                        , Border.rounded 2
                        , Border.color (Element.rgba255 24 195 251 1)
                        , Border.dashed
                        , Font.size 20
                        , Font.semiBold
                        , Font.color (Element.rgba255 24 195 251 1)
                        , Border.widthXY 1 1
                        , spacingXY 8 8
                        , centerX
                        , Element.width (Element.shrink |> Element.maximum 100)
                        ]
                        { onChange = NewVaultThresholdChanged
                        , text = model.newVaultThreshold
                        , placeholder = Nothing
                        , label =
                            Input.labelAbove
                                []
                                (Element.text "")
                        }
                    ]
                , el [ paddingXY 0 20, centerX ]
                    (Input.button
                        [ Border.shadow
                            { offset = ( 0, 2 )
                            , size = 0
                            , blur = 15
                            , color = Element.rgba255 24 164 251 1
                            }
                        , Background.color (Element.rgba255 24 164 251 1)
                        , Element.centerY
                        , Element.centerX
                        , Font.center
                        , Font.color (Element.rgba255 255 255 255 1)
                        , Element.paddingXY 16 8
                        , Border.rounded 2
                        , Border.color (Element.rgba255 24 164 251 1)
                        , Border.solid
                        , Border.widthXY 1 1
                        , mouseOver [ Background.color (Element.rgba255 24 195 251 1) ]
                        ]
                        { onPress = Just CreateVaultPressed, label = Element.text "Create Vault" }
                    )
                ]
            ]
        ]


transactionCards model =
    column
        [ width fill
        , height fill
        , spacing 12
        ]
        [ el [ alignRight, paddingXY 8 8 ]
            (Input.button
                [ Border.shadow
                    { offset = ( 0, 2 )
                    , size = 0
                    , blur = 15
                    , color = Element.rgba255 24 164 251 1
                    }
                , Background.color (Element.rgba255 24 164 251 1)
                , Font.center
                , Font.color (Element.rgba255 255 255 255 1)
                , Element.paddingXY 16 8
                , Border.rounded 2
                , Border.color (Element.rgba255 24 164 251 1)
                , Border.solid
                , Border.widthXY 1 1
                , mouseOver [ Background.color (Element.rgba255 24 195 251 1) ]
                ]
                { onPress = Just PressedAddAnotherVault, label = Element.text "Add Another Vault" }
            )
        , vaultDashboard model
        , newTransactionFormView model
        , transactionListView model (selectedVault model) ( PressedSignTransaction, PressedExecuteTransaction )
        , transactionHistoryListView model
        ]


newTransactionFormView model =
    column
        [ centerX
        , width (px 750)
        , spacing 20
        , paddingXY 0 20
        ]
        [ row
            [ Font.size 24
            , Font.color (Element.rgba255 0 103 138 1)
            , width fill
            ]
            [ text "Create Transaction" ]
        , Element.row
            [ Element.spacingXY 12 0
            , Element.height Element.shrink
            , Element.width Element.fill
            , spacingXY 40 0
            ]
            [ Input.text
                [ Border.shadow
                    { offset = ( 0, 2 )
                    , size = 0
                    , blur = 5
                    , color = Element.rgba255 24 195 251 1
                    }
                , Background.color (Element.rgba255 240 251 255 1)
                , Element.centerX
                , Font.family [ Font.typeface "Rubik" ]
                , Font.size 24
                , Element.spacingXY 0 10
                , Element.height Element.shrink
                , Element.width (Element.shrink |> Element.maximum 150)
                , Element.paddingEach
                    { top = 16, right = 8, bottom = 8, left = 8 }
                , Border.rounded 2
                , Border.color (Element.rgba255 24 195 251 1)
                , Border.dashed
                , Border.widthXY 1 1
                ]
                { onChange = ChangedNewTransactionFormOutputAmount
                , text = model.newTransactionForm.output.amount
                , placeholder = Nothing
                , label =
                    Input.labelAbove
                        [ Font.color (Element.rgba255 24 164 251 1) ]
                        (Element.text "Amount")
                }
            , Input.text
                [ Border.shadow
                    { offset = ( 0, 2 )
                    , size = 0
                    , blur = 5
                    , color = Element.rgba255 24 195 251 1
                    }
                , Background.color (Element.rgba255 240 251 255 1)
                , Element.centerX
                , Font.family [ Font.typeface "Rubik" ]
                , Font.size 24
                , Element.spacingXY 0 10
                , Element.height Element.shrink
                , Element.width (px 540)
                , Element.paddingEach
                    { top = 16, right = 8, bottom = 8, left = 8 }
                , Border.rounded 2
                , Border.color (Element.rgba255 24 195 251 1)
                , Border.dashed
                , Border.widthXY 1 1
                ]
                { onChange = ChangedNewTransactionFormOutputAddress
                , text = model.newTransactionForm.output.address
                , placeholder = Nothing
                , label =
                    Input.labelAbove
                        [ Font.color (Element.rgba255 24 164 251 1) ]
                        (Element.text "Recipient")
                }
            ]
        , Element.row
            [ Element.spacingXY 12 0
            , Element.height Element.shrink
            , Element.width Element.fill
            ]
            [ Input.button
                [ Border.shadow
                    { offset = ( 0, 2 )
                    , size = 0
                    , blur = 15
                    , color = Element.rgba255 24 164 251 1
                    }
                , Background.color (Element.rgba255 24 164 251 1)
                , Element.centerY
                , Element.centerX
                , Font.center
                , Font.color (Element.rgba255 255 255 255 1)
                , Element.height Element.shrink
                , Element.width Element.shrink
                , Element.paddingXY 16 8
                , Border.rounded 2
                , Border.color (Element.rgba255 24 164 251 1)
                , Border.solid
                , Border.widthXY 1 1
                , mouseOver [ Background.color (Element.rgba255 24 195 251 1) ]
                ]
                { onPress = Just PressedNewTransactionFormCreateTransaction
                , label = Element.text "Create Transaction"
                }
            ]
        ]



-- (List.map
--     (\transaction ->
--         row
--             [ height shrink
--             , width fill
--             , paddingXY 8 8
--             , Border.rounded 2
--             , Border.color (rgba255 24 195 251 1)
--             , Border.dashed
--             , Border.widthXY 1 1
--             ]
--             [ column
--                 [ height shrink
--                 , width fill
--                 ]
--                 [ paragraph
--                     [ spacingXY 0 4
--                     , height shrink
--                     , width fill
--                     ]
--                     [ text (String.slice 0 4 transaction.txid) ]
--                 ]
--             ]
--     )
--     model.txHistory
-- )


selectedVault : Model -> Vault
selectedVault model =
    Maybe.withDefault
        { id = ""
        , identityIds = []
        , publicKeys = []
        , threshold = 0
        , vaultAddress = ""
        }
    <|
        List.head <|
            List.filter (\vault -> vault.id == Maybe.withDefault "" model.selectedVaultId) model.vaults


vaultDashboard model =
    Element.column
        [ Font.color (Element.rgba255 46 52 54 1)
        , Font.family [ Font.typeface "Rubik" ]
        , Font.size 16
        , Element.spacingXY 0 12
        , centerX
        , Border.rounded 2
        , Border.color (Element.rgba255 24 195 251 1)
        , Border.dashed
        , Border.widthXY 1 1
        , paddingXY 12 12
        , width (px 750)
        ]
        [ el
            [ Font.color (Element.rgba255 0 103 138 1)
            , Font.size 24
            , Element.height Element.shrink
            , Element.width Element.shrink
            ]
            (Element.text <|
                "Threshold: "
                    ++ String.fromInt (selectedVault model).threshold
                    ++ "/"
                    ++ String.fromInt
                        (List.length
                            (selectedVault model).identityIds
                        )
            )
        , el
            [ Font.color (Element.rgba255 0 103 138 1)
            , Font.size 24
            , Element.height Element.shrink
            , Element.width Element.shrink
            ]
            (Element.text <|
                "VaultAddress: "
                    ++ (selectedVault model).vaultAddress
            )
        , el
            [ Font.color (Element.rgba255 0 103 138 1)
            , Font.size 24
            , Element.height Element.shrink
            , Element.width Element.shrink
            ]
            (text
                ("Balance: "
                    ++ (case model.utxoStatus of
                            Loaded utxos ->
                                duffsToDashString (List.foldl (+) 0 (List.map (\t -> t.satoshis) utxos)) ++ " Dash"

                            Loading ->
                                "Loading UTXOs.."

                            Errored errorMessage ->
                                "Error: " ++ errorMessage
                       )
                )
            )
        , el
            [ Font.color (Element.rgba255 0 103 138 1)
            , Font.size 18
            , Element.height Element.shrink
            , Element.width Element.shrink
            ]
            (Element.text <|
                "UTXOs:"
            )
        , Element.column
            [ Element.spacingXY 12 0
            , Element.height Element.shrink
            , Element.width Element.fill
            ]
          <|
            case model.utxoStatus of
                Loaded utxos ->
                    List.map (\utxo -> row [] [ textColumn [] [ text (duffsToDashString utxo.satoshis ++ ", Dash "), text ("vout: " ++ String.fromInt utxo.vout), text ("txId: " ++ utxo.txid) ] ]) utxos

                Loading ->
                    [ text "Loading UTXOs.." ]

                Errored errorMessage ->
                    [ text ("Error: " ++ errorMessage) ]
        ]



-- contentCard model caption =
--     column [ width fill ]
--         [ el [ paddingXY 12 5 ] <|
--             text caption
--         , column [ width fill, spacingXY 5 5, paddingXY 12 0 ] <|
--             cardItem model.selectedTx model.transactions
--         ]


cardItem selectedTx items =
    List.map
        (\item ->
            if selectedTx == item.id then
                row
                    [ spacing 50, height (px 100), width fill, Background.color (rgb 255 255 255), pointer, mouseOver [ Background.color (rgb 0 200 200) ] ]
                    [ el [] (text (String.fromInt item.id))
                    , el [] (text item.direction)
                    , el [] (text item.time)
                    , el [] (text (String.fromInt item.amount))
                    ]

            else
                row
                    [ spacing 50
                    , width fill
                    , Background.color (rgb 255 0 255)
                    , pointer
                    , mouseOver [ Background.color (rgb 0 200 200) ]
                    ]
                    [ el [] (text (String.fromInt item.id))
                    , el [] (text item.direction)
                    , el [] (text item.time)
                    , el [] (text (String.fromInt item.amount))
                    ]
        )
        items



---- PROGRAM ----


init : ( Model, Cmd Msg )
init =
    ( initialModel, Cmd.none )


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = subscriptions
        }


type Status a
    = Loading
    | Loaded a
    | Errored String


apiurl : String -> String
apiurl address =
    "https://testnet-insight.dashevo.org/insight-api/addrs/" ++ address ++ "/txs?from=0&to=50"


explorerurl =
    "https://testnet-insight.dashevo.org/insight/tx/"


type TxHistoryType
    = Received
    | Sent


type alias TxHistoryItem =
    { txid : String
    , valueIn : Float
    , valueOut : Float
    , time : Int
    , txType : TxHistoryType
    , amount : Float
    , vout : List Vout
    , vin : List Vin
    , toAddress : String
    , fromAddress : String
    }


transactionHistoryListView model =
    column
        [ spacingXY 0 8
        , centerX
        , height shrink
        , width (px 750)

        -- , Border.rounded 2
        -- , Border.color (Element.rgba255 24 195 251 1)
        -- , Border.dashed
        -- , Border.width 1
        , paddingXY 0 12
        , spacingXY 0 20
        ]
        (row
            [ Font.size 24
            , Font.color (Element.rgba255 0 103 138 1)
            , width fill
            ]
            [ text "Transaction History" ]
            :: (case model.txHistoryStatus of
                    Loaded txs ->
                        List.map
                            (\tx ->
                                newTabLink
                                    [ width fill
                                    ]
                                    { url = explorerurl ++ tx.txid
                                    , label =
                                        row
                                            [ Background.color (Element.rgba255 221 246 248 1)
                                            , Font.size 16
                                            , Font.color (Element.rgba255 0 103 138 1)
                                            , Border.shadow
                                                { offset = ( 0, 5 )
                                                , size = 0
                                                , blur = 15
                                                , color = Element.rgba255 23 126 161 1
                                                }
                                            , spacingXY 12 12
                                            , width fill
                                            , Border.rounded 8
                                            , Border.color (Element.rgba255 23 126 161 1)
                                            , pointer
                                            , mouseOver [ Border.color (Element.rgba255 223 226 161 1) ]
                                            , Border.solid
                                            , Border.widthXY 4 4
                                            , paddingXY 12 12
                                            ]
                                            [ column []
                                                [ case tx.txType of
                                                    Received ->
                                                        text ("Received " ++ String.fromFloat tx.amount ++ " Dash from " ++ tx.fromAddress)

                                                    Sent ->
                                                        text ("Sent " ++ String.fromFloat tx.amount ++ " Dash to " ++ tx.toAddress)
                                                ]
                                            , column [] [ text (prettyTime tx.time) ]
                                            ]
                                    }
                            )
                            txs

                    Loading ->
                        [ text "Loading Transactions.." ]

                    Errored errorMessage ->
                        [ text ("Error: " ++ errorMessage) ]
               )
        )


buildTxHistoryItem : String -> String -> Float -> Float -> Int -> List Vout -> List Vin -> TxHistoryItem
buildTxHistoryItem vaultAddress txid valueIn valueOut timeSecs vout vin =
    let
        -- TODO handle more complex transactions with multiple vins / vouts
        fromUtxo =
            Maybe.withDefault { address = "", value = 0 } (List.head vin)

        fromAddress =
            fromUtxo.address

        toUtxo =
            Maybe.withDefault { addresses = [ "" ], value = 0 } (List.head vout)

        toAddress =
            Maybe.withDefault "" (List.head toUtxo.addresses)

        amount =
            toUtxo.value

        txType =
            if fromUtxo.address == vaultAddress then
                Sent

            else
                Received

        time =
            timeSecs * 1000
    in
    { txid = txid
    , valueIn = valueIn
    , valueOut = valueOut
    , time = time
    , amount = amount
    , txType = txType
    , vout = vout
    , vin = vin
    , toAddress = toAddress
    , fromAddress = fromAddress
    }



-- type Msg
-- = GotTxHistory (Result Http.Error (List TxHistoryItem))


type alias Vin =
    { address : String
    , value : Float
    }


buildVout : String -> List String -> Vout
buildVout stvalue addresses =
    let
        value =
            Maybe.withDefault 0 (String.toFloat stvalue)
    in
    { value = value, addresses = addresses }


type alias Vout =
    { value : Float
    , addresses : List String
    }



-- buildVout: String -> List String -> Vout


txHistoryVoutDecoder =
    succeed buildVout
        |> required "value" string
        |> requiredAt [ "scriptPubKey", "addresses" ] (list string)


txHistoryVinDecoder =
    succeed Vin
        |> required "addr" string
        |> required "value" float



-- listTxHistoryVoutDecode =
--     succeed Vout
--         |> required "vout" (list txHistoryVoutDecoder)


txHistoryDecoder : String -> Decoder TxHistoryItem
txHistoryDecoder vaultAddress =
    succeed (buildTxHistoryItem vaultAddress)
        |> required "txid" string
        |> required "valueIn" float
        |> required "valueOut" float
        |> required "time" int
        |> required "vout" (list txHistoryVoutDecoder)
        |> required "vin" (list txHistoryVinDecoder)


cmdFetchTxs : String -> Cmd Msg
cmdFetchTxs vaultAddress =
    Http.get
        -- TODO "enable dynamic vault address once dashcore-lib produces testnet addresses"
        -- TODO "enable pagination"
        -- TODO "enable local/testnet/mainnet"
        { url = Debug.log "url " (apiurl vaultAddress)
        , expect = Http.expectJson GotTxHistory (field "items" (list (txHistoryDecoder vaultAddress)))
        }
