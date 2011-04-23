# Frankenstein HTTP experiment: HTTP -> SPDY -> ZMQ

All reverse proxy servers have a common pain point: they have to know which backends requests can be relayed to. This frankenstein setup does not:

**Server/Router:**

- Incoming HTTP requests are parsed via an async Goliath web-server handler (router.rb)
- The router converts incoming HTTP request into SPDY protocol
    - Each HTTP request is assigned a unique stream-id (as per SPDY spec)
- The router binds an XREQ 0MQ socket on port 8000 and forwards all SPDY packets there

**Workers:**

- Any number of workers connect (via XREP) to port 8000
- Worker accepts an HTTP request (delivered in SPDY format) and generates a response
- Worker sends an unbuffered stream of response SPDY packets back to the router
- Router processes the SPDY response and emits an async HTTP response back to the client

## Example

    $> ruby hello.rb worker-1
    $> ruby hello.rb worker-2
    $>
    $> ruby router.rb -sv -p 9000
    $>
    $> curl http://localhost:9000/
       Hello from worker-1
    $> curl http://localhost:9000/
       Hello from worker-2

What happened here? First, notice that we started the workers before the router was up! The order doesn't matter (thanks to ZMQ). Next, we started the router, which is listening to HTTP requests on port 9000, and forwarding SPDY requests to port 8000. Next we dispatch some queries, and low and behold, ZMQ does its job and load balances the requests between the workers.

Now kill one of the workers, and send a new request.. ZMQ does all the cleanup work for us, and now all the requests are going to the single live server. Now start five more workers, and once again, we get transparent load balancing. No config reloads, no worries.