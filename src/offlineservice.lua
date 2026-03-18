local OfflineService = _G.class()

function OfflineService:__init(name)
    assert(type(name) == "string", "Name must be a string")
    _G[name] = self
    self.name = name
    self.handlers = {}
    print("["..name.."] is here~")
end

return OfflineService