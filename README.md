# CryptPad docker  

This repository has been created as part of an ongoing effort to separate docker from [the CryptPad platform repo](https://github.com/xwiki-labs/cryptpad).

The officially recommended deployment method is to use the `example.nginx.conf` file provided by the core repo and to manage updates directly on the host system using `git`, `npm` (as provided by [nvm](https://github.com/nvm-sh/nvm)) and `bower`.

Docker images and their supporting configuration files are provided as a community effort by those using them, with support provided by the core development team on a _best-effort_ basis. Keep in mind that the core team neither uses nor tests Docker images, so your results may vary.

## Migration
Please see the [migration guide](MIGRATION.md) for further information on switching to this repository.  

## General notices  
* **Important**: New images tagged `nginx` and `nginx-alpine` have been added to this repository. The `docker-compose.yml` and `traefik2.yml` examples files have been modified to use the `nginx` image because the legacy versions didn't provide Content-Security-Policy headers which is a requirement to properly expose CryptPad to the internet.  
It is recommended to use the `promasu/cryptpad:nginx` image (see [Standalone Cryptpad](#cryptpad-proxied-by-nginx)).  

* Mounted files and folders for CryptPad have to be owned by userid 4001. It is possible you have to run `sudo chown -R 4001:4001 filename`. If your container engine uses namespacing to shift uids and gids in the containers, you need correct the uid and gid or to run the command from within the container.  

## Standalone CryptPad  
Tags: `latest` and `alpine`  
Files: `Dockerfile` and `Dockerfile-alpine`  

This image provides CryptPad served by Node without certs or CSP. It is up to you to deploy it behind a reverse proxy as per CryptPad's devs recommendations (see [Opening CryptPad to the Internet](https://github.com/xwiki-labs/cryptpad/wiki/Installation-guide#opening-cryptpad-to-the-internet)).  
It is kept in order to avoid breaking existing deployment.
If you already have a reverse proxy with CSP properly configured, you can keep using this image.  
Otherwise you should use the `nginx` or `nginx-alpine` versions.

#### Usage  

##### Run:  
```
docker run -d -p 3000:3000 -p 3001:3001 promasu/cryptpad
```  

##### Run with customizations:  
```
docker run -d -p 3000:3000 -p 3001:3001 -v ${PWD}/customize:/cryptpad/customize promasu/cryptpad
```  

##### Run with configuration:  
```
docker run -d -p 3000:3000 -p 3001:3001 -v ${PWD}/config.js:/cryptpad/config/config.js promasu/cryptpad
```  

##### Run with persistent data:  
```
docker run -d -p 3000:3000 -p 3001:3001 -v ${PWD}/data/blob:/cryptpad/blob \
-v ${PWD}/data/block:/cryptpad/block -v ${PWD}/customize:/cryptpad/customize \
-v ${PWD}/data/data:/cryptpad/data -v ${PWD}/data/files:/cryptpad/datastore promasu/cryptpad
```

## CryptPad proxied by Nginx  
Tags: `nginx` and `nginx-alpine`  
Files: `Dockerfile-nginx` and `Dockerfile-nginx-alpine`  

This image provides CryptPad proxied by Nginx. It offers more configuration options than the standalone version (but will not run if the bare minimum options aren't set) and lets Nginx handle the different HTTP headers like CSP.  
The `docker-entrypoint.sh` script copies Nginx configuration from the example provided in CryptPad repository (see file [`example.nginx.conf`](https://github.com/xwiki-labs/cryptpad/blob/main/docs/example.nginx.conf)) and substitutes the deployment environment variables.

* With minimum settings, Nginx will listen for unencrypted HTTP2 requests on port 80. Most browsers won't be able to connect without a reverse proxy to upgrade the connection (also if you use Traefik, please read `docker-compose.yml` comment above this option).  
To disable HTTP2 set the environment variable `CPAD_HTTP2_DISABLE` to `true`.  

* If you'd prefer Nginx to terminate TLS connections, provide a fullchain certificate and a key and set `CPAD_TLS_CERT` and `CPAD_TLS_KEY`. Both variables MUST be set for the entrypoint script to set paths in config. You can also provide Diffie-Hellman parameters with `CPAD_TLS_DHPARAM`. If no `dhparam.pem` file is provided, it will be generated upon container start. Beware that this is a time consuming step.  

#### Environment variables  

| Variables | Description | Required | Default |
| --- | --- | --- | --- |
| `CPAD_MAIN_DOMAIN` | CryptPad main domain FQDN | Yes | None |
| `CPAD_SANDBOX_DOMAIN` | CryptPad sandbox subdomain FQDN | Yes | None |
| `CPAD_API_DOMAIN` | CryptPad API subdomain FQDN| No | `$CPAD_MAIN_DOMAIN` |
| `CPAD_FILES_DOMAIN` | CryptPad files subdomain FQDN | No | `$CPAD_MAIN_DOMAIN` |
| `CPAD_TRUSTED_PROXY` | Trusted proxy address or CIDR | No | None |
| `CPAD_REALIP_HEADER`| Header to get client IP from (`X-Real-IP` or `X-Forwarded-For`) | No | `X-Real-IP` |
| `CPAD_REALIP_RECURSIVE`| Instruct Nginx to perform a recursive search to find client's real IP (`on`/`off`) (see [ngx_http_realip_module](https://nginx.org/en/docs/http/ngx_http_realip_module.html)) | No | `off` |
| `CPAD_TLS_CERT` | Path to TLS certificate file | No | None |
| `CPAD_TLS_KEY` | Path to TLS private key file | No | None |
| `CPAD_TLS_DHPARAM` | Path to Diffie-Hellman parameters file | No | `/etc/nginx/dhparam.pem` |
| `CPAD_HTTP2_DISABLE` | Disable HTTP2, mostly meant for test purpose | No | `false` |

#### Usage

##### Run with minimal settings:  
```
docker run -d -e "CPAD_MAIN_DOMAIN=example.com" -e "CPAD_SANDBOX_DOMAIN=sandbox.example.com" -p 80:80 promasu/cryptpad:nginx
```  

##### Run with configuration:
```
docker run -d -e "CPAD_MAIN_DOMAIN=example.com" -e "CPAD_SANDBOX_DOMAIN=sandbox.example.com" \
-v ${PWD}/dhparam.pem:/path/to/dhparam.pem -p 80:80 promasu/cryptpad:nginx
```

##### Run with TLS:  
```
docker run -d -e "CPAD_MAIN_DOMAIN=example.com" -e "CPAD_SANDBOX_DOMAIN=sandbox.example.com" \
-e "CPAD_TLS_CERT=/path/to/cert.pem" -e "CPAD_TLS_KEY=/path/to/key.pem" \
-e "CPAD_TLS_DHPARAM=/path/to/dhparam.pem" -v ${PWD}/cert.pem:/path/to/cert.pem \
-v ${PWD}/key.pem:/path/to/key.pem -v ${PWD}/dhparam.pem:/path/to/dhparam.pem \
-p 443:443 promasu/cryptpad:nginx
```  

##### Run behind a reverse proxy  
```
docker run -d -e "CPAD_MAIN_DOMAIN=example.com" -e "CPAD_SANDBOX_DOMAIN=sandbox.example.com" \
-e "CPAD_TRUSTED_PROXY=10.0.0.0/8" -e "CPAD_REALIP_HEADER=X-Forwarded-For" \
-e "CPAD_REALIP_RECURSIVE=on" -p 80:80 promasu/cryptpad:nginx
```  

##### Run with customizations:  
```
docker run -d -e "CPAD_MAIN_DOMAIN=example.com" -e "CPAD_SANDBOX_DOMAIN=sandbox.example.com" \
-v ${PWD}/customize:/cryptpad/customize -p 80:80 promasu/cryptpad:nginx
```

##### Run with persistent data:  
```
docker run -d -e "CPAD_MAIN_DOMAIN=example.com" -e "CPAD_SANDBOX_DOMAIN=sandbox.example.com" \
-v ${PWD}/data/blob:/cryptpad/blob -v ${PWD}/data/block:/cryptpad/block \
-v ${PWD}/customize:/cryptpad/customize -v ${PWD}/data/data:/cryptpad/data \
-v ${PWD}/data/files:/cryptpad/datastore -p 80:80 promasu/cryptpad:nginx
```

#### Docker-compose

##### Run:
`docker-compose up`

##### Run with traefik2 labels:
`docker-compose -f docker-compose.yml -f traefik2.yml up`
