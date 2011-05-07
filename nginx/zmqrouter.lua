module("zmqrouter", package.seeall)
require("zmq")

local ctx = zmq.init(1)
local s = ctx:socket(zmq.XREQ)

s:bind("tcp://127.0.0.1:5555")

function send(data)
  s:send("", zmq.SNDMORE)
  s:send(data)
end

function response()
  s:recv()        -- separator
  return s:recv() -- response
end