{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE NoImplicitPrelude #-}

module HMM.Config.Config
  ( Config (..),
    getRule,
    bumpVersion,
    updateDeps,
    updateTag,
  )
where

import Data.Aeson (FromJSON (..), Options (..), ToJSON (toJSON), genericParseJSON, genericToJSON)
import Data.Aeson.Types (defaultOptions)
import HMM.Config.Build (Builds)
import HMM.Config.PkgGroup (PkgGroup, PkgRegistry, isMember)
import HMM.Config.Tag (Tag)
import HMM.Core.Bounds (Bounds, updateDepBounds, versionBounds)
import HMM.Core.Bump (Bump)
import HMM.Core.Dependencies (Dependencies, getBounds, traverseDeps)
import HMM.Core.HkgRef (VersionsMap)
import HMM.Core.Version (Version, nextVersion)
import HMM.Utils.Class (Check (..), HIO)
import HMM.Utils.Core (DependencyName, Name, aesonYAMLOptions)
import HMM.Utils.FromConf (ReadConf)
import Relude

data Config = Config
  { version :: Version,
    bounds :: Bounds,
    groups :: [PkgGroup],
    builds :: Builds,
    dependencies :: Dependencies,
    scripts :: Map Name String,
    currentBuild :: Maybe Tag
  }
  deriving
    ( Generic,
      Show
    )

getRule :: (MonadFail m) => PkgRegistry -> DependencyName -> Config -> m Bounds
getRule ps name Config {..}
  | isMember name ps = pure bounds
  | otherwise = getBounds name dependencies

instance FromJSON Config where
  parseJSON = genericParseJSON aesonYAMLOptions

instance ToJSON Config where
  toJSON = genericToJSON aesonYAMLOptions

instance (ReadConf m '[VersionsMap]) => Check m Config where
  check Config {..} = traverse_ check (toList builds)

bumpVersion :: Bump -> Config -> Config
bumpVersion bump Config {..} =
  let version' = nextVersion bump version
      bounds' = versionBounds version'
   in Config {version = version', bounds = bounds', ..}

updateDeps :: (HIO m, ReadConf m '[VersionsMap]) => Config -> m Config
updateDeps Config {..} = do
  dependencies' <- traverseDeps updateDepBounds dependencies
  pure Config {dependencies = dependencies', ..}

updateTag :: Maybe Tag -> Config -> Config
updateTag tag config = config {currentBuild = tag <|> currentBuild config}