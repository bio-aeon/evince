module Evince.SrcLoc

import Data.List
import Data.String
import Language.Reflection
import Language.Reflection.TT
import Language.Reflection.TTImp

%language ElabReflection

||| A source file location (file path, line, column). Line and column
||| are 0-indexed (matching Idris 2's FC representation).
public export
record SrcLoc where
  constructor MkSrcLoc
  file : String
  line : Int
  col  : Int

export
Show SrcLoc where
  show loc = loc.file ++ ":" ++ show (loc.line + 1)

originToString : OriginDesc -> String
originToString (PhysicalIdrSrc (MkMI parts)) = concat (intersperse "/" (reverse parts))
originToString (PhysicalPkgSrc fname) = fname
originToString (Virtual _) = "<virtual>"

||| Convert an Idris 2 FC to a SrcLoc.
export
fcToSrcLoc : FC -> SrcLoc
fcToSrcLoc (MkFC origin (l, c) _) = MkSrcLoc (originToString origin) l c
fcToSrcLoc (MkVirtualFC origin (l, c) _) = MkSrcLoc (originToString origin) l c
fcToSrcLoc EmptyFC = MkSrcLoc "<unknown>" 0 0
