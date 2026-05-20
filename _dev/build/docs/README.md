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
elastic-package test system
elastic-package test system --data-streams STREAM_NAME --defer-cleanup 5m
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
