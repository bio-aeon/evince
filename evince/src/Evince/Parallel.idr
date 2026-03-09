module Evince.Parallel

import System.Concurrency

%foreign "scheme:blodwen-thread"
prim__fork : PrimIO () -> PrimIO ()

%foreign "scheme:(lambda (ty act fb) (guard (x [#t (fb (vector 0))]) (act (vector 0))))"
prim__tryIO : PrimIO a -> PrimIO a -> PrimIO a

||| Fork an IO action into a new thread (Chez Scheme only).
export
forkIO : IO () -> IO ()
forkIO act = primIO $ prim__fork (toPrim act)

||| Run an IO action; if it throws a Scheme exception, run the fallback.
export
tryIO : IO a -> IO a -> IO a
tryIO act fallback = primIO $ prim__tryIO (toPrim act) (toPrim fallback)
