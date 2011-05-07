require 'ffi-rzmq'

link = 'tcp://127.0.0.1:5555'

ctx = ZMQ::Context.new 1
s1 = ctx.socket ZMQ::XREP

s1.connect(link)

puts "Worker connected to: #{link}"

loop do
  id = s1.recv_string
  sp = s1.recv_string
  bd = s1.recv_string

  puts "Received from Nginx: [#{bd}]"

  s1.send_string id, ZMQ::SNDMORE
  s1.send_string '', ZMQ::SNDMORE
  s1.send_string ['ruby echo:', bd].join(' ')

  puts "Response sent"
end