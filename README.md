# Teredo Network For Containers

You might develop your service as a container and you might to give a
 Teredo Network access to your Container service. You can use this container to giving Teredo Network access to your container or your host network.

To start teredo service for host network.

```bash
docker run -it --rm --privileged --network host ahmetozer/docker-teredo
```

If you want to give a teredo network for your container, you can
run below command.

```bash
# Please change container_name variable to your container id or name.
container_name="net-tools-service"

docker run -it --rm --privileged -v /proc/$(docker inspect -f '{{.State.Pid}}' $container_name)/ns/net:/var/run/netns/container ahmetozer/docker-teredo
```

Starting teredo service at system startup, you can replace `--rm` arg with `--restart always`.  
**Note:** This is only avaible for host network, because after restarting container pid are changed.

```bash
docker run -it --restart always --privileged --network host ahmetozer/docker-teredo
```

After restarting your server or container for automate find pid and setting teredo, set container name as variable and bind proc and docker socket to container.

```bash
docker run -it --rm --privileged -e container_name=net-tools-service -v /proc/:/proc2/ -v /var/run/docker.sock:/var/run/docker.sock --name teredo ahmetozer/docker-teredo
```

You might to remove default IPv6 access and only give Teredo access, set delro environment variable to yes. delro (Delete Default Route) function is has a backup mechanism. When the teredo container closes well, system reload old IPv6 routes to first container.
**NOTE:** I disabled delro in host to prevent any user mistake to delete default route on main network.

```bash
docker run -it --rm --privileged -e container_name=net-tools-service -e delro=yes -v /proc/:/proc2/ -v /var/run/docker.sock:/var/run/docker.sock --name teredo ahmetozer/docker-teredo
```
