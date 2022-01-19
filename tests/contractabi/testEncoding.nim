
import std/unittest
import std/sequtils
import pkg/stint
import pkg/stew/byteutils
import contractabi
import ./examples

suite "ABI encoding":

  proc zeroes(amount: int): seq[byte] =
    newSeq[byte](amount)

  test "encodes uint8":
    check AbiEncoder.encode(42'u8) == 31.zeroes & 42'u8

  test "encodes booleans":
    check AbiEncoder.encode(false) == 31.zeroes & 0'u8
    check AbiEncoder.encode(true) == 31.zeroes & 1'u8

  test "encodes uint16, 32, 64":
    check AbiEncoder.encode(0xABCD'u16) ==
      30.zeroes & 0xAB'u8 & 0xCD'u8
    check AbiEncoder.encode(0x11223344'u32) ==
      28.zeroes & 0x11'u8 & 0x22'u8 & 0x33'u8 & 0x44'u8
    check AbiEncoder.encode(0x1122334455667788'u64) ==
      24.zeroes &
      0x11'u8 & 0x22'u8 & 0x33'u8 & 0x44'u8 &
      0x55'u8 & 0x66'u8 & 0x77'u8 & 0x88'u8

  test "encodes int8, 16, 32, 64":
    check AbiEncoder.encode(1'i8) == 31.zeroes & 0x01'u8
    check AbiEncoder.encode(-1'i8) == 0xFF'u8.repeat(32)
    check AbiEncoder.encode(1'i16) == 31.zeroes & 0x01'u8
    check AbiEncoder.encode(-1'i16) == 0xFF'u8.repeat(32)
    check AbiEncoder.encode(1'i32) == 31.zeroes & 0x01'u8
    check AbiEncoder.encode(-1'i32) == 0xFF'u8.repeat(32)
    check AbiEncoder.encode(1'i64) == 31.zeroes & 0x01'u8
    check AbiEncoder.encode(-1'i64) == 0xFF'u8.repeat(32)

  test "encodes ranges":
    type SomeRange = range[0x0000'u16..0xAAAA'u16]
    check AbiEncoder.encode(SomeRange(0x1122)) == 30.zeroes & 0x11'u8 & 0x22'u8

  test "encodes enums":
    type SomeEnum = enum
      one = 1
      two = 2
    check AbiEncoder.encode(one) == 31.zeroes & 1'u8
    check AbiEncoder.encode(two) == 31.zeroes & 2'u8

  test "encodes stints":
    let uint256 = UInt256.example
    let uint128 = UInt128.example
    check AbiEncoder.encode(uint256) == @(uint256.toBytesBE)
    check AbiEncoder.encode(uint128) == 16.zeroes & @(uint128.toBytesBE)
    check AbiEncoder.encode(1.i256) == 31.zeroes & 0x01'u8
    check AbiEncoder.encode(1.i128) == 31.zeroes & 0x01'u8
    check AbiEncoder.encode(-1.i256) == 0xFF'u8.repeat(32)
    check AbiEncoder.encode(-1.i128) == 0xFF'u8.repeat(32)

  test "encodes addresses":
    let address = Address.example
    check AbiEncoder.encode(address) == 12.zeroes & @(address.toArray)

  test "encodes byte arrays":
    let bytes3 = [1'u8, 2'u8, 3'u8]
    check AbiEncoder.encode(bytes3) == @bytes3 & 29.zeroes
    let bytes32 = array[32, byte].example
    check AbiEncoder.encode(bytes32) == @bytes32
    let bytes33 = array[33, byte].example
    check AbiEncoder.encode(bytes33) == @bytes33 & 31.zeroes

  test "encodes byte sequences":
    let bytes3 = @[1'u8, 2'u8, 3'u8]
    let bytes3len = AbiEncoder.encode(bytes3.len.uint64)
    check AbiEncoder.encode(bytes3) == bytes3len & bytes3 & 29.zeroes
    let bytes32 = @(array[32, byte].example)
    let bytes32len = AbiEncoder.encode(bytes32.len.uint64)
    check AbiEncoder.encode(bytes32) == bytes32len & bytes32
    let bytes33 = @(array[33, byte].example)
    let bytes33len = AbiEncoder.encode(bytes33.len.uint64)
    check AbiEncoder.encode(bytes33) == bytes33len & bytes33 & 31.zeroes

  test "encodes tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
    check AbiEncoder.encode( (a, b, c, d) ) ==
      AbiEncoder.encode(a) &
      AbiEncoder.encode(4 * 32'u8) & # offset in tuple
      AbiEncoder.encode(c) &
      AbiEncoder.encode(6 * 32'u8) & # offset in tuple
      AbiEncoder.encode(b) &
      AbiEncoder.encode(d)

  test "encodes nested tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
    check AbiEncoder.encode( (a, b, (c, d)) ) ==
      AbiEncoder.encode(a) &
      AbiEncoder.encode(3 * 32'u8) & # offset of b in outer tuple
      AbiEncoder.encode(5 * 32'u8) & # offset of inner tuple in outer tuple
      AbiEncoder.encode(b) &
      AbiEncoder.encode(c) &
      AbiEncoder.encode(2 * 32'u8) & # offset of d in inner tuple
      AbiEncoder.encode(d)

  test "encodes arrays":
    let a, b = seq[byte].example
    check AbiEncoder.encode([a, b]) == AbiEncoder.encode( (a,b) )

  test "encodes sequences":
    let a, b = seq[byte].example
    check AbiEncoder.encode(@[a, b]) ==
      AbiEncoder.encode(2'u64) &
      AbiEncoder.encode( (a, b) )

  test "encodes sequence as dynamic element":
    let s = @[42.u256, 43.u256]
    check AbiEncoder.encode( (s,) ) ==
      AbiEncoder.encode(32'u8) & # offset in tuple
      AbiEncoder.encode(s)

  test "encodes array of static elements as static element":
    let a = [[42'u8], [43'u8]]
    check AbiEncoder.encode( (a,) ) == AbiEncoder.encode(a)

  test "encodes array of dynamic elements as dynamic element":
    let a = [@[42'u8], @[43'u8]]
    check AbiEncoder.encode( (a,) ) ==
      AbiEncoder.encode(32'u8) & # offset in tuple
      AbiEncoder.encode(a)

  test "encodes strings as UTF-8 byte sequence":
    check AbiEncoder.encode("hello!☺") == AbiEncoder.encode("hello!☺".toBytes)

  test "can determine whether types are dynamic or static":
    check static AbiEncoder.isStatic(uint8)
    check static AbiEncoder.isDynamic(seq[byte])
    check static AbiEncoder.isStatic(array[2, array[2, byte]])
    check static AbiEncoder.isDynamic(array[2, seq[byte]])

# https://medium.com/b2expand/abi-encoding-explanation-4f470927092d
# https://docs.soliditylang.org/en/v0.8.1/abi-spec.html#formal-specification-of-the-encoding
