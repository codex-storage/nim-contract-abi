import std/random
import std/sequtils
import pkg/stint
import pkg/contractabi/address

randomize()

proc example*(_: type bool): bool =
  rand(0'u8..1'u8) == 1

proc example*[T: SomeInteger](_: type T): T =
  rand(T)

proc example*[I: static int, T](_: type array[I, T]): array[I, T] =
  for i in 0..<I:
    result[i] = T.example

proc example*[T](_: type seq[T], len = 0..5): seq[T] =
  let chosenlen = rand(len)
  newSeqWith(chosenlen, T.example)

proc example*(T: type StUint): T =
  T.fromBytes(array[sizeof(T), byte].example)

proc example*(T: type StInt): T =
  cast[T](StUint[T.bits].example)

proc example*(T: type Address): T =
  Address.init(array[20, byte].example)
