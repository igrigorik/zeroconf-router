require 'lib/worker'

class HelloWorld < Worker
  def response(head, body)
    p [:HELLO_WORLD, head, body]

    [200, {'X-ZMQ' => @worker_identity}, "Hello from #{@worker_identity}"]
  end
end

puts "Starting worker: #{ARGV[0]}"
w = HelloWorld.new({:route => 'tcp://127.0.0.1:8000', :identity => ARGV[0]})
w.run