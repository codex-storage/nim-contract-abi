import std/unittest
import pkg/questionable/results
import contractabi
import ./examples

suite "ABI decoding":

  proc checkDecode[T](value: T) =
    let encoded = AbiEncoder.encode(value)
    check !AbiDecoder.decode(encoded, T) == value

  proc checkDecode(T: type) =
    checkDecode(T.example)
    checkDecode(T.low)
    checkDecode(T.high)

  test "decodes uint8, uint16, 32, 64":
    checkDecode(uint8)
    checkDecode(uint16)
    checkDecode(uint32)
    checkDecode(uint64)

  test "decodes int8, int16, int32, int64":
    checkDecode(int8)
    checkDecode(int16)
    checkDecode(int32)
    checkDecode(int64)

  test "fails to decode when reading past end":
    var encoded = AbiEncoder.encode(uint8.example)
    encoded.delete(encoded.len-1)
    let decoded = AbiDecoder.decode(encoded, uint8)
    check decoded.error.msg == "reading past end"

  test "fails to decode when trailing bytes remain":
    var encoded = AbiEncoder.encode(uint8.example)
    encoded.add(byte.example)
    let decoded = AbiDecoder.decode(encoded, uint8)
    check decoded.error.msg == "unread trailing bytes found"

  test "fails to decode when padding does not consist of zeroes":
    var encoded = AbiEncoder.encode(uint8.example)
    encoded[3] = 42'u8
    let decoded = AbiDecoder.decode(encoded, uint8)
    check decoded.error.msg == "invalid padding found"

  test "decodes booleans":
    checkDecode(false)
    checkDecode(true)

  test "fails to decode boolean when value is not 0 or 1":
    let encoded = AbiEncoder.encode(2'u8)
    check AbiDecoder.decode(encoded, bool).error.msg == "invalid boolean value"

  test "decodes ranges":
    type SomeRange = range[0x0000'u16..0xAAAA'u16]
    checkDecode(SomeRange(42))
    checkDecode(SomeRange.low)
    checkDecode(SomeRange.high)

  test "fails to decode when value not in range":
    type SomeRange = range[0x0000'u16..0xAAAA'u16]
    let encoded = AbiEncoder.encode(0xFFFF'u16)
    let decoded = AbiDecoder.decode(encoded, SomeRange)
    check decoded.error.msg == "value not in range"

  test "decodes enums":
    type SomeEnum = enum
      one = 1
      two = 2
    checkDecode(one)
    checkDecode(two)

  test "fails to decode enum when encountering invalid value":
    type SomeEnum = enum
      one = 1
      two = 2
    let encoded = AbiEncoder.encode(3'u8)
    check AbiDecoder.decode(encoded, SomeEnum).error.msg == "invalid enum value"

  test "decodes stints":
    checkDecode(UInt128)
    checkDecode(UInt256)
    checkDecode(Int128)
    checkDecode(Int256)

  test "decodes addresses":
    checkDecode(Address.example)

  test "decodes byte arrays":
    checkDecode([1'u8, 2'u8, 3'u8])
    checkDecode(array[32, byte].example)
    checkDecode(array[33, byte].example)

  test "decodes byte sequences":
    checkDecode(@[1'u8, 2'u8, 3'u8])
    checkDecode(@(array[32, byte].example))
    checkDecode(@(array[33, byte].example))

  test "decodes tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
    checkDecode( (a, b, c, d) )

  test "decodes nested tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
    checkDecode( (a, b, (c, d)) )

  test "reads elements after dynamic tuple":
    let a = @[1'u8, 2'u8, 3'u8]
    let b = 0xAABBCCDD'u32
    checkDecode( ((a,), b) )

  test "reads elements after static tuple":
    let a = 0x123'u16
    let b = 0xAABBCCDD'u32
    checkDecode( ((a,), b) )

  test "reads static tuple inside dynamic tuple":
    let a = @[1'u8, 2'u8, 3'u8]
    let b = 0xAABBCCDD'u32
    checkDecode( (a, (b,)) )

  test "reads empty tuples":
    checkDecode( ((),) )

  test "decodes sequences":
    checkDecode(@[seq[byte].example, seq[byte].example])

  test "decodes arrays with static elements":
    checkDecode([array[32, byte].example, array[32, byte].example])

  test "decodes arrays with dynamic elements":
    checkDecode([seq[byte].example, seq[byte].example])

  test "decodes strings":
    checkDecode("hello!☺")
