module HMB.Common.Parser
(messageSetParser )
where 

import HMB.Common.Types
import Data.Binary.Get
import qualified Data.ByteString.Lazy as BL

payloadParser :: Get Payload
payloadParser = do
  keylen <- getWord32be
  paylen <- getWord32be
  payload <- getByteString $ fromIntegral paylen
  return $! Payload keylen paylen payload

messageParser :: Get Message 
messageParser = do 
  crc    <- getWord32be
  magic  <- getWord8
  attr   <- getWord8
  p      <- payloadParser
  return $! Message crc magic attr p

messageSetParser :: Get MessageSet 
messageSetParser = do 
  offset <- getWord64be
  len <- getWord32be 
  message <- messageParser
  return $! MessageSet offset len message
