{-# LANGUAGE NumericUnderscores #-}
module Main where

import Test.Tasty.Bench ( bench, bgroup, defaultMain, nf, Benchmark)
import Test.Tasty.QuickCheck
import System.Random (randomRIO)

import qualified Sorts.New3WM    as N3
import qualified Sorts.New3WMOpt as N3O
import qualified Sorts.Old       as O

import Control.Monad (replicateM, forM, forM_)
import Control.DeepSeq (NFData (rnf))

import Test.Tasty.Providers (TestTree)
import Data.Ord (comparing)
import Data.IORef
import GHC.IO (unsafePerformIO, evaluate)
import Data.List.NonEmpty (NonEmpty((:|)))

main :: IO ()
main = do
  -- testComparisons
  tData <- mapM benchmark sizes
  defaultMain $ testCorrect : testStable : tData

sorts :: (Show a, Ord a) => (a -> a -> Ordering) -> [[a] -> [a]]
sorts cmp = ($ cmp) <$> [O.sortBy, N3.sortBy, N3O.sortBy]

testCorrect :: TestTree
testCorrect = testProperty "correct" $
  \d -> allEq $ map (\f -> f (d :: [Int])) (sorts compare)

testStable :: TestTree
testStable = testProperty "stable" $
  \d -> allEq $ map (\f -> f $ zip (d :: [Int]) [(0 :: Int)..]) (sorts (comparing fst))

sizes :: [Int]
sizes = [ 10_000, 100_000, 1_000_000 ]

benchmark :: Int -> IO Benchmark
benchmark size = do
  dataN <- randoms size 10
  let name n = concat [n, " - ", show size]
      random    = mk (name "Random") dataN map
      expensive = mk (name "Expensive-Random") dataN (\f -> map (f . map (\x -> replicate 500 0 ++ [x])))
      sorted    = mk (name "Sorted") [1..size] id
      reversed  = mk (name "Reverse-Sorted") (reverse [1..size]) id
  pure $ bgroup "sort" [random, sorted, reversed]

mk :: (Show a, Ord a, NFData b) => String -> c -> (([a] -> [a]) -> c -> b) -> Benchmark
mk name dataN f = bgroup name
  [ bench "original" $ foo O.sort
  , bench "3 way merge" $ foo N3.sort
  , bench "3 way merge optimized" $ foo N3O.sort
  ]
  where foo g = nf (f g) dataN

allEq :: Eq a => [a] -> Bool
allEq [] = True
allEq (x : xs) = all (== x) xs

randoms :: Int -> Int -> IO [[Int]]
randoms n m = replicateM m $ replicateM n $ randomRIO (0, 10_000)
comparisons :: ((Int -> Int -> Ordering) -> [Int] -> [Int]) -> [Int] -> IO Int
comparisons sortBy xs = do
    v <- newIORef 0
    let cmp a b  = unsafePerformIO $ do
            modifyIORef' v succ
            pure $ a `compare` b
    evaluate $ rnf $ sortBy cmp xs
    readIORef v

test :: [[Int]] -> String -> ((Int -> Int -> Ordering) -> [Int] -> [Int]) -> IO ()
test xss l sortBy = do
    x <- sum <$> forM xss (comparisons sortBy)
    putStrLn $ l ++ show (fromIntegral x / fromIntegral (length xss))

testComparisons :: IO ()
testComparisons = do
    forM_ [1..10] $ \n' -> do
           let n = n' * 1000
           putStrLn $ "size " ++ show n
           xss <- randoms n 1024
           test xss "  original        - " O.sortBy
           test xss "  3-way           - " N3.sortBy
           test xss "  3-way optimized - " N3O.sortBy
