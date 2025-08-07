# FAQ

### What is the relationship between Google CEL and Elastic CEL?
The Elastic mito project https://github.com/elastic/mito extends 
google CEL with more evaluations including those that that support http requests
. Written in go, Mito uses https://github.com/google/cel-go libraries.
Every function in go-CEL is available in mito except for send().
Each version of mito is built on a specific version of go-CEL. Each version of
filebeat, which runs the mito library is bound to a specific version of mito.
As CEL-go evolves, mito evolves as well. To get the latest mito version 
available for CEL input, use the latest version of filebeat or the latest
available agent. The go.mod file
for the beats version you are using will have the version of mito that filebeat
was built with. https://github.com/elastic/beats/blob/main/go.mod

Documentation for the mito extension of CEL can be found here
https://www.elastic.co/docs/reference/beats/filebeat/filebeat-input-CEL .
Documentation for google CEL can be found here 
https://github.com/google/CEL-spec/blob/master/doc/langdef.md

### What is the relationship between mito, CEL scripts and filebeat.
The CEL program is a script that is run by filebeat using the mito library.
Filebeat will keep running (invoking or evaluating) the CEL script
until the state variable 'want_more' is false. The evaluation of 'want_more' 
occurs outside the CEL script and outside mito. Using mito to run the CEL script
is equivalent to running a single invocation (evaluation) of the CEL script by
filebeat.

### Why are url, api_key not available in the second periodic run?
url and api keys are set in the state object on the initial run of the program.
The state on the next periodic run is the state that was returned from the 
previous periodic run. If the returned object is not derived from the state 
object using the state.with() syntax, the state object will contain only what
was returned. There are two ways to handle this:
1. Wrap the program with state.with() so every object returned has all the state
variables.
2. Explicitly set the variables that you want to be available in the next
periodic run.

### Why is CEL preferred over HTTPJSON?
CEL is the preferred input method as HTTPJSON is planned to be phased out in
favor on CEL. The reasons for this are:
1.CEL allows for more complex logic and transformations on data, both in 
requests and responses, compared to the more limited capabilities of the 
HTTPJSON input.
2. CEL provides a more programmatic and expressive way to interact with APIs 
and process data, leading to a better development workflow for custom 
integrations.
3. CEL is easier to debug than HTTPJSON.

### Real-world examples?
https://github.com/elastic/integrations.packages has over 150 integrations, many
written using CEL. To find an integration using CEL, look for files called
CEL.yml.hbs under <datastream>/agent. We have evolved our use of CEL over
time so some examples more closely align with how we do things now. The use
of tail() for worklists is recent. Many integrations still use array indexing
for worklists. Using automatic authentication is also relatively recent.

### Compiling and testing CEL scripts without filebeat
https://github.com/elastic/mito can be used to create a 'mito' executable which
can be used at the command line to compile and run cel programs.

https://github.com/elastic/miko is a UI playground for working with the mito CEL 
extension. To open the playground:
```
cd miko
go build 
./miko
``` 
https://github.com/elastic/celfmt is a tool to compile and format the cel 
program.

Note, that each of these tools are versioned, as is filebeat. Running different
versions of the tools on the same program may result in different behavior.
Try to use the versions required by the minimum version of filebeat that is 
being targeted. The go.mod file for the beats version you are using will have 
the version of mito that filebeat was built with. Make sure that you are using
the correct tag for the beats repository
https://github.com/elastic/beats/blob/main/go.mod. The go.mod for miko and 
celfmt will also have the 



### Implementing loops?
CEL is a non-turing complete language. It does not support loops. The use of 
'want_more' to continually loop over the program until want_more is false is
controlled by filebeat or mito. Looping can be emulated by using 'want_more',
even in more complex programs.
[message_group_tail.yml.hbs](../examples/worklist/message_group/message_group_tail.yml.hbs)
shows an example of creating a worklist from one api call that then gets 
worked off in recurring evocations of the program.

### Convert an array of numbers to an array of strings
```
-- data -- 
{ "list": [1,2,3] }

-- src --
state.list1.map(num, string(num))

-- out --
[
	"1",
	"2",
	"3"
]

```
### Create a map of numbers
When output in a state object, keys in maps must be strings.
Used as a temporary object, the keys can be numbers.


```
-- data --
{ "list": [1,2,3], "number": 3}

-- src --
state.list.map(num, string(num)).as(str_num, zip(str_num, state.list))

-- out --
{
	"1": 1,
	"2": 2,
	"3": 3
}

-- src --
zip(state.list, state.list)[state.number]

-- out --
3

-- src --
zip(state.list, state.list)

-- out --
failed proto conversion: type conversion error from Double to 'string'
```
### Check if a value exists in a map
```
-- data --
{   
  "list_map": {
	"10": 10,
	"2": 2,
	"9": 9
   },
   "nine" : "9",
   "five" : "5"
}

-- src --
try(state.list_map[state.five], "map_has_no_key_error").as(
   value,
   !has(value.map_has_no_key_error)
)

-- out --
false

-- src --
try(state.list_map[state.nine], "map_has_no_key_error").as(
   value,
   !has(value.map_has_no_key_error)
)
-- out --
true
```

### Check if a list does not contain a value.
Convert the list to a map, then use try to check for the key
```
-- data --
{
  "list": [1,2,3],
  "number": 3
}

-- src --
try(zip(state.list, state.list)[state.number], "has_no_such_key_error")
.as(value, !has(value.has_no_such_key_error))

-- out --
true
```
### Creating a sorted deduplicated list
zip the list with itself to produce a map where the key and value are the same
value in a list, then take list the keys;
```
-- data --
{ "list": [9,10,1,5,3, 9, 10] }

-- src --
zip(state.list, state.list).keys()
or
state.list.zip(state.list).keys()

-- out --
[
	1,
	3,
	5,
	9,
	10
```

### Comparing two lists and returning values from the second list that do not occur in the first list. (set operation complement)
```
Given 2 unordered, non-sorted, non-unique lists.

-- data --
{ "list1": [9,10,2] , "list2" : [4,8,2,7,4] }

-- src --
zip(state.list1, state.list1).as(existing,
  zip(state.list2, state.list2).keys().filter(x, try(existing[x], "error").as(value, has(value.error))))

-- out --
[
	4,
	7,
	8
]
```

### Find the intersection of two lists?

```
Given 2 unordered, non-sorted, non-unique lists.

-- data --
{ "list1": [9,10,2] , "list2" : [4,8,2,7,4] }

-- src --
zip(state.list1, state.list1).as(existing,
	zip(state.list2, state.list2).keys().filter(x, try(existing[x], "error").as(value, !has(value.error))))

-- out --
[
	2
]
```

### Adding two lists? (set operation union)
```
-- data --
{ "list1": [9,10,2] , "list2" : [4,8,7] }

-- src --
(state.list1 + state.list2)

-- out --
[
	9,
	10,
	2,
	4,
	8,
	7
]
```

### Adding two lists and sort result? (set operation union)
```
-- data --
{ "list1": [9,10,2] , "list2" : [4,8,7] }

-- src --
(state.list1 + state.list2).as(union, zip(union, union).keys())

-- out --
[
	2,
	4,
	7,
	8,
	9,
	10
]
```

### Determining if a value is between to other values
```
-- data -- 
{ "v1": 2, "v2": 4, target1" : 3, "target2" : 5, "targets": [3,5] } 

-- src --
[state.v1, state.v2].as(values, zip(values, values).keys())
	.as(ordered_values, state.target1 > ordered_values[0] && state.target1 < ordered_values[1])

-- out --
true

-- src --
[state.v1, state.v2].as(values, zip(values, values).keys())
	.as(ordered_values, state.target2 > ordered_values[0] && state.target2 < ordered_values[1])

-- out --
false

-- src --
[state.v1, state.v2].as(values, zip(values, values).keys())
	.as(ordered_values, state.targets.map(x, x > ordered_values[0] && x < ordered_values[1]))

-- out --
[
    true,
    false
]
```

### Convert a list of strings to uppercase
```
-- data -- 
{ "list": ["abc", "cde"] } 

-- src --
state.list.map(e, e.to_upper())

--- out --- 
[
	"ABC",
	"CDE"
]
```

### What is the optional type?
The optional type is based on Java's java.util.Optional<T> which is a container 
object that may or may not contain a non-null value. In CEL, if the assigned
optional doe not contain a value, the value is removed from state.

A '?' before a value marks the value as an optional type. Use
optional.of() to set a value, and optional.none() to not set the value or
to remove it.
```
-- data --
{ 
  "some_variable" : "imastring"
}

-- src --
state.with({
    ?"limit": has(state.limit) ? optional.of(state.limit) : optional.none()
})
    
-- out --
{
	"some_variable": "imastring"
}

-- data --
{ 
  "some_variable" : "imastring",
  "limit": 1
}

-- src --
state.with({
    ?"limit": has(state.limit) ? optional.of(state.limit) : optional.none()
})
    
-- out --
{
	"limit": 1,
	"some_variable": "imastring"
}

-- src --
state.with({
    ?"limit": has(state.limit) ? optional.of(state.limit) : optional.none()
})
    
-- out --
{
	"limit": 1,
	"some_variable": "imastring"
}
```

### Use optional.none() over null
The use of null requires this syntax
```
has(value) && has(value) != null
or
!has(value) !! value == null
```

Using optional.none() removes the value entirely removing the requirement to
check for null.

### Handling "found no matching overload for 'with' applied to" errors
The work around for this is to use dyn(< the object>) to allow for runtime 
determination of type.

```
object = {...}

dyn(object)
```
If you see this, please create an issue with a reproducible test case in
the mito repository.

### Handling type 'string' does not support field selection errors

Occasionally the compiler will think that an object is a string and not an
object. Use dyn(< the object>) to allow for runtime determination of type.

### Turning array of objects with maps into a list of maps.

```
-- data --
[
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
    }
]

-- src --

zip(
  state.map(e,e.map(key,key)).flatten(),
  state.map(e,
    e.map(key, e[key])
  ).flatten()
)

-- output --

{
	"abcdef": {
		"key1": "value5",
		"key2": "value6"
	},
	"ghijkl": {
		"key3": "value3",
		"key4": "value4"
	},
	"mnopqrs": {
		"key1": "value1",
		"key2": "value2"
	}
}
```


