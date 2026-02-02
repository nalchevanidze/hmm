{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}

module HMM.Utils.Execute
  ( execute,
    isSuccess,
    Warning (..),
    printWarnings,
    parseWarnings,
    runShell,
  )
where

import Data.Text (pack, unpack)
import qualified Data.Text as T
import GHC.IO.Exception (ExitCode (..))
import HMM.Utils.Class (HIO, Log (..))
import HMM.Utils.Log
  ( field,
    task,
    warn,
  )
import HMM.Utils.Source
  ( isIndentedLine,
    parseLines,
    startsLike,
  )
import Relude
import System.Process (CreateProcess (..), StdStream (..), createProcess, proc, readProcessWithExitCode, waitForProcess)

type Result = Either String

execute :: (MonadIO m) => FilePath -> [String] -> [String] -> m (Result String)
execute name args options = do
  (code, _, out) <- liftIO (readProcessWithExitCode name (args <> map ("--" <>) options) "")
  pure
    $ if isSuccess code
      then Right out
      else Left out

isSuccess :: ExitCode -> Bool
isSuccess ExitSuccess = True
isSuccess ExitFailure {} = False

data Warning = Warning Text [Text]

instance Log Warning where
  log (Warning x ls) = warn (unpack x) >> traverse_ (warn . unpack) ls

printWarnings :: (HIO m) => String -> [Warning] -> m ()
printWarnings cmd [] = field cmd "ok"
printWarnings cmd xs = task cmd $ traverse_ log xs

parseWarnings :: String -> [Warning]
parseWarnings = mapMaybe toWarning . groupTopics . parseLines . pack

toWarning :: [Text] -> Maybe Warning
toWarning (h : lns) | startsLike "warning" h = Just $ Warning h $ takeWhile isIndentedLine lns
toWarning _ = Nothing

groupTopics :: [Text] -> [[Text]]
groupTopics = regroup . break emptyLine
  where
    emptyLine = (== "")
    regroup (h, t)
      | null t = [h]
      | otherwise = h : groupTopics (dropWhile emptyLine t)

-- | Run a shell script command with arguments, inheriting stdio, and fail on nonzero exit code.
runShell :: (MonadIO m, MonadFail m) => Text -> [Text] -> m ()
runShell cmdText scriptArgs = do
  let fullCmd = if null scriptArgs then cmdText else T.unwords (cmdText : scriptArgs)
  liftIO $ putStrLn ("run: " <> T.unpack fullCmd)
  exitCode <- liftIO $ do
    (_, _, _, ph) <- createProcess (proc "/bin/sh" ["-c", T.unpack fullCmd]) {std_out = Inherit, std_err = Inherit, std_in = Inherit}
    waitForProcess ph
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure code -> fail $ "Script failed with exit code: " <> show code
