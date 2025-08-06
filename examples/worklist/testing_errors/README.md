# Testing Error Handling

This example is based on the worklist example 
[message_group_tail.yml.hbs](../message_group/message_group_tail.yml.hbs)
This example requires that the state be modified on errors to clear some variables.
To test that the error logic correctly sets the state, this example includes 
three different configuration files for docker containers.
docker-compose.yml uses a configuration file where all API calls are successful.
docker-compose-test-first-api-500-error.yml uses a configuration file where the
first API call in the worklist algorithm fails with a 500 error. 
docker-compose-test-second-api-500-error.yml uses a configuration file where the
second API call in the worklist algorithm fails with a 500 error.

Testing for error handling requires that the docker container for the desired
failed API call to be run. Tests can be run using mito or filebeat.

To test all states, run docker-compose.yml then stop that container and run
one of the server error containers. Inspect output to manually verify
expected states.





