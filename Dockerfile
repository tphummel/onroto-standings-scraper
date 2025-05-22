FROM node:23.11.1-alpine3.21

COPY ./ /var/app
WORKDIR /var/app
RUN ["npm", "install"]

ENTRYPOINT ["./bin.js"]
