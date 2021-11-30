import std/unittest
import contractabi
import ./examples

suite "ABI decoding":

  proc checkDecode[T](value: T) =
    let encoded = AbiEncoder.encode(value)
    check AbiDecoder.decode(encoded, T) == value

  proc checkDecode(T: type) =
    checkDecode(T.example)
    checkDecode(T.low)
    checkDecode(T.high)

  test "decodes uint8, uint16, 32, 64":
    checkDecode(uint8)
    checkDecode(uint16)
    checkDecode(uint32)
    checkDecode(uint64)

  # TODO: failure to decode when prefix not all zeroes
  # TODO: failure when trailing bytes

  test "decodes booleans":
    checkDecode(false)
    checkDecode(true)

  # TODO: failure to decode when value not 0 or 1

  test "decodes ranges":
    type SomeRange = range[0x0000'u16..0xAAAA'u16]
    checkDecode(SomeRange(42))
    checkDecode(SomeRange.low)
    checkDecode(SomeRange.high)

  # TODO: failure to decode when value not in range

  test "decodes enums":
    type SomeEnum = enum
      one = 1
      two = 2
    checkDecode(one)
    checkDecode(two)

  # TODO: failure to decode when invalid enum value

  test "decodes stints":
    checkDecode(UInt128)
    checkDecode(UInt256)

  test "decodes byte arrays":
    checkDecode([1'u8, 2'u8, 3'u8])
    checkDecode(array[32, byte].example)
    checkDecode(array[33, byte].example)

  # TODO: failure to decode when byte array of wrong length

  test "decodes byte sequences":
    checkDecode(@[1'u8, 2'u8, 3'u8])
    checkDecode(@(array[32, byte].example))
    checkDecode(@(array[33, byte].example))

  # TODO: failure to decode when not enough bytes

  test "decodes tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]

    var encoder= AbiEncoder.init()
    encoder.startTuple()
    encoder.write(a)
    encoder.write(b)
    encoder.write(c)
    encoder.write(d)
    encoder.finishTuple()
    let encoding = encoder.finish()

    var decoder = AbiDecoder.init(encoding)
    decoder.startTuple(dynamic=true)
    check decoder.read(bool) == a
    check decoder.read(seq[byte]) == b
    check decoder.read(uint32) == c
    check decoder.read(seq[byte]) == d
    decoder.finishTuple()
    decoder.finish()

  test "decodes nested tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]

    var encoder= AbiEncoder.init()
    encoder.startTuple()
    encoder.write(a)
    encoder.write(b)
    encoder.startTuple()
    encoder.write(c)
    encoder.write(d)
    encoder.finishTuple()
    encoder.finishTuple()
    let encoding = encoder.finish()

    var decoder = AbiDecoder.init(encoding)
    decoder.startTuple(dynamic=true)
    check decoder.read(bool) == a
    check decoder.read(seq[byte]) == b
    decoder.startTuple(dynamic=true)
    check decoder.read(uint32) == c
    check decoder.read(seq[byte]) == d
    decoder.finishTuple()
    decoder.finishTuple()
    decoder.finish()

  test "reads elements after dynamic tuple":
    let a = @[1'u8, 2'u8, 3'u8]
    let b = 0xAABBCCDD'u32
    var encoder = AbiEncoder.init()
    encoder.startTuple()
    encoder.write(a)
    encoder.finishTuple()
    encoder.write(b)
    let encoding = encoder.finish()

    var decoder = AbiDecoder.init(encoding)
    decoder.startTuple(dynamic=true)
    check decoder.read(seq[byte]) == a
    decoder.finishTuple()
    check decoder.read(uint32) == b
    decoder.finish()

  test "reads elements after static tuple":
    let a = 0x123'u16
    let b = 0xAABBCCDD'u32
    var encoder = AbiEncoder.init()
    encoder.startTuple()
    encoder.write(a)
    encoder.finishTuple()
    encoder.write(b)
    let encoding = encoder.finish()

    var decoder = AbiDecoder.init(encoding)
    decoder.startTuple(dynamic=false)
    check decoder.read(uint16) == a
    decoder.finishTuple()
    check decoder.read(uint32) == b
    decoder.finish()

  test "reads static tuple inside dynamic tuple":
    let a = @[1'u8, 2'u8, 3'u8]
    let b = 0xAABBCCDD'u32

    var encoder= AbiEncoder.init()
    encoder.startTuple()
    encoder.write(a)
    encoder.startTuple()
    encoder.write(b)
    encoder.finishTuple()
    encoder.finishTuple()
    let encoding = encoder.finish()

    var decoder = AbiDecoder.init(encoding)
    decoder.startTuple(dynamic=true)
    check decoder.read(seq[byte]) == a
    decoder.startTuple(dynamic=false)
    check decoder.read(uint32) == b
    decoder.finishTuple()
    decoder.finishTuple()
    decoder.finish()

  test "reads empty tuples":
    var encoder = AbiEncoder.init()
    encoder.startTuple()
    encoder.startTuple()
    encoder.finishTuple()
    encoder.finishTuple()
    let encoding = encoder.finish()

    var decoder = AbiDecoder.init(encoding)
    decoder.startTuple(dynamic=false)
    decoder.startTuple(dynamic=false)
    decoder.finishTuple()
    decoder.finishTuple()
    decoder.finish()

  test "decodes sequences":
    checkDecode(@[seq[byte].example, seq[byte].example])

  test "decodes arrays with static elements":
    checkDecode([array[32, byte].example, array[32, byte].example])

  test "decodes arrays with dynamic elements":
    checkDecode([seq[byte].example, seq[byte].example])

  test "decodes strings":
    checkDecode("hello!☺")
