
Spawning from https://github.com/MadLittleMods/zig-neural-networks/pull/13. This repo
contains a more barebones reproduction so we can just get the serialize/deserialize
pattern working.

This uses just the `DenseLayer` and `ActivationLayer` types that come with the library itself.

```
zig run ./interface/main.zig
```

This one uses a custom user-supplied layer type `CustomDropoutLayer` which is a bit
harder to deserialize because we don't know this type from the perspective of the
library.

```
zig run ./interface/main_custom_network.zig
```


