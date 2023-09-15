import System
import Monad
import Text.ParserCombinators.Parsec hiding(spaces)
import qualified Text.ParserCombinators.Parsec.Token as P
import Text.ParserCombinators.Parsec.Language (emptyDef)

data Token	= Arch String
		| Atom String
		| Label String
		| Immed Integer
		deriving(Show, Eq, Ord)

type Tokens	= [Token]

-- Lexer
lexer :: P.TokenParser ()
lexer =	P.makeTokenParser
	(emptyDef
		{ P.reservedNames = [	"data",
					"align",
					"space",
					"nop"
				]
		}
	)

lexeme		= P.lexeme lexer
natural		= P.natural lexer
symbol		= P.symbol lexer
reserved	= P.reserved lexer
stringLit	= P.stringLiteral lexer


spaces :: Parser ()
spaces = skipMany1 space

labelChar :: Parser Char
labelChar	= (alphaNum <|> char '_')

labelWord :: Parser String
labelWord	= do	x	<- (letter <|> char '_')
			xs	<- many labelChar
			return	(x:xs)

readExpr :: String -> String
readExpr input = case parse (parseComment >> getArch) "asm" input of
	Left err -> "No match: " ++ show err
	Right val -> "Found value: " ++ show val


parseExpr :: Parser Token
parseExpr	= parseArch
		<|> parseAtom
		<|> parseNum
		<|> parseLabel


-- Scan through input file until the `architecture:' is found.
getArch :: Parser Bool
getArch	= do	string "architecture:"
		x	<- labelWord
		return	$ case x of
				"vgatta"	-> True
				otherwise	-> False
	<|> do	parseComment
		spaces
		x	<- getArch
		return	x


parseString :: Parser Token
parseString = do	char '"'
			x <- many (noneOf "\"")
			char '"'
			return $ Label x

parseLabel :: Parser Token
parseLabel	=	do	x	<- labelWord
				return $ Label x

-- Only single line comments ATM.
parseComment :: Parser ()
parseComment	= do	char ';'
			skipMany $ noneOf "\n"
			newline
			return	()
		<|>	return	()

parseNum :: Parser Token
parseNum = liftM (Immed . read) $ many1 digit

parseArch :: Parser Token
parseArch = do	string "architecture:"
		x <- many labelChar
		return	$ Arch x

parseAtom :: Parser Token
parseAtom = do	first <- letter <|> char '_'
		rest <- many (letter <|> digit <|> char '_')
		let atom = [first] ++ rest
		return $ case atom of 
				"architecture" -> Arch atom
				otherwise -> Atom atom

main :: IO ()
main = do
	args <- getArgs
	--putStrLn (readExpr (args !! 0))
	inStr	<- readFile $ args !! 0 -- "freega.asm"
	putStrLn (readExpr inStr)
