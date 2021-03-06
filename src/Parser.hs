module Parser (lambdaRead)
where

import Data.Char
import Text.ParserCombinators.Parsec

import LambdaAST

definition :: Parser LambdaTerm
definition = do
  l <- variable
  spaces
  char '='
  spaces
  t <- lambdaTerm
  return $ Definition (var l) t

variable :: Parser LambdaTerm
variable =
  do var <- many1 $ satisfy (\c -> not (isSpace c) && not (elem c "\\λ.()="))
     return $ Variable var

application :: Parser LambdaTerm
application =
  chainl1 lambdaTermNoApp (spaces >> return Application)

lambdaAbstraction :: Parser LambdaTerm
lambdaAbstraction =
  do char 'λ' <|> char '\\'
     x <- variable
     char '.'
     spaces
     term <- lambdaTerm
     return $ Lambda (var x) term

topLevelLambdaTerm :: Parser LambdaTerm
topLevelLambdaTerm =   (try definition)
                   <|> lambdaTerm

lambdaTerm :: Parser LambdaTerm
lambdaTerm =   (try application)
           <|> lambdaTermNoApp

lambdaTermNoApp :: Parser LambdaTerm
lambdaTermNoApp =   (char '(' >> lambdaTerm >>= (\lt -> char ')' >> return lt))
                <|> lambdaAbstraction
                <|> variable

lambdaRead :: String -> Either ParseError LambdaTerm
lambdaRead s = parse (topLevelLambdaTerm >>= (\term -> eof >> return term)) "" $ process $ prepare s

-- Fungsi untuk melakukan arrangement pada string input sebelum diproses menjadi representasi lambda calculus
-- (Terutama untuk operasi perkalian)
prepare :: [Char] -> [Char]
prepare s
    | length s < 3 = s
    | allMultiplication s = modifyToPrefixMultiplication s
    | multiplicationWithCertainCondition s = swapMultiplicationPosition s 0
    | otherwise = s

-- Fungsi untuk memproses setiap karakter pada string ke representasi lambda calculus nya
process :: [Char] -> [Char]
process s = concat $ map (\x -> convert x) s

-- Fungsi untuk memeriksa apakah string tersebut tidak mengandung tanda kurung
isNoParentheses :: [Char] -> Bool
isNoParentheses s
    | doesContainElement '(' s || doesContainElement ')' s = False
    | otherwise = True

-- Fungsi untuk memeriksa apakah string tersebut tidak mengandung operasi perkalian
isNoMultiplication :: [Char] -> Bool
isNoMultiplication s
    | doesContainElement '*' s = False
    | otherwise = True

-- Fungsi untuk memeriksa apakah string tersebut tidak mengandung operasi penjumlahan
isNoAddition :: [Char] -> Bool
isNoAddition s
    | doesContainElement '+' s = False
    | otherwise = True

-- Fungsi untuk memeriksa apakah string hanya merupakan operasi perkalian infix
-- (Tidak ada penjumlahan)
isMultiplyInRightPosition :: [Char] -> Bool
isMultiplyInRightPosition s = checkIndexElement 0
  where
    checkIndexElement idx
        | idx >= length s = True
        | idx `mod` 2 == 0 = isNumber (s !! idx) && checkIndexElement (idx+1)
        | idx `mod` 2 == 1 = s !! idx == '*' && checkIndexElement (idx+1)

-- Fungsi untuk memeriksa apakah sesuatu yang menjadi parameter nanti mengandung element 'c'
doesContainElement :: (Foldable t, Eq a) => a -> t a -> Bool
doesContainElement c = foldr((||) . (c==)) False

-- Fungsi untuk memeriksa apakah string mengandung operasi perkalian yang memenuhi constraint yang sudah dijelaskan di penjelasan.MD
doesSatisfyCondition :: [Char] -> Int -> Bool
doesSatisfyCondition s idx
    | idx >= length s = True
    | (s !! idx == '*') = checkCondition s idx && doesSatisfyCondition s (idx+1) 
    | otherwise = doesSatisfyCondition s (idx+1)

-- Fungsi helper untuk memastikan bahwa tidak ada lebih dari 2 bilangan berturut-turut pada operasi perkalian
checkCondition :: [Char] -> Int -> Bool
checkCondition s idx = checkIfNumber (idx-1) && checkIfNumber (idx+1) && checkIfPlus (idx-2) && checkIfPlus (idx+2)
  where
    checkIfPlus x
        | x >= 0 && x < length s = s !! x == '+'
        | otherwise = True
    checkIfNumber x
        | x >= 0 && x < length s = isNumber (s !! x)
        | otherwise = True

-- Fungsi yang memeriksa apakah string tersebut memenuhi constraint operasi perkalian yang sudah dijelaskan di penjelasan.MD
multiplicationWithCertainCondition :: [Char] -> Bool
multiplicationWithCertainCondition s = isNoParentheses s && doesSatisfyCondition s 0

-- Fungsi yang memeriksa apakah string tersebut hanya terdiri dari operasi perkalian infix
allMultiplication :: [Char] -> Bool
allMultiplication s = isNoParentheses s && isNoAddition s && isMultiplyInRightPosition s

-- Fungsi yang menghasilkan string prefix untuk operasi perkalian yang memenuhi syarat
swapMultiplicationPositionHelper :: [Char] -> Int -> [Char]
swapMultiplicationPositionHelper s idx = take (idx-1) s ++ "(" ++ [s !! idx] ++ [s !! (idx-1)] ++ [s !! (idx+1)] ++ ")" ++ drop (idx+2) s

-- Fungsi yang menghandle string yang memiliki operasi perkalian agar dapat diubah ke bentuk prefix
swapMultiplicationPosition :: [Char] -> Int -> [Char]
swapMultiplicationPosition s idx
    | idx >= length s = s
    | s !! idx == '*' && idx > 0 = swapMultiplicationPosition (swapMultiplicationPositionHelper s idx) (idx+4)
    | otherwise = swapMultiplicationPosition s (idx+1)

-- Fungsi yang mengubah string yang hanya terdiri dari operasi perkalian (tidak ada penjumlahan) ke bentuk prefixnya
modifyToPrefixMultiplication :: [Char] -> [Char]
modifyToPrefixMultiplication s
    | length s > 3 = drop (length s - 2) s ++ "(" ++ modifyToPrefixMultiplication (take (length s - 2) s) ++ ")"
    | length s == 3 = [s !! 1] ++ [s !! 0] ++ [s !! 2]

-- Fungsi yang mengkonversikan sebuah karakter, baik itu berbentuk bilangan, '+' atau '*' ke bentuk lambda calculusnya
convert :: Char -> [Char]
convert x
    | isNumber x = toLambdaExpression (digitToInt x)
    | x == '+' = "(\\w.(\\y.(\\x.(y(w y x)))))"
    | x == '*' = "(\\x.(\\y.(\\z.(x(y z)))))"
    | otherwise = [x]

-- Fungsi yang mengkonversikan bilangan ke representasi lambda calculus nya
toLambdaExpression :: Int -> [Char]
toLambdaExpression n = "(\\s.(\\z." ++ toLambdaExpressionHelper n ++ "))"

-- Fungsi rekursi untuk membantu konversi bilangan ke representasi lambda calculus nya
toLambdaExpressionHelper :: Int -> [Char]
toLambdaExpressionHelper 0 = "z"
toLambdaExpressionHelper 1 = "(s z)"
toLambdaExpressionHelper n = "(s" ++ toLambdaExpressionHelper (n-1) ++ ")"
