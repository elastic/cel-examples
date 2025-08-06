# Error Handling

## Failure types
### Requests return non 2xx responses
1. Authorization or authentication errors, usually 401 or 403. Authorization
errors often return 404 errors to not leak information.
2. Rate limiting causing 429 errors.
3. Target server changed API request contract resulting in 4xx errors.
4. Unexpected transitory issues with the target server causing 5xx or 4xx errors.
5. 404 errors due to the API of the request being incorrect.

##### Reset all variables so periodic run restarts from same conditions

1. Steps to implement
   1. Set 'want_more' to false.
   2. Reset all temporary periodic variables.
   3. Rollback any changes in the cursor OR write the program so the cursor
      is only updated when the run is successfully completed and 'want_more' is set to
      false.
2. Cons
   1. If the error started in the middle of the periodic run after some events
      were sent, this will most likely cause duplicate events to be sent when the
      periodic run restarts. Use a fingerprint to stop ingestion of duplicate events.
   2. Variables that are left over from incomplete periodic runs can cause
      unexpected behavior.
   3. Program can get behind if it restarts continually from the same place.
3. Pros
   1. Straight forward implementation.
   2. Robust.
   3. Well written state management translates well to an integration that is 
      moved to a new agent. (i.e. only the cursor is available after moving)

#### Allow program to resume where it left off
1. Steps to implement
   1. Use 'want_more' only to signal that the periodic run is over, not that it
      was complete. Do not use it as a signal that periodic run variables need
      to be initialized.
   2. Use state.with() around the returned objects so periodic run variables
      are not lost on errors.
   3. Reset all periodic run variables after the periodic run successfully
      completes.
2. Cons
   1. Requires discipline in the use of periodic run variables and 'want_more.'
   2. Needs more testing than the "reset" method.
3. Pros
   1. Useful for integrations that occasionally exceed maximum executions.
   2. Useful when connection issues are common.


### HTTP Request fails completely with no http status code.
1. Internet problems causing intermittent communications errors where there
is no response to the request due to the server being unreachable.
2. The target server is down or disappears during the periodic run.
3. The API is incorrect and the server does not exist.
4. Maximum executions for the loop has been exceeded. 

#### Strategies for requests that fail without a status code
1. Use the try function to detect request failures. On failure, set the state
according to one of the strategies suggested for non-2xx responses.
../examples/url-query/basic_auth_manual_next_link/basic_auth_manual_next.yml.hbs
has an example of using the try function.
2. Without the try function, the cel script will automatically retry the API 
indefinitely. see
https://www.elastic.co/docs/reference/beats/filebeat/elasticsearch-output#_max_retries

