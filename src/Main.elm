port module Main exposing (..)

import Browser
import DashClient exposing (..)
import Dict exposing (Dict)
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
import List.Extra exposing (unique)
import Network exposing (..)
import Platform.Cmd exposing (Cmd)
import Time
import TimeFormat exposing (prettyTime)
import TransactionQueue exposing (transactionQueueView)



---- Ports ----


type alias CreateVaultArgs =
    { threshold : Int
    , identityIds : List String
    , network : String
    }


port createVault : CreateVaultArgs -> Cmd msg


type alias FetchVaultArgs =
    { network : String
    }


port fetchVaults : FetchVaultArgs -> Cmd msg


type alias CreateTransactionArgs =
    { vault : Vault
    , utxos : List UTXO
    , output : Output
    , network : String
    }


port createTransaction : CreateTransactionArgs -> Cmd msg


type alias FetchTransactionsArgs =
    { vaultAddress : String, vaultId : String, network : String }


port fetchTransactions : FetchTransactionsArgs -> Cmd msg


type alias SignTransactionArgs =
    { transactionId : String, network : String }


port signTransaction : SignTransactionArgs -> Cmd msg


type alias ExecuteTransactionArgs =
    { transactionId : String, network : String }


port executeTransaction : ExecuteTransactionArgs -> Cmd msg


port searchDashNames : String -> Cmd msg


port getdashNameResults : (Json.Decode.Value -> msg) -> Sub msg


port getVaults : (Json.Decode.Value -> msg) -> Sub msg


port getTransactionQueue : (Json.Decode.Value -> msg) -> Sub msg


port getSignatures : (Json.Decode.Value -> msg) -> Sub msg


port getCreatedVaultId : (String -> msg) -> Sub msg



---- Subscriptions ----


subscriptions _ =
    Sub.batch
        [ getVaults GotVaults
        , getdashNameResults GotdashNameResults
        , getCreatedVaultId ClickedSelectVault
        , getTransactionQueue GotTxQueue
        , getSignatures GotSignatures
        , getDashClient GotDashClient
        , Time.every 5000 PollData
        ]



------ Decoders


type alias VaultBalance =
    { balanceSat : Int, txAppearances : Int }


vaultBalanceDecoder : Decoder VaultBalance
vaultBalanceDecoder =
    succeed VaultBalance
        |> required "balanceSat" int
        |> required "txAppearances" int


fetchVaultBalance : String -> String -> Cmd Msg
fetchVaultBalance vaultAddress url =
    Http.get
        { url = url
        , expect = Http.expectJson (GotVaultBalance vaultAddress) vaultBalanceDecoder
        }


type alias TransactionQueueItem =
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


transactionQueueDecoder : Decoder TransactionQueueItem
transactionQueueDecoder =
    succeed TransactionQueueItem
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
    , vaultsByAddress : Dict String VaultByAddress
    , newVaultIdentityIds : String
    , newVaultDashNames : List ResultDashName
    , newVaultThreshold : Int
    , searchDashName : String
    , dashNameResults : List ResultDashName
    , newTransactionForm : TransactionForm
    , signatures : List Signature
    , dpns : Dict String Dpns
    , flags : Flags
    , chosenL1Network : ChosenL1Network
    }


type alias VaultByAddress =
    { balanceSat : Int
    , txAppearances : Int
    , utxoStatus : Status (List UTXO)
    , vault : Status Vault
    , txHistoryStatus : Status (List TxHistoryItem)
    , txQueueStatus : Status (List TransactionQueueItem)
    }


initVaultByAddress : VaultByAddress
initVaultByAddress =
    { balanceSat = 0, txAppearances = 0, utxoStatus = Loading, vault = Loading, txHistoryStatus = Loading, txQueueStatus = Loading }


type alias ChosenL1Network =
    { network : Network, apiHost : String }


type alias Flags =
    { network : Network, apiHostTestnet : String, apiHostMainnet : String }


initialModel : Flags -> Model
initialModel flags =
    { selectedTx = -1
    , vaults = []
    , vaultsByAddress = Dict.empty
    , newVaultThreshold = 1
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
        , addressIsValid = False
        }
    , signatures = []
    , dpns = Dict.empty
    , flags = flags
    , chosenL1Network = { network = Testnet, apiHost = flags.apiHostTestnet }
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
    , addressIsValid : Bool
    }



---- Helpers ----


filteredDashNameResults : Model -> List ResultDashName
filteredDashNameResults model =
    List.filter (\name -> not (List.member name model.newVaultDashNames)) model.dashNameResults


viewVaultBalance vaultAddress model =
    case Dict.get vaultAddress model.vaultsByAddress of
        Just vaultBalance ->
            duffsToDashString vaultBalance.balanceSat ++ " Dash"

        Nothing ->
            "Loading .."



---- UPDATE ----


type Msg
    = ClickedSearchDashName ResultDashName
    | ClickedSelectVault String
    | ClickedNewVaultDashName ResultDashName
    | CreateVaultPressed
    | PressedNewTransactionFormCreateTransaction
    | PressedAddAnotherVault
    | PressedSignTransaction String
    | PressedExecuteTransaction String
    | ChooseL1Network Network
      --
    | NewVaultIdentityIdsChanged String
    | NewVaultThresholdChanged String
    | SearchDashNameChanged String
    | ChangedNewTransactionFormOutputAmount String
    | ChangedNewTransactionFormOutputAddress String
      --
    | GotUtxos String (Result Http.Error (List UTXO))
    | GotTxQueue Json.Decode.Value
    | GotTxHistory String (Result Http.Error (List TxHistoryItem))
    | GotVaultBalance String (Result Http.Error VaultBalance)
    | GotDashClient Json.Decode.Value
    | GotVaults Json.Decode.Value
    | GotdashNameResults Json.Decode.Value
    | GotSignatures Json.Decode.Value
      --
    | PollData Time.Posix


digitsOnly : String -> String
digitsOnly =
    String.filter Char.isDigit


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotVaultBalance vaultAddress vaultBalance ->
            let
                -- TODO wrap vaultBalance in Status to handle errors
                vaultBalanceWithDefault =
                    Result.withDefault { balanceSat = 0, txAppearances = 0 } vaultBalance

                oldVaultByAddress =
                    Dict.get vaultAddress model.vaultsByAddress

                newVaultByAddress =
                    case oldVaultByAddress of
                        Just vaultByAddress ->
                            { vaultByAddress | balanceSat = vaultBalanceWithDefault.balanceSat, txAppearances = vaultBalanceWithDefault.txAppearances }

                        Nothing ->
                            { initVaultByAddress | balanceSat = vaultBalanceWithDefault.balanceSat, txAppearances = vaultBalanceWithDefault.txAppearances }

                newModel =
                    { model | vaultsByAddress = Dict.insert vaultAddress newVaultByAddress model.vaultsByAddress }
            in
            ( newModel, Cmd.none )

        PollData _ ->
            let
                -- fetch balances for all vaults
                cmdFetchVaultBalances =
                    List.map
                        (\vault ->
                            let
                                url =
                                    model.chosenL1Network.apiHost ++ "/addrs/" ++ vault.vaultAddress ++ "/?noTxList=1"
                            in
                            fetchVaultBalance vault.vaultAddress url
                        )
                        model.vaults

                cmdFetchVaults =
                    fetchVaults { network = Network.toString model.chosenL1Network.network }

                cmdFetchTxHistory =
                    case model.selectedVaultId of
                        Just _ ->
                            fetchTxHistory model.chosenL1Network.apiHost (selectedVault model).vaultAddress

                        Nothing ->
                            Cmd.none

                cmdFetchTransactions =
                    case model.selectedVaultId of
                        Just vaultId ->
                            fetchTransactions
                                { vaultId = vaultId
                                , network = Network.toString model.chosenL1Network.network
                                , vaultAddress = (selectedVault model).vaultAddress
                                }

                        Nothing ->
                            Cmd.none

                cmdFetchUtxos =
                    case model.selectedVaultId of
                        Just _ ->
                            let
                                vault =
                                    selectedVault model
                            in
                            Http.get
                                { url = model.chosenL1Network.apiHost ++ "/addr/" ++ vault.vaultAddress ++ "/utxo"
                                , expect = Http.expectJson (GotUtxos vault.vaultAddress) (list utxoDecoder)
                                }

                        Nothing ->
                            Cmd.none
            in
            ( model, Cmd.batch ([ cmdFetchVaults, cmdFetchUtxos, cmdFetchTransactions, cmdFetchTxHistory ] ++ cmdFetchVaultBalances) )

        ChooseL1Network network ->
            case network of
                Testnet ->
                    let
                        newModel =
                            { model | chosenL1Network = { network = network, apiHost = model.flags.apiHostTestnet }, selectedVaultId = Nothing }

                        cmdFetchVaults =
                            fetchVaults { network = Network.toString newModel.chosenL1Network.network }
                    in
                    ( newModel, cmdFetchVaults )

                Mainnet ->
                    let
                        newModel =
                            { model | chosenL1Network = { network = network, apiHost = model.flags.apiHostMainnet }, selectedVaultId = Nothing }

                        cmdFetchVaults =
                            fetchVaults { network = Network.toString newModel.chosenL1Network.network }
                    in
                    ( newModel, Cmd.batch [ cmdFetchVaults ] )

        GotDashClient result ->
            let
                newModel =
                    decodeDashClient model result
            in
            ( newModel, Cmd.none )

        GotTxHistory vaultAddress (Ok txs) ->
            let
                oldVaultByAddress =
                    Dict.get vaultAddress model.vaultsByAddress

                newVaultByAddress =
                    case oldVaultByAddress of
                        Just vaultByAddress ->
                            { vaultByAddress | txHistoryStatus = Loaded (List.sortWith descendingTxHistoryTime txs) }

                        Nothing ->
                            { initVaultByAddress | txHistoryStatus = Loaded (List.sortWith descendingTxHistoryTime txs) }

                newModel =
                    { model | vaultsByAddress = Dict.insert vaultAddress newVaultByAddress model.vaultsByAddress }
            in
            ( newModel, Cmd.none )

        GotTxHistory vaultAddress (Err httpError) ->
            let
                oldVaultByAddress =
                    Dict.get vaultAddress model.vaultsByAddress

                newVaultByAddress =
                    case oldVaultByAddress of
                        Just vaultByAddress ->
                            { vaultByAddress | txHistoryStatus = Errored "Insight API Error!" }

                        Nothing ->
                            { initVaultByAddress | txHistoryStatus = Errored "Insight API Error!" }

                newModel =
                    { model | vaultsByAddress = Dict.insert vaultAddress newVaultByAddress model.vaultsByAddress }
            in
            ( newModel, Cmd.none )

        GotUtxos vaultAddress (Ok utxos) ->
            let
                oldVaultByAddress =
                    Dict.get vaultAddress model.vaultsByAddress

                newVaultByAddress =
                    case oldVaultByAddress of
                        Just vaultByAddress ->
                            { vaultByAddress | utxoStatus = Loaded (List.sortWith descendingUtxo utxos) }

                        Nothing ->
                            { initVaultByAddress | utxoStatus = Loaded (List.sortWith descendingUtxo utxos) }

                newModel =
                    { model | vaultsByAddress = Dict.insert vaultAddress newVaultByAddress model.vaultsByAddress }
            in
            ( newModel, Cmd.none )

        GotUtxos vaultAddress (Err httpError) ->
            let
                oldVaultByAddress =
                    Dict.get vaultAddress model.vaultsByAddress

                newVaultByAddress =
                    case oldVaultByAddress of
                        Just vaultByAddress ->
                            { vaultByAddress | utxoStatus = Errored "Insight API Error!" }

                        Nothing ->
                            { initVaultByAddress | utxoStatus = Errored "Insight API Error!" }

                newModel =
                    { model | vaultsByAddress = Dict.insert vaultAddress newVaultByAddress model.vaultsByAddress }
            in
            ( newModel, Cmd.none )

        PressedExecuteTransaction transactionId ->
            let
                cmd =
                    executeTransaction { transactionId = transactionId, network = Network.toString model.chosenL1Network.network }
            in
            ( model
            , cmd
            )

        PressedSignTransaction transactionId ->
            let
                cmd =
                    signTransaction { transactionId = transactionId, network = Network.toString model.chosenL1Network.network }
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

        GotTxQueue transactionQueue ->
            let
                maybeVaultAddress =
                    decodeValue (field "vaultAddress" string) transactionQueue
            in
            case maybeVaultAddress of
                Ok vaultAddress ->
                    let
                        oldVaultByAddress =
                            Dict.get vaultAddress model.vaultsByAddress

                        newVaultByAddress =
                            case oldVaultByAddress of
                                Just vaultByAddress ->
                                    { vaultByAddress | txQueueStatus = Loaded <| Result.withDefault [] (decodeValue (field "transactions" (list transactionQueueDecoder)) transactionQueue) }

                                Nothing ->
                                    { initVaultByAddress | txQueueStatus = Loaded <| Result.withDefault [] (decodeValue (field "transactions" (list transactionQueueDecoder)) transactionQueue) }
                    in
                    ( { model | vaultsByAddress = Dict.insert vaultAddress newVaultByAddress model.vaultsByAddress }, Cmd.none )

                Err _ ->
                    -- TODO log error, vaultAddress must always be present
                    ( model, Cmd.none )

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
                    case
                        (Maybe.withDefault initVaultByAddress <|
                            Dict.get (selectedVault model).vaultAddress model.vaultsByAddress
                        ).utxoStatus
                    of
                        Loaded utxos ->
                            selectEnoughUtxos (Maybe.withDefault 0 (String.toInt model.newTransactionForm.output.amount)) utxos 0 []

                        _ ->
                            Debug.todo "todo"

                cmd =
                    createTransaction
                        { vault = selectedVault model
                        , utxos = selectedUtxos
                        , output = model.newTransactionForm.output
                        , network = Network.toString model.chosenL1Network.network
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

                cmd =
                    dashClient { cmd = "address.isValid", payload = [ address, Network.toString model.chosenL1Network.network ] }
            in
            ( { model
                | newTransactionForm = newTransactionForm
              }
            , cmd
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
            ( { model
                | selectedVaultId = Nothing
                , signatures = []
                , newVaultThreshold = 1
                , searchDashName = ""
                , newVaultDashNames = []
                , dashNameResults = []
              }
            , Cmd.none
            )

        SearchDashNameChanged searchDashName ->
            let
                cmd =
                    searchDashNames searchDashName
            in
            ( { model | searchDashName = searchDashName, signatures = [] }, cmd )

        CreateVaultPressed ->
            let
                cmd =
                    createVault { network = Network.toString model.chosenL1Network.network, threshold = model.newVaultThreshold, identityIds = List.map (\name -> name.identityId) model.newVaultDashNames }
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
                | newVaultThreshold = Maybe.withDefault 0 (String.toInt (digitsOnly newVaultThreshold))
              }
            , Cmd.none
            )

        GotVaults vaults ->
            let
                newModel =
                    { model
                        | vaults = Result.withDefault [] (decodeValue (list vaultDecoder) vaults)
                    }

                concat : Vault -> List String
                concat a =
                    Debug.log "identityIds concat" a.identityIds

                identityIds =
                    Debug.log "identityIds" (List.map concat newModel.vaults)

                resultids =
                    List.map (\vault -> vault.identityIds) newModel.vaults
                        |> List.foldl (++) []
                        |> unique

                v =
                    Debug.log "identityIds result" resultids

                --TODO filter out identityIds that are already in the dpns dict (member)
                -- create a cmd that sends these identity ids over a port to js
                -- js resolves the identities to dpns
                -- subscription reads the dpns and decodes it
                -- view shows username or #id
                cmd =
                    dashClient { cmd = "resolveIdentities", payload = resultids }
            in
            ( newModel
            , cmd
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
                        , network = Network.toString model.chosenL1Network.network
                        , vaultAddress = (selectedVault model).vaultAddress
                        }

                newModel =
                    { model | selectedVaultId = Just vaultId, signatures = [] }

                vault =
                    Debug.log "selectedVault" (selectedVault newModel)

                cmdFetchUtxos =
                    Http.get
                        -- TODO "enable dynamic vault address once dashcore-lib produces testnet addresses"
                        { url = model.chosenL1Network.apiHost ++ "/addr/" ++ vault.vaultAddress ++ "/utxo"
                        , expect = Http.expectJson (GotUtxos vault.vaultAddress) (list utxoDecoder)
                        }
            in
            ( newModel, Cmd.batch [ cmdFetchTransactions, cmdFetchUtxos, fetchTxHistory model.chosenL1Network.apiHost vault.vaultAddress ] )



---- VIEW ----


view : Model -> Html Msg
view model =
    layout [ Font.size 12, width fill, height fill ] <|
        column [ width fill, height fill, spacing -1, clip ] [ topBar model, mainContent model ]


menuBackground =
    rgb255 246 247 248


topBar model =
    row
        [ width fill
        , paddingXY 4 4
        , spacingXY 20 20
        ]
        [ Element.paragraph
            [ Element.height Element.shrink
            , Element.width Element.shrink
            , paddingXY 20 0
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
            [ Element.text "HoneyPot"
            ]
        , el
            [ width fill
            , alignRight
            ]
            (Input.radioRow
                [ padding 10
                , spacing 20
                ]
                { onChange = ChooseL1Network
                , selected = Just model.chosenL1Network.network
                , label = Input.labelLeft [ Font.size 18, Font.extraBold, Element.centerY ] (text "L1 Network")
                , options =
                    [ Input.option Testnet (text "Testnet")
                    , Input.option Mainnet (text "Mainnet")
                    ]
                }
            )
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
                            , Font.size 14
                            , Font.bold
                            , Font.color (rgb255 0 103 138)

                            -- , Font.color
                            ]
                            [ text (viewVaultBalance vault.vaultAddress model) ]
                        , Element.wrappedRow
                            [ Element.spacingXY 12 12
                            , Element.height Element.shrink
                            , Element.width Element.fill
                            ]
                            (List.map
                                (\identityId ->
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
                                        (Element.text <|
                                            viewDashName identityId model.dpns
                                        )
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
                [ el [] (text "Signers: ")
                , el
                    [ inputColorValid (isNewVaultSignersValid model)
                    ]
                    (text (String.fromInt (List.length model.newVaultDashNames)))
                ]
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
                        , inputColorValid (isNewVaultThresholdValid model)
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
                        , text = String.fromInt model.newVaultThreshold
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
                        , Element.centerY
                        , Element.centerX
                        , Font.center
                        , Font.color (Element.rgba255 255 255 255 1)
                        , Element.paddingXY 16 8
                        , Border.rounded 2
                        , Border.color (Element.rgba255 24 164 251 1)
                        , Border.solid
                        , Border.widthXY 1 1
                        , if isNewVaultValid model then
                            btnEnabledColor

                          else
                            btnDisabledColor
                        , mouseOver [ Background.color (Element.rgba255 24 195 251 1) ]
                        ]
                        { onPress =
                            if isNewVaultValid model then
                                Just CreateVaultPressed

                            else
                                Nothing
                        , label = Element.text "Create Vault"
                        }
                    )
                ]
            ]
        ]


isNewVaultThresholdValid : Model -> Bool
isNewVaultThresholdValid model =
    model.newVaultThreshold > 0 && model.newVaultThreshold <= List.length model.newVaultDashNames


isNewVaultSignersValid : Model -> Bool
isNewVaultSignersValid model =
    List.length model.newVaultDashNames > 0


isNewVaultValid : Model -> Bool
isNewVaultValid model =
    isNewVaultSignersValid model && isNewVaultThresholdValid model


btnDisabledColor =
    Background.color (Element.rgba255 24 164 251 0.6)


btnEnabledColor =
    Background.color (Element.rgba255 24 164 251 1)


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
        , transactionQueueView model (selectedVault model) initVaultByAddress ( PressedSignTransaction, PressedExecuteTransaction )
        , transactionHistoryView model
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
                , inputColorValid model.newTransactionForm.addressIsValid
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
                , Background.color <|
                    if model.newTransactionForm.addressIsValid then
                        Element.rgba255 24 164 251 1

                    else
                        Element.rgba255 24 164 251 0.3
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


inputColorValid isValid =
    Background.color
        (if isValid then
            Element.rgba255 240 251 255 1

         else
            Element.rgba255 251 24 24 0.7
        )



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
                    ++ (case
                            (Maybe.withDefault initVaultByAddress <|
                                Dict.get (selectedVault model).vaultAddress model.vaultsByAddress
                            ).utxoStatus
                        of
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
            case
                (Maybe.withDefault initVaultByAddress <|
                    Dict.get (selectedVault model).vaultAddress model.vaultsByAddress
                ).utxoStatus
            of
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


buildFlags : String -> String -> String -> Flags
buildFlags networkString apiHostTestnet apiHostMainnet =
    let
        network =
            case networkString of
                "mainnet" ->
                    Mainnet

                "testnet" ->
                    Testnet

                _ ->
                    Debug.todo "handle error"
    in
    { apiHostTestnet = apiHostTestnet, apiHostMainnet = apiHostMainnet, network = network }


flagsDecoder =
    succeed buildFlags
        |> required "network" string
        |> required "apiHostTestnet" string
        |> required "apiHostMainnet" string


init : Json.Decode.Value -> ( Model, Cmd Msg )
init flags =
    let
        decodedFlags =
            Result.withDefault { network = Testnet, apiHostTestnet = "", apiHostMainnet = "" } (Debug.log "flagdecoder" (decodeValue flagsDecoder flags))

        model =
            initialModel decodedFlags
    in
    ( model, Cmd.batch [ fetchVaults { network = Network.toString model.chosenL1Network.network } ] )


main : Program Json.Decode.Value Model Msg
main =
    Browser.element
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }


apiurl : String -> String -> String
apiurl apiHost address =
    apiHost ++ "/addrs/" ++ address ++ "/txs?from=0&to=50"


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


transactionHistoryView model =
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
            :: (case
                    (Maybe.withDefault initVaultByAddress <|
                        Dict.get (selectedVault model).vaultAddress model.vaultsByAddress
                    ).txHistoryStatus
                of
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


fetchTxHistory : String -> String -> Cmd Msg
fetchTxHistory apiHost vaultAddress =
    Http.get
        -- TODO "enable dynamic vault address once dashcore-lib produces testnet addresses"
        -- TODO "enable pagination"
        -- TODO "enable local/testnet/mainnet"
        { url = Debug.log "url " (apiurl apiHost vaultAddress)
        , expect = Http.expectJson (GotTxHistory vaultAddress) (field "items" (list (txHistoryDecoder vaultAddress)))
        }


recipientBGColor model =
    if model.newTransactionForm.addressIsValid then
        Element.rgba255 240 251 255 1

    else
        Element.rgba255 251 24 24 0.7
