# Thin layer over the upstream Strata image so it runs as any UID set with `user:`.
# Upstream assumes root: setup writes into /opt/strata and, with no HOME, into /.config.
ARG BASE=strata-upstream:latest
FROM ${BASE}

# Writable by any UID (OpenShift-style). Only affects files inside the container.
RUN chmod -R a+rwX /opt/strata \
    && mkdir -p /data && chmod 1777 /data

# setup.py saves ~/.config/strata/settings.json; keep it on the persistent volume.
ENV HOME=/data
