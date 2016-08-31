module Query
    exposing
        ( Schema
        , Field
        , schema
        , field
        , nested
        , Query
        , read
        , send
        , select
        , Filter
        , filter
        , like
        , eq
        , gte
        , gt
        , lte
        , lt
        , neq
        , ilike
        , in'
        , notin
        , is
        , isnot
        , contains
        , not'
        , OrderBy
        , order
        , asc
        , desc
        , paginate
        , offset
        , limit
        , singular
        , count
        )

{-| DEPRECATED: Renamed to http://package.elm-lang.org/john-kelly/query
# Types
@docs Schema, Field, Query, Filter, OrderBy
# Functions
@docs schema, field, nested, read, send, select, filter, like, eq, gte, gt, lte, lt, neq, ilike, in', notin, is, isnot, contains, not', order, asc, desc, paginate, offset, limit, singular, count
-}

import Http
import String
import Task
import Query.Types as QT exposing (..)


{-| -}
type alias Schema shape =
    QT.Schema shape


{-| -}
type alias Query shape =
    QT.Query shape


{-| -}
type alias Field shape =
    QT.Field shape


{-| -}
type alias Filter shape =
    QT.Filter shape


{-| -}
type alias OrderBy shape =
    QT.OrderBy shape



-- Schema Builder


{-| -}
schema : String -> shape -> Schema shape
schema =
    Schema


{-| -}
field : String -> Field shape
field =
    SimpleField


{-| -}
nested : Schema shape1 -> List (shape1 -> Field shape1) -> shape2 -> Field shape1
nested schema fieldAccessors =
    let
        ( schemaName, schemaShape ) =
            unwrapSchema schema

        nestedField =
            fieldAccessors
                |> List.map (\fn -> fn schemaShape)
                |> NestedField schemaName
    in
        always nestedField



-- Query Builder


{-| -}
read : String -> Schema shape -> Query shape
read url schema =
    Query
        { fields = []
        , filters = []
        , orders = []
        , limit = Nothing
        , offset = Nothing
        , singular = False
        , suppressCount = True
        , verb = "GET"
        , schema = schema
        , url = url
        }



-- Selecting


{-| -}
select : List (shape -> Field shape) -> Query shape -> Query shape
select fieldAccessors query =
    let
        unwrappedQuery =
            unwrapQuery query

        ( _, schemaShape ) =
            unwrapSchema unwrappedQuery.schema
    in
        Query
            { unwrappedQuery
              -- NOTE: we append new props, is this the best api?
                | fields = unwrappedQuery.fields ++ List.map (\fn -> fn schemaShape) fieldAccessors
            }



-- Filtering
-- TODO: take a look here for api example: https://docs.djangoproject.com/en/1.10/ref/models/querysets/#field-lookups


{-| -}
filter : List (shape -> Filter shape) -> Query shape -> Query shape
filter filterAccessors query =
    let
        unwrappedQuery =
            unwrapQuery query

        ( _, schemaShape ) =
            unwrapSchema unwrappedQuery.schema
    in
        Query
            { unwrappedQuery
                | filters = unwrappedQuery.filters ++ List.map (\fn -> fn schemaShape) filterAccessors
            }


{-| -}
toFilterFn : (Field shape -> a -> Condition shape) -> a -> (shape -> Field shape) -> (shape -> Filter shape)
toFilterFn condValueConstructor val fieldAccessor =
    (\shape -> Filter False (condValueConstructor (fieldAccessor shape) val))


{-| -}
like : String -> (shape -> Field shape) -> (shape -> Filter shape)
like =
    toFilterFn Like


{-| -}
eq : String -> (shape -> Field shape) -> (shape -> Filter shape)
eq =
    toFilterFn Eq


{-| -}
gte : String -> (shape -> Field shape) -> (shape -> Filter shape)
gte =
    toFilterFn Gte


{-| -}
gt : String -> (shape -> Field shape) -> (shape -> Filter shape)
gt =
    toFilterFn Gt


{-| -}
lte : String -> (shape -> Field shape) -> (shape -> Filter shape)
lte =
    toFilterFn Lte


{-| -}
lt : String -> (shape -> Field shape) -> (shape -> Filter shape)
lt =
    toFilterFn Lt


{-| -}
neq : String -> (shape -> Field shape) -> (shape -> Filter shape)
neq =
    -- TODO: DEPRECATE in favor of smaller base api.
    not' eq


{-| -}
ilike : String -> (shape -> Field shape) -> (shape -> Filter shape)
ilike =
    -- TODO: What is the best name for this? Too low level?
    toFilterFn ILike


{-| -}
in' : List String -> (shape -> Field shape) -> (shape -> Filter shape)
in' =
    -- TODO: What is the best name for this?
    toFilterFn In


{-| -}
notin : List String -> (shape -> Field shape) -> (shape -> Filter shape)
notin =
    -- TODO: DEPRECATE
    not' in'


{-| -}
is : String -> (shape -> Field shape) -> (shape -> Filter shape)
is =
    toFilterFn Is


{-| -}
isnot : String -> (shape -> Field shape) -> (shape -> Filter shape)
isnot =
    -- TODO: DEPRECATE
    not' is


{-| -}
contains : String -> (shape -> Field shape) -> (shape -> Filter shape)
contains =
    -- TODO: Is this the right name? I don't think so.
    -- https://docs.djangoproject.com/en/1.10/ref/models/querysets/#contains
    toFilterFn Contains


{-| -}
not' : (a -> (shape -> Field shape) -> (shape -> Filter shape)) -> a -> (shape -> Field shape) -> (shape -> Filter shape)
not' filterAccessorConstructor val fieldAccessor =
    -- TODO: What is the best name for this?
    let
        filterAccessor =
            filterAccessorConstructor val fieldAccessor
    in
        (\shape ->
            case filterAccessor shape of
                Filter negated cond ->
                    Filter (not negated) cond
        )



-- Ordering


{-| -}
order : List (shape -> OrderBy shape) -> Query shape -> Query shape
order orderByAccessors query =
    let
        unwrappedQuery =
            unwrapQuery query

        ( _, shape ) =
            unwrapSchema unwrappedQuery.schema
    in
        Query
            { unwrappedQuery
                | orders = unwrappedQuery.orders ++ List.map (\fn -> fn shape) orderByAccessors
            }


{-| -}
asc : (shape -> Field shape) -> (shape -> OrderBy shape)
asc fieldAccessor =
    (\shape -> Ascending (fieldAccessor shape))


{-| -}
desc : (shape -> Field shape) -> (shape -> OrderBy shape)
desc fieldAccessor =
    (\shape -> Descending (fieldAccessor shape))



-- Count and Pagination


{-| -}
offset : Int -> Query shape -> Query shape
offset offset' query =
    -- TODO: setting?
    let
        unwrapped =
            unwrapQuery query
    in
        Query { unwrapped | offset = Just offset' }


{-| -}
limit : Int -> Query shape -> Query shape
limit limit' query =
    let
        unwrapped =
            unwrapQuery query
    in
        Query { unwrapped | limit = Just limit' }


{-| -}
paginate : Int -> Int -> Query shape -> Query shape
paginate pageSize pageNumber query =
    let
        unwrapped =
            unwrapQuery query
    in
        Query
            { unwrapped
              -- TODO: should this append?
                | limit = Just pageSize
                , offset = Just <| (pageNumber - 1) * pageSize
            }


{-| -}
singular : Query shape -> Query shape
singular query =
    let
        unwrapped =
            unwrapQuery query
    in
        Query { unwrapped | singular = True }


{-| -}
count : Query shape -> Query shape
count query =
    -- NOTE: maybe this belongs as a settings? it's nice to have it as a fn,
    -- but it allows for a potentially confusing user interaction of calling
    -- count more than once. what other functions may belong as settings?
    -- this might be a perfect canidate for a Query.Settings! the adapter can go
    -- in there too, and dev mode options, etc.
    let
        unwrapped =
            unwrapQuery query
    in
        Query { unwrapped | suppressCount = False }



-- Query Task Builder


{-| -}
send : (Query shape -> Http.Request) -> Http.Settings -> Query shape -> Task.Task Http.RawError Http.Response
send adapter settings restRequest =
    restRequest
        |> adapter
        |> Http.send settings
