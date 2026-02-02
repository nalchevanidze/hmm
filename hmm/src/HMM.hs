{-# LANGUAGE NamedFieldPuns #-}
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
import HMM.Config.Config (Config (..), bumpVersion, updateDeps, updateTag)
import HMM.Config.ConfigT (ConfigT, HCEnv (..), ok, updateConfig)
import HMM.Config.Tag (Tag (Latest))
import HMM.Core.Bump (Bump (..))
import HMM.Core.Env (Env (..), defaultConfig)
import HMM.Format (format)
import HMM.Hie (syncHie)
import HMM.Lint (lintMonorepo)
import HMM.Scripts (runScript)
import HMM.Stack.Package (publishPackages, syncPackages)
import HMM.Stack.StackYaml (syncStackYaml)
import HMM.Utils.Class (Parse (..))
import HMM.Utils.Core (Name)
import qualified Paths_haskell_monorepo_manager as CLI
import Relude

data Command
  = Use {tag :: Maybe Tag}
  | Sync
  | Version {bump :: Maybe Bump}
  | UpdateDeps
  | Format {check :: Bool}
  | Lint
  | Publish {groupName :: Maybe Name}
  | Run {scriptName :: Name, scriptArgs :: [Text]}
  deriving (Show)

currentVersion :: String
currentVersion = showVersion CLI.version

exec :: Command -> ConfigT String
exec Publish {groupName} = publishPackages groupName >> ok
exec Version {bump = Just bump} = bumpVersion bump `updateConfig` syncPackages >> ok
exec UpdateDeps = updateDeps `updateConfig` syncPackages >> ok
exec Use {tag} = updateTag tag `updateConfig` syncStackYaml >> ok
exec Sync = syncHie *> syncPackages *> syncStackYaml >> ok
exec Version {bump = Nothing} = toString . version <$> asks config
exec Format {check} = format check >> ok
exec Lint = lintMonorepo >> ok
exec Run {scriptName, scriptArgs} = runScript scriptName scriptArgs >> ok
