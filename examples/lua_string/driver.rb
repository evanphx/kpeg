require_relative 'lua_string.kpeg'

ls = LuaString.new("[[blah]]")
ls.parse

p ls.result

ls = LuaString.new("[==[blah2]==]")
ls.parse

p ls.result

ls = LuaString.new("[==[embeded]stuff]==]")
ls.parse

p ls.result

ls = LuaString.new("[==[embeded]=]stuff]==]")
ls.parse

p ls.result
