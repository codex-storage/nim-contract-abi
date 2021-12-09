import pkg/stint

template unsigned*(T: type SomeSignedInt): type SomeUnsignedInt =
  when T is int8: uint8
  elif T is int16: uint16
  elif T is int32: uint32
  elif T is int64: uint64
  else: {.error "unsupported signed integer type".}

template unsigned*(T: type StInt): type StUint =
  StUint[T.bits]

func unsigned*(value: SomeSignedInt): SomeUnsignedInt =
  cast[typeof(value).unsigned](value)

func unsigned*[bits](value: StInt[bits]): StUint[bits] =
  value.stuint(bits)
