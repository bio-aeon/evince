module Evince.Async.Hoist

import Data.SnocList
import Evince.Core

mutual
  hoistTree : ({0 x : Type} -> f x -> g x) -> SpecTree f a -> SpecTree g a
  hoistTree nt (Describe label children) = Describe label (hoistTrees nt children)
  hoistTree nt (It label loc test) = It label loc (\res => nt (test res))
  hoistTree nt (Pending label reason) = Pending label reason
  hoistTree nt (Focused t) = Focused (hoistTree nt t)
  hoistTree nt (WithCleanup cleanup children) = WithCleanup (nt cleanup) (hoistTrees nt children)

  hoistTrees : ({0 x : Type} -> f x -> g x) -> List (SpecTree f a) -> List (SpecTree g a)
  hoistTrees nt [] = []
  hoistTrees nt (t :: ts) = hoistTree nt t :: hoistTrees nt ts

||| Re-target a spec from one effect monad to another, mapping every test
||| action and cleanup through the given natural transformation. Lets a spec
||| written as `Spec IO` run under the async driver via `liftIO`.
export
hoistSpec : ({0 x : Type} -> f x -> g x) -> Spec f a b -> Spec g a b
hoistSpec nt (MkSpec trees x) = MkSpec (map (hoistTree nt) trees) x
