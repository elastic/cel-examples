# Examples and FAQs for Working with CEL

### Overview
The cel-examples repository has a directory of fully functional examples as
well as a directory of FAQs. The goal of these resources is to help developers 
working with the Elastic mito extension of CEL understand the language better 
and to be more productive. 

### CEL
Common Expression Language (CEL) is non-Turing complete functional language.
Elastic chose CEL due to its performance and safety. Rather than using a sandbox 
to run the program, CEL can be embedded as a library. Elastic extended CEL in 
the mito project to include support for requesting and processing API requests.

As a non-turing complete functional language, the structure of CEL programs can 
seem foreign to procedural or object-oriented programmers. For more information 
on CEL and mito extensions, see the official documentation:
[Google CEL](https://github.com/google/CEL-spec/blob/master/doc/langdef.md),
[mito CEL extension](https://www.elastic.co/docs/reference/beats/filebeat/filebeat-input-CEL). 

### Examples
The examples directory has functioning CEL programs. Each example has a 
docker-compose file to run a mock server to server an API so the example can
be run in realistically. The README.md explains how to use run the examples.

### FAQs
There are several files in the FAQS directory with how-tos on how to write CEL
code, structure CEL programs for handling API request errors, how to fix
compile errors and set up an editor for CEL. Many code examples for the mito
extensions exist in the mito repository testdata directory
[mito testdata](https://github.com/elastic/mito/tree/dev/testdata). The FAQ
code snippets are complementary to the code examples in the mito repository.
The code examples in the FAQs are focused on use in processing API requests.
