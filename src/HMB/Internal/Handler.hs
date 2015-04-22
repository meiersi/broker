module HMB.Internal.Handler 
( readRequest
, initHandler
, listenLoop
) where 

import Network.Socket 
import qualified Network.Socket.ByteString.Lazy as SBL
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Char8 as BS

import System.IO 
import System.Environment
import Control.Concurrent
import Control.Monad

import Kafka.Protocol
import Data.Binary.Get

import HMB.Internal.Log
import qualified Data.ByteString.Char8 as C

readRequest :: BL.ByteString -> IO RequestMessage
readRequest a = do 
  return (runGet requestMessageParser a)

initHandler :: IO Socket
initHandler = do
  sock <- socket AF_INET Stream 0
  setSocketOption sock ReuseAddr 1
  bindSocket sock (SockAddrInet 4343 iNADDR_ANY)
  listen sock 2
  return sock

listenLoop :: Socket -> IO()
listenLoop sock =  do
  conn <- accept sock
  forkIO $ forever $ do
      readReqFromSock conn
  listenLoop sock

readReqFromSock :: (Socket, SockAddr) -> IO()
readReqFromSock (sock, sockaddr) = do
  input <- SBL.recv sock 4096
  let i  = input
  requestMessage <- readRequest i
  case rqApiKey requestMessage of
    0  -> handleProduceRequest (rqRequest requestMessage) sock
    1  -> handleFetchRequest (rqRequest requestMessage) sock
    2  -> putStrLn "OffsetRequest"
    3  -> putStrLn "MetadataRequest"
    8  -> putStrLn "OffsetCommitRequest"
    9  -> putStrLn "OffsetFetchRequest"
    10 -> putStrLn "ConsumerMetadataRequest"
    _  -> putStrLn "Unknown ApiKey"
  print requestMessage
  return ()

-----------------
-- ProduceRequest
-----------------

handleProduceRequest :: Request -> Socket -> IO()
handleProduceRequest req sock = do
  mapM writeLog [ 
      (BS.unpack(topicName x), fromIntegral(rqPrPartitionNumber y), rqPrMessageSet y ) 
      | x <- rqPrTopics req, y <- partitions x 
    ]
  sendProduceResponse sock packProduceResponse 

-- TODO dynamic function
packProduceResponse :: ResponseMessage 
packProduceResponse = 
  let error = RsPrError 0 0 0 
  in
  let response = ProduceResponse 
        (fromIntegral $ BS.length $ BS.pack "topicHardCoded")
        (BS.pack "topicHardCoded")
        (fromIntegral $ length [error])
        [error]
  in
  let responseMessage = ResponseMessage 0 1 [response]
  in 
  responseMessage 

sendProduceResponse :: Socket -> ResponseMessage -> IO()
sendProduceResponse socket responsemessage = do
  let msg = buildPrResponseMessage responsemessage
  SBL.sendAll socket msg

-----------------
-- FetchRequest
-----------------

packPartitionsToFtRsPayload :: TopicName -> Partition -> IO RsFtPayload
packPartitionsToFtRsPayload t p = do
    log <- readLog (BS.unpack $ t, fromIntegral $ rqFtPartitionNumber p, fromIntegral $ rqFtFetchOffset p)
    return $ RsFtPayload
        0
        0
        0
        (fromIntegral $ BL.length $ foldl (\acc ms -> BL.append acc (buildMessageSet ms)) BL.empty log)
        log

packLogToFtRs :: Topic -> IO Response
packLogToFtRs t = do
    rss <- (mapM (packPartitionsToFtRsPayload $ topicName t) $ partitions t)
    return $ FetchResponse
        (topicNameLen t)
        (topicName t)
        (numPartitions t )
        rss

handleFetchRequest :: Request -> Socket -> IO()
handleFetchRequest req sock = do
  rs <- mapM packLogToFtRs (rqFtTopics req)
  let rsms = ResponseMessage 0 1 rs
  let msg = buildFtRsMessage rsms
  SBL.sendAll sock msg

