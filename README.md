# lua-nginx-deploy

This module validate POST request from GitHub and execute linux command from Nginx user.

## Installing

Go to Nginx config directory:

```bash
cd /etc/nginx
```

Create lua script directory:

```bash
mkdir lua && cd lua
```

Clone this repository:

```bash
git clone git@github.com:2ski/lua-nginx-deploy.git
``` 

## Configuration

Nginx configuration:

```nginx
server {
  # ...
  
  location /deploy {
    client_body_buffer_size 3M;
    client_max_body_size 3M;
    
    content_by_lua_file /etc/nginx/lua/domain.com.lua;
  }
}
```

Where `domain.com.lua` is a deploy domain script:

```lua
local deploy = require('lua-nginx-deploy.deploy')

_G.secret = '<MY SUPRE SECRET>'
_G.event = 'push'
_G.branch = 'refs/heads/master'
_G.command = 'cd ~www-data/domain.com && git pull'

ngx.header.content_type = "text/plain; charset=utf-8"

if deploy.validate_hook() then
  deploy.run()
end
``` 