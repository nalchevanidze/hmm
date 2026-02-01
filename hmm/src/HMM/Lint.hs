{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}

module HMM.Lint (lintMonorepo) where

import HMM.Core.Env (Env (..))
import Relude
import System.Exit (ExitCode (..))
import System.IO (hPutStrLn)
import System.Process (readProcess, readProcessWithExitCode)
import qualified Prelude

-- | Run hlint across all Haskell source files in the monorepo using hlint executable
lintMonorepo :: Env -> IO ()
lintMonorepo _ = do
  putStrLn "Running hlint on all Haskell source files..."
  hsFilesStr <- readProcess "find" [".", "-name", "*.hs"] ""
  let hsFiles = Prelude.lines hsFilesStr
  if null hsFiles
    then putStrLn "No Haskell source files found."
    else do
      results <- forM hsFiles $ \file -> do
        putStrLn $ "hlint: " ++ file
        (code, out, err) <- readProcessWithExitCode "hlint" [file] ""
        unless (null out) $ putStrLn out
        unless (null err) $ hPutStrLn stderr err
        pure (file, code)
      let failed = [file | (file, ExitFailure _) <- results]
      unless (null failed) $ do
        hPutStrLn stderr $ "hlint failed on files: " ++ show failed
        exitWith (ExitFailure 1)
