import std/strutils
import pkg/nimcrypto
import pkg/stint
import pkg/stew/byteutils
import ./address

export address
export stint

type FunctionSelector* = distinct array[4, byte]

proc toArray*(selector: FunctionSelector): array[4, byte] =
  array[4, byte](selector)

proc `$`*(selector: FunctionSelector): string =
  "0x" & selector.toArray.toHex

template solidityType(T: type, s: string) =
  func solidityType*(_: type T): string = s

solidityType uint8,   "uint8"
solidityType uint16,  "uint16"
solidityType uint32,  "uint32"
solidityType uint64,  "uint64"
solidityType UInt128, "uint128"
solidityType UInt256, "uint256"
solidityType int8,    "int8"
solidityType int16,   "int16"
solidityType int32,   "int32"
solidityType int64,   "int64"
solidityType Int128,  "int128"
solidityType Int256,  "int256"
solidityType bool,    "bool"
solidityType string,  "string"
solidityType Address, "address"

func solidityType*[N: static int](_: type array[N, byte]): string =
  "bytes" & $N

func solidityType*(_: type seq[byte]): string =
  "bytes"

func solidityType*[T, N](_: type array[N, T]): string =
  solidityType(T) & "[" & $array[N, T].default.len & "]"

func solidityType*[T](_: type seq[T]): string =
  solidityType(T) & "[]"

func solidityType*(Tuple: type tuple): string =
  var names: seq[string]
  for parameter in Tuple.default.fields:
    names.add(solidityType(typeof parameter))
  "(" & names.join(",") & ")"

func signature*(function: string, Parameters: type tuple = ()): string =
  function & solidityType(Parameters)

func hash(s: string): array[32, byte] =
  keccak256.digest(s.toBytes).data

func selector*(function: string, parameters: type tuple): FunctionSelector =
  let signature = signature(function, parameters)
  let hash = hash(signature)
  var selector: array[4, byte]
  selector[0..<4] = hash[0..<4]
  FunctionSelector(selector)
