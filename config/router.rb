@router = {}

config['stream'] = 1
config['identity'] = 'http-spdy-bridge'
config['router'] = @router

Thread.abort_on_exception = true
ctx = EM::ZeroMQ::Context.new(1)

class ZMQHandler
  attr_reader :received

  def initialize(router)
    @router = router
    @p = SPDY::Parser.new

    @p.on_headers_complete do |stream, astream, priority, head|
      p [:ZMQ_REPLY, :stream, stream, :headers, head]

      status = head.delete('status')
      version = head.delete('version')

      headers  = "#{version} #{status}\r\n"
      head.each do |k,v|
        headers << "%s: %s\r\n" % [k.capitalize, v]
      end

      @router[stream].stream_send(headers + "\r\n")
    end

    @p.on_body do |stream, data|
      p [:SPDY_BODY, stream, data]
      @router[stream].stream_send data
    end

    @p.on_message_complete do |stream|
      p [:SPDY_FIN, stream]

      @router[stream].stream_close
      @router.delete stream
    end
  end

  def on_readable(socket, messages)
    messages.each do |m|
      @p << m.copy_out_string
    end
  end
end

handler = ZMQHandler.new(@router)
config['zmq'] = ctx.bind(ZMQ::XREQ, 'tcp://127.0.0.1:8000', handler, :identity => config['identity'])

puts "Bound XREQ handler to port 8000, let the games begin!"
