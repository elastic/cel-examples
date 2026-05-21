# cel-examples

This Elastic Agent integration package demonstrates how to express several
common data collection patterns in the CEL language, using Filebeat's CEL
Input.

It is not a production integration for a specific vendor API.

## Layout

The package has several focused CEL examples, each in a separate data stream.
Each data stream has a CEL program and tests that exercise the behavior being
demonstrated by running it against a mock API.

The main content of interest is the CEL program in each data stream's
`cel.yml.hbs` file and the corresponding mock API configuration under
`_dev/deploy/docker/`.

Field definitions, ingest pipelines, and other package files are minimal
support scaffolding so the examples can be installed and run as an integration.

## Data streams

Each data stream is a separate example:

- **`url_query_noauth_page_number`**: Page-number pagination, without authentication.
- **`url_query_basic_auth_manual_next_link`**: Manual Basic auth in CEL, next-link pagination.
- **`url_query_oauth2_next_links`**: Input-level OAuth2, cursor and next-link pagination.
- **`request_body_id_timestamp_filter`**: POST body filters, time windows, and ID-based paging.
- **`worklist_message_group_array_index`**: A two-phase worklist using array indexing.
- **`worklist_message_group_tail`**: A two-phase worklist using `front()` and `tail()`.
- **`worklist_testing_errors`**: Worklist error handling and returned-state assertions.

## How to exercise the examples

Run the baseline package checks from the package root:

```sh
elastic-package lint
elastic-package test static
elastic-package test pipeline
```

Run the system tests to run the full integration against mock APIs.

```sh
elastic-package test -v system
elastic-package test -v system --data-streams STREAM_NAME --defer-cleanup 5m
```

You can select a specific data stream with the `--data-streams` option, and use
`--defer-cleanup` so that you have a chance to inspect the agent under test,
its request trace logs, the running mock server and the ingested documents in
Elasticsearch, before everything is cleaned up.

Run script tests when available for more complex test scenarios, such as
testing negative cases:

```sh
elastic-package test script --data-streams worklist_testing_errors
```

The `worklist_testing_errors` uses script tests to run the CEL code directly
via [Mito](https://github.com/elastic/mito) and validate its error handling.
API mocks to support this testing are included in the main mock used by system
tests, but with different URL paths.

## CEL tips

For an accessible introduction to CEL for the CEL Input read the blog post
[Common Expression Language (CEL): How the CEL input improves data collection in Elastic Agent integrations](https://www.elastic.co/search-labs/blog/common-expression-language-elasticsearch).

Many code examples covering the Mito extensions can be found in the `mito`
repository's [`testdata` directory](https://github.com/elastic/mito/tree/dev/testdata).

<details>
<summary>Expand to read additional tips.</summary>

### Table of contents

- [Concepts](#concepts)
  - [Optional values](#optional-values)
  - [Number handling](#number-handling)
- [Recommended practices](#recommended-practices)
  - [Prefer the CEL Input over the HTTP JSON Input](#prefer-the-cel-input-over-the-http-json-input)
  - [Compile and test CEL without Filebeat or an integration](#compile-and-test-cel-without-filebeat-or-an-integration)
  - [Prefer `optional.none()` to `null`](#prefer-optionalnone-to-null)
  - [Plan state handling after errors](#plan-state-handling-after-errors)
  - [Handle requests that fail without a status code](#handle-requests-that-fail-without-a-status-code)
- [Troubleshooting](#troubleshooting)
  - [Fields are missing on the second periodic run](#fields-are-missing-on-the-second-periodic-run)
  - [Errors and `want_more`](#errors-and-want_more)
  - [HTTP request fails completely with no HTTP status code](#http-request-fails-completely-with-no-http-status-code)
  - [`timestamp : no such overload: timestamp(double)`](#timestamp--no-such-overload-timestampdouble)
  - [`found no matching overload for '_?_:_'`](#found-no-matching-overload-for-___)
  - [`found no matching overload for 'with' applied to`](#found-no-matching-overload-for-with-applied-to)
  - [Type `string` does not support field selection](#type-string-does-not-support-field-selection)
- [Cookbook](#cookbook)
  - [Type conversion and object shaping](#type-conversion-and-object-shaping)
    - [Convert an array of numbers to an array of strings](#convert-an-array-of-numbers-to-an-array-of-strings)
    - [Convert a list of strings to uppercase](#convert-a-list-of-strings-to-uppercase)
    - [Create a map of numbers](#create-a-map-of-numbers)
    - [Merge an array of maps into a single map](#merge-an-array-of-maps-into-a-single-map)
  - [Maps and membership checks](#maps-and-membership-checks)
    - [Check whether a map contains a key](#check-whether-a-map-contains-a-key)
    - [Check whether a list contains a value](#check-whether-a-list-contains-a-value)
  - [List and set operations](#list-and-set-operations)
    - [Create a sorted deduplicated list](#create-a-sorted-deduplicated-list)
    - [Return values from the second list that do not occur in the first list](#return-values-from-the-second-list-that-do-not-occur-in-the-first-list)
    - [Find the intersection of two lists](#find-the-intersection-of-two-lists)
    - [Add two lists](#add-two-lists)
    - [Add two lists and sort the result](#add-two-lists-and-sort-the-result)
    - [Determine whether a value is between two other values](#determine-whether-a-value-is-between-two-other-values)
- [Compatibility notes](#compatibility-notes)
  - [`bytes(resp.Body).decode_json()` and `resp.Body.decode_json()`](#bytesrespbodydecode_json-and-respbodydecode_json)

### Concepts

#### Optional values

The optional type is similar to Java's `java.util.Optional<T>`, which is a
container object that may or may not contain a non-null value. In CEL, if the
assigned optional does not contain a value, the value is removed from `state`.

A `.?` before a field marks the value as an optional type. Use `optional.of()`
to set a value, and `optional.none()` to not set the value or to remove it. A
`?` before a field name in a literal object constructor allows the field to be
optionally included in the object only when the optional value is not
`optional.none()`.

With no response body data, the optional field is not added to `state`:

```shell
mito -data <(echo '{
  "some_variable": "imastring"
}') <(echo '
  {}.as(body,
    state.with({
      ?"end_cursor": body.?data.hasNextPage.orValue(false) ?
        body.?data.endCursor
      :
        optional.none()
      ,
    })
  )
')
```

```json
{
	"some_variable": "imastring"
}
```

With an empty `data` object, the optional field is still not added:

```shell
mito -data <(echo '{
  "some_variable": "imastring"
}') <(echo '
  {"data":{}}.as(body,
    state.with({
      ?"end_cursor": body.?data.hasNextPage.orValue(false) ?
        body.?data.endCursor
      :
        optional.none()
      ,
    })
  )
')
```

```json
{
	"some_variable": "imastring"
}
```

When the optional value exists, it is added to `state`:

```shell
mito -data <(echo '{
  "some_variable": "imastring"
}') <(echo '
  {"data":{"hasNextPage" : true, "endCursor": "nfnfdwo"}}.as(body,
    state.with({
      ?"end_cursor": body.?data.hasNextPage.orValue(false) ?
        body.?data.endCursor
      :
        optional.none()
      ,
    })
  )
')
```

```json
{
	"end_cursor": "nfnfdwo",
	"some_variable": "imastring"
}
```

#### Number handling

Numbers come into CEL as floating point values when deserialized from JSON.
Similarly, all numbers are serialized as floating point values when returned
from a CEL evaluation.

### Recommended practices

#### Prefer the CEL Input over the HTTP JSON Input

CEL is the preferred input method, as HTTP JSON is planned to be phased out in
favor of CEL. The reasons for this are:

1. CEL allows for more complex logic and transformations on data, both in
   requests and responses, compared to the more limited capabilities of the HTTP
   JSON input.
2. CEL provides a more programmatic and expressive way to interact with APIs and
   process data, leading to a better development workflow for custom
   integrations.
3. CEL is easier to debug than HTTP JSON.

#### Compile and test CEL without Filebeat or an integration

[`mito`](https://github.com/elastic/mito) can be used to create a `mito`
executable that can compile and run CEL programs from the command line.

[`miko`](https://github.com/efd6/miko) is a UI playground for working with the
mito CEL extension. To install the playground:

```
go install github.com/efd6/miko
```

`miko` requires that `mito` is installed.

[`celfmt`](https://github.com/elastic/celfmt) is a tool to compile and format a
CEL program. If `celfmt` is installed, `miko` can use it to format the code in
the playground.

Each of these tools is versioned. Running different versions of the tools on
the same program may result in different behavior. Try to use the versions
required by the minimum version of Filebeat that is being targeted. The Beats
[`go.mod`](https://github.com/elastic/beats/blob/main/go.mod) file has the
version of mito that Filebeat was built with. Make sure that you are using the
correct tag for the Beats repository.

#### Prefer `optional.none()` to `null`

The use of `null` requires this syntax:

```
has(state.value) && state.value != null
```

Using `optional.none()` requires only this syntax:

```
state.?value.hasValue()
```

Using `optional.none()` removes the value entirely, removing the requirement to
check for `null`.

#### Plan state handling after errors

The following suggestions are meant to help the developer design their error
handling strategy. These suggestions are not exhaustive, and they are not
applicable to every program design.

1. Decide how the program should resume after failure.
   1. Does the program need to restart from the initial conditions of the failed
      periodic run?
   2. Can the program restart from the place where it failed?
2. To start from the same initial conditions as the failed periodic run:
   1. Reset all temporary periodic variables when an error occurs.
   2. Roll back any changes in the cursor, or write the program so the cursor is
      only updated when the run is successfully completed and `want_more` is set
      to false.
   3. Be aware of the effect of potentially sending duplicate events. Using a
      fingerprint processor will stop the indexing of duplicate events.
3. To allow the program to resume after an error:
   1. Do not use `want_more` as a signal that periodic run variables need to be
      initialized. Because `want_more` is set to false on an error, using
      `want_more == false` as a signal to initialize variables will cause those
      variables to be overwritten.
   2. Update the cursor or other variables on each invocation of the CEL program.
4. Depending on how you have designed the initialization of variables for a
   periodic run, the variables may need to be cleared when the periodic run
   successfully completes.
5. Be aware that if the integration is moved from one agent to another agent,
   only the cursor object in the state object will be copied.

#### Handle requests that fail without a status code

1. Use the [`try`](https://pkg.go.dev/github.com/elastic/mito/lib#hdr-Try-Try)
   function to detect request failures. On failure, set the state according to
   one of the strategies suggested for non-2xx responses. The
   `url_query_basic_auth_manual_next_link` example demonstrates use of the
   `try` function.
2. Without the `try` function, the CEL program will automatically retry the API
   indefinitely. See the documentation for
   [`max_retries`](https://www.elastic.co/docs/reference/beats/filebeat/elasticsearch-output#_max_retries).

### Troubleshooting

#### Fields are missing on the second periodic run

The `state` object is created on the initial run of the program. On agent
restarts, `state` is initialized from the cursor field and from fields defined in
the configuration. If `url` is missing from the `state` object, it will be added
to `state` at the beginning of the periodic run.

The `state` on the next periodic run is the `state` that was returned from the
last evaluation of the previous periodic run. The developer controls what is
returned. Missing fields occur if the returned object from the program
evaluation does not contain the expected fields. This occurs if the returned
object is not created with the `state.with(...)` syntax, or if the developer has
not explicitly set fields in the returned object.

Best practice is to keep fields that should be persisted across periodic runs in
the cursor object.

A typical error for missing fields looks like this:

```
failed eval: ERROR: :21:50: no such key: limit
```

This error indicates that the field `limit` is missing.

#### Errors and `want_more`

CEL programs can exit normally, exit with errors, or exit due to hitting the
maximum number of executions allowed in a periodic run.

1. On normal execution, the CEL program may set `want_more` to `true`, which
   signals that the CEL program is to be run again during this periodic run.
2. On error, Filebeat will set `want_more` to false if it is set to any value.
3. If the periodic run hits the maximum number of executions allowed for the
   periodic run, Filebeat will not set `want_more` to false, but will terminate
   the periodic run. The program will resume using an unchanged state object at
   the next periodic run of the input.

#### HTTP request fails completely with no HTTP status code

Possible causes include:

1. Internet problems causing intermittent communication errors where there is no
   response to the request because the server is unreachable.
2. The target server is down or disappears during the periodic run.
3. The API is incorrect and the server does not exist.
4. The maximum number of executions for the loop has been exceeded.

#### `timestamp : no such overload: timestamp(double)`

The conversion fails because there is no defined overload for converting a
double to a timestamp. To fix this, convert the timestamp to an int.

```
timestamp(int(ts))
```

#### `found no matching overload for '_?_:_'`

You may see this error when a conditional expression returns different static
types, for example:

```
true ? [] : {}
```

The compile-time type does not allow the evaluation. Use `dyn()` conversion to
allow runtime determination of type. For this specific example, `dyn()` is only
required for one term. Other examples may require that both terms be runtime
typed.

```
true ? dyn([]) : {}
```
or
```
true ? [] : dyn({})
```
or
```
true ? dyn([]) : dyn({})
```

#### `found no matching overload for 'with' applied to`

The workaround for this is to use `dyn(<the object>)` to allow runtime
determination of type.

```
object = {...}

dyn(object)
```

#### Type `string` does not support field selection

Occasionally the compiler will think that an object is a string and not an
object. Use `dyn(<the object>)` to allow runtime determination of type.

### Cookbook

#### Type conversion and object shaping

##### Convert an array of numbers to an array of strings

```shell
mito -data <(echo '{
  "list": [1,2,3]
}') <(echo '
  state.list.map(num, string(num))
')
```

```json
[
	"1",
	"2",
	"3"
]
```

##### Convert a list of strings to uppercase

```shell
mito -data <(echo '{
  "list": ["abc", "cde"]
}') <(echo '
  state.list.map(e, e.to_upper())
')
```

```json
[
	"ABC",
	"CDE"
]
```

##### Create a map of numbers

When output in a `state` object, keys in maps must be strings. Used as a
temporary object, the keys can be numbers.

This command creates a map with string keys:

```shell
mito -data <(echo '{
  "list": [1,2,3],
  "number": 3
}') <(echo '
  state.list.map(num, string(num)).as(str_num, zip(str_num, state.list))
')
```

```json
{
	"1": 1,
	"2": 2,
	"3": 3
}
```

A temporary map can use number keys:

```shell
mito -data <(echo '{
  "list": [1,2,3],
  "number": 3
}') <(echo '
  zip(state.list, state.list)[state.number]
')
```

```json
3
```

Returning that map directly fails because output map keys must be strings:

```shell
mito -data <(echo '{
  "list": [1,2,3],
  "number": 3
}') <(echo '
  zip(state.list, state.list)
')
```

```text
failed proto conversion: type conversion error from Double to 'string'
```

##### Merge an array of maps into a single map

```shell
mito -data <(echo '[
  {
    "abcdef": {
      "key1": "value1",
      "key2": "value2"
    },
    "mnopqrs": {
      "key1": "value5",
      "key2": "value6"
    }
  },
  {
    "ghijkl": {
      "key3": "value3",
      "key4": "value4"
    }
  },
  {
    "xyz": {
      "key7": "value7"
    }
  }
]') <(echo '
  state.map(e,
    e.keys().map(k, {
      "key": k,
      "value": e[k],
    })
  ).flatten().as(entries,
    zip(
      entries.map(entry, entry.key),
      entries.map(entry, entry.value)
    )
  )
')
```

```json
{
	"abcdef": {
		"key1": "value1",
		"key2": "value2"
	},
	"ghijkl": {
		"key3": "value3",
		"key4": "value4"
	},
	"mnopqrs": {
		"key1": "value5",
		"key2": "value6"
	},
	"xyz": {
		"key7": "value7"
	}
}
```

#### Maps and membership checks

##### Check whether a map contains a key

The key from `state.five` is not present:

```shell
mito -data <(echo '{
  "list_map": {
    "10": 10,
    "2": 2,
    "9": 9
  },
  "nine" : "9",
  "five" : "5"
}') <(echo '
  try(state.list_map[state.five], "map_has_no_key_error").as(
    value,
    !has(value.map_has_no_key_error)
  )
')
```

```json
false
```

The key from `state.nine` is present:

```shell
mito -data <(echo '{
  "list_map": {
    "10": 10,
    "2": 2,
    "9": 9
  },
  "nine" : "9",
  "five" : "5"
}') <(echo '
  try(state.list_map[state.nine], "map_has_no_key_error").as(
    value,
    !has(value.map_has_no_key_error)
  )
')
```

```json
true
```

##### Check whether a list contains a value

Convert the list to a map, then use `try` to check for the key.

```shell
mito -data <(echo '{
  "list": [1,2,3],
  "number": 3
}') <(echo '
  try(zip(state.list, state.list)[state.number], "has_no_such_key_error")
    .as(value, !has(value.has_no_such_key_error))
')
```

```json
true
```

#### List and set operations

##### Create a sorted deduplicated list

Zip the list with itself to produce a map where the key and value are the same
value in a list, then take the keys.

Either form returns the same sorted, deduplicated list:

```shell
mito -data <(echo '{
  "list": [9,10,1,5,3,9,10]
}') <(echo '
  zip(state.list, state.list).keys()
')
```

```json
[
	1,
	3,
	5,
	9,
	10
]
```

```shell
mito -data <(echo '{
  "list": [9,10,1,5,3,9,10]
}') <(echo '
  state.list.zip(state.list).keys()
')
```

```json
[
	1,
	3,
	5,
	9,
	10
]
```

##### Return values from the second list that do not occur in the first list

This is a set complement operation for two unordered, unsorted, non-unique
lists.

```shell
mito -data <(echo '{
  "list1": [9,10,2],
  "list2": [4,8,2,7,4]
}') <(echo '
  zip(state.list1, state.list1).as(existing,
    zip(state.list2, state.list2).keys().filter(x, try(existing[x], "error").as(value, has(value.error))))
')
```

```json
[
	4,
	7,
	8
]
```

##### Find the intersection of two lists

This is a set intersection operation for two unordered, unsorted, non-unique
lists.

```shell
mito -data <(echo '{
  "list1": [9,10,2],
  "list2": [4,8,2,7,4]
}') <(echo '
  zip(state.list1, state.list1).as(existing,
    zip(state.list2, state.list2).keys().filter(x, try(existing[x], "error").as(value, !has(value.error))))
')
```

```json
[
	2
]
```

##### Add two lists

This concatenates two lists. It does not deduplicate or sort the result.

```shell
mito -data <(echo '{
  "list1": [9,10,2],
  "list2": [4,8,7]
}') <(echo '
  (state.list1 + state.list2)
')
```

```json
[
	9,
	10,
	2,
	4,
	8,
	7
]
```

##### Add two lists and sort the result

This creates a sorted, deduplicated union.

```shell
mito -data <(echo '{
  "list1": [9,10,2],
  "list2": [4,8,7]
}') <(echo '
  (state.list1 + state.list2).as(union, zip(union, union).keys())
')
```

```json
[
	2,
	4,
	7,
	8,
	9,
	10
]
```

##### Determine whether a value is between two other values

This command checks `state.target1`:

```shell
mito -data <(echo '{
  "v1": 2,
  "v2": 4,
  "target1": 3,
  "target2": 5,
  "targets": [3,5]
}') <(echo '
  [state.v1, state.v2].as(values, zip(values, values).keys())
    .as(ordered_values, state.target1 > ordered_values[0] && state.target1 < ordered_values[1])
')
```

```json
true
```

This command checks `state.target2`:

```shell
mito -data <(echo '{
  "v1": 2,
  "v2": 4,
  "target1": 3,
  "target2": 5,
  "targets": [3,5]
}') <(echo '
  [state.v1, state.v2].as(values, zip(values, values).keys())
    .as(ordered_values, state.target2 > ordered_values[0] && state.target2 < ordered_values[1])
')
```

```json
false
```

This command checks each value in `state.targets`:

```shell
mito -data <(echo '{
  "v1": 2,
  "v2": 4,
  "target1": 3,
  "target2": 5,
  "targets": [3,5]
}') <(echo '
  [state.v1, state.v2].as(values, zip(values, values).keys())
    .as(ordered_values, state.targets.map(x, x > ordered_values[0] && x < ordered_values[1]))
')
```

```json
[
	true,
	false
]
```

### Compatibility notes

#### `bytes(resp.Body).decode_json()` and `resp.Body.decode_json()`

`resp.Body.decode_json()` is preferred. In early releases of mito,
`bytes(resp.Body).decode_json()` was the required syntax. This is no longer the
case.

</details>
