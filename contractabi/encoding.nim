import pkg/stint
import pkg/upraises
import pkg/stew/byteutils
import ./integers
import ./address

export stint
export address

push: {.upraises:[].}

type
  AbiEncoder* = object
    stack: seq[Tuple]
  Tuple = object
    bytes: seq[byte]
    postponed: seq[Split]
    dynamic: bool
  Split = object
    head: Slice[int]
    tail: seq[byte]

func write*[T](encoder: var AbiEncoder, value: T)
func encode*[T](_: type AbiEncoder, value: T): seq[byte]

func init(_: type AbiEncoder): AbiEncoder =
  AbiEncoder(stack: @[Tuple()])

func append(tupl: var Tuple, bytes: openArray[byte]) =
  tupl.bytes.add(bytes)

func postpone(tupl: var Tuple, bytes: seq[byte]) =
  var split: Split
  split.head.a = tupl.bytes.len
  tupl.append(AbiEncoder.encode(0'u64))
  split.head.b = tupl.bytes.high
  split.tail = bytes
  tupl.postponed.add(split)

func finish(tupl: Tuple): seq[byte] =
  var bytes = tupl.bytes
  for split in tupl.postponed:
    let offset = bytes.len
    bytes[split.head] = AbiEncoder.encode(offset.uint64)
    bytes.add(split.tail)
  bytes

func append(encoder: var AbiEncoder, bytes: openArray[byte]) =
  encoder.stack[^1].append(bytes)

func postpone(encoder: var AbiEncoder, bytes: seq[byte]) =
  if encoder.stack.len > 1:
    encoder.stack[^1].postpone(bytes)
  else:
    encoder.stack[0].append(bytes)

func setDynamic(encoder: var AbiEncoder) =
  encoder.stack[^1].dynamic = true

func startTuple*(encoder: var AbiEncoder) =
  encoder.stack.add(Tuple())

func encode(encoder: var AbiEncoder, tupl: Tuple) =
  if tupl.dynamic:
    encoder.postpone(tupl.finish())
    encoder.setDynamic()
  else:
    encoder.append(tupl.finish())

func finishTuple*(encoder: var AbiEncoder) =
  encoder.encode(encoder.stack.pop())

func pad(encoder: var AbiEncoder, len: int, padding=0'u8) =
  let padlen = (32 - len mod 32) mod 32
  for _ in 0..<padlen:
    encoder.append([padding])

func padleft(encoder: var AbiEncoder, bytes: openArray[byte], padding=0'u8) =
  encoder.pad(bytes.len, padding)
  encoder.append(bytes)

func padright(encoder: var AbiEncoder, bytes: openArray[byte], padding=0'u8) =
  encoder.append(bytes)
  encoder.pad(bytes.len, padding)

func encode(encoder: var AbiEncoder, value: SomeUnsignedInt | StUint) =
  encoder.padleft(value.toBytesBE)

func encode(encoder: var AbiEncoder, value: SomeSignedInt | StInt) =
  let bytes = value.unsigned.toBytesBE
  let padding = if value.isNegative: 0xFF'u8 else: 0x00'u8
  encoder.padleft(bytes, padding)

func encode(encoder: var AbiEncoder, value: bool) =
  encoder.encode(if value: 1'u8 else: 0'u8)

func encode(encoder: var AbiEncoder, value: enum) =
  encoder.encode(uint64(ord(value)))

func encode(encoder: var AbiEncoder, value: Address) =
  encoder.padleft(value.toArray)

func encode[I](encoder: var AbiEncoder, bytes: array[I, byte]) =
  encoder.padright(bytes)

func encode(encoder: var AbiEncoder, bytes: seq[byte]) =
  encoder.encode(bytes.len.uint64)
  encoder.padright(bytes)
  encoder.setDynamic()

func encode[I, T](encoder: var AbiEncoder, value: array[I, T]) =
  encoder.startTuple()
  for element in value:
    encoder.write(element)
  encoder.finishTuple()

func encode[T](encoder: var AbiEncoder, value: seq[T]) =
  encoder.encode(value.len.uint64)
  encoder.startTuple()
  for element in value:
    encoder.write(element)
  encoder.finishTuple()
  encoder.setDynamic()

func encode(encoder: var AbiEncoder, value: string) =
  encoder.encode(value.toBytes)

func encode(encoder: var AbiEncoder, tupl: tuple) =
  encoder.startTuple()
  for element in tupl.fields:
    encoder.write(element)
  encoder.finishTuple()

func finish(encoder: var AbiEncoder): Tuple =
  doAssert encoder.stack.len == 1, "not all tuples were finished"
  doAssert encoder.stack[0].bytes.len mod 32 == 0, "encoding invariant broken"
  encoder.stack[0]

func write*[T](encoder: var AbiEncoder, value: T) =
  var writer = AbiEncoder.init()
  writer.encode(value)
  encoder.encode(writer.finish())

func encode*[T](_: type AbiEncoder, value: T): seq[byte] =
  var encoder = AbiEncoder.init()
  encoder.write(value)
  encoder.finish().bytes

proc isDynamic*(_: type AbiEncoder, T: type): bool {.compileTime.} =
  var encoder = AbiEncoder.init()
  encoder.write(T.default)
  encoder.finish().dynamic

proc isStatic*(_: type AbiEncoder, T: type): bool {.compileTime.} =
  not AbiEncoder.isDynamic(T)
