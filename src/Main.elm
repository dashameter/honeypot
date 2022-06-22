port module Main exposing (..)

import Browser
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events exposing (onClick)
import Element.Font as Font exposing (semiBold)
import Element.Input as Input
import Element.Region as Region
import Html exposing (Html)
import Json.Decode exposing (Decoder, decodeValue, field, int, list, string, succeed)
import Json.Decode.Pipeline exposing (optional, required)
import Platform.Cmd exposing (Cmd)



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


port searchDashNames : String -> Cmd msg


port getdashNameResults : (Json.Decode.Value -> msg) -> Sub msg


port getVaults : (Json.Decode.Value -> msg) -> Sub msg


port getCreatedVaultId : (String -> msg) -> Sub msg



---- Subscriptions ----


subscriptions _ =
    Sub.batch
        [ getVaults GotVaults
        , getdashNameResults GotdashNameResults
        , getCreatedVaultId ClickedSelectVault
        ]



------ Decoders


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
            { txId = "140f16060bede8a6a4c14866cc6e0e46b69bdc946d59dea6f08eb5dde376a230"
            , outputIndex = "0"
            , satoshis = "1000000"
            }
        , output =
            { address = "yWmaDGGSz1hFxXkVUR6n69E3FqfpQ5qgQn"
            , amount = "100000"
            }
        }
    }


init : ( Model, Cmd Msg )
init =
    ( initialModel, Cmd.none )



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


digitsOnly : String -> String
digitsOnly =
    String.filter Char.isDigit


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
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
            ( { model | searchDashName = searchDashName }, cmd )

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
            ( { model | selectedVaultId = Just vaultId }, Cmd.none )



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

        -- , row [ width fill ]
        --     [ contentCard model "Transaction Queue"
        --     ]
        -- , row [ width fill ]
        --     [ contentCar d model "Transaction History"
        --     ]
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
        [ Element.el
            [ Font.color (Element.rgba255 0 103 138 1)
            , Font.size 24
            , Element.height Element.shrink
            , Element.width Element.shrink
            ]
            (Element.text <|
                String.fromInt (selectedVault model).threshold
                    --
                    ++ "/"
                    ++ String.fromInt
                        (List.length
                            (selectedVault model).identityIds
                        )
                    ++ " "
                    ++ (selectedVault model).vaultAddress
            )
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
                , Element.width (Element.shrink |> Element.maximum 50)
                , Element.paddingEach
                    { top = 16, right = 8, bottom = 8, left = 8 }
                , Border.rounded 2
                , Border.color (Element.rgba255 24 195 251 1)
                , Border.dashed
                , Border.widthXY 1 1
                ]
                { onChange = ChangedNewTransactionFormInputSatoshis
                , text = model.newTransactionForm.input.satoshis
                , placeholder = Nothing
                , label =
                    Input.labelAbove
                        [ Font.color (Element.rgba255 24 164 251 1) ]
                        (Element.text "sats")
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
                , Element.width (Element.shrink |> Element.maximum 50)
                , Element.paddingEach
                    { top = 16, right = 8, bottom = 8, left = 8 }
                , Border.rounded 2
                , Border.color (Element.rgba255 24 195 251 1)
                , Border.dashed
                , Border.widthXY 1 1
                ]
                { onChange = ChangedNewTransactionFormInputOutputIndex
                , text = model.newTransactionForm.input.outputIndex
                , placeholder = Nothing
                , label =
                    Input.labelAbove
                        [ Font.color (Element.rgba255 24 164 251 1) ]
                        (Element.text "vout")
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
                , Element.width (Element.shrink |> Element.maximum 250)
                , Element.paddingEach
                    { top = 16, right = 8, bottom = 8, left = 8 }
                , Border.rounded 2
                , Border.color (Element.rgba255 24 195 251 1)
                , Border.dashed
                , Border.widthXY 1 1
                ]
                { onChange = ChangedNewTransactionFormInputTxId
                , text = model.newTransactionForm.input.txId
                , placeholder = Nothing
                , label =
                    Input.labelAbove
                        [ Font.color (Element.rgba255 24 164 251 1) ]
                        (Element.text "txId")
                }
            ]
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
                        (Element.text "amount")
                }
            ]
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
                , Element.width (Element.shrink |> Element.maximum 250)
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
                        (Element.text "pay to address")
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


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = subscriptions
        }
