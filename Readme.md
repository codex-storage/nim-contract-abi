Contract ABI
============

Implements encoding of parameters according to the Ethereum
[Contract ABI Specification][1].

Installation
------------

Use the [Nimble][2] package manager to add `contractabi` to an existing project.
Add the following to its .nimble file:

```nim
requires "https://github.com/status-im/nim-contract-abi >= 0.1.0 & < 0.2.0"
```

Usage
-----

```nim
import contractabi
import stint

# encode unsigned integers, booleans, enums
AbiEncoder.encode(42'u8)

# encode uint256
AbiEncoder.encode(42.u256)

# encode byte arrays and sequences
AbiEncoder.encode([1'u8, 2'u8, 3'u8])
AbiEncoder.encode(@[1'u8, 2'u8, 3'u8])

# encode tuples
var encoder = AbiEncoder.init()
encoder.startTuple()
encoder.write(42'u8)
encoder.write(@[1'u8, 2'u8, 3'u8])
encoder.write(true)
encoder.finishTuple()
encoder.finish()
```

[1]: https://docs.soliditylang.org/en/latest/abi-spec.html
[2]: https://github.com/nim-lang/nimble
