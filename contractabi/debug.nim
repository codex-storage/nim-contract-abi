import std/sequtils
import pkg/stew/byteutils
import ./encoding

func debugEcho*(_: type AbiEncoder, encoding: seq[byte]) =
  for line in encoding.distribute(encoding.len div 32):
    debugEcho "0x", line.toHex
