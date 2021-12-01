import std/unittest
import pkg/questionable/results
import contractabi

type CustomType = object
  a: uint16
  b: string

func encode(encoder: var AbiEncoder, custom: CustomType) =
  encoder.write( (custom.a, custom.b) )

func decode(decoder: var AbiDecoder, T: type CustomType): ?!T =
  let (a, b) = ?decoder.read( (uint16, string) )
  success CustomType(a: a, b: b)

suite "custom types":

  let custom = CustomType(a: 42, b: "ultimate answer")

  test "can be encoded":
    check AbiEncoder.encode(custom) == AbiEncoder.encode( (custom.a, custom.b) )

  test "can be decoded":
    let encoding = AbiEncoder.encode(custom)
    check AbiDecoder.decode(encoding, CustomType) == success custom
