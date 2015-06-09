-- |
-- Module      : HMB.Internal.Index
-- Copyright   : (c) Marc Juchli, Lorenz Wolf 2015
-- License     : BSD-style
--
-- Maintainer  :
-- Stability   : WIP
-- Portability : GHC
--
-- This module encapsulates Index functionality.

module HMB.Internal.Index
  ( new
  , append
  , isInterval
  , find
  , lastOrNull
  , lookup
  , IndexState(..)
  ) where

import Kafka.Protocol
import qualified HMB.Internal.LogConfig as L

import Prelude hiding (lookup)
import Data.Word
import Data.List hiding (find, lookup)
import qualified Data.Map.Lazy as Map
import Data.Maybe
import Data.Int
import Data.Binary.Get
import qualified Data.ByteString.Lazy as BL

import Text.Printf
import Control.Concurrent.MVar
import System.IO

import System.IO.MMap

type OffsetPosition = (RelativeOffset, FileOffset)
type RelativeOffset = Word32
type FileOffset = Word32
type BaseOffset = Int

type Indices = Map.Map (L.TopicStr, L.PartitionNr) [OffsetPosition]
newtype IndexState = IndexState (MVar Indices)

-- | Creates a new and empty IndexState. The index is represented as a Map
-- whereas the key is a tuple of topic and partition.
new :: IO IndexState
new = do
  m <- newMVar Map.empty
  return (IndexState m)

-- | Appends an OffsetPosition to memory and eventually writes to disk. The
-- index will be kept in memory as long as the broker is running.
append :: Indices -> (L.TopicStr, L.PartitionNr) -> Log -> Int64 -> IO Indices
append indices (t, p) ms logSize = do
  let old = find (t, p) indices
  let bo = 0 -- PERFORMANCE
  let path = L.getPath (L.logFolder t p) (L.indexFile bo)
  fs <- getFileSize path
  let new = pack (fromIntegral (msOffset (last ms)) - bo, fs + (fromIntegral logSize)) -- filesize needs size of encoded ms too
  let newIndex = old ++ [new]
  return $ Map.insert (t, p) newIndex indices
  -- TODO: write to disk

-- | Find a list of OffsetPosition within the map of Indices. If nothing is
-- found, return an empty List
-- TODO: make generic
find :: (L.TopicStr, L.PartitionNr) -> Indices -> [OffsetPosition]
find (t, p) indices = fromMaybe [] (Map.lookup (t, p) indices)

-- | The byte interval at which we add an entry to the offset index. When
-- executing a fetch request the server must do a linear scan for up to this
-- many bytes to find the correct position in the log to begin and end the
-- fetch. So setting this value to be larger will mean larger index files (and a
-- bit more memory usage) but less scanning. However the server will never add
-- more than one index entry per log append (even if more than
-- log.index.interval worth of messages are appended).
isInterval :: Int64 -> Bool
isInterval s = 4096 < s

getFileSize :: String -> IO Integer
getFileSize path = withFile path ReadMode (\hdl -> hFileSize hdl)

pack :: (Int, Integer) -> OffsetPosition
pack (o, fs) = (fromIntegral o, fromIntegral fs)

lastOrNull :: [OffsetPosition] -> OffsetPosition
lastOrNull [] = (0,0)
lastOrNull xs = last xs

--buildOffsetPosition :: OffsetPosition -> Put
--buildOffsetPosition (o, p) = do
--    putWord32be o
--    putWord32be p
--
--encodeIndex = runPutOrFail buildOffsetPosition
--
--
--getLastOffsetPosition' :: BL.ByteString -> OffsetPosition
--getLastOffsetPosition' bs =
--  case decode bs of
--    Left (bs, bo, e) -> (0,0)
--    Right (bs, bo, ops) -> lastIndex ops

lookup :: (L.TopicStr, Int) -> BaseOffset -> Offset -> IO OffsetPosition
---locate the offset/location pair for the greatest offset less than or equal
-- to the target offset.
lookup (t, p) bo to = do
  let path = L.getPath (L.logFolder t p) (L.indexFile bo)
  bs <- mmapFileByteStringLazy path Nothing
  case decode bs of
    Left (bs, byo, e)   -> do
        print e
        return $ (0,0) --todo: error handling
    Right (bs, byo, ops) -> do
      --print ops
      return $ getOffsetPositionFor ops bo to

-- decode as long as physical position != 0 which means last index has passed
decodeEntry :: Get [OffsetPosition]
decodeEntry = do
  empty <- isEmpty
  if empty
    then return []
    else do rel  <- getWord32be
            phys <- getWord32be
            case phys of
              0 -> return $ (rel, phys)  : []
              _ -> do
                    e <- decodeEntry
                    return $ (rel, phys) : e

decode :: BL.ByteString -> Either (BL.ByteString, ByteOffset, String) (BL.ByteString, ByteOffset, [OffsetPosition])
decode = runGetOrFail decodeEntry


getOffsetPositionFor :: [OffsetPosition] -> BaseOffset -> Offset -> OffsetPosition
-- get greatest offsetPosition from list that is less than or equal target offset
getOffsetPositionFor [] bo to = (0, 0)
getOffsetPositionFor [x] bo to = x
getOffsetPositionFor (x:xs) bo to
       | targetOffset <= absoluteIndexOffset = (0,0)
       | absoluteIndexOffset <= targetOffset && targetOffset < nextAbsoluteIndexOffset = x
       | otherwise = getOffsetPositionFor xs bo to
  where  nextAbsoluteIndexOffset = ((fromIntegral $ fst $ head $ xs) + bo)
         absoluteIndexOffset = (fromIntegral $ fst $ x) + bo
         targetOffset = fromIntegral $ to



