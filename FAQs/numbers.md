# Number types in CEL

### Why are integers being converted to doubles

Numbers come in to CEL as floating point values when deserialized from JSON. Similarly,
all numbers are serialized as floating point when being returned from a CEL evaluation.

### Why is the compile failing with "timestamp : no such overload: timestamp(double)"
The conversion fails because there is no defined overload for converting 
to a timestamp from a double. To fix this, convert the timestamp to an int.

```
timestamp(int(ts))
```
