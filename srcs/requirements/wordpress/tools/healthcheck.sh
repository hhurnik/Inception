#!/bin/sh
set -eu

# [EN] Query PHP-FPM's built-in ping endpoint over FastCGI.
# [PL] Odpytaj wbudowany endpoint ping PHP-FPM przez FastCGI.
response=$(
    SCRIPT_NAME=/ping \
    SCRIPT_FILENAME=/ping \
    REQUEST_METHOD=GET \
    cgi-fcgi -bind -connect 127.0.0.1:9000 2>/dev/null
)
printf '%s\n' "$response" | grep -q 'pong'
