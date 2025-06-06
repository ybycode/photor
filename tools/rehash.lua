-- This transforms a list of base16 encoded sha256 hash to a base32 hash.
-- Will be used to migrate hashes to their more compact form.
--
-- Assuming a list of "photo_id hash" Use if like this:
--
--    $ pv -l hashes.txt | lua rehash.lua > hashes_base32_lua.txt

local bit = bit32

-- Convert hex string to binary string
local function hex_to_bin(hex)
  return (hex:gsub("..", function(byte)
    return string.char(tonumber(byte, 16))
  end))
end

-- RFC 4648 Base32 alphabet
local alphabet = "abcdefghijklmnopqrstuvwxyz234567"

-- Encode binary string to Base32 (no padding)
local function base32_encode(data)
  local out = {}
  local buffer, bits = 0, 0

  for i = 1, #data do
    buffer = bit.bor(bit.lshift(buffer, 8), data:byte(i))
    bits = bits + 8
    while bits >= 5 do
      bits = bits - 5
      local index = bit.rshift(buffer, bits) % 32 + 1
      table.insert(out, alphabet:sub(index, index))
    end
  end

  if bits > 0 then
    local index = bit.lshift(buffer, 5 - bits) % 32 + 1
    table.insert(out, alphabet:sub(index, index))
  end

  return table.concat(out)
end

-- Read stdin
for line in io.lines() do
  local id, hex = line:match("(%S+)%s+(%x+)")
  local b32 = base32_encode(hex_to_bin(hex))
  print(id .. " " .. b32)
end
