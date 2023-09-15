module Main where

import Text.ParserCombinators.Parsec
import qualified Text.ParserCombinators.Parsec.Token as P
import Text.ParserCombinators.Parsec.Language

import System

main = do argv <- getArgs
          x <- readFile (head argv)
          runLex haskellTokens x
--          runLex haskellCounter x -- or use haskellTokens

whiteSpace = P.whiteSpace haskell
lexeme     = P.lexeme     haskell
symbol     = P.symbol     haskell
natural    = P.natural    haskell
parens     = P.parens     haskell
semi       = P.semi       haskell
identifier = P.identifier haskell
reserved   = P.reserved   haskell
reservedOp = P.reservedOp haskell

run :: Show a => Parser a -> String -> IO ()
run p input = case (parse p "" input) of
              Left err -> do putStr "parse error at "
                             print err
              Right x -> print x

runLex :: Show a => Parser a -> String -> IO ()
runLex p input = run (do { whiteSpace
                         ; x <- p
                         ; eof
                         ; return x }) input

haskellTok :: Parser String
haskellTok = ( identifier                   <|> 
               semi                         <|> 
               haskellReserveds             <|>
               haskellReservedOps           <|>
               symbols ["(", ")", "+", "-", "*", "/", ">", 
                        "<", "=", "[", "]", ":", "$", ".",
                        "{", "}", "'", "|", "\"", ",", 
                        "\\\\", "!", "@", "_", "%", "&", 
                        "`", "^", "#"] <|> 
               do { x <- natural ; return (show x) } )

haskellTokens :: Parser [String]
haskellTokens = many1 haskellTok

haskellCounter :: Parser Integer
haskellCounter = counter haskellTok

counter :: Parser a -> Parser Integer
counter p = do p
               whiteSpace
               x <- counter p
               return (x + 1)
            <|> return 0

combine f = (foldl1 (<|>)) . (map f)

symbols :: [String] -> Parser String
symbols = combine symbol

haskellReserveds, haskellReservedOps :: Parser String
haskellReserveds   = do combine reserved   $ reservedNames   haskellDef
                        return "{reserved}"
haskellReservedOps = do combine reservedOp $ reservedOpNames haskellDef
                        return "{reservedOp}"
