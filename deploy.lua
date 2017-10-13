--
-- Created by IntelliJ IDEA.
-- User: arsen
-- Date: 27.09.17
-- Time: 14:15
-- To change this template use File | Settings | File Templates.
--

-- luarocks install JSON4Lua
-- luarocks install luacrypto

local json = require "json"
local crypto = require "crypto"

-- public global variable
local project = _G.project
local secret = _G.secret
local event = _G.event
local branch = _G.branch
local command = _G.command

local slackWebHook = _G.webhook_url

local deploy = {}

getmetatable('').__index = function (str, i)
    return string.sub(str, i, i)
end

local function const_eq (a, b)
    -- Check is string equals, constant time exec
    local equal = string.len(a) == string.len(b)
    for i = 1, math.max(string.len(a), string.len(b)) do
        equal = (a[i] == b[i]) and equal
    end
    return equal
end

local function verify_signature (hub_sign, data)
    local sign = 'sha1=' .. crypto.hmac.digest('sha1', data, secret)
    return const_eq(hub_sign, sign)
end

local function execute(message)
    local handle = io.popen('curl -X POST -H \'Content-type: application/json\' --data \'{"text":"' .. message .. '"}\' ' .. slackWebHook)
    handle:close()
end

--- Validate inbound request
-- @return mixed
function deploy.validate_hook ()
    -- should be POST method
    if ngx.req.get_method() ~= "POST" then
        ngx.log(ngx.ERR, "wrong event request method: ", ngx.req.get_method())
        execute(project .. ": Не правильный запрос.")
        return ngx.exit (ngx.HTTP_NOT_ALLOWED)
    end

    local headers = ngx.req.get_headers()
    -- with correct header
    if headers['X-GitHub-Event'] ~= event then
        ngx.log(ngx.ERR, "wrong event type: ", headers['X-GitHub-Event'])
        execute(project .. ": Не правильный тип.")
        return ngx.exit (ngx.HTTP_NOT_ACCEPTABLE)
    end

    -- should be json encoded request
    if headers['Content-Type'] ~= 'application/json' then
        ngx.log(ngx.ERR, "wrong content type header: ", headers['Content-Type'])
        execute(project .. ": Не правильный формат.")
        return ngx.exit (ngx.HTTP_NOT_ACCEPTABLE)
    end

    -- read request body
    ngx.req.read_body()
    local data = ngx.req.get_body_data()

    if not data then
        ngx.log(ngx.ERR, "failed to get request body")
        execute(project .. ": Пустое тело запроса.")
        return ngx.exit (ngx.HTTP_BAD_REQUEST)
    end

    -- validate GH signature
    if not verify_signature(headers['X-Hub-Signature'], data) then
        ngx.log(ngx.ERR, "wrong webhook signature")
        execute(project .. ": Не правильная подпись.")
        return ngx.exit (ngx.HTTP_FORBIDDEN)
    end

    data = json.decode(data)
    -- on master branch
    if data['ref'] ~= branch then
        ngx.say("Skip branch ", data['ref'])
        execute(project .. ": Не правильная ветка.")
        return ngx.exit (ngx.HTTP_OK)
    end

    return true
end

function deploy.run ()
    -- run command for deploy
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()

    ngx.say (result)
    execute(project .. ": Деплой выполнен.")
    return ngx.exit (ngx.HTTP_OK)
end

return deploy