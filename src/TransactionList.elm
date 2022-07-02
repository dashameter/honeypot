module TransactionList exposing (..)

import Browser
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Helpers exposing (duffsToDashString)
import Html


transactionListView model selectedVault ( pressedSignTransaction, pressedExecuteTransaction ) =
    column
        [ centerX

        -- , explain Debug.todo
        , width (px 750)
        , spacing 20
        , paddingXY 0 20
        ]
        [ row
            [ Font.size 24
            , Font.color (Element.rgba255 0 103 138 1)
            , width fill
            ]
            [ text "Transaction Queue" ]
        , column
            [ spacingXY 0 8
            , centerX
            , height shrink
            , width fill
            , Font.family [ Font.typeface "Rubik" ]
            , Font.size 14
            , Font.color (Element.rgba255 0 103 138 1)
            ]
            (List.map
                (\transaction ->
                    row
                        [ height shrink
                        , width fill
                        , paddingXY 8 8
                        , Border.rounded 2
                        , Border.color (rgba255 24 195 251 1)
                        , Border.dashed
                        , Border.widthXY 1 1
                        ]
                        [ column
                            [ height shrink
                            , width fill
                            ]
                            [ paragraph
                                [ spacingXY 0 4
                                , height shrink
                                , width fill
                                ]
                                [ text (String.slice 0 4 transaction.id) ]
                            ]
                        , column
                            [ height shrink
                            , width fill
                            ]
                            [ paragraph
                                [ spacingXY 0 4
                                , height shrink
                                , width fill
                                ]
                                [ text <| signatureCount model transaction.id ++ "/"
                                , text <| String.fromInt selectedVault.threshold
                                , text <| " (of " ++ (String.fromInt <| List.length selectedVault.publicKeys) ++ ")"
                                ]
                            ]
                        , column
                            [ height shrink
                            , width fill
                            ]
                            [ paragraph
                                [ spacingXY 0 4
                                , height shrink
                                , width fill
                                ]
                                [ text <| duffsToDashString transaction.amount ++ " Dash" ]
                            ]
                        , column
                            []
                            [ el
                                [ spacingXY 0 4
                                , paddingXY 8 8
                                ]
                                (text
                                    transaction.address
                                )
                            ]
                        , column
                            [ width fill
                            ]
                            [ row
                                [ spacingXY 4 4
                                , paddingXY 0 0
                                , alignRight
                                ]
                                [ button "Sign" (pressedSignTransaction transaction.id)
                                , button "Execute" (pressedExecuteTransaction transaction.id)
                                ]
                            ]
                        ]
                )
                model.transactionList
            )
        ]


signatureCount model transactionId =
    String.fromInt <|
        List.length <|
            List.filter (\t -> t.transactionId == transactionId) model.signatures


button label action =
    Input.button
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
        { onPress = Just action, label = Element.text label }
