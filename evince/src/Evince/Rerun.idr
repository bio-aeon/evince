module Evince.Rerun

import Data.List
import Data.String
import System.File

failureFilePath : String
failureFilePath = ".evince-failures"

joinPath : List String -> String
joinPath = concat . intersperse "."

||| Write failed test paths to the failure file. Deletes the file if
||| there are no failures (clean slate).
export
writeFailures : List (List String) -> IO ()
writeFailures [] = do
  _ <- removeFile failureFilePath
  pure ()
writeFailures paths = do
  let content = unlines (map joinPath paths)
  _ <- writeFile failureFilePath content
  pure ()

||| Read previously failed test paths from the failure file.
export
readFailures : IO (Maybe (List String))
readFailures = do
  Right content <- readFile failureFilePath
    | Left _ => pure Nothing
  let paths = filter (/= "") (lines content)
  pure (if null paths then Nothing else Just paths)
