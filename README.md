# Examples and FAQs for Working with CEL

### Overview
The cel-examples repository has a directory of fully functional examples as
well as a directory of FAQs. The goal of these resources is to help developers
working with the Elastic mito extension of CEL understand the language better
and to be more productive.

### CEL
Common Expression Language (CEL) is a non-Turing complete functional language.
Elastic chose CEL due to its performance and safety. Rather than using a sandbox
to run the program, CEL can be embedded as a library. Elastic extended CEL in
the mito project to include support for requesting and processing API requests.

As a non-turing complete functional language, the structure of CEL programs can
seem foreign to procedural or object-oriented programmers. For more information
on CEL and mito extensions, see the official documentation:
[Google CEL](https://github.com/google/CEL-spec/blob/master/doc/langdef.md),
[mito CEL extension](https://www.elastic.co/docs/reference/beats/filebeat/filebeat-input-cel).

### Examples
The examples directory has functioning CEL programs. Each example has a
docker-compose file to run a mock server to serve an API so the example can
be run in realistically. The [README.md](./examples/README.md) explains how to
run the examples. The scripts directory has scripts to generate a runnable 
filebeat configuration file from the CEL program template.

### FAQs
There are several files in the FAQs directory with how-tos on how to write CEL
code, structure CEL programs for handling API request errors, how to fix
compile errors and set up an editor for CEL. Many code examples for the mito
extensions exist in the mito repository testdata directory
[mito testdata](https://github.com/elastic/mito/tree/dev/testdata). The FAQ
code snippets are complementary to the code examples in the mito repository.
The code examples in the FAQs are focused on use in processing API requests.

## Structure of Examples Directory

Each example has its own directory with an agent configuration file 
(cel.yml.hbs file), a filebeat directory and a docker directory.
The displayed structure is based on using default values when
running '[beats-config-from-agent-config-template.sh](../scripts/beats-config-from-agent-config-template.sh)'
and running 'filebeat'.

```
scripts
    ├── beats-config-from-agent-config-template.sh   #script
    ├── render.js                       #script that is used by 
    │                                    beats-config-from-agent-config-template.sh
└── filebeat-cel-input-base.yml     #File for the filebeat cel-input file to
                                     which the CEL progam will be added.
                                     Can be any name.  
examples                                   
    └──example_name/             # an example directory
       ├── cel.yml.hbs           # agent configuration file. *
       ├── variables.yml         # yaml file with replacement values for handlebar
       │                           handlebar variables in the cel.yml.hbs file. * 
       ├── filebeat/         # filebeat directory
       │   ├── filebeat.yml  # filebeat executable configuration file *
       │   ├── inputs.d      # generated directory to hold filebeat CEL input file *
       │   │   └── test.yml  # generated filebeat config. 
       │   └── out           # generated directory for output *
       └── docker/           # docker files to run a test API server
           ├── docker-compose.yml 
           └── files
               └── config.yml   # contains responses from the API Server

Files with an "*" after the description can have their name and location
overridden. The locations must be in sync with the 'filebeat.yml' specified
on the commandline when running 'filebeat'. This is an advanced use and not 
expected in the normal flow of testing and debugging.                                   
```

### What does each file do?
#### CEL input template file (cel.yml.hbs)
The 'cel.yml.hbs' the templated CEL input file that 
has templated parameters and the CEL program. Once tested and
debugged this file can be used as the CEL input template in an integration.
This is what makes using cel-examples so powerful. The user can test and debug
the actual file used in an integration instead of copying out the CEL program and 
debugging it separately from its templated parameters.
#### variables.yml
The 'variables.yml' file has concrete parameters for the templated parameters
in the CEL input template file. This file represents variables that would be set
during the configuration of an integration.
#### filebeat.yml
The 'filebeat.yml' file is a filebeat execution configuration file. It defines 
where 'filebeat' can find the CEL input file(s) and where to send output. The 
default configuration looks for the generated CEL input file in the path defined 
by 'filebeat.config.inputs.path' (default './filebeat/inputs.d') and sends output 
to the file defined by 'output.file.path' (default './filebeat/out').
#### generated file "./filebeat/inputs.d/test.yml"
This a filebeat CEL inputs file that is generated by replacing the 
templated variables in the 'cel.yml.hbs' file with concrete variables 
from 'variables.yml' and then adding the result to the base filebeat configuration 
file defined in 'filebeat-cel-input-base.yml'.
#### generated directory "out"
This is the default output directory based on the configuration variable
'output.file.path' in 'filebeat.yml'. This is based on configuration and can be 
changed. 'filebeat' will create this directory when it is run.
#### ./scripts/beats-config-from-agent-config-template.sh
This script takes the CEL input template (default 'cel.yml.hbs'), 
the variables file (default 'variables.yml'), the filebeat output template
(default './scripts/filebeat-cel-input-base.yml') and the generated CEL inputs
file (default './filebeat/inputs.d/test.yml') and produces the generated
CEL input file. If the '-m' switch is applied, it will run the generated
script through 'mito' for testing and debugging.
#### ./scripts/filebeat-cel-input-base.yml
An empty CEL inputs configuration file to which the generated CEL input will
be added to create a runnable filebeat inputs file. 
#### docker directory
The docker directory follows the same structure as the docker directories in
the integrations repo that are used for testing. It contains at least one
docker-compose file to run a test server for testing. The 'docker/files' directory
contains config files for generating responses for requests.  For developing
a new CEL program, the user may choose to use alternate test servers or
the actual endpoint. However, new integrations require a test server like the
ones in the examples. For documentation on how to config test servers see
https://github.com/elastic/stream.


### Test cycle

Testing and debugging takes place when the CEL input file is generated and when
filebeat runs the generated file. Generating the file with the '-m' switch
runs the CEL program through 'mito' which compiles and runs the program. Once
the CEL input file runs correctly with 'mito', the file can be more fully tested
by running it using 'filebeat'.

#### Generating the CEL input file
'./scripts/beats-config-from-agent-config-template.sh' converts
the agent configuration file ('cel.yml.hbs') into a CEL input file that 
can be run by 'filebeat'. To test and debug with 'mito' during the generation step
use the '-m always' or '-m error' commandline switch.

##### About the script
1. Depends on the './scripts/render.js' script that uses handlebars to replace 
handlebar variables in the 'cel.yml.hbs' file with the concrete values from 
'variables.yml'. 
2. Adds the resulting state and program keys to 'filebeat-cel-input-base.yml' 
to create the complete filebeat CEL input file and writes it out by default 
to './filebeat/inputs.d'.
3. If '-m' is supplied to run with 'mito', the script parses the filebeat CEL
input file to generate the state object and the CEL program and passes these to
'mito'.
4. If '-m' is supplied, the CEL program will be executed. A test server or live 
server needs to be accessible to the CEL program.

```txt
Usage: beats-config-from-agent-config-template.sh 
     -e <example directory>
     -t <template_file> 
     -v <variables_file> 
     -c <cel_input_file> 
     -o <output_file>

    -e  Path and name of example to run  (default is current directory)"
    -t  Path and name to agent configuration template file (default <example-name>/cel.yml.hbs)"
    -v  Path and name to YAML file with replacement values for handlebar variables (default <example-name>/variables.yml)"
    -c  Path and name to filebeat CEL input file to append CEL script information (default <example-name>/../scripts/filebeat-cel-input-base.yml)"
    -o  Path and name to output beats configuration file (default <example-name>/filebeat/inputs.d/test.yml)"
    -m  (Optional) Run a check using mito option (always | error)"
    -h  Show help"

```
The easiest way to run the script is to use the defaults. Assuming your
example directory is under examples, 'cd' in the example 
directory and run:

```text
 ../../scripts/beats-config-from-agent-config-template.sh 
```

To run from outside the example directory using the defaults run
```text
 <absolute or relative path_to>/scripts/beats-config-from-agent-config-template.sh 
    -e <path to example directory>
```

Note that if you want to override any of the files used for generating the CEL
input file, the file paths need to be relative to the location of the 
example directory. For instance, if the CEL input template is called 
"<my_path>/cel_2.yml.hbs", and the example directory was "<my_path>/example2", 
run:
```text
 <absolute or relative path_to>/scripts/beats-config-from-agent-config-template.sh 
    -e <my_path>/example2 -t cel_2.yml.hbs
```

#### To check and convert the cel.yml.hbs file then run it in filebeat

1. Start the docker container with the test API server using the
   './examples/example_name/docker/docker-compose.yml' file.
   Mito note: 'mito' does not do automatic authorization. These headers are added 
   by 'filebeat'. API requests will not have Authorization headers added when 
   running in 'mito'. To use 'mito' verification for scripts that use automatic
   authorization (ex 'url_query_oauth2_next_links'), use 
   'docker-compose-noauth.yml' to start the mock API server. That server will 
   not require an Authorization header.
2. Create the CEL input file from the 'cel.yml.hbs' template file using 
   'beats-config-from-agent-config-template.sh'

```txt
cd ./examples/example_name
../../beats-config-from-agent-config-template.sh -m always
```
3. Run the filebeat CEL input file in 'filebeat'. The location of 
path.config and the filebeat configuration file 'filebeat.yml' are set through
commandline options. You may set up your filebeat configuration anyway you like.
It will work as long as the resultant CEL input file can be found by filebeat.

```txt        
cd ./examples/example_name/filebeat
filebeat -e --path.config . -c filebeat.yml  
```
'filebeat' can take about a minute to start. Monitor the console until requests
and responses begin to be printed out.
4. ctrl-C to stop 'filebeat'. Wait a few seconds for the files to 
'./filebeat/out' to be written out.
5. Verify output. The default filebeat configuration that comes with the 
examples will output to './filebeat/out' and write metadata to './filebeat/data'.
To verify behavior, inspect the output files in './filebeat/out' to see what 
messages are produced. Use Docker commands or Docker Desktop to see what API calls 
were made to the test API server. To see what states of cursor were stored, 
look in './'filebeat/data/registry/filebeat/log.json'
6. 'filebeat' can be run repeatedly without deleting the 'data' directory. 
To rerun a test from start conditions, delete the './filebeat/data' directory.

## Creating your own examples or testing new CEL program.

Copy any example as a basis for your new CEL program. Modify 'cel.yml.hbs',
'variables.yml' and the config file for the test API server. 

### Values that you might need or want to change in Docker
1. The port number for all examples is 8090. Only one
example docker container can be run at a time to avoid port collision.
Synchronize changed port numbers in the docker-compose files with 
'./docker/files/config.yml' and 'variables.yml'
2. The name of mock api server is defined in the docker-compose files under
services. This name is the name of the container in docker. 
