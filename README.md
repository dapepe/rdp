This Repository contains docker compose files for Apache Guacamole and Cloudflare:

## Usage:
start the docker container:

cd /home
docker compose -p guac -f docker-compose-guacamole.yaml up -d
docker compose -f docker-compose-cloudflare.yaml up -d

check if container are starting:
```
docker container ps
```
it should now display something like that:
```
462e74a50462   cloudflare/cloudflared:2024.11.0 "cloudflared --no-au…" 13 seconds ago Up 12 seconds home-guacamole-1
```
```
df9decd3f3c9   abesnier/guacamole:1.5.5-pg15 "/init" About a minute ago Up About a minute (healthy) 0.0.0.0:8080->8080/tcp, :::8080->8080/tcp guac-guacamole-1*
```
## Important!!!
**Change the default login** from Guacamole immediately after setting up the container.
Guacamole default login: 

User: guacadmin

Password: guacadmin

### add users

### add remote connections

### add cloudflare tunnel 


### check if cloudflare tunnel connection was successfull: 
Under "Zero-trust/networks/Tunnels" on the Cloudflare website you can check the tunnel
status.  