# Number types in CEL

###  Integers being converted to doubles

Numbers come in to CEL as double when deserialized from JSON. As well,
integers published as JSON from CEL will be converted to doubles.

### Handling errors with timestamp : no such overload: timestamp(double)
A timestamp that is an integer needs to be explicitly
case to an int

```
timestamp(int(ctx.timestamp))
```

In other cases
```
- script:
  if: ctx.json?.anum != null && ctx.json?.anum != ''
  tag: anum_is_long
  lang: painless
  source: >
    if (ctx.json.anum instanceof String) {
      try {
        long anum = Long.parseLong(ctx.json.anum);
        ctx.tenable_io.asset.anum = anum;
      } catch (NumberFormatException e) {
        double anum = Double.parseDouble(ctx.json.anum);
        ctx.tenable_io.asset.anum = (long) anum; 
      }
      return;
    }
    if (ctx.json.anum instanceof int || ctx.json.anum instanceof long) {
      ctx.tenable_io.asset.anum = (long) ctx.json.anum;
      return;
    }
    if (ctx.json.anum instanceof double) {
      ctx.tenable_io.asset.anum = (long) ctx.json.anum;
      return;
    } 
    if (ctx.json.anum instanceof Number) {
      ctx.tenable_io.asset.anum = ((Number) ctx.json.anum).longValue();
      return;
    }
```

### Timestamps should not be stored in cursors as numbers

Due to the conversion of integers to floats, the timestamp will be converted
to an exponent and lose precision. Instead, store the timestamp as a string
or convert it to a datetime string.