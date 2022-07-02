module TimeFormat exposing (..)

import DateFormat
import Time exposing (Posix, Zone, utc)


dateFormatter : Zone -> Posix -> String
dateFormatter =
    DateFormat.format
        [ DateFormat.monthNameFull
        , DateFormat.text " "
        , DateFormat.dayOfMonthSuffix
        , DateFormat.text ", "
        , DateFormat.yearNumber
        ]


timeFormatter : Zone -> Posix -> String
timeFormatter =
    DateFormat.format
        [ DateFormat.hourMilitaryNumber
        , DateFormat.text ":"
        , DateFormat.minuteNumber
        , DateFormat.text " "
        , DateFormat.monthNameFull
        , DateFormat.text " "
        , DateFormat.dayOfMonthSuffix
        , DateFormat.text ", "
        , DateFormat.yearNumber
        , DateFormat.text " UTC "
        ]


ourTimezone : Zone
ourTimezone =
    utc


posixTime : Int -> Posix
posixTime millis =
    Time.millisToPosix millis


prettyDate : Int -> String
prettyDate millis =
    dateFormatter ourTimezone (posixTime millis)


prettyTime : Int -> String
prettyTime millis =
    timeFormatter ourTimezone (posixTime millis)
