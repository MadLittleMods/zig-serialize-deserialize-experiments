# Serialize/deserialize experiments with Zig

Spawning from https://github.com/MadLittleMods/zig-neural-networks/pull/13. This repo
contains a more barebones reproduction of what I'm trying to do there so we can just get
the serialize/deserialize pattern working.


## Tagged Union

If all of your types are known to your library, then it's probably best just to use a tagged union.

```sh
zig run ./tagged_union/main.zig
```



## Interface

Following the interface pattern outlined in https://www.openmymind.net/Zig-Interfaces/,
how can we make the types that inherit from the interface serializable/deserializable?

 - How can we handle types that are already known and part of the library?
 - How can we handle custom types that come from someone using our library?

The first example covers the first question and just uses the `DenseLayer` and
`ActivationLayer` types that come with the library itself. The "library" is just an
imaginary neural network library in the context of this barebones example. A neural
network has several layers of various types. Noting this library boundary of what's
known from the perspective inside vs outside the library is an important distinction
because we actually will only know about the types that are part of the library in a
real-world scenario. All the source files here are in the same directory just to
simplify what's needed to reproduce the problem and make it easier to run (no build
necessary).

```sh
zig run ./interface/main.zig
```

---

The second example uses a custom user-supplied `Layer` type `CustomDropoutLayer` which
is a bit harder to deserialize because we don't know this type from the perspective of
the library.

```sh
zig run ./interface/main_custom_network.zig
```



