import std/random
import std/sequtils
import pkg/stint

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

proc example*(_: type UInt256): UInt256 =
  UInt256.fromBytes(array[32, byte].example)

proc example*(_: type UInt128): UInt128 =
  UInt128.fromBytes(array[16, byte].example)
