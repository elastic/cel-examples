# Examples Repository

## Structure

Each example has its own directory with an agent configuration file 
(*.yml.hbs file), a filebeat directory and a docker directory.

```
├── README.md       # This file
├── beats-config-from-agent-config-template.sh   #script
├── render.js      #script
├── filebeat-cel-input-base.yml     #File for the filebeat cel-input file to
│                                     which the cel progam will be added.
│                                     Can be any name.                                     
└── example_set_name/            # groups of examples that are related
    └──example_name/             # an example directory
       ├── example_name.yml.hbs  # agent configuration file. Can be any name
       ├── variables.yml         # yaml file with replacement values for handlebar
       │                           handlebar variables in the *.yml.hbs file. 
       │                           Can be any name.
       ├── filebeat/         # filebeat directory
       │   ├── inputs.d      # directory to hold filebeat cel input file
       │   │   └── <generated cel input file. Can be any name>      
       │   ├── filebeat.yml  # filebeat executable configuration file
       │                       Can be any name but is filebeat.yml by default.
       └── docker/           # docker files to run a test API server
           └── files
               ├── config.yml   # contains responses from the API Server
               └── docker-compose.yml 
                                      
```
### Test cycle using beats-config-from-agent-config-template.sh

beats-config-from-agent-config-template.sh converts
the agent configuration file (*.yml.hbs file) into a cel input file that 
can be run by filebeat. Optionally, the cel file can be verified using mito 
which is useful for debugging compilation and running errors before running the
file in filebeat.

The script:
1. Depends on the render.js script that uses handlebars to replace 
handlebar variables in the *.yml.hbs file with the concrete values from the YAML
file that contains the replacement values for the templated variables. 
2. Adds the resulting state and program keys to the partial filebeat cel input 
file to create the complete filebeat cel input file. The location where the 
filebeat cel input is configurable in the filebeat.yml configuration file.
The filebeat.yml in each example configures the inputs to be in 
${path.config}/inputs.d/*.yml. You may change this.
3. If -m is supplied to run with mito, the script parses the filebeat cel input
file to break out the state object and the cel program and passes these to mito.

```txt
Usage: beats-config-from-agent-config-template.sh -t <template_file> -v <variables_file> -c <cel_input_file> -o <output_file>

  -t  Path and name to agent configuration template file (e.g., cel.yml.hbs)
  -v  Path and name to YAML file with replacement values for handlebar variables
  -c  Path and name to partial filebeat cel input file to append cel script information
  -o  Path and name to output beats configuration file
  -m  Run a check using mito. --dump option (always | error)
  -h  Show help
```

#### To check and convert the *.yml.hbs file then run it in filebeat

1. Start the docker container with the test API server using the
   ./example_set_name/example_name/docker/docker-compose.yml file.
   Mito note: Mito does not do automatic authorization. hese headers are added 
   by filebeat. API requests will not have Authorization headers added when 
   running mito. To use mito verification for scripts that use automatic
   authorization, use docker-compose-noauth.yml to start the mock API server.
   That server will not require an Authorization header.
2. Create the cel input file from the *.yml.hbs file using 
beats-config-from-agent-config-template.sh

```txt
cd ./example_set_name/example_name

../../beats-config-from-agent-config-template.sh \
 -c ../../filebeat-cel-input-base.yml \
 -t example_name.yml.hbs \
 -v variables.yml \
 -o ./filebeat/inputs.d/test.yml \
- m always
```
3. Run the filebeat cel input file in filebeat. The location of 
path.config and the filebeat configuration file filebeat.yml are set through
commandline options. You may set up your filebeat configuration anyway you like.
It will work as long as the resultant cel input file can be found by filebeat.

```txt        
cd ./filebeat
filebeat -e --path.config . -c filebeat.yml  
```
4. The default filebeat configuration that comes with the examples will
output to './filebeat/out' and generate files in './filebeat/data'.
To verify behavior, inspect the output files in './filebeat/out' to see what 
was produced. Use Docker commands or docker desktop to see what API calls 
were made to the API server.

```txt
 cat ./filebeat/out/*
```
## Creating your own examples or test of new cel scripts

We welcome new examples. Feel free to create your own and add them to the
repository.

To create a new example, copy one of the existing examples as a basis for the new
example. Then
1. Update the *.hbs file with the new cel program. 
2. Update 'variables.yml' to initialize the state fields for your new CEL program.
3. Update the config file for the mock server: 'docker/file/config.yml'
4. Clear the inputs.d directory and the /data directory if there is data there.


### Values that you might need or want to change.
1. The port number for all examples is 8090. Only one
example docker container can be run at a time. To run more than one docker 
container at a time, change the port number in
./docker/files/config.yml and variables.yml to an unused port.
2. The name of mock api server is defined in ./docker/docker-compose.yml under
services. This name is the name of the container in docker.
