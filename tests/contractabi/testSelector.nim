import std/unittest
import pkg/contractabi/selector

suite "function selector":

  test "translates nim types into solidity types":
    check solidityType(uint8) == "uint8"
    check solidityType(uint16) == "uint16"
    check solidityType(uint32) == "uint32"
    check solidityType(uint64) == "uint64"
    check solidityType(UInt128) == "uint128"
    check solidityType(UInt256) == "uint256"
    check solidityType(int8) == "int8"
    check solidityType(int16) == "int16"
    check solidityType(int32) == "int32"
    check solidityType(int64) == "int64"
    check solidityType(Int128) == "int128"
    check solidityType(Int256) == "int256"
    check solidityType(bool) == "bool"
    check solidityType(string) == "string"
    check solidityType(Address) == "address"
    check solidityType(array[4, byte]) == "bytes4"
    check solidityType(array[16, byte]) == "bytes16"
    check solidityType(seq[byte]) == "bytes"
    check solidityType(array[4, string]) == "string[4]"
    check solidityType(seq[string]) == "string[]"
    check solidityType((Address, string, bool)) == "(address,string,bool)"

  test "calculates solidity function selector":
    check $selector("transfer", (Address, UInt256)) == "0xa9059cbb"
    check $selector("transferFrom", (Address, Address, UInt256)) == "0x23b872dd"
