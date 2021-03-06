-- |
-- Module      : HMB.Main
-- Copyright   : (c) Marc Juchli, Lorenz Wolf 2015
-- License     : BSD-style
--
-- Maintainer  :
-- Stability   : WIP
-- Portability : GHC
--
-- Main module of Haskell message broker server application. 
module Main (
  main
) where

import HMB.Internal.Types
import HMB.Internal.Network
import HMB.Internal.API

import Control.Monad
import Control.Concurrent.Async
import Control.Concurrent

-- | Bootstrap server application, wait for threads to be finished
main = do

  sock <- initSock
  rqChan <- initRqChan
  rsChan <- initRsChan

  -- FIXME (SM): this and other modules contain trailing whitespace. It is
  -- considered good style in the open-source community to not have that. If
  -- you Google for it you should easily find a command-line invocation to
  -- drop all trailing whitespace, and editor configurations that highlight it
  -- and possibly remove it on save.
  withAsync (runAcceptor sock rqChan) $ \a1 -> do 
    putStrLn "***Acceptor Thread started***"
    withAsync (runResponder rsChan) $ \a2 -> do 
      putStrLn "***Responder Thread started***"
      withAsync (runApiHandler rqChan rsChan) $ \a3 -> do 
        putStrLn "***API Worker Thread started"
        page1 <- wait a1
        page2 <- wait a2
        page3 <- wait a3
        putStrLn "exit"
