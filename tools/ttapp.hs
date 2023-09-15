module Main where

import System
import Monad
import Text.ParserCombinators.Parsec

data Token	= Arch String
		| Keyword String
		| Number Integer
		| Label String
		| Atom String
		| Instr String
		| NewLine
		| Space
		deriving(Show, Eq, Ord)

type Tokens	= [Token]

asmLex :: Parser Tokens
asmLex	= many1 asmTok

asmTok :: Parser Token
asmTok	= (isArch <|> isLabel <|> isKeyword <|> isNum <|> isAtom <|> isInstr <|> isComment <|> isSpaces <|> isNewLine)

isSpaces, isComment, isNewLine, isInstr, isAtom, isNum, isLabel, isKeyword, isArch :: Parser Token
isKeyword	= do	char '.'
			x <- (string "align" <|> string "data" <|> string "space")
			return	$ Keyword x

isInstr	= do	{ char '{' ; x <- many1 $ noneOf "}" ; char '}'
		; return $ Instr ("{" ++ x ++ "}")}

isLabel	= try $ do { x <- labelWord ; char ':' ; return $ Label x }
isNum	= liftM (Number . read) $ many1 digit
isAtom	= do { x <- labelWord ; return	$ Atom x }
isArch	= do { try $ string "architecture:" ; x <- labelWord ; return $ Arch x }
isNewLine	= do { many $ oneOf " \t" ; newline ; return NewLine }
isSpaces	= do { many1 $ oneOf " \t" ; return Space }
isComment	=	do { char ';' ; skipMany $ noneOf "\n" ; return Space }
		<|>	do { try $ string "/*" ; findEndComment ; return Space }

findEndComment :: Parser ()	-- Look for end of multi-line comment
findEndComment	= do	{ skipMany $ noneOf "*" ; anyChar
			; do {char '/' ; return ()} <|> findEndComment}

labelRest :: Parser Char
labelRest	= (alphaNum <|> char '_')

labelWord :: Parser String
labelWord	= do	x	<- (letter <|> char '_')
			xs	<- many labelRest
			return	(x:xs)

-- When parsing the assembly file, only instructions causes the line number
-- to increase.
-- TODO: This is ugly. Clean it!!
getKeyword, getNewLine, getInstr, getArch :: Tokens -> Int -> ([String], Int)

asmParse :: Tokens -> ([String], Int)
armParse []	= (["error"], 0)
asmParse t	= getArch t 0

-- Get `architecture:' first.
getArch	(t:ts) x = case t of
			Space	-> getArch ts x
			NewLine	-> getArch ts x
			Arch "vgatta" -> (ns, n)
					where	(s, n)	= getInstr ts x
						a	= "architecture:vgatta\n"
						ns	= ([a] ++ s)
			otherwise -> (["getArch error"], x)

getNewLine (t:ts) x = case t of
			Space	-> getNewLine ts x
			NewLine	-> getInstr ts x
			otherwise -> (["getNewLine error"], x)

getLabel :: Tokens -> Int -> String -> ([String], Int)
getLabel [] x _	= (["getLabel error"], x)
getLabel ts x l	= (ns, n)
			where	(s, n)	= getInstr ts x
--				ll	= (length (s) `mod` 8) ? "\t" : ""
				ns	= (l ++ " " ++ (head s)):(tail s)

getInstr [] x		= ([], x)
getInstr (t:ts) x	= case t of
				Space	-> getInstr ts x
				NewLine	-> getInstr ts x
				Label l	-> getLabel ts x (l++":")
				Keyword _ -> getKeyword (t:ts) x
				Instr i	-> (("\t"++i):s, n)
						where (s, n) = getNewLine ts (x+1)
				otherwise -> (["getInstr error:" ++ (show t)], x)

-- Just skip keywords ATM.
getKeyword (t:ts) x	= case t of
				Keyword "align" -> insertNops ts x n "{,,,}"
					where	n = (16 - (x `mod` 16)) `mod` 16
				Keyword "space" -> insertNops ts x 16 "{,,,}"
				NewLine -> getInstr ts x
				otherwise -> getKeyword ts x

getNumber (t:ts) x	= case t of
				Space     -> getNumber ts x
				Number _  -> getNewLine ts x
				otherwise -> (["getNumber error: "++(show t)], x)

asmPrint :: ([String], Int) -> Int -> IO ()
asmPrint ([], _) _	= return ()
--asmPrint ((x:xs), _) n	= do	putStrLn $ (show n) ++ "\t" ++ x
asmPrint ((x:xs), _) n	= do	putStrLn x
				asmPrint (xs,0) (n+1)

-- Forward recursion needed dumbass!
insertNops ::  Tokens -> Int -> Int -> String -> ([String], Int)
insertNops ts x 0 _	= getNumber ts x
--insertNops ts x n nop	= insertNops ((Instr nop):NewLine:ts) (x+1) (n-1) nop
insertNops ts x n nop	= (ns, nx)
				where	(s, nx)	= insertNops ts (x+1) (n-1) nop
					ns	= (nop:s)


main	= do	args	<- getArgs
		input	<- readFile $ head args
		case (parse asmLex "lexasm" input) of
			Left err	-> do	putStr "Lex error at "
						print	err
-- 			Right val	-> print $ asmParse val
			Right val	-> asmPrint (asmParse val) 0
