module Evince.Random

import Data.Vect
import Data.List

%default total

-- Minimal LCG (Numerical Recipes constants)
lcg : Nat -> Nat
lcg s = cast {to = Nat} $ (cast {to = Integer} s * 1664525 + 1013904223) `mod` 4294967296

-- Fisher-Yates shuffle on a Vect, driven by LCG.
shuffleVect : {n : Nat} -> Nat -> Vect n a -> Vect n a
shuffleVect {n = 0}     _    xs = xs
shuffleVect {n = 1}     _    xs = xs
shuffleVect {n = S k}   seed xs =
  let idx = seed `mod` (S k)
      i   = restrict k (cast idx)
      xs' = swapFin FZ i xs
      seed' = lcg seed
  in head xs' :: shuffleVect seed' (tail xs')
  where
    swapFin : Fin (S k) -> Fin (S k) -> Vect (S k) a -> Vect (S k) a
    swapFin i j v =
      let vi = index i v
          vj = index j v
      in replaceAt i vj (replaceAt j vi v)

||| Shuffle a list using a seed value.
export
shuffle : Nat -> List a -> List a
shuffle seed xs =
  let v = fromList xs
  in toList (shuffleVect seed v)
