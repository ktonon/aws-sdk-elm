module SignersTests.CanonicalTests
    exposing
        ( canonicalHeadersTests
        , canonicalPayloadTests
        , canonicalQueryStringTests
        , canonicalTests
        , canonicalUriTests
        , signedHeadersTests
        )

import AWS.Http exposing (..)
import AWS.Signers.Canonical exposing (..)
import Expect
import Json.Encode as JE
import Test exposing (Test, describe, test)
import TestHelpers exposing (expectMatches)


canonicalTests : Test
canonicalTests =
    describe "canonical"
        [ test "does the same request encoding as http://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html" <|
            \_ ->
                canonical "get"
                    ""
                    [ ( "Content-Type", "application/x-www-form-urlencoded;  charset=utf-8" )
                    , ( "x-amz-date", "20150830T123600Z" )
                    , ( "host", "  iam.amazonaws.com" )
                    ]
                    [ ( "Version", "2010-05-08" )
                    , ( "Action", "ListUsers" )
                    ]
                    NoBody
                    |> Expect.equal "f536975d06c0309214f805bb90ccff089219ecd68b2577efef23edd43b7e1a59"
        , test "does the same request encoding as http://docs.aws.amazon.com/general/latest/gr/signature-v4-test-suite.html#signature-v4-test-suite-example" <|
            \_ ->
                canonical "get"
                    ""
                    [ ( "X-Amz-Date", "20150830T123600Z" )
                    , ( "Host", "example.amazonaws.com" )
                    ]
                    [ ( "Param1", "value1" )
                    , ( "Param2", "value2" )
                    ]
                    NoBody
                    |> Expect.equal "816cd5b414d056048ba4f7c5386d6e0533120fb1fcfa93762cf0fc39e2cf19e0"
        ]


canonicalUriTests : Test
canonicalUriTests =
    describe "canonicalUri"
        [ test "converts an empty path to /" <|
            \_ ->
                ""
                    |> canonicalUri
                    |> Expect.equal "/"
        , test "removes redundant separators (i.e. slash /)" <|
            \_ ->
                "//foo//bar/car"
                    |> canonicalUri
                    |> Expect.equal "/foo/bar/car"
        , test "uri encodes path components" <|
            \_ ->
                "/foo-bar/biz baz/one=two"
                    |> canonicalUri
                    |> Expect.equal "/foo-bar/biz%20baz/one%3Dtwo"
        ]


canonicalQueryStringTests : Test
canonicalQueryStringTests =
    describe "canonicalQueryString"
        [ test "empty string when query params is an empty list" <|
            \_ ->
                []
                    |> canonicalQueryString
                    |> Expect.equal ""
        , test "sorts by query keys" <|
            \_ ->
                [ ( "bar", "car" ), ( "Foo", "baz" ), ( "alpha", "beta" ) ]
                    |> canonicalQueryString
                    |> Expect.equal "Foo=baz&alpha=beta&bar=car"
        , test "encodes a key without a value as key=" <|
            \_ ->
                [ ( "foo", "baz" ), ( "bar", "" ) ]
                    |> canonicalQueryString
                    |> Expect.equal "bar=&foo=baz"
        , test "uri encodes keys and values" <|
            \_ ->
                [ ( "one & two", "three=four" ) ]
                    |> canonicalQueryString
                    |> Expect.equal "one%20%26%20two=three%3Dfour"
        , test "does not uri encode 0-9, -, _, ., or ~" <|
            \_ ->
                [ ( "keep-these", "_.~0123456789" ) ]
                    |> canonicalQueryString
                    |> Expect.equal "keep-these=_.~0123456789"
        , test "uri encodes all other non-letter characters" <|
            \_ ->
                [ ( "encode-these"
                  , " !\"#$%&'()*+,/:;<=>?@[\\]^`{|}"
                  )
                ]
                    |> canonicalQueryString
                    |> Expect.equal "encode-these=%20%21%22%23%24%25%26%27%28%29%2A%2B%2C%2F%3A%3B%3C%3D%3E%3F%40%5B%5C%5D%5E%60%7B%7C%7D"
        ]


canonicalHeadersTests : Test
canonicalHeadersTests =
    describe "canonicalHeaders"
        [ test "sorts the headers and converts names to lowercase" <|
            \_ ->
                [ ( "one-1", "a" ), ( "two-2", "b" ), ( "Three-3", "c" ), ( "four-4", "d" ) ]
                    |> canonicalHeaders
                    |> Expect.equal
                        ([ "four-4:d"
                         , "one-1:a"
                         , "three-3:c"
                         , "two-2:b"
                         ]
                            |> String.join "\n"
                        )
        , test "removes extra spaces from the values" <|
            \_ ->
                [ ( "my-header-1", "  a   b      c " )
                , ( "My-header-2", "  \"a b  c\" " )
                , ( "content-type", "application/json;  charset=utf-8" )
                ]
                    |> canonicalHeaders
                    |> Expect.equal
                        ([ "content-type:application/json; charset=utf-8"
                         , "my-header-1:a b c"
                         , "my-header-2:\"a b c\""
                         ]
                            |> String.join "\n"
                        )
        ]


signedHeadersTests : Test
signedHeadersTests =
    describe "signedHeaders"
        [ test "sorts the header names and converts to lowercase" <|
            \_ ->
                [ ( "one-1", "a" ), ( "two-2", "b" ), ( "Three-3", "c" ), ( "four-4", "d" ) ]
                    |> signedHeaders
                    |> Expect.equal "four-4;one-1;three-3;two-2"
        ]


canonicalPayloadTests : Test
canonicalPayloadTests =
    let
        hexPattern =
            "^[0-9a-f]+$"
    in
    describe "canonicalPayload"
        [ test "hex encodes a JSON body" <|
            \_ ->
                JsonBody
                    (JE.object
                        [ ( "name", JE.string "george" )
                        , ( "age", JE.int 6 )
                        ]
                    )
                    |> canonicalPayload
                    |> expectMatches hexPattern
        , test "hex encodes an empty body" <|
            \_ ->
                NoBody
                    |> canonicalPayload
                    |> expectMatches hexPattern
        ]
