{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Main
  ( main,
  )
where

import Data.Text (pack)
import HMM
  ( Bump,
    Command (..),
    Env (..),
    Parse (parse),
    Tag,
    currentVersion,
    defaultConfig,
    exec,
  )
import Options.Applicative
  ( Parser,
    argument,
    command,
    customExecParser,
    fullDesc,
    help,
    helper,
    info,
    long,
    metavar,
    prefs,
    progDesc,
    short,
    showHelpOnError,
    subparser,
    switch,
  )
import Options.Applicative.Builder (str)
import Relude hiding (ByteString, fix)

commands :: [(String, String, Parser a)] -> Parser a
commands =
  subparser
    . mconcat
    . map
      ( \(name, desc, value) ->
          command name (info (helper <*> value) (fullDesc <> progDesc desc))
      )

flag :: Char -> String -> String -> Parser Bool
flag s l h = switch (long l <> short s <> help h)

run :: Parser a -> IO a
run app =
  customExecParser
    (prefs showHelpOnError)
    ( info
        (helper <*> app)
        (fullDesc <> progDesc "HMM CLI - Haskell Monorepo Manager for multi-GHC projects")
    )

class CLIType a where
  cliType :: Parser a

instance CLIType Tag where
  cliType = argument (str >>= parse) (metavar "VERSION" <> help "version tag to use for setup")

instance CLIType Bump where
  cliType = argument (str >>= parse) (metavar "BUMP" <> help "version bump type: major, minor, or patch")

instance CLIType Command where
  cliType =
    commands
      [ ("use", "choose a stack resolver by tag from hmm.yaml and update stack.yaml accordingly", Use <$> optional cliType),
        ("sync", "synchronize package.yaml, hie.yaml, and stack.yaml", pure Sync),
        ("version", "show project version, or bump version with: major|minor|patch", Version <$> optional cliType),
        ("update-deps", "check and update dependency version bounds", pure UpdateDeps),
        ("format", "format Haskell source files using Ormolu (use --check to validate only)", Format <$> switch (long "check" <> short 'c' <> help "check formatting without making changes")),
        ("lint", "run hlint across the monorepo", pure Lint),
        ("publish", "publish packages to Hackage by group", Publish <$> optional (argument (pack <$> str) (metavar "NAME" <> help "name of the package group to publish"))),
        ( "run",
          "run a script from hmm.yaml",
          Run
            <$> argument (pack <$> str) (metavar "SCRIPT" <> help "script name to run")
            <*> many (argument (pack <$> str) (metavar "ARGS" <> help "arguments to pass to the script"))
        )
      ]

data Options = Options
  { optVersion :: Bool,
    optQuiet :: Bool
  }
  deriving (Show)

instance CLIType Options where
  cliType =
    Options
      <$> flag 'v' "version" "show HMM version number"
      <*> flag 'q' "quiet" "run quietly with minimal output"

main :: IO ()
main = do
  (ops, cmd) <- run ((,) <$> cliType <*> optional cliType)
  if optVersion ops
    then putStrLn currentVersion
    else case cmd of
      Just c -> exec c (defaultConfig {quiet = optQuiet ops})
      Nothing -> do
        putStrLn "Missing: COMMAND\n\nUse --help for available commands."
        exitFailure
