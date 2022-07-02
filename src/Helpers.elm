module Helpers exposing (..)


dashDecimals =
    100000000


duffsToDash : Int -> Float
duffsToDash duffs =
    toFloat duffs / dashDecimals


duffsToDashString : Int -> String
duffsToDashString duffs =
    String.fromFloat <|
        duffsToDash duffs


dashToDuffs : Float -> Int
dashToDuffs dash =
    floor (dash * dashDecimals)


descendingUtxo a b =
    case compare a.satoshis b.satoshis of
        LT ->
            GT

        GT ->
            LT

        EQ ->
            EQ


descendingTxHistoryTime a b =
    case compare a.time b.time of
        LT ->
            GT

        GT ->
            LT

        EQ ->
            EQ
