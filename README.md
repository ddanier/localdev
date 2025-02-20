# About

This is a very simple docker or podman setup to run traefik locally for easy development. This
setup will give you a `localdev`-TLD you can use for all your projects. All projects you then
start using docker/podman will automatically get a `$SERVICE.$PROJECT_NAME.localdev` domain
name. This allows you to run multiple projects simultaneously without open port collisions.

The setup is handled using my task runner I build on top of `nu` shell. See the `nurfile` and
the [nur documentation](https://nur-taskrunner.github.io/docs/) for details.

## Help wanted

I developed and tested this setup using Podman Desktop on macOS. I would love to get PRs for
other setups, feel free to open an issue or a PR about that. Improvements are always welcome.

# Installation

You need to have Docker Desktop or Podman Setup installed and setup correctly. Please see the
official documentation of both projects for details.

Please note that you will also need to setup local DNS resolution for the `.localdev` domain. This
will be explained below. We use `dnsmasq` for this. Also note you need to have `nur` installed as
your task runner.

To download the `traefik` container image use the following.

```bash
nur install
```

The installation process will create a local certificate you can use to access `traefik` via HTTPS.
If you want to use this add `cert/ca.crt` to your trusted root certificates.

After everything is installed you can run your local `traefik` instance using the following command:

```bash
nur run
```

**Note:** This will run `docker compose up -d` or `podman compose up -d`, depending on your setup.

## Update your setup & housekeeping

Use the following command to update your setup.

```bash
nur update
nur run
```

To stop your local `traefik` instance use the following command.

```bash
nur halt
```

## Setup of you `.localdev` domain

To use `.localdev` as your local development domain we will use `dnsmasq` as a local nameserver.
Please install `dnsmasq` on your system. On macOs this can be done by using `brew`:
```shell
$ brew install dnsmasq
```

Afterwards you need to setup `dnsmasq` to respond to `.localdev`. It should always return `127.0.0.1`
as the IP address, so the whole domain will be resolved to your local machine. To configure `dnsmasq`
you need to edit the file called `dnsmasq.conf` and add the following content:

```
address=/.localdev/127.0.0.1
```

On macOs you cann do this by running the following commands:
```shell
$ cd $(brew --prefix)
$ mkdir -p etc
$ echo 'address=/.localdev/127.0.0.1' > etc/dnsmasq.conf
```

After this ansure that `dnsmasq` is running, on macOs you can start it using `brew`:
```shell
$ sudo brew services start dnsmasq
```

You can check that `dnsmasq` is running and working correctly by resolving any local domain like
`something-random.localdev` with `host` or `nslookup`. For example:

```shell
$ host something-random.localdev 127.0.0.1
Using domain server:
Name: 127.0.0.1
Address: 127.0.0.1#53
Aliases:

something-random.localdev has address 127.0.0.1
```

Now that you have your local nameserver you need to ensure your local machine is actually using
this nameserver. This can be done by adding the following line to your `/etc/resolver/localdev`
file:

```
nameserver 127.0.0.1
```

You may use the following commands on macOs to do this:
```shell
$ sudo mkdir -p /etc/resolver
$ sudo bash -c 'echo "nameserver 127.0.0.1" > /etc/resolver/localdev'
```

You can verify the usage of the new resolver for `.localdev` domains using `scutil --dns` on macOS.

## Check traefik is running

Now that the domain, the namesever and traefik are up and running you should be able to point your
browser to `http://traefik.localdev/` and see the traefik dashboard. If you see the dashboard you
are ready to go.

If `traefik` is not accessible yet a **reboot** might help. Otherwise please check the setup process again.

# Add traefik using `.localdev` domains to your project

Adding `traefik` to your project is faily simple, if you are used to docker/podman compose files. See
the [offical documentaion](https://docs.docker.com/reference/compose-file/) for details.

I will now guild you through the necessary steps to add `traefik` to your project. I will use the
following example project as a base.

```yaml
name: example  # Set the COMPOSE_PROJECT_NAME to 'example', just for this documentation

services:
  www:
    image: docker.io/nginx
```

To add the `traefik` setup to this configuration we will need to add labels:

```yaml
name: example

services:
  www:
    image: docker.io/nginx
    labels:
      # Enable traefik, by default traefik will not expose any services
      - traefik.enable=true
      # Setup the correct port to be used by treafik to access the service, IF REQUIRED
      #- traefik.http.services.${COMPOSE_PROJECT_NAME}_www.loadbalancer.server.port=80
```

You may also setup HTTP, authentication, some domain other than the default and tons of other
things using just labels. See the [traefik documentation](https://doc.traefik.io/traefik/) for
details. I added a configuration for a manual port setup in the example above. Note you will only
need this if your container does not `EXPOSE` the port you want to use.

With just the label your project will still not be accessible. This is due to the fact that docker/podman
will create a separate network for all of your projects. So the `traefik` container will use a different
network that your `nginx` container, which means traefik cannot reach the `nginx` container.

To fix this issue the `traefik` container provides a network called `traefik_gateway`. This network
was created when you did run `nur run` before and can be used inside your project. To use the network
extend the configuration to the following:

```yaml
name: example

services:
  www:
    image: docker.io/nginx
    labels:
      - traefik.enable=true
    # Add the required networks to your service
    networks:
      - default
      - traefik_gateway

networks:
  # Keep the original default network, this is required if your services need to reach each other
  default:
  # Add the additional `traefik_gateway` network, but mark it as external so the existing network
  # will be re-used
  traefik_gateway:
    external: true
```

If you now start your project using `docker compose up` or `podman compose up` you should be able to
access your project using the domain `www.example.localdev` using your browser:
[http://www.example.localdev/](http://www.example.localdev/)

**Note:** This setup is also provided in the `example` directory.
