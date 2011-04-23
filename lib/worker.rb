$: << '/git/spdy/lib'

require 'ffi-rzmq'
require 'spdy'

class Worker
  def initialize(opts = {})
    @worker_identity = opts[:identity]

    ctx = ZMQ::Context.new(1)
    @conn = ctx.socket(ZMQ::XREP)
    @conn.setsockopt(ZMQ::IDENTITY, opts[:identity])
    @conn.connect(opts[:route])

    @stream_id = nil
    @headers = {}
    @body = ''

    @p = SPDY::Parser.new
    @p.on_headers_complete do |stream, astream, priority, head|
      @stream_id = stream
      @headers = head
    end

    @p.on_body do |stream, body|
      @body << body
    end

    @p.on_message_complete do |stream|
      status, head, body = response(@headers, @body)

      synreply = SPDY::Protocol::Control::SynReply.new
      headers = {'status' => status.to_s, 'version' => 'HTTP/1.1'}.merge(head)
      synreply.create(:stream_id => @stream_id, :headers => headers)

      @conn.send_string(@identity, ZMQ::SNDMORE)
      @conn.send_string(synreply.to_binary_s)

      # Send body & close connection
      resp = SPDY::Protocol::Data::Frame.new
      resp.create(:stream_id => @stream_id, :flags => 1, :data => body)

      @conn.send_string(@identity, ZMQ::SNDMORE)
      @conn.send_string(resp.to_binary_s)
    end
  end

  def run
    loop do
      @identity = @conn.recv_string()
      delimiter = @conn.recv_string()

      head = @conn.recv_string()
      body = @conn.recv_string()

      @p << head
      @p << body
    end
  end

end