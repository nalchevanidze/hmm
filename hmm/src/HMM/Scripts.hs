{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}

module HMM.Scripts
  ( runScript,
  )
where

import qualified Data.Map as M
import HMM.Config.Config (Config (..))
import HMM.Config.ConfigT (ConfigT, HCEnv (..))
import HMM.Utils.Core (Name)
import HMM.Utils.Execute (runShell)
import Relude

runScript :: Name -> [Text] -> ConfigT ()
runScript name args = do
  cfg <- asks config
  case M.lookup name (scripts cfg) of
    Just cmd -> runShell (toText cmd) args
    Nothing -> fail $ "Script not found: " <> toString name
