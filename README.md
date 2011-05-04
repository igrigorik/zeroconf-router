# Zero-config reverse proxies: let's get there!

- tl;dr - zero config reverse proxy example via HTTP -> SPDY -> 0MQ
- [discussion on hacker news](http://news.ycombinator.com/item?id=2514308)

All reverse proxy servers have a common pain point: they have to know which backends requests can be routed to. Need to bring up a new appserver behind Nginx, HAProxy, or equivalent? Update your config, then HUP or reboot the server - painful. Why can't we decouple this relationship once and for all? Nginx, HAProxy and similar tools are all great, but what is missing is a simple protocol that would allow us to decouple these frontends from explicitly specifying each and every routing rule for every backend. Specifically, what we talking about?

```
upstream backend {
  server 10.0.0.20:8000;
  server 10.0.0.20:8001;
  server 10.0.0.20:8002;
}

server {
  listen 0.0.0.0:80;
  location / {
    proxy_pass https://backend;
  }

```

Looks familiar? We specified three backend app servers in this Nginx config. How do you add more? Update the config - ugh. Ideally, we should be able to bring up additional backends without modifying the frontend servers and requests "should just flow" to the new server - wouldn't that be nice? Below is an (admittedly somewhat frankenstein) experiment to allow us to do exactly that.

## Architecture / Assumptions

Ultimately this functionality should be nothing more than a module in Nginx, Apache, or equivalent, but for the sake of a prototype, this is built via/with an async [Goliath app server](github.com/postrank-labs/goliath) which parses the HTTP protocol and feeds us incoming data.

**Converting HTTP to a stream oriented protocol:** HTTP is not built for stream multiplexing, but protocols like [SPDY attempt to solve this](http://www.igvita.com/2011/04/07/life-beyond-http-11-googles-spdy/) by introducing an explicit concept of streams and stream IDs into each packet. Hence, Goliath parses the HTTP request and converts the incoming request into SPDY protocol (Control + Data packets) - in other words, `router.rb` is an HTTP -> SPDY proxy.

**Decoupling frontends from backends:** Usually a router needs to be aware of all the backends before it can decide where to route the request (i.e. Nginx example above and exactly what we want to avoid). Instead, our router does something smarter: it uses [ZeroMQ XREP/XREQ](http://www.igvita.com/2010/09/03/zeromq-modern-fast-networking-stack/) sockets to break this dependency. Specifically, the router *binds* an XREQ socket on port 8000 when it first comes up. The router accepts HTTP requests and pushes SPDY packets to port 8000 - the router knows nothing about where or how many backends there are.

Next, we have `hello.rb` which is a simple example of a worker process, in this case written in Ruby, but it could be any language or runtime. What does it do? It connects to port 8000 (via an XREP socket) when it comes up and waits to receive 0MQ messages, which are actually carrying SPDY frames - 0MQ + SPDY are a great match here, since both are message and stream oriented.

That's it, and the best part is.. Start the router, and then start as many workers as you want, or shut them down at will. 0MQ will do all the work for connection setup and teardown. Our router knows nothing about how many workers there are, and our worker knows nothing about how many frontends there are. Now all we need is this as an Nginx module! A quick visual representation of what is happening here:

![arch](https://img.skitch.com/20110504-kqgt26cyjiapj3hqy5j6m7t6hk.jpg)

(If you are not familiar with 0MQ: XREQ socket automatically load-balances incoming requests (round-robin) to all the XREP workers. As implemented the example code will buffer the incoming HTTP request before it is dispatched to the worker but will/can stream the response back from the worker without waiting for complete response).

## Summary

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

```
$> bundle install

$> ruby hello.rb worker-1
$> ruby hello.rb worker-2

$> ruby router.rb -sv -p 9000
$>
$> curl http://localhost:9000/
   Hello from worker-1
$> curl http://localhost:9000/
   Hello from worker-2
```

What happened here? First, notice that we started the workers before the router was up! The order doesn't matter (thanks to 0MQ). Next, we started the router, which is listening to HTTP requests on port 9000, and forwarding SPDY requests to port 8000. Next we dispatch some queries, and ZMQ does its job and load balances the requests between the workers.

Now kill one of the workers, and send a new request.. ZMQ does all the cleanup work for us, and now all the requests are going to the single live server. Now start five more workers, and once again, we get transparent load balancing. No config reloads, no worries.

## Related:

- [ZeroMQ: Modern & Fast Networking Stack](http://www.igvita.com/2010/09/03/zeromq-modern-fast-networking-stack/)
- [Life beyond HTTP 1.1: Google’s SPDY](http://www.igvita.com/2011/04/07/life-beyond-http-11-googles-spdy/)
- [@igrigorik](http://www.twitter.com/igrigorik)