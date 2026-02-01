{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}

module HMM
  ( Env (..),
    Tag (..),
    Parse (..),
    exec,
    Command (..),
    currentVersion,
    defaultConfig,
    Bump (..),
  )
where

import Data.Version (showVersion)
import HMM.Config.Config (Config (..), bumpVersion, updateDeps)
import HMM.Config.ConfigT (HCEnv (..), mapConfig, run)
import HMM.Config.Tag (Tag (Latest))
import HMM.Core.Bump (Bump (..))
import HMM.Core.Env (Env (..), defaultConfig)
import HMM.Format (format)
import HMM.Hie (syncHie)
import HMM.Stack.Package (publishPackages, syncPackages)
import HMM.Stack.StackYaml (syncStackYaml)
import HMM.Utils.Class (Parse (..))
import HMM.Utils.Core (Name)
import qualified Paths_hmm as CLI
import Relude hiding (fix)

data Command
  = Use {tag :: Maybe Tag}
  | Sync
  | Version {bump :: Maybe Bump}
  | UpdateDeps
  | Format {check :: Bool}
  | Publish {groupName :: Maybe Name}
  deriving (Show)

currentVersion :: String
currentVersion = showVersion CLI.version

exec :: Command -> Env -> IO ()
exec Publish {groupName} = run (Just "publish") (publishPackages groupName)
exec Version {bump = Just bump} = run (Just "version") (mapConfig (pure . bumpVersion bump) syncPackages)
exec Use {tag} = run (Just "use") $ syncStackYaml tag
exec UpdateDeps = run (Just "update deps") (mapConfig updateDeps syncPackages)
exec Sync = run (Just "sync") (syncHie *> syncPackages)
exec Version {bump = Nothing} = run Nothing (version <$> asks config)
exec Format {check} = run (Just "format") (format check)
