# Quick-Start

## Server side Configuration

1. Find a server to deploy openppp2 server

2. Connect to the server.

3. Download the openppp2 zip remotely.

4. Modify the given appsettings.json template file in the openppp2 compressed file.

    1. If you have no need to use this server as SNIProxy server, please delete the "cdn" param.

    2. If your server has 256MiB+ mem and disk I/O speed of 4K-blocks is not satifying, please delete the vmem param

    3. If your server has more than 1 thread, you would better set the cocurrent to the thread number.

    4. Set the server listening ip address

        1. If you decide to use all the ip assinged to the server, please change the ip.interface and ip.public to "::"

            ```json
            "ip": {
                "interface": "::",
                "public": "::"
            }
            ```
        2. If you decide to use only one ip address, please change the the ip.interface and ip.public to the ip that you want to use.

        3. In some special situations, that the public ip is assigned by route, you should change the interface to the "::" and change the public to the ip address going to be used.

        4. Hate IPv6? Replace all "::" to "0.0.0.0"

    5. Set the tcp and udp port by modifying tcp.listen.port and udp.listen.port

    6. Delete the whole websocket param, since the tcp connection would be secured enough facing the censorship.(Websocket connection should be used in some specific situations)

    7. Set some server running params 
    
        1. server.log is the path to store the connection logs. If you hate logs, please set to "/dev/null"

        2. Delete the following params in server block.

            ```json
            
            "server": {
                "log": "/dev/null"
            }

            ```
    
    8. use `screen -S` to keep openppp2 running at backstage

    9. Remenber to chmod +x !

    10. Boot the server

## Client Side Configuration

1. Delete the vmem params as long as you client is running on your PC or the client device is using eMMc as the storage.

2. Set the udp.static.server

    - IP:PORT

    - DOMAIN:PORT

    - DOMAIN[IP]:PORT

3. Set client.guid to a totally random one, please make sure no other client share the same GUID with the one that you are using.

4. Set the client.server

    - ppp://IP:PORT

    - ppp://DOMAIN:PORT

    - ppp://DOMAIN[IP]:PORT

5. Delete the client.bandwidth to unleash the openppp2 full speed

6. Delete the mappings params

## Client CLI notice

1. The TUN gateway on windows should be x.x.x.0

2. Only by adding the --tun-static=yes , the UDP streams would be trasfered seperately.

3. If the --block-quic=yes, no matter what the --tun-static is, there won't be any QUIC streams.
