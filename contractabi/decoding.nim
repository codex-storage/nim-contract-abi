import pkg/stint
import pkg/stew/endians2
import pkg/upraises
import ./encoding

push: {.upraises:[].}

type
  AbiDecoder* = object
    bytes: seq[byte]
    index: int
    stack: seq[Tuple]
  Tuple = object
    start: int
    finish: int
    dynamic: bool
  Padding = enum
    padLeft,
    padRight
  UInt = SomeUnsignedInt | StUint

func init*(_: type AbiDecoder, bytes: seq[byte], offset=0): AbiDecoder =
  AbiDecoder(bytes: bytes, index: offset, stack: @[Tuple()])

func currentTuple(decoder: var AbiDecoder): var Tuple =
  decoder.stack[^1]

func updateFinish(decoder: var AbiDecoder, index: int) =
  if index > decoder.currentTuple.finish:
    decoder.currentTuple.finish = index

func advance(decoder: var AbiDecoder, amount: int) =
  decoder.index += amount
  decoder.updateFinish(decoder.index)

func read(decoder: var AbiDecoder, amount: int, padding = padLeft): seq[byte] =
  let padlen = (32 - amount mod 32) mod 32
  if padding == padLeft:
    decoder.advance(padlen)
  result = decoder.bytes[decoder.index..<decoder.index+amount]
  decoder.advance(amount)
  if padding == padRight:
    decoder.advance(padlen)

func read*(decoder: var AbiDecoder, T: type UInt): T =
  T.fromBytesBE(decoder.read(sizeof(T)))

func read*(decoder: var AbiDecoder, T: type bool): T =
  decoder.read(uint8) != 0

func read*(decoder: var AbiDecoder, T: type enum): T =
  T(decoder.read(uint64))

func read*[I: static int](decoder: var AbiDecoder, T: type array[I, byte]): T =
  result[0..<I] = decoder.read(I, padRight)

func read*(decoder: var AbiDecoder, T: type seq[byte]): T

func readOffset(decoder: var AbiDecoder): int =
  let offset = decoder.read(uint64)
  decoder.currentTuple.start + offset.int

func readTail(decoder: var AbiDecoder, T: type seq[byte]): T =
  let offset = decoder.readOffset()
  var tailDecoder = AbiDecoder.init(decoder.bytes, offset)
  result = tailDecoder.read(T)
  decoder.updateFinish(tailDecoder.index)

func read*(decoder: var AbiDecoder, T: type seq[byte]): T =
  if decoder.currentTuple.dynamic:
    decoder.readTail(T)
  else:
    let len = decoder.read(uint64).int
    let bytes = decoder.read(len, padRight)
    bytes

func startTuple*(decoder: var AbiDecoder, dynamic: bool) =
  var start: int
  if decoder.currentTuple.dynamic and dynamic:
    start = decoder.readOffset()
  else:
    start = decoder.index
  decoder.stack.add(Tuple(start: start, finish: start, dynamic: dynamic))
  decoder.index = decoder.currentTuple.start

func finishTuple*(decoder: var AbiDecoder) =
  doAssert decoder.stack.len > 1, "unable to finish a tuple that hasn't started"
  let tupl = decoder.stack.pop()
  decoder.updateFinish(tupl.finish)
  decoder.index = tupl.finish

func finish*(decoder: var AbiDecoder) =
  doAssert decoder.stack.len == 1, "not all tuples were finished"
  doAssert decoder.index == decoder.bytes.len, "unread trailing bytes found"
  doAssert decoder.index mod 32 == 0, "encoding variant broken"

func read*[T](decoder: var AbiDecoder, _: type seq[T]): seq[T] =
  let len = decoder.read(uint64)
  decoder.startTuple(dynamic=true)
  for _ in 0..<len:
    result.add(decoder.read(T))
  decoder.finishTuple()

func read*[I,T](decoder: var AbiDecoder, _: type array[I,T]): array[I,T] =
  const dynamic = AbiEncoder.isDynamic(T)
  decoder.startTuple(dynamic)
  for i in 0..<result.len:
    result[i] = decoder.read(T)
  decoder.finishTuple()

func decode*(_: type AbiDecoder, bytes: seq[byte], T: type): T =
  var decoder = AbiDecoder.init(bytes)
  result = decoder.read(T)
  decoder.finish()