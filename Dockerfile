FROM ubuntu as teredo

WORKDIR /src/

COPY . .

RUN apt update && \
apt install --no-install-recommends -y miredo curl && \
chmod +x /src/teredo.sh ;\
find /var/lib/apt/lists/ -maxdepth 1 -type f -print0 | xargs -0 rm 

ENTRYPOINT [ "/src/teredo.sh" ]