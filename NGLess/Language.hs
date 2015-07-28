{- Copyright 2013-2015 NGLess Authors
 - License: MIT
 -}
{-# LANGUAGE OverloadedStrings #-}


module Language
    ( Expression(..)
    , Variable(..)
    , UOp(..)
    , BOp(..)
    , Index(..)
    , Block(..)
    , FuncName(..)
    , MethodName(..)
    , NGLType(..)
    , Header(..)
    , ModInfo(..)
    , Script(..)
    , NGLessObject(..)
    , function_opt_arg_type
    , function_required_args
    , function_args_allowed_symbols
    , function_return_type
    , function_arg_type
    , methodSelfType
    , methodArgType
    , methodReturnType
    , methodKwargType
    , typeOfConstant
    ) where

{- This module defines the internal representation the language -}
import qualified Data.Text as T

import Data.FastQ
import Data.Sam

newtype Variable = Variable T.Text
    deriving (Eq, Show)

-- | functions are hard coded here
data FuncName =
                Ffastq
                | Fsamfile
                | Fpaired
                | Funique
                | Fpreprocess
                | Fsubstrim
                | Fmap
                | Fas_reads
                | Fselect
                | Fcount
                | Fwrite
                | Fprint
                | Fannotate
    deriving (Eq)

instance Show FuncName where
    show Ffastq = "fastq"
    show Fsamfile = "samfile"
    show Fpaired = "paired"
    show Funique = "unique"
    show Fpreprocess = "preprocess"
    show Fsubstrim = "substrim"
    show Fmap = "map"
    show Fas_reads = "as_reads"
    show Fselect = "select"
    show Fcount = "count"
    show Fwrite = "write"
    show Fprint = "print"
    show Fannotate = "annotate"

data MethodName =
        Mflag
        | Mscore
    deriving (Eq, Show)

functionArgTypeReturnType :: FuncName -> (NGLType,           NGLType)
functionArgTypeReturnType Ffastq =       (NGLString,         NGLReadSet)
functionArgTypeReturnType Fsamfile =     (NGLString,         NGLMappedReadSet)
functionArgTypeReturnType Fpaired =      (NGLString,         NGLReadSet)
functionArgTypeReturnType Funique =      (NGLReadSet,        NGLReadSet)
functionArgTypeReturnType Fpreprocess =  (NGLReadSet,        NGLVoid)
functionArgTypeReturnType Fsubstrim =    (NGLRead,           NGLRead)
functionArgTypeReturnType Fmap =         (NGLReadSet,        NGLMappedReadSet)
functionArgTypeReturnType Fas_reads =    (NGLMappedReadSet,  NGLReadSet)
functionArgTypeReturnType Fselect =      (NGLMappedReadSet,  NGLMappedReadSet)
functionArgTypeReturnType Fcount =       (NGLMappedReadSet,  NGLCounts)
functionArgTypeReturnType Fannotate =    (NGLMappedReadSet,  NGLMappedReadSet)
functionArgTypeReturnType Fwrite =       (NGLAny,            NGLVoid)
functionArgTypeReturnType Fprint =       (NGLAny,            NGLVoid)

function_arg_type :: FuncName -> NGLType
function_arg_type = fst . functionArgTypeReturnType

function_return_type :: FuncName -> NGLType
function_return_type = snd . functionArgTypeReturnType

function_opt_arg_type :: FuncName -> Variable -> Either T.Text NGLType
function_opt_arg_type Funique     (Variable "max_copies")           = Right NGLInteger
function_opt_arg_type Fmap        (Variable "reference")            = Right NGLString
function_opt_arg_type Fannotate   (Variable "gff")                  = Right NGLString
function_opt_arg_type Fannotate   (Variable "mode")                 = Right NGLSymbol
function_opt_arg_type Fannotate   (Variable "features")             = Right $ NGList NGLSymbol
function_opt_arg_type Fannotate   (Variable "keep_ambiguous")       = Right NGLBool
function_opt_arg_type Fannotate   (Variable "strand")               = Right NGLBool
function_opt_arg_type Fselect     (Variable "keep_if")              = Right (NGList NGLSymbol)
function_opt_arg_type Fselect     (Variable "drop_if")              = Right (NGList NGLSymbol)
function_opt_arg_type Fcount      (Variable "counts")               = Right $ NGList NGLSymbol
function_opt_arg_type Fcount      (Variable "min")                  = Right NGLInteger
function_opt_arg_type Fsubstrim   (Variable "min_quality")          = Right NGLInteger
function_opt_arg_type Fwrite      (Variable "ofile")                = Right NGLString
function_opt_arg_type Fwrite      (Variable "format")               = Right NGLSymbol
function_opt_arg_type Fwrite      (Variable "verbose")              = Right NGLBool
function_opt_arg_type Ffastq      (Variable "encoding")             = Right NGLSymbol
function_opt_arg_type Fpaired     (Variable "second")               = Right NGLString
function_opt_arg_type Fpaired     (Variable "singles")              = Right NGLString
function_opt_arg_type Fpaired      _ = Left "paired function does not have any argument"
function_opt_arg_type Fpreprocess  _ = Left "Preprocess function does not have any argument"
function_opt_arg_type e (Variable x) = Left $ T.concat ["Function " ,T.pack . show $ e ," does not have argument: ", x]

function_required_args :: FuncName -> [T.Text]
function_required_args Fmap         = ["reference"]
function_required_args Fwrite       = ["ofile"]
function_required_args _            = []

function_args_allowed_symbols :: FuncName -> T.Text -> [T.Text]
function_args_allowed_symbols Fannotate "features"   = ["gene", "cds", "exon"]
function_args_allowed_symbols Fannotate "mode"       = ["union", "intersection_strict", "intersection_non_empty"]
function_args_allowed_symbols Fwrite "format"        = ["tsv", "csv", "bam", "sam"]
function_args_allowed_symbols Fcount "counts"        = ["gene", "cds", "exon"]
function_args_allowed_symbols Fselect "keep_if"      = ["mapped", "unmapped"]
function_args_allowed_symbols Fselect "drop_if"      = ["mapped", "unmapped"]
function_args_allowed_symbols Ffastq "encoding"      = ["auto", "33", "64", "sanger", "solexa"]
function_args_allowed_symbols _ _                    = []


methodArgTypeReturnType :: MethodName -> ((NGLType, Maybe NGLType), NGLType)
methodArgTypeReturnType Mflag = ((NGLMappedRead, Just NGLSymbol), NGLBool)
methodArgTypeReturnType Mscore = ((NGLMappedRead, Just NGLSymbol), NGLInteger)

methodSelfType :: MethodName -> NGLType
methodSelfType = fst . fst . methodArgTypeReturnType

methodArgType :: MethodName -> (Maybe NGLType)
methodArgType = snd . fst. methodArgTypeReturnType

methodReturnType :: MethodName -> NGLType
methodReturnType = snd . methodArgTypeReturnType

methodKwargType :: MethodName -> Variable -> NGLType
methodKwargType _ _ = NGLVoid

typeOfConstant :: T.Text -> Maybe NGLType
typeOfConstant "STDIN"        = Just NGLString
typeOfConstant "STDOUT"       = Just NGLString
typeOfConstant _              = Nothing

-- | unary operators
data UOp = UOpLen | UOpMinus | UOpNot
    deriving (Eq, Show)

-- | binary operators
data BOp = BOpAdd | BOpMul | BOpGT | BOpGTE | BOpLT | BOpLTE | BOpEQ | BOpNEQ
    deriving (Eq, Show)

-- | index expression encodes what is inside an index variable
-- either [a] (IndexOne) or [a:b] (IndexTwo)
data Index = IndexOne Expression
            | IndexTwo (Maybe Expression) (Maybe Expression)
    deriving (Eq, Show)

-- | a block is
--  f(a) using |inputvariables|:
--      expression
data Block = Block
                [Variable] -- ^ input arguments
                Expression -- ^ block body, will likely be Sequence
    deriving (Eq, Show)

data NGLType =
        NGLString
        | NGLInteger
        | NGLBool
        | NGLSymbol
        | NGLFilename
        | NGLRead
        | NGLReadSet
        | NGLMappedRead
        | NGLMappedReadSet
        | NGLCounts
        | NGLVoid
        | NGLAny
        | NGList NGLType
    deriving (Eq, Show)

data NGLessObject =
        NGOString T.Text
        | NGOBool Bool
        | NGOInteger Integer
        | NGOSymbol T.Text
        | NGOFilename FilePath
        | NGOShortRead ShortRead
        | NGOReadSet1 FastQEncoding FilePath -- ^ encoding file_on_disk
        | NGOReadSet2 FastQEncoding FilePath FilePath -- ^ encoding file_on_disk
        | NGOReadSet3 FastQEncoding FilePath FilePath FilePath-- ^ encoding file_on_disk
        | NGOMappedReadSet FilePath (Maybe T.Text) -- ^ This is represented by a SAM file on disk + optional reference information
        | NGOMappedRead SamLine
        | NGOAnnotatedSet FilePath
        | NGOVoid
        | NGOList [NGLessObject]
    deriving (Eq, Show, Ord)


-- | 'Expression' is the main type for holding the AST.

data Expression =
        Lookup Variable -- ^ This looks up the variable name
        | ConstStr T.Text -- ^ constant string
        | ConstNum Integer -- ^ integer
        | ConstBool Bool -- ^ true/false
        | ConstSymbol T.Text -- ^ a symbol
        | BuiltinConstant Variable -- ^ built-in constant
        | ListExpression [Expression] -- ^ a list
        | Continue -- ^ continue
        | Discard -- ^ discard
        | UnaryOp UOp Expression  -- ^ op ( expr )
        | BinaryOp BOp Expression Expression -- ^ expr bop expr
        | Condition Expression Expression Expression -- ^ if condition: true-expr else: false-expr
        | IndexExpression Expression Index -- ^ expr [ index ]
        | Assignment Variable Expression -- ^ var = expr
        | FunctionCall FuncName Expression [(Variable, Expression)] (Maybe Block)
        | MethodCall MethodName Expression (Maybe Expression) [(Variable, Expression)] -- ^ expr.method(expre)
        | Sequence [Expression]
    deriving (Eq)

instance Show Expression where
    show (Lookup (Variable v)) = "Lookup '"++T.unpack v++"'"
    show (ConstStr t) = show t
    show (ConstNum n) = show n
    show (ConstBool b) = show b
    show (ConstSymbol t) = "{"++T.unpack t++"}"
    show (BuiltinConstant (Variable v)) = T.unpack v
    show (ListExpression e) = show e
    show Continue = "continue"
    show Discard = "discard"
    show (UnaryOp UOpLen a) = "len("++show a++")"
    show (UnaryOp op a) = show op ++ " " ++ show a
    show (BinaryOp op a b) = show a ++ show op ++ show b
    show (Condition c a b) = "if ["++show c ++"] then {"++show a++"} else {"++show b++"}"
    show (IndexExpression a ix) = show a ++ "[" ++ show ix ++ "]"
    show (Assignment (Variable v) a) = T.unpack v++" = "++show a
    show (FunctionCall fname a args block) = show fname ++ "(" ++ show a ++ showArgs args ++ ")"
                                    ++ (case block of
                                        Nothing -> ""
                                        Just b -> "using {"++show b ++ "}")
    show (MethodCall mname self a args) = "(" ++ show self ++ ")." ++ show mname ++ "( " ++ show a ++ showArgs args ++ " )"
    show (Sequence e) = "Sequence " ++ show e

showArgs [] = ""
showArgs ((Variable v, e):args) = "; "++T.unpack v++"="++show e++showArgs args

data ModInfo = ModInfo
    { modName :: !T.Text
    , modVersion :: !T.Text
    } deriving (Eq, Show)

data Header = Header
    { nglVersion :: T.Text
    , nglModules :: [ModInfo]
    } deriving (Eq, Show)

-- | Script is a version declaration followed by a series of expressions
data Script = Script
    { nglHeader :: Maybe Header -- ^ optional if -e option is used
    , nglBody :: [(Int,Expression)] -- ^ (line number, expression)
    } deriving (Eq,Show)

