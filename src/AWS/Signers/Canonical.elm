module AWS.Signers.Canonical exposing (..)

import AWS.Encode
import AWS.Http exposing (QueryParams, RequestBody(..), UnsignedRequest)
import Crypto.Hash exposing (sha256)
import Json.Encode as JE
import Regex exposing (HowMany(All), regex)


-- http://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html


canonical : String -> String -> List ( String, String ) -> QueryParams -> RequestBody -> String
canonical method path headers params body =
    canonicalRaw method path headers params body
        |> sha256


canonicalRaw : String -> String -> List ( String, String ) -> QueryParams -> RequestBody -> String
canonicalRaw method path headers params body =
    [ String.toUpper method
    , canonicalUri path
    , canonicalQueryString params
    , canonicalHeaders headers
    , ""
    , signedHeaders headers
    , canonicalPayload body
    ]
        |> String.join "\n"


canonicalUri : String -> String
canonicalUri path =
    if String.isEmpty path then
        "/"
    else
        -- TODO: vvv
        -- In exception to this, you do not normalize URI paths for requests to
        -- Amazon S3. For example, if you have a bucket with an object named
        --
        --    my-object//example//photo.user
        --
        -- use that path. Normalizing the path to
        --    my-object/example/photo.user
        --
        -- will cause the request to fail. For more information, see
        -- Task 1: Create a Canonical Request in the Amazon Simple Storage
        -- Service API Reference:
        -- http://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html#canonical-request
        path
            |> Regex.replace All (regex "/{2,}") (\_ -> "/")
            |> resolveRelativePath
            |> String.split "/"
            |> List.map AWS.Encode.uri
            |> String.join "/"


canonicalQueryString : QueryParams -> String
canonicalQueryString params =
    params
        |> List.sort
        |> List.map (encode2Tuple "=")
        |> String.join "&"


canonicalHeaders : List ( String, String ) -> String
canonicalHeaders headers =
    headers
        |> List.map normalizeHeader
        |> List.foldl mergeSameHeaders []
        |> List.map joinHeader
        |> List.sort
        |> String.join "\n"


signedHeaders : List ( String, String ) -> String
signedHeaders headers =
    headers
        |> List.foldl mergeSameHeaders []
        |> List.map (\( a, _ ) -> String.toLower a)
        |> List.sort
        |> String.join ";"


canonicalPayload : RequestBody -> String
canonicalPayload body =
    (case body of
        JsonBody value ->
            JE.encode 0 value

        NoBody ->
            ""
    )
        |> sha256



-- HELPERS


resolveRelativePath : String -> String
resolveRelativePath path =
    let
        rel =
            regex "(([^/]+)/[.]{2}|/[.])/?"
    in
    if Regex.contains rel path then
        path
            |> Regex.replace All
                rel
                (\{ match } ->
                    if match == "/./" || match == "/." then
                        "/"
                    else
                        ""
                )
            |> resolveRelativePath
    else
        path


normalizeHeader : ( String, String ) -> ( String, String )
normalizeHeader ( key, val ) =
    ( String.toLower key
    , val
        |> Regex.replace All (regex "\\s*?\n\\s*") (\_ -> ",")
        |> Regex.replace All (regex "(^\\s*|\\s*$)") (\_ -> "")
        |> Regex.replace All (regex "\\s{2,}") (\_ -> " ")
    )


mergeSameHeaders : ( String, String ) -> List ( String, String ) -> List ( String, String )
mergeSameHeaders ( key1, val1 ) acc =
    case acc of
        ( key0, val0 ) :: rest ->
            if key0 == key1 then
                ( key0, val0 ++ "," ++ val1 ) :: rest
            else
                ( key1, val1 ) :: ( key0, val0 ) :: rest

        _ ->
            ( key1, val1 ) :: acc


joinHeader : ( String, String ) -> String
joinHeader ( key, val ) =
    key ++ ":" ++ val


encode2Tuple : String -> ( String, String ) -> String
encode2Tuple separator ( a, b ) =
    [ AWS.Encode.uri a, AWS.Encode.uri b ] |> String.join separator
