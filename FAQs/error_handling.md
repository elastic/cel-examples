# Error Handling

### What is the effect of errors on the value of `want_more` when a CEL program is run from Filebeat

CEL programs can exit normally, exit with errors, or exit due to hitting the
maximum number of executions allowed in a periodic run.
1. On normal execution, the CEL program may set `want_more` to `true` which
   signals that the CEL program is to be run again during this periodic run.
2. On error, Filebeat will set `want_more` to false if it is set to any value.
3. If the periodic run hits the maximum number of executions allowed for the 
   periodic run, Filebeat will not set `want_more` to false, but will terminate
   the periodic run. The program will resume using an unchanged state object at
   the next periodic run of the input.

### Be aware of the effect of the state of variables when the periodic run exits with an error.

The following suggestions are meant to help the developer design their error 
handling strategy. These suggestions are not exhaustive nor are they
applicable to every program design.
1. Make a decision about how the program should resume after failure. 
   1. Does the program need to restart from the initial conditions of the failed
      periodic run?
   2. Can the program restart from the place where it failed?
2. To start from the same initial conditions as the failed periodic run:
   1. Reset all temporary periodic variables when an error occurs.
   2. Rollback any changes in the cursor _or_ write the program so the cursor
      is only updated when the run is successfully completed and `want_more` is 
      set to false.
   3. Be aware of the effect of potentially sending duplicate events. Using a
      fingerprint processor will stop the indexing of duplicate events. 
3. To allow the program to resume after an error:
   1. Do not use `want_more` as a signal that periodic run variables need
      to be initialized. Due to `want_more` being set to false on an error, using
      `want_more == false` as a signal to initialize variables will cause 
      those variables to be overwritten.
   2. Update the cursor or other variables on each invocation of the CEL 
      program.
4. Depending upon how you have designed the initialization of variables for a
   periodic run, the variables may need to be cleared when periodic run 
   successfully completes.
5. Be aware that if the integration is moved from one agent to another agent,
   only the cursor object in the state object will be copied. 

### HTTP Request fails completely with no HTTP status code.

1. Internet problems causing intermittent communications errors where there
   is no response to the request due to the server being unreachable.
2. The target server is down or disappears during the periodic run.
3. The API is incorrect and the server does not exist.
4. Maximum executions for the loop has been exceeded. 

### Strategies for requests that fail without a status code

1. Use the [`try`](https://pkg.go.dev/github.com/elastic/mito/lib#hdr-Try-Try)
   function to detect request failures. On failure, set the state according to
   one of the strategies suggested for non-2xx responses.
   The [url-query](../examples/url-query/basic_auth_manual_next_link/basic_auth_manual_next.yml.hbs)
   example shows the use of the the `try` function.
2. Without the `try` function, the CEL program will automatically retry the API 
   indefinitely. See the [documentation for `max_retries`](https://www.elastic.co/docs/reference/beats/filebeat/elasticsearch-output#_max_retries).
