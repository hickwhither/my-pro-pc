local class = {}
function class:__call(...)
    local object = {}
    setmetatable(object, self)
    if self.__init then
        self.__init(object, ...)
    end 
    return object
end
return function()
    local newClass = {}
    newClass.__index = newClass
    return setmetatable(newClass, class)
end