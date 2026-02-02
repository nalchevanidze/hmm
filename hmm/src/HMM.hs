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
import HMM.Config.Config (Config (..), bumpVersion, updateDeps, updateTag)
import HMM.Config.ConfigT (HCEnv (..), mapConfig, run)
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
import Relude hiding (fix)

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

exec :: Command -> Env -> IO ()
exec Publish {groupName} = run (Just "publish") (publishPackages groupName)
exec Version {bump = Just bump} = run (Just "version") ((pure . bumpVersion bump) `mapConfig` syncPackages)
exec Use {tag} = run (Just "use") $ ((pure . updateTag tag) `mapConfig` syncStackYaml)
exec UpdateDeps = run (Just "update deps") (updateDeps `mapConfig` syncPackages)
exec Sync = run (Just "sync") (syncHie *> syncPackages *> syncStackYaml)
exec Version {bump = Nothing} = run Nothing (version <$> asks config)
exec Format {check} = run (Just "format") (format check)
exec Lint = lintMonorepo
exec Run {scriptName, scriptArgs} = run Nothing (runScript scriptName scriptArgs)
