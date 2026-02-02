{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE NoImplicitPrelude #-}

module HMM.Config.ConfigT
  ( ConfigT (..),
    HCEnv (..),
    run,
    VersionMap,
    updateConfig,
  )
where

import Control.Exception (tryJust)
import qualified Crypto.Hash.SHA256 as SHA256
import qualified Data.ByteString.Base16 as Base16
import qualified Data.Map as Map
import qualified Data.Set as Set
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import HMM.Config.Build (Builds, allDeps)
import HMM.Config.Config (Config (..), getRule)
import HMM.Config.PkgGroup (PkgGroup, PkgRegistry, pkgDirs, pkgRegistry)
import HMM.Config.Tag (Tag (Latest))
import HMM.Core.Bounds (Bounds)
import HMM.Core.Env (Env (..))
import HMM.Core.HkgRef (VersionMap, Versions, VersionsMap)
import HMM.Core.PkgDir (PkgDirs)
import HMM.Core.Version (Version)
import HMM.Utils.Chalk (Color (Green), chalk)
import HMM.Utils.Class
  ( Check (..),
    Format (format),
    HIO (..),
  )
import HMM.Utils.Core (DependencyName (..), getField, printException)
import HMM.Utils.FromConf (ByKey (..), ReadFromConf (..), readList)
import HMM.Utils.Http (hackage)
import HMM.Utils.Log
  ( alert,
    debug,
    task,
  )
import HMM.Utils.Yaml (readYaml, rewrite_)
import Relude

data HCEnv = HCEnv
  { config :: Config,
    env :: Env,
    indention :: Int,
    versionsMap :: VersionsMap,
    pkgs :: PkgRegistry
  }

newtype ConfigT (a :: Type) = ConfigT {_runConfigT :: ReaderT HCEnv IO a}
  deriving
    ( Functor,
      Applicative,
      Monad,
      MonadReader HCEnv,
      MonadIO,
      MonadFail
    )

getFileHash :: FilePath -> IO (Maybe Text)
getFileHash filePath = do
  content <- T.decodeUtf8 <$> readFileBS filePath
  case T.lines content of
    (firstLine : _) ->
      case T.stripPrefix "# hash: " firstLine of
        Just hash -> pure (Just hash)
        Nothing -> pure Nothing
    [] -> pure Nothing

updateConfig :: (Config -> ConfigT Config) -> ConfigT b -> ConfigT b
updateConfig f m = do
  cfg <- asks config
  updatedCfg <- f cfg
  local (\e -> e {config = updatedCfg}) $ save >> m

prefetchVersions :: ConfigT b -> ConfigT b
prefetchVersions m = do
  debug "Prefetching package versions from Hackage..."
  cfg <- asks config
  let unresolved = toList (Set.fromList $ concatMap allDeps (builds cfg))
  ls <- traverse fetchVersions unresolved
  local (\e -> e {versionsMap = Map.fromList ls}) m

runConfigT :: ConfigT a -> Env -> Config -> IO (Either String a)
runConfigT (ConfigT (ReaderT f)) env config = do
  pkgs <- pkgRegistry (groups config)
  tryJust (Just . printException) (f HCEnv {indention = 0, versionsMap = Map.empty, ..})

indent :: Int -> String -> String
indent i = (replicate (i * 2) ' ' <>)

instance HIO ConfigT where
  read = liftIO . read
  write f = liftIO . write f
  remove = liftIO . remove
  putLine txt = do
    q <- asks (quiet . env)
    unless q $ do
      i <- asks indention
      liftIO $ putLine $ indent i txt
  inside f m = do
    asks indention >>= putLine . f
    local (\c -> c {indention = indention c + 1}) m

fetchVersions :: (HIO m) => DependencyName -> m (DependencyName, Versions)
fetchVersions name = do
  vs <- hackage ["package", format name, "preferred"] >>= getField "normal-version"
  pure (name, vs)

computeConfigHash :: Config -> Text
computeConfigHash cfg =
  let hashInput = T.encodeUtf8 (T.pack (show cfg))
      hashBytes = SHA256.hash hashInput
   in T.decodeUtf8 (Base16.encode hashBytes)

hasHashChanged :: Config -> Maybe Text -> Bool
hasHashChanged _ Nothing = True
hasHashChanged cfg (Just storedHash) = storedHash /= computeConfigHash cfg

run :: (ParseResponse a) => ConfigT a -> Env -> IO ()
run m env@Env {..} = do
  cfg <- readYaml hmm
  storedHash <- getFileHash hmm
  let m' = if not (hasHashChanged cfg storedHash) then m else prefetchVersions (asks config >>= check >> save >> m)
  result <- runConfigT (m' >>= logResponse) env cfg
  case result of
    Left x -> alert ("ERROR: " <> x) >> liftIO exitFailure
    (Right x) -> pure x
  where
    logResponse = putLine . fromMaybe (chalk Green "\nOk") . parseResponse

class ParseResponse a where
  parseResponse :: a -> Maybe String

instance ParseResponse String where
  parseResponse = Just

instance ParseResponse Version where
  parseResponse = Just . toString

instance ParseResponse () where
  parseResponse _ = Nothing

save :: ConfigT ()
save = task "save" $ task "hmm.yaml" $ do
  cfg <- asks config
  ctx <- asks id
  let filePath = hmm $ env ctx
  rewrite_ filePath (const $ pure cfg)
  content <- liftIO $ T.decodeUtf8 <$> readFileBS filePath
  let contentWithHash = "# hash: " <> computeConfigHash cfg <> "\n" <> content
  liftIO $ writeFileBS filePath (T.encodeUtf8 contentWithHash)

instance ReadFromConf ConfigT PkgDirs where
  readFromConf _ = concatMap pkgDirs <$> readList

instance ReadFromConf ConfigT [PkgGroup] where
  readFromConf _ = asks (groups . config)

instance ReadFromConf ConfigT Builds where
  readFromConf = const $ asks (builds . config)

instance ReadFromConf ConfigT Env where
  readFromConf = const $ asks env

instance ReadFromConf ConfigT Version where
  readFromConf = const $ asks (version . config)

instance ReadFromConf ConfigT Tag where
  readFromConf = const $ asks (fromMaybe Latest . currentBuild . config)

instance ReadFromConf ConfigT (ByKey DependencyName Bounds) where
  readFromConf name = do
    ps <- asks pkgs
    ByKey <$> (asks config >>= getRule ps name)

instance ReadFromConf ConfigT VersionsMap where
  readFromConf _ = asks versionsMap
