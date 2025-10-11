# BP MC Server

A Minecraft server configured for Blueprint.

## Setup

### 1. Install Prerequisites

1. [Install Docker Engine](https://docs.docker.com/engine/install/)
2. Access to a machine that can run a Minecraft server (e.g. an old laptop)
3. Access to a machine accessible by public network (e.g. machine with portforwarded IP or cloud VPS machine)
    - This can be the same machine as (2) if you can port-forward it
    - If you do not have one, I have [an article on setting up a free VM instance on GCP](https://www.jfang.dev/blogs/setting-up-compute-engine)
4. Access to a DNS and a domain name
    - If you do not have one, the good news is that most domain names are cheap - under $10/yr. Of course, the bad news is that it does cost money.

### 2. Setup Reverse Proxy

If you can port-forward the machine that will run the server, feel free to use port-forwarding and [skip to the next step](https://github.com/jinkang-0/mc-server-bp#3-configure-rclone).

If you cannot port-forward your machine (e.g. cannot access router), this step is for you.

**Setup Reverse Proxy Server**

Your reverse proxy server will be hosted on the machine that is accessible to the public. To setup the reverse proxy server, first install [frp](https://github.com/fatedier/frp/releases) on this machine. Choose the binary that matches your machine's architecture.

After unzipping the release tar.gz file, you should have a `frps` binary and a `frps.toml` file. You shouldn't need to modify the `frps.toml` file, but take note of the `bindPort` number specified. By default, it should be 7000. You will need this to configure the reverse proxy client on the Minecraft server machine.

You can start the server using this command:
```sh
./frps -c frps.toml
```

If your reverse proxy machine happens to use Linux, it's recommended to setup a SystemD service to always restart this server if the system reboots. You can configure a service by creating a service file like `frp.service` in `/etc/systemd/system/`.

Here is a sample service file content:
```service
[Unit]
Description=Fast Reverse Proxy server
After=network.target

[Service]
WorkingDirectory=/home/username/frp
ExecStart=/bin/sh -c "./frps -c frps.toml"
Restart=always

[Install]
WantedBy=multi-user.target
```

**Setup Reverse Proxy Client**

On your machine that will run the Minecraft server, you will also want to install [frp](https://github.com/fatedier/frp/releases). Ensure the binary matches your machine's computer architecture.

Now, you'll want to configure the `frpc.toml` file to something like this:

```toml
serverAddr = "x.x.x.x"
serverPort = 7000

[[proxies]]
name = "tcp"
type = "tcp"
localIP = "127.0.0.1"
localPort = 25565
remotePort = 25565
```

Replace the `serverAddr` field with the IP address of the machine hosting the reverse proxy server (e.g. the machine that is accessible to the public).

Next, start the reverse proxy client with this command:

```sh
./frpc -c frpc.toml
```

You should be able to see a message in the client that the connection was successful, and likewise in the server.

If you are receiving timed out attempts or connection failures, make sure you check the network firewall of your reverse proxy server.

If you are running the reverse proxy server on a VM in GCP, you need to add new firewall rules to allow TCP on port 7000 and TCP on port 25565 as ingress from any source IP address through to your VM. After adding the rule, make sure the network tags assigned to the rule is applied to VM instance that corresponds to your reverse proxy server.

### 3. Configure RClone

The backup container uses RClone to push backups to a remote repository on the cloud for data persistence.

If you would rather use a simple local backup option, modify the `docker-compose.yml` file for the `mc-backup` container as such:
```yaml
  backup:
    ...
    environment:
      BACKUP_INTERVAL: "1d"
      RCON_HOST: mc
    volumes:
      - ./data:/data:ro
      - ./backups:/backups
```

If saving to the cloud is a feature you would want to keep, run the following command to setup the [RClone config](https://rclone.org/remote_setup/):

```sh
# for Linux, you may need to prefix this with sudo
docker run -it --rm -v rclone-config:/config/rclone rclone/rclone config
```

When prompted for the name, enter "remote." If you entered anything else, make sure that name is reflected in the `docker-compose.yml` file in the `RCLONE_REMOTE` environment variable, for the `mc-backup` container.

### 4. Setup DNS Record

For Minecraft to recognize it as a valid server, we must setup a SRV record on a DNS.

Most DNS that come with domain name registrars should be able to achieve this. However, if your's don't, Cloudflare offers a great DNS for free. You just have to follow the instructions on Cloudflare to connect the two services.

There are two records to setup. The first is an A record. The name can be anything (e.g. minecraft.domain.tld), but the value must be the IP address of the reverse proxy server (or the actual server, if port-forwarding). If your DNS offers the ability to proxy the A record, make sure you turn that off for this record, as it can mess with how it gets received.

The second is a SRV record, with the name `_minecraft._tcp.subdomain`. You can replace `subdomain` with whatever you like - this will appear as the server address when inputting it in Minecraft, as `subdomain.domain.tld`. The port must be 25565, and the target must be the value of the A record that you just setup (e.g. `minecraft.domain.tld`).

### 5. Starting the Server

Finally, we can start the Minecraft server.

If you'd like, you can configure any of the server properties in the `docker-compose.yml` file. Refer to the Minecraft server Docker image [documentation](https://docker-minecraft-server.readthedocs.io/en/latest/configuration/server-properties/) for syntax details.

One crucial thing to set is the `OPS` environment variable. You may want to give yourself operator privileges to change gamerules and debug issues in the server.

When you're ready to start, run:

```sh
# on Linux, you may need to prefix this with sudo
docker compose up -d
```

If you want to examine the logs, run:

```sh
# view latest log snapshot
docker compose logs

# follow logs
docker compose logs -f
```

