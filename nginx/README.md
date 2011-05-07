# Nginx zeroconf router: via ZMQ, and back

Proof of concept: Nginx + Luajit + ZMQ for "zeroconfig router". Meaning, when Nginx is started, our `zmqrouter.lua` module is loaded into the Nginx worker, which in turn opens an XREQ ZeroMQ socket. When a request comes in, we extract the user agent, the body of the request, push it into the XREQ socket, and then wait for the response.

The response is served by a simple ruby worker which accepts ZeroMQ messages and sends an echo response back - this, of course, could be implemented in any language you like.

## Getting started

- Install [ZeroMQ](http://www.zeromq.org/intro:get-the-software)
- Install [super-nginx build with luajit](https://github.com/ezmobius/super-nginx)
- Start nginx: `/path/to/super-nginx/sbin/nginx -c /zeroconf-router/nginx/nginx.conf`
- Start worker: `ruby appserver.rb` (as many as you like... :-))
- Issue a request to nginx: `curl -v localhost:3000/zmq -d "some post body"`

```
* About to connect() to localhost port 3000 (#0)
*   Trying 127.0.0.1... connected
* Connected to localhost (127.0.0.1) port 3000 (#0)
> POST /zmq HTTP/1.1
> User-Agent: curl/7.19.7 (i386-apple-darwin10.4.0) libcurl/7.19.7 OpenSSL/0.9.8l zlib/1.2.3
> Host: localhost:3000
> Accept: */*
> Content-Length: 19
> Content-Type: application/x-www-form-urlencoded
>
< HTTP/1.1 200 OK
< Server: nginx/0.8.54
< Date: Sat, 07 May 2011 16:51:24 GMT
< Content-Type: text/plain
< Transfer-Encoding: chunked
< Connection: keep-alive
<
ruby echo: curl/7.19.7 (i386-apple-darwin10.4.0) libcurl/7.19.7 OpenSSL/0.9.8l zlib/1.2.3 > sending a post body
* Connection #0 to host localhost left intact
* Closing connection #0
```

Voila! Nginx parsed the request, pushed it to one of our Ruby workers via ZMQ and returned the response back to the client.

## Notes

This is a minimal proof of concept at best - there is a number of issues with the above example. First, the ZMQ socket will block the nginx reactor as implemented: it needs to be integrated into the nginx loop. Further, once you integrate the ZMQ socket into the run loop you'll have to keep track of all the incoming streams and respond to the correct client (not to mention properly handle the header relay, etc).