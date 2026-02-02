{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}

module HMM.Lint (lintMonorepo) where

import HMM.Config.ConfigT (ConfigT)
import HMM.Utils.Log (task)
import Relude
import System.Exit (ExitCode (..))
import System.IO (hPutStrLn)
import System.Process (readProcess, readProcessWithExitCode)
import qualified Prelude

lintMonorepo :: ConfigT ()
lintMonorepo = task "Lint Haskell source files..." $ liftIO $ do
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
