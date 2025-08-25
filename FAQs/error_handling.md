# Error Handling

#### What is the effect of errors on the value of 'want_more' when a CEL program is run from Filebeat
CEL programs can exit normally, exit with errors or exit due to hitting the
maximum number of executions allowed in a periodic run.
1. On normal execution, the CEL program will set 'want_more' to false which
   signals that the CEL program is not to be run again during this periodic run.
2. On error, 'want_more', filebeat will set 'want_more' to false.
3. If the periodic run hits the maximum number of executions allowed for the 
   periodic run, Filebeat will not reset 'want_more'. This allows the program to
   resume using an unchanged state object.

#### Be aware of the effect of the state of variables when the periodic run exits with an error.
1. Make a decision about how the program should resume after failure. 
   1. Does the program need to restart from the initial conditions of the failed
      periodic run?
   2. Can the program restart from the place where it failed?
2. To start from the same initial conditions as the failed periodic run:
   1. Reset all temporary periodic variables when an error occurs.
   2. Rollback any changes in the cursor OR write the program so the cursor
      is only updated when the run is successfully completed and 'want_more' is 
      set to false.
   3. Be aware of the effect of potentially sending duplicate events. Using a
      fingerprint processor will stop the indexing of duplicate events. 
3. To allow the program to resume after an error:
   1. Do not use 'want_more' as a signal that periodic run variables need
      to be initialized. Due to 'want_more' being set to false on an error, using
      'want_more' == false as a signal to initialize variables will cause 
       those variables to be overwritten.
   2. Update the cursor or other variables on each invocation of the CEL 
      program.
4. Depending upon how you have designed the initialization of variables for a
   periodic run, the variables may need to be cleared when periodic run 
   successfully completes.
5. Be aware that if the integration is moved from one agent to another agent,
   only the cursor object in the state object will be copied. 

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
