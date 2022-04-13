import pkg/stint
import pkg/stew/endians2
import pkg/stew/byteutils
import pkg/questionable/results
import pkg/upraises
import ./encoding
import ./integers
import ./address

export stint
export address

push: {.upraises:[].}

type
  AbiDecoder* = object
    bytes: seq[byte]
    stack: seq[Tuple]
    last: int
  Tuple = object
    start: int
    index: int
  Padding = enum
    padLeft,
    padRight
  UInt = SomeUnsignedInt | StUint
  Int = SomeSignedInt | StInt

func read*(decoder: var AbiDecoder, T: type): ?!T

func init(_: type Tuple, offset: int): Tuple =
  Tuple(start: offset, index: offset)

func init(_: type AbiDecoder, bytes: seq[byte], offset=0): AbiDecoder =
  AbiDecoder(bytes: bytes, stack: @[Tuple.init(offset)])

func currentTuple(decoder: var AbiDecoder): var Tuple =
  decoder.stack[^1]

func index(decoder: var AbiDecoder): var int =
  decoder.currentTuple.index

func `index=`(decoder: var AbiDecoder, value: int) =
  decoder.currentTuple.index = value

func startTuple*(decoder: var AbiDecoder) =
  decoder.stack.add(Tuple.init(decoder.index))

func finishTuple*(decoder: var AbiDecoder) =
  doAssert decoder.stack.len > 1, "unable to finish a tuple that hasn't started"
  let tupl = decoder.stack.pop()
  decoder.index = tupl.index

func updateLast(decoder: var AbiDecoder, index: int) =
  if index > decoder.last:
    decoder.last = index

func advance(decoder: var AbiDecoder, amount: int): ?!void =
  decoder.index += amount
  decoder.updateLast(decoder.index)
  if decoder.index <= decoder.bytes.len:
    success()
  else:
    failure "reading past end"

func skipPadding(decoder: var AbiDecoder, amount: int): ?!void =
  let index = decoder.index
  ?decoder.advance(amount)
  for i in index..<index+amount:
    if decoder.bytes[i] notin [0x00'u8, 0xFF'u8]:
      return failure "invalid padding found"
  success()

func read(decoder: var AbiDecoder, amount: int, padding=padLeft): ?!seq[byte] =
  let padlen = (32 - amount mod 32) mod 32
  if padding == padLeft:
    ?decoder.skipPadding(padlen)
  let index = decoder.index
  ?decoder.advance(amount)
  result = success decoder.bytes[index..<index+amount]
  if padding == padRight:
    ?decoder.skipPadding(padlen)

func decode(decoder: var AbiDecoder, T: type UInt): ?!T =
  success T.fromBytesBE(?decoder.read(sizeof(T)))

func decode(decoder: var AbiDecoder, T: type Int): ?!T =
  let unsigned = ?decoder.read(T.unsigned)
  success cast[T](unsigned)

template basetype(Range: type range): untyped =
  when Range isnot SomeUnsignedInt: {.error: "only uint ranges supported".}
  elif sizeof(Range) == sizeof(uint8): uint8
  elif sizeof(Range) == sizeof(uint16): uint16
  elif sizeof(Range) == sizeof(uint32): uint32
  elif sizeof(Range) == sizeof(uint64): uint64
  else: {.error "unsupported range type".}

func decode(decoder: var AbiDecoder, T: type range): ?!T =
  let bytes = ?decoder.read(sizeof(T))
  let value = basetype(T).fromBytesBE(bytes)
  if value in T.low..T.high:
    success T(value)
  else:
    failure "value not in range"

func decode(decoder: var AbiDecoder, T: type bool): ?!T =
  case ?decoder.read(uint8)
    of 0: success false
    of 1: success true
    else: failure "invalid boolean value"

func decode(decoder: var AbiDecoder, T: type enum): ?!T =
  let value = ?decoder.read(uint64)
  if value in T.low.uint64..T.high.uint64:
    success T(value)
  else:
    failure "invalid enum value"

func decode(decoder: var AbiDecoder, T: type Address): ?!T =
  var bytes: array[20, byte]
  bytes[0..<20] =(?decoder.read(20))[0..<20]
  success T.init(bytes)

func decode[I](decoder: var AbiDecoder, T: type array[I, byte]): ?!T =
  var arr: T
  arr[0..<arr.len] = ?decoder.read(arr.len, padRight)
  success arr

func decode(decoder: var AbiDecoder, T: type seq[byte]): ?!T =
  let len = ?decoder.read(uint64)
  decoder.read(len.int, padRight)

func decode[T: tuple](decoder: var AbiDecoder, _: typedesc[T]): ?!T =
  var tupl: T
  decoder.startTuple()
  for element in tupl.fields:
    element = ?decoder.read(typeof(element))
  decoder.finishTuple()
  success tupl

func decode[T](decoder: var AbiDecoder, _: type seq[T]): ?!seq[T] =
  var sequence: seq[T]
  let len = ?decoder.read(uint64)
  decoder.startTuple()
  for _ in 0..<len:
    sequence.add(?decoder.read(T))
  decoder.finishTuple()
  success sequence

func decode[I,T](decoder: var AbiDecoder, _: type array[I,T]): ?!array[I,T] =
  var arr: array[I, T]
  decoder.startTuple()
  for i in 0..<arr.len:
    arr[i] = ?decoder.read(T)
  decoder.finishTuple()
  success arr

func decode(decoder: var AbiDecoder, T: type string): ?!T =
  success string.fromBytes(?decoder.read(seq[byte]))

func readOffset(decoder: var AbiDecoder): ?!int =
  let offset = ?decoder.read(uint64)
  success decoder.currentTuple.start + offset.int

func readTail*(decoder: var AbiDecoder, T: type): ?!T =
  let offset = ?decoder.readOffset()
  var tailDecoder = AbiDecoder.init(decoder.bytes, offset.int)
  result = tailDecoder.read(T)
  decoder.updateLast(tailDecoder.last)

func read*(decoder: var AbiDecoder, T: type): ?!T =
  const dynamic = AbiEncoder.isDynamic(typeof(!result))
  if dynamic and decoder.stack.len > 1:
    decoder.readTail(T)
  else:
    decoder.decode(T)

func finish(decoder: var AbiDecoder): ?!void =
  doAssert decoder.stack.len == 1, "not all tuples were finished"
  doAssert decoder.last mod 32 == 0, "encoding invariant broken"
  if decoder.last != decoder.bytes.len:
    failure "unread trailing bytes found"
  else:
    success()

func decode*(_: type AbiDecoder, bytes: seq[byte], T: type): ?!T =
  var decoder = AbiDecoder.init(bytes)
  var value = ?decoder.decode(T)
  ?decoder.finish()
  success value
