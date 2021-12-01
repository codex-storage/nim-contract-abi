import pkg/stint
import pkg/stew/endians2
import pkg/stew/byteutils
import pkg/upraises
import ./encoding

push: {.upraises:[].}

type
  AbiDecoder* = object
    bytes: seq[byte]
    stack: seq[Tuple]
    last: int
  Tuple = object
    start: int
    index: int
    dynamic: bool
  Padding = enum
    padLeft,
    padRight
  UInt = SomeUnsignedInt | StUint

func init(_: type Tuple, offset: int, dynamic: bool): Tuple =
  Tuple(start: offset, index: offset, dynamic: dynamic)

func init*(_: type AbiDecoder, bytes: seq[byte], offset=0): AbiDecoder =
  AbiDecoder(bytes: bytes, stack: @[Tuple.init(offset, dynamic=false)])

func currentTuple(decoder: var AbiDecoder): var Tuple =
  decoder.stack[^1]

func index(decoder: var AbiDecoder): var int =
  decoder.currentTuple.index

func `index=`(decoder: var AbiDecoder, value: int) =
  decoder.currentTuple.index = value

func updateLast(decoder: var AbiDecoder, index: int) =
  if index > decoder.last:
    decoder.last = index

func advance(decoder: var AbiDecoder, amount: int) =
  decoder.index += amount
  decoder.updateLast(decoder.index)

func read(decoder: var AbiDecoder, amount: int, padding = padLeft): seq[byte] =
  let padlen = (32 - amount mod 32) mod 32
  if padding == padLeft:
    decoder.advance(padlen)
  result = decoder.bytes[decoder.index..<decoder.index+amount]
  decoder.advance(amount)
  if padding == padRight:
    decoder.advance(padlen)

func read*(decoder: var AbiDecoder, T: type): T =
  decoder.decode(T)

func decode*(decoder: var AbiDecoder, T: type UInt): T =
  T.fromBytesBE(decoder.read(sizeof(T)))

func decode*(decoder: var AbiDecoder, T: type bool): T =
  decoder.read(uint8) != 0

func decode*(decoder: var AbiDecoder, T: type enum): T =
  T(decoder.read(uint64))

func decode*[I](decoder: var AbiDecoder, T: type array[I, byte]): T =
  result[0..<result.len] = decoder.read(result.len, padRight)

func readOffset(decoder: var AbiDecoder): int =
  let offset = decoder.read(uint64)
  decoder.currentTuple.start + offset.int

func readTail(decoder: var AbiDecoder, T: type seq[byte]): T =
  let offset = decoder.readOffset()
  var tailDecoder = AbiDecoder.init(decoder.bytes, offset)
  result = tailDecoder.read(T)
  decoder.updateLast(tailDecoder.index)

func decode*(decoder: var AbiDecoder, T: type seq[byte]): T =
  if decoder.currentTuple.dynamic:
    decoder.readTail(T)
  else:
    let len = decoder.read(uint64).int
    decoder.read(len, padRight)

func startTuple*(decoder: var AbiDecoder, dynamic: bool) =
  var start: int
  if decoder.currentTuple.dynamic and dynamic:
    start = decoder.readOffset()
  else:
    start = decoder.index
  decoder.stack.add(Tuple.init(start, dynamic))

func finishTuple*(decoder: var AbiDecoder) =
  doAssert decoder.stack.len > 1, "unable to finish a tuple that hasn't started"
  let tupl = decoder.stack.pop()
  if not tupl.dynamic:
    decoder.index = tupl.index

func finish*(decoder: var AbiDecoder) =
  doAssert decoder.stack.len == 1, "not all tuples were finished"
  doAssert decoder.last == decoder.bytes.len, "unread trailing bytes found"
  doAssert decoder.last mod 32 == 0, "encoding variant broken"

func decode*[T](decoder: var AbiDecoder, _: type seq[T]): seq[T] =
  let len = decoder.read(uint64)
  decoder.startTuple(dynamic=true)
  for _ in 0..<len:
    result.add(decoder.read(T))
  decoder.finishTuple()

func decode*[I,T](decoder: var AbiDecoder, _: type array[I,T]): array[I,T] =
  const dynamic = AbiEncoder.isDynamic(T)
  decoder.startTuple(dynamic)
  for i in 0..<result.len:
    result[i] = decoder.read(T)
  decoder.finishTuple()

func decode*(decoder: var AbiDecoder, T: type string): T =
  string.fromBytes(decoder.read(seq[byte]))

func decode*(_: type AbiDecoder, bytes: seq[byte], T: type): T =
  var decoder = AbiDecoder.init(bytes)
  result = decoder.decode(T)
  decoder.finish()
