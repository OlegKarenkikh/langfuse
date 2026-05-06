#!/bin/bash
sed -i 's/RUN cd packages\/kysely \&\& \\/RUN cd packages\/kysely \&\& mkdir -p dist\/esm dist\/cjs \&\& \\/g' web/Dockerfile
sed -i 's/RUN cd packages\/kysely \&\& \\/RUN cd packages\/kysely \&\& mkdir -p dist\/esm dist\/cjs \&\& \\/g' worker/Dockerfile
