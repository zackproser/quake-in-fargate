FROM florianpiesche/ioquake3-server 

WORKDIR /usr/local/games/quake3

COPY baseq3 baseq3 

EXPOSE 27960
EXPOSE 30000

CMD ["/bin/sh", "/usr/local/games/quake3/entrypoint.sh"]
