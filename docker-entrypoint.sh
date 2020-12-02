#/bin/sh

## Required vars
# CPAD_MAIN_DOMAIN
# CPAD_SANDBOX_DOMAIN
#
## Optional vars
# CPAD_API_DOMAIN
# CPAD_FILES_DOMAIN
#
## Both these vars must be set in order for nginx to terminate TLS
# CPAD_TLS_CERT
# CPAD_TLS_KEY
## If dhparam.pem file is absent it will be generated
# CPAD_TLS_DHPARAM
#
# CPAD_TRUSTED_PROXY
# CPAD_REALIP_HEADER
# CPAD_REALIP_RECURSIVE
#
## Testing vars, may be removed later
# CPAD_HTTP2_DISABLE="true"
#

set -e

CPAD_HOME="/cryptpad"

# Since Nginx configuration is copied from the official image we need to
# correct some stuff
# Fix log path
sed -i -e "s@\(error_log\) */.* \(.*;\)@\1 /dev/stderr \2@" \
       -e "s@\(access_log\) */.* \(.*;\)@\1 /dev/stdout \2@" \
       ${CPAD_NGINX_CONF:=/etc/nginx/nginx.conf}

# Remove nginx default enabled conf
if [ -f /etc/nginx/conf.d/default.conf ]; then
  rm /etc/nginx/conf.d/default.conf
fi

# Test if nginx config file already exists (eg: docker swarm config)
# if absent, copy example and apply corrections
if [ ! -f "${CPAD_NGINX_CPAD_CONF:=/etc/nginx/conf.d/cryptpad.conf}" ]; then

  # Copy nginx config example from Cryptpad
  cp $CPAD_HOME/docs/example.nginx.conf $CPAD_NGINX_CPAD_CONF

  # Set domains
  if [ -z "${CPAD_MAIN_DOMAIN:-}" ]; then
    echo "Error: No main domain specified"
    exit 1
  else
    sed -i "s@your-main-domain.com@$CPAD_MAIN_DOMAIN@g" $CPAD_NGINX_CPAD_CONF
  fi

  if [ -z "${CPAD_SANDBOX_DOMAIN:-}" ]; then
    echo "Error: No sandbox domain specified"
    exit 1
  else
    sed -i "s@your-sandbox-domain.com@$CPAD_SANDBOX_DOMAIN@g" $CPAD_NGINX_CPAD_CONF
  fi

  if [ -z "${CPAD_API_DOMAIN}" ]; then
    sed -i "s@api.$CPAD_MAIN_DOMAIN@\$\{main_domain\}@" $CPAD_NGINX_CPAD_CONF
  fi

  if [ -z "${CPAD_FILES_DOMAIN}" ]; then
    sed -i "s@files.$CPAD_MAIN_DOMAIN@\$\{main_domain\}@" $CPAD_NGINX_CPAD_CONF
  fi

  # Change nginx document root
  sed -i "s@\(root\) */.*\([^;]\)@\1 $CPAD_HOME@" $CPAD_NGINX_CPAD_CONF

  # Wether or not Nginx should terminate TLS (defaults to true)
  if [ -n "$CPAD_TLS_CERT" \
    -a -n "$CPAD_TLS_KEY" ]; then

    # If cert is present, set path. If not, exit with error
    if [ -f "$CPAD_TLS_CERT" ]; then
      sed -i "s@\( *ssl_certificate[^_key] *\).*[^;]@\1$CPAD_TLS_CERT@" $CPAD_NGINX_CPAD_CONF
    else
      echo "Error: Missing TLS certificate file"
      exit 1
    fi

    # If key is present, set path. If not, exit with error
    if [ -f "$CPAD_TLS_KEY" ]; then
      sed -i "s@\( *ssl_certificate_key *\).*[^;]@\1$CPAD_TLS_KEY@" $CPAD_NGINX_CPAD_CONF
    else
      echo "Error: Missing TLS key file"
      exit 1
    fi

    # This option is only useful for OCSP stapling which Cryptpad doesn't use
    # so we'll comment it to avoid errors.
    sed -i "s@\(ssl_trusted_certificate\)@#\1@" $CPAD_NGINX_CPAD_CONF

    # If no DH parameters are provided, generate them
    if [ ! -f "${CPAD_TLS_DHPARAM:=/etc/nginx/dhparam.pem}" ]; then
      # Generate DH parameters
      openssl dhparam -out $CPAD_TLS_DHPARAM 4096
    fi

  # If no TLS termination
  else
    # Make Nginx listen on 80 in plaintext
    # and comment out all ssl related options
    sed -i  -e "s@\(^.*\) \+443 ssl\(.*$\)@\1 80\2@" \
            -e "s@[^#]ssl_@ #ssl_@g" $CPAD_NGINX_CPAD_CONF
  fi

  # Should Nginx use http_realip_module
  if [ -n "${CPAD_TRUSTED_PROXY:=}" ]; then
    # Set trusted proxy
    sed -i  -e "/listen/ G" \
    -e "/listen/ a \   \ # Set trusted proxy and header containing real client IP" \
    -e "/listen/ a \   \ set_real_ip_from  $CPAD_TRUSTED_PROXY;" $CPAD_NGINX_CPAD_CONF

    # Set header to get real client IP from
    if [ -n "${CPAD_REALIP_HEADER:-}" ]; then
      sed -i "/set_real_ip_from/ a \   \ real_ip_header    $CPAD_REALIP_HEADER;" $CPAD_NGINX_CPAD_CONF
    fi

    # Should Nginx perform a recursive search to get real client IP
    if [ -n "${CPAD_REALIP_RECURSIVE:-}" ]; then
      sed -i "/set_real_ip_from/ a \   \ real_ip_recursive $CPAD_REALIP_RECURSIVE;" $CPAD_NGINX_CPAD_CONF
    fi
  fi

  # Should nginx use HTTP2 (defaults to false)
  if [ "${CPAD_HTTP2_DISABLE:-false}" = "true" ]; then
    sed -i  -e "s@\(^.*\) \+http2\(.*$\)@\1\2@" $CPAD_NGINX_CPAD_CONF
  fi

  ## WIP
  # If cryptad conf isn't provided
  # if [ ! -f "$CPAD_CONF" ]; then
  #   echo -e "\n\
  #         ############################################### \n\
  #         Warning: No config file provided for cryptpad \n\
  #         We will create a basic one for now but you should rerun this service \n\
  #         by providing a file with your settings \n\
  #         eg: docker run -v /path/to/config.js:/cryptpad/config/config.js \n\
  #         ############################################### \n"
  #
  #   cp $CPAD_HOME/config/config.example.js $CPAD_CONF
  #
  #   # Set domains
  #   sed -i  -e "s@\(httpUnsafeOrigin:\).*[^,]@\1 'https://$CPAD_MAIN_DOMAIN'@" \
  #           -e "s@\(^ *\).*\(httpSafeOrigin:\).*[^,]@\1\2 'https://$CPAD_SANDBOX_DOMAIN'@" $CPAD_CONF
  #
  #   # Set admin email
  #   if [ -z "$CPAD_ADMIN_EMAIL" ]; then
  #     echo "Error: Missing admin email (Did you read the config?)"
  #     exit 1
  #   else
  #     sed -i "s@\(adminEmail:\).*[^,]@\1 '$CPAD_ADMIN_EMAIL'@" $CPAD_CONF
  #   fi
  # fi

fi

exec "$@"
