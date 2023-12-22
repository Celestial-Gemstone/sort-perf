module Sorts.New3WM (sort) where

sort :: Ord a => [a] -> [a]
sort = sortBy compare

sortBy :: (a -> a -> Ordering) -> [a] -> [a]
sortBy cmp = mergeAll . sequences
  where
    sequences (a:b:xs)
      | a `cmp` b == GT = descending b [a]  xs
      | otherwise       = ascending  b (a:) xs
    sequences xs = [xs]

    descending a as (b:bs)
      | a `cmp` b == GT = descending b (a:as) bs
    descending a as bs  = (a:as): sequences bs

    ascending a as (b:bs)
      | a `cmp` b /= GT = ascending b (\ys -> as (a:ys)) bs
    ascending a as bs   = let !x = as [a]
                          in x : sequences bs

    mergeAll [x] = x
    mergeAll xs  = mergeAll (mergePairs xs)

    rec xs !x = x : mergePairs xs

    mergePairs (a:b:c:xs)     = rec xs $ merge' a b c
    mergePairs (a:b:xs)       = rec xs $ merge a b
    mergePairs xs             = xs

    x `gt` y = x `cmp` y == GT

    merge as@(a:as') bs@(b:bs')
      | a `gt` b  = b : merge as  bs'
      | otherwise = a : merge as' bs
    merge [] bs   = bs
    merge as []   = as

    merge' as@(a:as') bs@(b:bs') cs@(c:cs')
      | a_gt_b, b_gt_c = c : merge' as bs cs'
      | a_gt_b         = b : merge' as bs' cs
      | a_gt_c         = c : merge' as bs cs'
      | otherwise      = a : merge' as' bs cs
      where a_gt_b = a `gt` b
            b_gt_c = b `gt` c
            a_gt_c = a `gt` c
    merge' [] bs cs = merge bs cs
    merge' as [] cs = merge as cs
    merge' as bs [] = merge as bs
