module Document
    ( unlines'
    , ReferenceId(..)
    , referenceName
    , allNameReferences
    , CodeProperty(..)
    , CodeBlock(..)
    , ReferenceMap
    , countReferences
    , Content(..)
    , Document(..)
    , isFileReference
    , stitchText
    , listActiveReferences
    ) where

import qualified Data.Text as T
import qualified Data.Map.Strict as M
import Data.Maybe
import Text.Parsec (SourcePos)

unlines' :: [T.Text] -> T.Text
unlines' = T.intercalate (T.pack "\n")

-- ========================================================================= --
-- Document structure                                                        --
-- ========================================================================= --

{-| A code block may reference a filename or a noweb reference.
 -}
data ReferenceId  = FileReferenceId FilePath
                  | NameReferenceId String Int
                  deriving (Show, Eq, Ord)

referenceName :: ReferenceId -> String
referenceName (FileReferenceId x) = x
referenceName (NameReferenceId x _) = x

data CodeProperty
    = CodeId String
    | CodeAttribute String String
    | CodeClass String
    deriving (Eq, Show)

data CodeBlock = CodeBlock
    { codeLanguage   :: String
    , codeProperties :: [CodeProperty]
    , codeSource     :: T.Text
    , sourcePos      :: SourcePos
    } deriving (Show, Eq)

{-| Each 'ReferenceID' connects to a 'CodeBlock'
-}
type ReferenceMap = M.Map ReferenceId CodeBlock

emptyReferenceMap :: ReferenceMap
emptyReferenceMap = M.fromList []

allNameReferences :: String -> ReferenceMap -> [ReferenceId]
allNameReferences name = filter ((== name) . referenceName) . M.keys

countReferences :: String -> ReferenceMap -> Int
countReferences name refs = length $ allNameReferences name refs

{-| Any piece of 'Content' is a 'RawText' or 'Reference'.
-}
data Content
    = RawText T.Text
    | Reference ReferenceId
    deriving (Show, Eq)

{-| A document is a list of 'Text' and a 'ReferenceMap'.
-}
data Document = Document
    { references      :: ReferenceMap
    , documentContent :: [Content]
    } deriving (Show)

contentToText :: ReferenceMap -> Content -> Maybe T.Text
contentToText ref (RawText x) = Just x
contentToText ref (Reference r) 
    | code == T.pack "" = Nothing
    | otherwise         = Just code
    where CodeBlock _ _ code _ = ref M.! r

stitchText :: Document -> T.Text
stitchText (Document refs c) = T.unlines $ mapMaybe (contentToText refs) c

isFileReference :: ReferenceId -> Bool
isFileReference (FileReferenceId _) = True
isFileReference _ = False

listFiles :: Document -> [ReferenceId]
listFiles (Document refs _) = filter isFileReference $ M.keys refs

listActiveReferences :: Document -> [ReferenceId]
listActiveReferences doc = mapMaybe getReference (documentContent doc)
    where getReference (RawText _)   = Nothing
          getReference (Reference r) = Just r
