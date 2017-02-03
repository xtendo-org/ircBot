{-# LANGUAGE QuasiQuotes #-}
module Xnukbot.Plugin.Hyeong (plugin) where

import Prelude hiding (writeFile)

import "unix" System.Posix.Temp (mkstemp)
import "directory" System.Directory (removeFile)
import "process" System.Process (createProcess, proc, CreateProcess(std_in, std_out, std_err, close_fds), StdStream(CreatePipe, NoStream), terminateProcess)
import "base" Control.Concurrent (forkFinally, threadDelay)
import "base" Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)

import "xnukbot" Xnukbot.Plugin (Plugin)
import "xnukbot" Xnukbot.Plugin.Simple (simplePlugin)
import "pcre-heavy" Text.Regex.PCRE.Heavy (re, Regex)

import "bytestring" Data.ByteString (hGet)
import "text" Data.Text (Text)
import qualified "text" Data.Text as T (null)
import "text" Data.Text.IO (writeFile)
import "text" Data.Text.Encoding (decodeUtf8With)
import System.IO (hClose)
import Control.Exception (catch, SomeException)

regex, prefRegex :: Regex
regex = [re|^((?:(?:[형항핫흣흡흑]|혀어*엉|하아*[앙앗]|흐으*[읏읍윽])[\.…⋯⋮]*[!\?♥❤💕💖💗💘💙💚💛💜💝♡]*\s*)+)$|]

prefRegex = [re|^hyeong\s*(.+)\s*$|]

runHyeong :: Text -> IO Text
runHyeong code = do
    (path, h) <- mkstemp "/tmp/hyeong"
    hClose h -- this handle sucks
    writeFile path code

    (_, Just hout, _, process) <- createProcess (proc "rshyeong" [path])
        { std_in = NoStream
        , std_out = CreatePipe
        , std_err = NoStream
        , close_fds = True
        }

    res <- newEmptyMVar
    _ <- forkFinally (hGet hout 600) $ \x -> do
        hClose hout
        terminateProcess process
        catch (removeFile path) $ \e -> print (e :: SomeException)
        putMVar res $ either (const mempty) id x

    _ <- forkFinally (threadDelay 5000000 {- 5 sec -}) $ const (hClose hout)

    decodeUtf8With (\_ _ -> Nothing) <$> takeMVar res

plugin :: Plugin
plugin = simplePlugin "Hyeong" (prefRegex, regex) $ \_ _ _ ->
    let toList x = if T.null x then [] else [x]
    in fmap toList . runHyeong . either head head
