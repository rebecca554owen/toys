# Configuration illustration

- Example

  ```json
  {
      "concurrent": 2,
      "cdn": [ 80, 443 ],
      "key": {
          "kf": 154543927,
          "kx": 128,
          "kl": 10,
          "kh": 12,
          "protocol": "aes-128-cfb",
          "protocol-key": "N6HMzdUs7IUnYHwq",
          "transport": "aes-256-cfb",
          "transport-key": "HWFweXu2g5RVMEpy",
          "masked": false,
          "plaintext": false,
          "delta-encode": false,
          "shuffle-data": false
      },
      "ip": {
          "public": "192.168.0.24",
          "interface": "192.168.0.24"
      },
      "vmem": {
          "size": 4096,
          "path": "./{}"
      },
      "tcp": {
          "inactive": {
              "timeout": 300
          },
          "connect": {
              "timeout": 5
          },
          "listen": {
              "port": 20000
          },
          "turbo": true,
          "backlog": 511,
          "fast-open": true
      },
      "udp": {
          "inactive": {
              "timeout": 72
          },
          "dns": {
              "timeout": 4,
              "redirect": "0.0.0.0"
          },
          "listen": {
              "port": 20000
          },
          "static": {
              "keep-alived": [ 1, 5 ],
              "dns": true,
              "quic": true,
              "icmp": true,
              "server": "192.168.0.24:20000"
          }
      },
      "websocket": {
          "host": "starrylink.net",
          "path": "/tun",
          "listen": {
              "ws": 20080,
              "wss": 20443
          },
          "ssl": {
              "certificate-file": "starrylink.net.pem",
              "certificate-chain-file": "starrylink.net.pem",
              "certificate-key-file": "starrylink.net.key",
              "certificate-key-password": "test",
              "ciphersuites": "TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256"
          },
          "verify-peer": true,
          "http": {
              "error": "Status Code: 404; Not Found",
              "request": {
                  "Cache-Control": "no-cache",
                  "Pragma": "no-cache",
                  "Accept-Encoding": "gzip, deflate",
                  "Accept-Language": "zh-CN,zh;q=0.9",
                  "Origin": "http://www.websocket-test.com",
                  "Sec-WebSocket-Extensions": "permessage-deflate; client_max_window_bits",
                  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0"
              },
              "response": {
                  "Server": "Kestrel"
              }
          }
      },
      "server": {
          "log": "./ppp.log",
          "node": 1,
          "subnet": true,
          "mapping": true,
          "backend": "ws://192.168.0.24/ppp/webhook",
          "backend-key": "HaEkTB55VcHovKtUPHmU9zn0NjFmC6tff"
      },
      "client": {
          "guid": "{F4569208-BB45-4DEB-B115-0FEA1D91B85B}",
          "server": "ppp://192.168.0.24:20000/",
          "bandwidth": 10000,
          "reconnections": {
              "timeout": 5
          },
          "paper-airplane": {
              "tcp": true
          },
          "http-proxy": {
              "bind": "192.168.0.24",
              "port": 8080
          },
          "mappings": [
              {
                  "local-ip": "192.168.0.24",
                  "local-port": 80,
                  "protocol": "tcp",
                  "remote-ip": "::",
                  "remote-port": 10001
              },
              {
                  "local-ip": "192.168.0.24",
                  "local-port": 7000,
                  "protocol": "udp",
                  "remote-ip": "::",
                  "remote-port": 10002
              }
          ]
      }
  }
  ```

- server-client shared parameters

    - .concurrent

		Set the connection concurrent number.

	- .vmem

		Create temporary virtual files on the disk as swap file

		- .vmem.size

			Specify the size of created virtual files. The number is calculated in KB

		- .vmem.path

			Specify the path to create virtual files.

	- .key

		The encryption and keyframe generation params.

		- .key.kf

			Just like the pre-shared IV in AES algorithm, kf value is used to generate the keyframe.

		- .key.kl & .key.kh

			Both value should be in [0..16], related with the keyframe position. Both should be set in the server and client configuration but no need to be same.

		- .key.kx
    
			This value should be within [0..255], related with the frame padding but not the padding length or frame length.

		- .key.protocol & .key.transport

			Both value should be among the algorithm names listed in the openssl-3.2.0/providers/implementations/include/prov/names.h

		- .key.protocol-key & .key.transport-key

			The key string for the protocol encryption and the transport encryption.

		- .key.masked
    
			The principle likes the masked procedure in establishing websocket connections. But not the same procedure.

		- .key.plain-text

			Use a self-developed algorithm to twist all traffic into printable text and integrated the entropy control. After enabling, the package size would be several times larger than the origin one.

		- .key.delta-encode

			Use a self-developed delta-encode algorithm to give the connection more security. Consumes more CPU time

		- .key.shuffle-data

			Shuffle the transferred binary data. Consumes more CPU time.

	- .ip

		Specify the ip address that openppp2 server should bind to.

		The following to parames are usually okay to be set as "::".

		- .ip.public

			Set the public ip of the openppp2 server
		
		- .ip.interface

			Set the interface ip that openppp2 server listen to.

	- .tcp

		Specify the tcp connection related parameters.

		- .tcp.inactive.timeout

			Specify how long the server would release the idle tcp connections.

		- .tcp.listen.port

            Specify the port that openppp2 server is going to listen the TCP connections.

    - .udp

        Specify the udp connection related parameters.

        - .udp.inactive.timeout

            Specify how long the openppp2 server release an udp port without any data transferred.

        - .udp.dns

            DNS unlock related settings. You could redirect all dns queries to an specific DNS.
            
            - .udp.dns.timeout

                Set the timeout length of the DNS query, calculated in sec.

            - .udp.redirect

                Default value is 0.0.0.0, which means no redirect.

                All the UDP traffic to port 53 would be redirect to this address

        - .udp.static

            When the CLI enables the --tun-static option, the UDP traffic would be seperated from the TCP traffic.

            The newly established UDP connection would follow the parameters setted here.

            - .udp.static.keep-alived

                This param should be an array contains two int value, which means the occupied UDP port at the client side would be smoothly changed to another one in this period.

                The former one should no larger than the latter one.

                If the array is unspecified or setted to [ 0, 0 ], the UDP port won't be released, which would cause some traffic problems in special network situations.

            - .udp.static.dns

                By enabling this param, openppp2 client would transfer dns queries through UDP instead of TCP.
            
            - .udp.static.quic

                Allow quic transferred through UDP, --block-quic should be set to no.

            - .udp.static.icmp

                Allow the icmp transferred through UDP

            - .udp.static.server

                The UDP endpoint. There are three formats accepted
                
                1. IP:PORT (e.g. 192.168.0.24:20000)

                2. DOMAIN:PORT (e.g. localhost:20000)

                3. DOMAIN[IP]:PORT (e.g. localhost[127.0.0.1]:20000)

		- .websocket.ssl

        Specify the TLS parameters when you trying to connect to the openppp2 server using wss protocol.

        - .websocket.request

        Specify the HTTP request headers sent to the openppp2 server when using ws or wss protocol.

    - .websocket.response

    Specify the HTTP response headers respond by openppp2 server when using ws or wss protocol.

  - .websocket.verify-peer

    Verify the client is openppp2 client

  - .websocket.http

    Specify the http headers when using websocket to connect openppp2 server.

  - 

- server-only parameters

  - .cdn

    Enable this node as an SNI-Proxy node. All the HTTP/HTTPS requests sent to the 80/443 of this server would be redirect to the website in the HTTP Host Head or the SNI.

  - .tcp & .udp

    Only you should modify is the .tcp.listen.port, which specifies the openppp2 listening port. 

  - .server

    These parameters specify the server side configurations.

    - .server.log

      Set the place where to store the log of the VPN connections. Leaving it blank to disable the log recording. 

    - .server.node

      If you have multiple node to manage, this value should be different to identify different server in the log.

    - .server.subnet

      By enabling this value, All the client would come into one subnet and able to ping each other or connect to each other.
    
    - .server.mapping
    
      By enabling this value, the openppp2 server is able to work as a reverse proxy server and export an internal client port to the public network.
    
    - .server.backend
    
      The address of control panel. The control panel source code is presented in the github.com/liulilittle/openppp2/go
    
    - .server.backend-key
    
      The key used to authenticate the connection with the control panel

- client-only parameters

  - .client

    specify the client parameters

    - .client.guid 

      Among all the client connect to the openppp2 server, the GUID string should keep unique.

    - .client.server

      Set the openppp2 server connecting to. If using tcp to connect, the string should be "ppp://[ip_addr | domain]:port/". If using websocket, just replace the ppp with ws, then add the wsebsocket listening path to the end of the string. (e.g. ws://cloudflare.com:8080/tun)

      Please bear in mind that there is no need to wrap the ipv6_addr in []. Due to the parse algorithm has been modified.

    - .client.bandwidth

      Limit the client bandwidth, valued in kbps.

    - .client.reconnections.timeout

      Set the reconnect timeout value

    - .client.paper-airplane.tcp

      Use a kernel component to speed up network connections and traffic flows. Due to the unaffordable developer certificate, the kernel component is not signed and would cause the Anti-Cheat Software warning.
    
    - .client.http-proxy
    
      Set the parameters of the http-proxy at the client side.
    
      - .client.http-proxy.bind
    
        Set the http-proxy listening ip-address.
    
      - .client.http-proxy.port
    
        Set the http-proxy listening port.
    
    - .client.mappings
    
      Set the frp functions at the client side. By setting these parameters in the Vectors, client is able to mirror its port to an specific port at the external openppp2 server 
    
      - .client.mappings.[n].local-ip
    
        Please use the virtual address assigned to the TUN. So that the data received by openppp2 server would be sent to the client through the established connection.
    
      - .client.mappings.[n].local-port
    
        Set the port at the client which is going to be mapping to the openppp2 server side.
    
      - .client.mappings.[n].protocol
    
        Set the protocol that would be received at the openppp2 server side.
    
      - .client.mappings.[n].remote-ip
    
        Set the remote ip that openppp2 server is going to listening at.
    
      - .client.mappings.[n].remote-port
    
        Set the remote port that openppp2 server is going to listening at.
