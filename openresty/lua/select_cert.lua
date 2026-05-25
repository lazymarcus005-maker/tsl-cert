local ssl = require("ngx.ssl")

local function read_case()
    local file = io.open("/state/current", "r")
    if not file then
        return "valid"
    end

    local current = file:read("*l") or "valid"
    file:close()
    return current
end

local current = read_case()
local cert_path = string.format("/certs/server/%s.crt", current)
local key_path = string.format("/certs/server/%s.key", current)

local cert_file = io.open(cert_path, "rb")
if not cert_file then
    ngx.log(ngx.ERR, "unable to open cert for case: ", current)
    return ngx.exit(ngx.ERROR)
end
local cert_pem = cert_file:read("*a")
cert_file:close()

local key_file = io.open(key_path, "rb")
if not key_file then
    ngx.log(ngx.ERR, "unable to open key for case: ", current)
    return ngx.exit(ngx.ERROR)
end
local key_pem = key_file:read("*a")
key_file:close()

local cert, cert_err = ssl.parse_pem_cert(cert_pem)
if not cert then
    ngx.log(ngx.ERR, "failed to parse cert for case ", current, ": ", cert_err)
    return ngx.exit(ngx.ERROR)
end

local key, key_err = ssl.parse_pem_priv_key(key_pem)
if not key then
    ngx.log(ngx.ERR, "failed to parse key for case ", current, ": ", key_err)
    return ngx.exit(ngx.ERROR)
end

local ok, clear_err = ssl.clear_certs()
if not ok then
    ngx.log(ngx.ERR, "failed to clear certs: ", clear_err)
    return ngx.exit(ngx.ERROR)
end

local ok_cert, set_cert_err = ssl.set_cert(cert)
if not ok_cert then
    ngx.log(ngx.ERR, "failed to set cert for case ", current, ": ", set_cert_err)
    return ngx.exit(ngx.ERROR)
end

local ok_key, set_key_err = ssl.set_priv_key(key)
if not ok_key then
    ngx.log(ngx.ERR, "failed to set key for case ", current, ": ", set_key_err)
    return ngx.exit(ngx.ERROR)
end
