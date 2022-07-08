module Network exposing (..)


type Network
    = Testnet
    | Mainnet


toString network =
    case network of
        Testnet ->
            "testnet"

        Mainnet ->
            "mainnet"
