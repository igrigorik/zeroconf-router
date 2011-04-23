$: << '/git/spdy/lib'
$: << '/git/goliath/lib'
$: << '/git/em-zeromq/lib'

require 'em-zeromq'
require 'goliath'
require 'spdy'

class Router < Goliath::API

  def proxy(env, data, flush = false)
    if flush
      data = [env['spdy'], data].flatten
      env.logger.info data
      sent = env.config['zmq'].send_msg('', *data)
      env.logger.info "Proxying: #{data.size} messages to ZMQ worker, status: #{sent}"

    else
      env['spdy'] ||= []
      env['spdy'] << data
      env.logger.info "Buffered SPDY message. buffer size: #{env['spdy'].size}"
    end
  end

  def on_headers(env, headers)
    env.logger.info 'received HTTP headers: ' + headers.inspect

    sr = SPDY::Protocol::Control::SynStream.new
    headers = headers.inject({}) {|h,(k,v)| h[k.downcase] = v; h}
    headers.merge!({
                     'version' => env['HTTP_VERSION'],
                     'method'  => env['REQUEST_METHOD'],
                     'url'     => env['REQUEST_URI']
    })

    # assign a unique stream ID and store it
    # in the HTTP > SPDY stream_id routing table
    env['stream_id'] = env.config['stream']
    env.config['router'][env['stream_id']] = env
    env.config['stream'] += 1

    sr.create(:stream_id => env['stream_id'], :headers => headers)
    proxy(env, sr.to_binary_s)
  end

  def on_body(env, data)
    return if data.empty?
    env.logger.info 'received HTTP data: ' + data

    # TODO: Proxy body data in chunks
    # body = SPDY::Protocol::Data::Frame.new
    # body.create(:stream_id => env['stream_id'], :data => data)
    # proxy(env, body.to_binary_s)

    (env['body'] ||= '') << data
  end

  def on_close(env)
    env.logger.info "client closed connection, stream: #{env['stream_id']}"
    env.config['router'].delete env['stream_id']

    # TODO: SEND RST
  end

  def response(env)
    env.logger.info "Finished connection-request"

    fin = SPDY::Protocol::Data::Frame.new
    fin.create(:stream_id => env['stream_id'], :data => env['body'], :flags => 1)

    proxy(env, fin.to_binary_s, true)

    # TODO: merge upstream Goliath return
    # Goliath::Connection::AsyncResponse
    nil
  end

end
