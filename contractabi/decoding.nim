import pkg/stint
import pkg/stew/endians2
import pkg/stew/byteutils
import pkg/questionable/results
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

func read*(decoder: var AbiDecoder, T: type): ?!T

func init(_: type Tuple, offset: int, dynamic: bool): Tuple =
  Tuple(start: offset, index: offset, dynamic: dynamic)

func init(_: type AbiDecoder, bytes: seq[byte], offset=0): AbiDecoder =
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

func advance(decoder: var AbiDecoder, amount: int): ?!void =
  decoder.index += amount
  decoder.updateLast(decoder.index)
  success()

func read(decoder: var AbiDecoder, amount: int, padding=padLeft): ?!seq[byte] =
  let padlen = (32 - amount mod 32) mod 32
  if padding == padLeft:
    ?decoder.advance(padlen)
  let index = decoder.index
  ?decoder.advance(amount)
  result = success decoder.bytes[index..<index+amount]
  if padding == padRight:
    ?decoder.advance(padlen)

func decode(decoder: var AbiDecoder, T: type UInt): ?!T =
  success T.fromBytesBE(?decoder.read(sizeof(T)))

func decode(decoder: var AbiDecoder, T: type bool): ?!T =
  success (?decoder.read(uint8) != 0)

func decode(decoder: var AbiDecoder, T: type enum): ?!T =
  success T(?decoder.read(uint64))

func decode[I](decoder: var AbiDecoder, T: type array[I, byte]): ?!T =
  var arr: T
  arr[0..<arr.len] = ?decoder.read(arr.len, padRight)
  success arr

func readOffset(decoder: var AbiDecoder): ?!int =
  let offset = ?decoder.read(uint64)
  success decoder.currentTuple.start + offset.int

func readTail(decoder: var AbiDecoder): ?!seq[byte] =
  let offset = ?decoder.readOffset()
  var tailDecoder = AbiDecoder.init(decoder.bytes, offset)
  result = tailDecoder.read(seq[byte])
  decoder.updateLast(tailDecoder.index)

func decode(decoder: var AbiDecoder, T: type seq[byte]): ?!T =
  if decoder.currentTuple.dynamic:
    decoder.readTail()
  else:
    let len = ?decoder.read(uint64)
    decoder.read(len.int, padRight)

func startTuple(decoder: var AbiDecoder, dynamic: bool): ?!void =
  var start: int
  if decoder.currentTuple.dynamic and dynamic:
    start = ?decoder.readOffset()
  else:
    start = decoder.index
  decoder.stack.add(Tuple.init(start, dynamic))
  success()

func finishTuple(decoder: var AbiDecoder) =
  doAssert decoder.stack.len > 1, "unable to finish a tuple that hasn't started"
  let tupl = decoder.stack.pop()
  if not tupl.dynamic:
    decoder.index = tupl.index

func decode[T: tuple](decoder: var AbiDecoder, _: typedesc[T]): ?!T =
  const dynamic = AbiEncoder.isDynamic(T)
  var tupl: T
  ?decoder.startTuple(dynamic)
  for element in tupl.fields:
    element = ?decoder.read(typeof(element))
  decoder.finishTuple()
  success tupl

func read*(decoder: var AbiDecoder, T: type): ?!T =
  decoder.decode(T)

func finish(decoder: var AbiDecoder) =
  doAssert decoder.stack.len == 1, "not all tuples were finished"
  doAssert decoder.last == decoder.bytes.len, "unread trailing bytes found"
  doAssert decoder.last mod 32 == 0, "encoding variant broken"

func decode[T](decoder: var AbiDecoder, _: type seq[T]): ?!seq[T] =
  var sequence: seq[T]
  let len = ?decoder.read(uint64)
  ?decoder.startTuple(dynamic=true)
  for _ in 0..<len:
    sequence.add(?decoder.read(T))
  decoder.finishTuple()
  success sequence

func decode[I,T](decoder: var AbiDecoder, _: type array[I,T]): ?!array[I,T] =
  var arr: array[I, T]
  const dynamic = AbiEncoder.isDynamic(T)
  ?decoder.startTuple(dynamic)
  for i in 0..<arr.len:
    arr[i] = ?decoder.read(T)
  decoder.finishTuple()
  success arr

func decode(decoder: var AbiDecoder, T: type string): ?!T =
  success string.fromBytes(?decoder.read(seq[byte]))

func decode*(_: type AbiDecoder, bytes: seq[byte], T: type): ?!T =
  var decoder = AbiDecoder.init(bytes)
  var value = ?decoder.decode(T)
  decoder.finish()
  success value
