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
import Json.Decode exposing (Decoder, decodeValue, field, int, list, string, succeed)
import Json.Decode.Pipeline exposing (optional, required, requiredAt)
import Platform.Cmd exposing (Cmd)
import TransactionList exposing (transactionListView)



---- Ports ----


type alias CreateVaultArgs =
    { threshold : Int
    , identityIds : List String
    }


port createVault : CreateVaultArgs -> Cmd msg


type alias CreateTransactionArgs =
    { vault : Vault
    , transactionArgs : TransactionForm
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
    }


utxoDecoder : Decoder UTXO
utxoDecoder =
    succeed UTXO
        |> required "address" string
        |> required "txid" string
        |> required "vout" int
        |> required "scriptPubKey" string
        |> required "satoshis" int
        |> required "height" int
        |> required "confirmations" int


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
    , utxoStatus : UTXOStatus
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
        { input =
            { txId = "556069a9991f618faf18a1d2853dd96aefaa25a2676cefdb625fa15e64ff1a50"
            , outputIndex = "0"
            , satoshis = "1000000"
            }
        , output =
            { address = "yWmaDGGSz1hFxXkVUR6n69E3FqfpQ5qgQn"
            , amount = "100000"
            }
        }
    , transactionList = []
    , signatures = []
    , utxoStatus = Loading
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
    { input : Input
    , output : Output
    }


type UTXOStatus
    = Loading
    | Loaded (List UTXO) String
    | Errored String



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
    | ChangedNewTransactionFormInputOutputIndex String
    | ChangedNewTransactionFormInputSatoshis String
    | ChangedNewTransactionFormInputTxId String
    | ChangedNewTransactionFormOutputAmount String
    | PressedNewTransactionFormCreateTransaction
    | ChangedNewTransactionFormOutputAddress String
    | PressedSignTransaction String
    | PressedExecuteTransaction String
    | GotUtxos (Result Http.Error (List UTXO))


digitsOnly : String -> String
digitsOnly =
    String.filter Char.isDigit


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotUtxos (Ok utxos) ->
            case utxos of
                first :: rest ->
                    ( { model | utxoStatus = Loaded utxos first.txid }, Cmd.none )

                [] ->
                    ( { model | utxoStatus = Errored "0 utxos found" }, Cmd.none )

        GotUtxos (Err httpError) ->
            ( { model | utxoStatus = Errored "Inisght API Error!" }, Cmd.none )

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
                cmd =
                    createTransaction
                        { vault = selectedVault model
                        , transactionArgs = model.newTransactionForm
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

        ChangedNewTransactionFormInputSatoshis satoshis ->
            let
                oldNewTransactionForm =
                    model.newTransactionForm

                oldInput =
                    oldNewTransactionForm.input

                input =
                    { oldInput | satoshis = digitsOnly satoshis }

                newTransactionForm =
                    { oldNewTransactionForm | input = input }
            in
            ( { model
                | newTransactionForm = newTransactionForm
              }
            , Cmd.none
            )

        ChangedNewTransactionFormInputOutputIndex outputIndex ->
            let
                oldNewTransactionForm =
                    model.newTransactionForm

                oldInput =
                    oldNewTransactionForm.input

                input =
                    { oldInput | outputIndex = digitsOnly outputIndex }

                newTransactionForm =
                    { oldNewTransactionForm | input = input }
            in
            ( { model
                | newTransactionForm = newTransactionForm
              }
            , Cmd.none
            )

        ChangedNewTransactionFormInputTxId txId ->
            let
                oldNewTransactionForm =
                    model.newTransactionForm

                oldInput =
                    oldNewTransactionForm.input

                input =
                    { oldInput | txId = txId }

                newTransactionForm =
                    { oldNewTransactionForm | input = input }
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

                vault =
                    selectedVault model

                cmdFetchUtxos =
                    Http.get
                        -- TODO "enable dynamic vault address once dashcore-lib produces testnet addresses"
                        -- { url = Debug.log "url " "https://testnet-insight.dashevo.org/insight-api/addr/" ++ vault.vaultAddress ++ "/utxo"
                        { url = Debug.log "url " "https://testnet-insight.dashevo.org/insight-api/addr/91DzvuNvNgP2p5KenQNYBSyivDL848fhzG/utxo"
                        , expect = Http.expectJson GotUtxos (list utxoDecoder)
                        }
            in
            ( { model | selectedVaultId = Just vaultId, signatures = [] }, Cmd.batch [ cmdFetchTransactions, cmdFetchUtxos ] )



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
        , newTransactionFormCard model
        , transactionListView model (selectedVault model) ( PressedSignTransaction, PressedExecuteTransaction )
        ]


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


newTransactionFormCard model =
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
                            Loaded utxos _ ->
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
                Loaded utxos _ ->
                    List.map (\utxo -> row [] [ textColumn [] [ text (duffsToDashString utxo.satoshis ++ ", Dash "), text ("vout: " ++ String.fromInt utxo.vout), text ("txId: " ++ utxo.txid) ] ]) utxos

                Loading ->
                    [ text "Loading UTXOs.." ]

                Errored errorMessage ->
                    [ text ("Error: " ++ errorMessage) ]
        , Element.row
            [ Element.spacingXY 12 0
            , Element.height Element.shrink
            , Element.width Element.fill
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
                , Element.width (px 500)
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
