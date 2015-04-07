module HMB.Network.Types
( RequestMessage (..)
, RequestSize
, ApiKey
, ApiVersion
, CorrelationId
, ClientId
, Request (..)
, RequiredAcks
, Timeout
, NumTopics
, Topic (..)
, TopicName
, TopicNameLen
, NumPartitions
, Partition (..)
, PartitionNumber

, Response (..)
, ResponseMessage (..)
, Error (..)
) where

import Data.Word
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import HMB.Common


type RequestSize = Word32
type ApiKey = Word16
type ApiVersion = Word16
type CorrelationId = Word32
type ClientId = BS.ByteString
type ClientIdLen = Word16
type RequiredAcks = Word16
type Timeout = Word32
type NumTopics = Word32
type TopicName = BS.ByteString
type TopicNameLen = Word16
type NumPartitions = Word32
type PartitionNumber = Word32
type MessageSetSize = Word32


type ErrorCode = Word16
type NumResponses = Word32
type NumErrors = Word32


------------
-- Resquest
------------

data RequestMessage = RequestMessage
  { reqSize     :: !RequestSize
  , reqApiKey          :: !ApiKey
  , reqApiVersion      :: !ApiVersion
  , reqCorrelationId   :: !CorrelationId
  , reqClientIdLen     :: !ClientIdLen
  , reqClientId        :: !ClientId
  , request            :: Request
  } deriving (Show)

data Request = ProduceRequest
  { reqRequiredAcks    :: !RequiredAcks
  , reqTimeout         :: !Timeout
  , reqNumTopics       :: !NumTopics
  , reqTopics          :: [Topic]
  }
  | MetainfoRequest
  { reqTopicNames      :: [TopicName] }
  deriving (Show)

data Topic = Topic
  { topicNameLen    :: !TopicNameLen
  , topicName       :: !TopicName
  , numPartitions   :: !NumPartitions
  , partitions      :: [Partition]
  } deriving (Show)

data Partition = Partition
  { partitionNumber :: !PartitionNumber
  , messageSetSize  :: !MessageSetSize
  , messageSet      :: [MessageSet]
  } deriving (Show)


------------
-- Response
------------

data ResponseMessage = ResponseMessage
  { resCorrelationId   :: !CorrelationId
  , resNumResponses    :: !NumResponses
  , responses        :: [Response]
  } deriving (Show)

data Response = ProduceResponse
  { resTopicNameLen    :: !TopicNameLen
  , resTopicName       :: !TopicName 
  , resNumErrors       :: !NumErrors
  , resErrors          :: [Error]
  }
  | MetadataResponse 
  { resTopicNameLen    :: !TopicNameLen
  , resTopicName       :: !TopicName 
  } deriving (Show) 

data Error = Error 
  { errPartitionNumber :: !PartitionNumber
  , errCode       :: !ErrorCode
  , errOffset          :: !Offset
  } deriving (Show)
