import std/unittest
import pkg/questionable/results
import contractabi

type
  Custom1 = object
    a: uint16
    b: string
  Custom2 = object
    a: uint16
    b: string
  Custom3 = object
    a: uint16
    b: string

func encode(encoder: var AbiEncoder, custom: Custom1) =
  encoder.write( (custom.a, custom.b) )

func decode(decoder: var AbiDecoder, T: type Custom1): ?!T =
  let (a, b) = ?decoder.read( (uint16, string) )
  success Custom1(a: a, b: b)

func encode(encoder: var AbiEncoder, custom: Custom2) =
  encoder.startTuple()
  encoder.write(custom.a)
  encoder.write(custom.b)
  encoder.finishTuple()

func decode(decoder: var AbiDecoder, T: type Custom2): ?!T =
  var custom: T
  decoder.startTuple()
  custom.a = ?decoder.read(uint16)
  custom.b = ?decoder.read(string)
  decoder.finishTuple()
  success custom

func encode(encoder: var AbiEncoder, custom: Custom3) =
  encoder.startTuple()
  encoder.write(custom.a)
  encoder.write(custom.b)
  # missing: encoder.finishTuple()

func decode(decoder: var AbiDecoder, T: type Custom3): ?!T =
  var custom: T
  decoder.startTuple()
  custom.a = ?decoder.read(uint16)
  custom.b = ?decoder.read(string)
  # missing: decoder.finishTuple()
  success custom

suite "custom types":

  let custom1 = Custom1(a: 42, b: "ultimate answer")
  let custom2 = Custom2(a: 42, b: "ultimate answer")
  let custom3 = Custom3(a: 42, b: "ultimate answer")

  test "can be encoded":
    check:
      AbiEncoder.encode(custom1) == AbiEncoder.encode( (custom1.a, custom1.b) )

  test "can be decoded":
    let encoding = AbiEncoder.encode(custom1)
    check AbiDecoder.decode(encoding, Custom1) == success custom1

  test "can be embedded in tuples, arrays and sequences":
    let embedding = (custom1, [custom1], @[custom1])
    let encoding = AbiEncoder.encode(embedding)
    let decoded = AbiDecoder.decode(encoding, typeof(embedding))
    check !decoded == embedding

  test "can use startTuple() and finishTuple()":
    let encoding = AbiEncoder.encode(custom2)
    check AbiDecoder.decode(encoding, Custom2) == success custom2

  test "fail when finishTuple() is missing":
    expect Exception:
      discard AbiEncoder.encode(custom3)
    let encoding = AbiEncoder.encode( (custom3.a, custom3.b) )
    expect Exception:
      discard AbiDecoder.decode(encoding, Custom3)
