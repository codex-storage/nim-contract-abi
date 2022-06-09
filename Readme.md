Contract ABI
============

Implements encoding of parameters according to the Ethereum
[Contract ABI Specification][1].

Installation
------------

Use the [Nimble][2] package manager to add `contractabi` to an existing project.
Add the following to its .nimble file:

```nim
requires "contractabi >= 0.4.5 & < 0.5.0"
```

Usage
-----

```nim
import contractabi

# encode unsigned integers, booleans, enums
AbiEncoder.encode(42'u8)

# encode uint256
import stint
AbiEncoder.encode(42.u256)

# encode byte arrays and sequences
AbiEncoder.encode([1'u8, 2'u8, 3'u8])
AbiEncoder.encode(@[1'u8, 2'u8, 3'u8])

# encode tuples
AbiEncoder.encode( (42'u8, @[1'u8, 2'u8, 3'u8], true) )

# decode values of different types
AbiDecoder.decode(bytes, uint8)
AbiDecoder.decode(bytes, UInt256)
AbiDecoder.decode(bytes, array[3, uint8])
AbiDecoder.decode(bytes, seq[uint8])

# decode tuples
AbiDecoder.decode(bytes, (uint32, bool, seq[byte]) )

# add support for encoding of custom types
import questionable/results

type CustomType = object
  a: uint16
  b: string

func encode(encoder: var AbiEncoder, custom: CustomType) =
  encoder.write( (custom.a, custom.b) )

func decode(decoder: var AbiDecoder, T: type CustomType): ?!T =
  let (a, b) = ?decoder.read( (uint16, string) )
  success CustomType(a: a, b: b)

```

[1]: https://docs.soliditylang.org/en/latest/abi-spec.html
[2]: https://github.com/nim-lang/nimble
