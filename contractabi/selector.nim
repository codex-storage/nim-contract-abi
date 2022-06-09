import std/strutils
import pkg/nimcrypto
import pkg/stint
import pkg/stew/byteutils
import ./address

export address
export stint

type FunctionSelector* = distinct array[4, byte]
type EventTopic* = distinct array[32, byte]

proc toArray*(selector: FunctionSelector): array[4, byte] =
  array[4, byte](selector)

proc toArray*(topic: EventTopic): array[32, byte] =
  array[32, byte](topic)

proc `$`*(value: FunctionSelector | EventTopic): string =
  "0x" & value.toArray.toHex

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
solidityType enum,    "uint8"

func solidityType*[N: static int, T](_: type array[N, T]): string =
  when T is byte:
    when 0 < N and N <= 32:
      "bytes" & $N
    else:
      "bytes1[" & $N & "]"
  else:
    solidityType(T) & "[" & $N & "]"

func solidityType*[T](_: type seq[T]): string =
  when T is byte:
    "bytes"
  else:
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

func topic*(event: string, parameters: type tuple): EventTopic =
  EventTopic(hash(signature(event, parameters)))
