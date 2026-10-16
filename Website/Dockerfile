FROM node:24-alpine@sha256:ebfe2f90462722a7a4de65e91990e97fe0d401c70e0e762c5b53302f905ec1c1
LABEL org.opencontainers.image.title="a2emu" \
      org.opencontainers.image.description="Apple IIGS Player Builder website and downloads" \
      org.opencontainers.image.url="https://a2emu.theredhead.nl" \
      org.opencontainers.image.licenses="GPL-3.0-only"
ENV NODE_ENV=production PORT=8080 DATA_DIR=/data
WORKDIR /app
RUN mkdir /data && chown node:node /data
COPY --chown=node:node server.mjs ./server.mjs
COPY --chown=node:node dist/ ./public/
USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD node -e "fetch('http://127.0.0.1:'+process.env.PORT+'/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "server.mjs"]
