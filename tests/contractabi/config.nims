switch("path", "..")
when (NimMajor, NimMinor, NimPatch) >= (1, 6, 11):
  switch("warning", "BareExcept:off")
