# CryptPad docker

This repository has been created as part of an ongoing effort to separate docker from [the CryptPad platform repo](https://github.com/xwiki-labs/cryptpad).

The officially recommended deployment method is to use the `example.nginx.conf` file provided by the core repo and to manage updates directly on the host system using `git`, `npm` (as provided by [nvm](https://github.com/nvm-sh/nvm)) and `bower`.

Docker images and their supporting configuration files are provided as a community effort by those using them, with support provided by the core development team on a _best-effort_ basis. Keep in mind that the core team neither uses nor tests Docker images, so your results may vary.

## Migration
Please see the [migration guide](MIGRATION.md) for further information on switching to this repository.

## Usage

### General notices
* Mounted files and folders have to be owned by userid 4001. It is possible you have to run 
`sudo chown -R 4001:4001 filename`

### Dockerfile

* Run: `docker run -d -p 3000:3000 -p 3001:3001 promasu/cryptpad`
* Run with customizations: `docker run -d -p 3000:3000 -p 3001:3001 -v customize:/cryptpad/customize promasu/cryptpad`
* Run with configuration: `docker run -d -p 3000:3000 -p 3001:3001 -v config.js:/cryptpad/config/config.js promasu/cryptpad`
* Run with persistent data: `docker run -d -p 3000:3000 -p 3001:3001 -v ${PWD}/data/blob:/cryptpad/blob -v ${PWD}/data/block:/cryptpad/block -v ${PWD}/customize:/cryptpad/customize -v ${PWD}/data/data:/cryptpad/data -v ${PWD}/data/files:/cryptpad/datastore promasu/cryptpad`

### Docker-compose

* Run: `docker-compose up`
* Run with traefik2 labels: `docker-compose -f docker-compose.yml -f traefik2.yml up`
