-- | Common utilities for import list processing

module Importify.Common
       ( Identifier (..)
       , cnameToIdentifier
       , getImportModuleName
       , getModuleName
       , getSourceModuleName
       , importSpecToIdentifiers
       , importSlice
       , nameToIdentifier
       , parseForImports
       ) where

import           Universum

import qualified Data.List.NonEmpty    as NE

import           Language.Haskell.Exts (CName (..), Extension, ImportDecl (..),
                                        ImportSpec (..), Module (..), ModuleHead (..),
                                        ModuleName, ModuleName (..), Name (..),
                                        NonGreedy (..), ParseResult (..),
                                        PragmasAndModuleName (..), SrcSpan (..),
                                        SrcSpanInfo (..), combSpanInfo, fromParseResult,
                                        parse, parseFileContentsWithExts)

-- | Returns module name for 'ImportDecl' with annotation erased.
getImportModuleName :: ImportDecl l -> ModuleName ()
getImportModuleName ImportDecl{..} = () <$ importModule

-- | Data type that represents function, operator, type or constructor identifier.
newtype Identifier = Identifier { getIdentifier :: String }
    deriving (Show, Eq, Ord)

nameToIdentifier :: Name l -> Identifier
nameToIdentifier (Ident  _ name) = Identifier name
nameToIdentifier (Symbol _ name) = Identifier name

cnameToIdentifier :: CName l -> Identifier
cnameToIdentifier (VarName _ name) = nameToIdentifier name
cnameToIdentifier (ConName _ name) = nameToIdentifier name

importSpecToIdentifiers :: ImportSpec l -> [Identifier]
importSpecToIdentifiers (IVar _ name)              = [nameToIdentifier name]
importSpecToIdentifiers (IAbs _ _ name)            = [nameToIdentifier name]
importSpecToIdentifiers (IThingAll _ name)         = [nameToIdentifier name]
importSpecToIdentifiers (IThingWith _ name cnames) = nameToIdentifier name:map cnameToIdentifier cnames

startAndEndLines :: SrcSpanInfo -> (Int, Int)
startAndEndLines (SrcSpanInfo SrcSpan{..} _) = (srcSpanStartLine, srcSpanEndLine)

-- | Returns pair of line numbers — first and last line of import section
-- if any import is in list.
importSlice :: [ImportDecl SrcSpanInfo] -> Maybe (Int, Int)
importSlice []               = Nothing
importSlice [ImportDecl{..}] = Just $ startAndEndLines importAnn
importSlice (x:y:xs)         = Just $ startAndEndLines
                                    $ combSpanInfo (importAnn x) (importAnn $ NE.last (y :| xs))

-- | Returns module name of the source file.
-- We can't parse the whole file to get it because default extensions are not available yet
-- so this method uses 'NonGreedy' parsing to parse only module head.
getSourceModuleName :: Text -> String
getSourceModuleName src =
    let parseResult :: ParseResult (NonGreedy (PragmasAndModuleName SrcSpanInfo))
        parseResult = parse $ toString src
        NonGreedy (PragmasAndModuleName _ _pragmas maybeModuleName) =
            fromParseResult parseResult
        ModuleName _ modNameStr =
            fromMaybe (error "File doesn't have `module' declaration") maybeModuleName
    in modNameStr

parseForImports :: [Extension] -> Text -> (Module SrcSpanInfo, [ImportDecl SrcSpanInfo])
parseForImports exts fileContent = (ast, imports)
    where ast@(Module _ _ _ imports _) =
              fromParseResult $ parseFileContentsWithExts exts $ toString fileContent

-- | Maybe returns name of module.
getModuleName :: Module l -> Maybe String
getModuleName (Module _ (Just (ModuleHead _ (ModuleName _ name) _ _)) _ _ _) = Just name
getModuleName _                                                              = Nothing
