# Teredo Network For Containers

You might develop your service as a container and you might to give a
 Teredo Network access to your Container service. You can use this container to giving Teredo Network access to your container or your host network.

To start teredo service for host network.

```bash
docker run -it --rm --privileged --network host ahmetozer/docker-teredo
```

If you want to give a teredo network for your container, you can 

```bash
# Please change container_name variable to your container id or name.
container_name="net-tools-service"

docker run -it --rm --privileged -v /proc/$(docker inspect -f '{{.State.Pid}}' $container_name)/ns/net:/var/run/netns/container
```

Starting teredo service at system startup, you can replace `--rm` arg with `--restart always`.  
**Note:** This is only avaible for host network, because your container might 

```bash
docker run -it --restart always --privileged --network host ahmetozer/docker-teredo
```
