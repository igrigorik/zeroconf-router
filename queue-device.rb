require 'rubygems'
require 'ffi-rzmq'

#
# Simple router which allows multiple frontends to distribute
# requests to many workers, without knowing where or how many
# of the workers there are. To do so, you can run this process
# and 'connect' to port 8001 on each of your frontends (HTTP
# routers).
#
# In other words N to N communication
#.

ctx = ZMQ::Context.new 1

q_front = ctx.socket(ZMQ::XREP)
q_back  = ctx.socket(ZMQ::XREQ)

q_front.bind('tcp://127.0.0.1:8001')
q_back.bind('tcp://127.0.0.1:8000')

ZMQ::Device.new(ZMQ::QUEUE, q_front, q_back)
