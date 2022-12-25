local audio = require "lib.wave"

local function isFile(path)
    local info = love.filesystem.getInfo(path)
    return info and info.type == "file"
end

local paths = {
    cache = {},
    fonts = {}
}

function paths.clearCache()
    for p, o in pairs(paths.cache) do
        if not paths.isPersistant(p) then
            if o.type == "image" then
                o.object:release()
            elseif o.type == "source" then
                o.object:stop()
            elseif o.type == "frames" then
                o.object.texture:release()
                for _, f in pairs(o.object.frames) do
                    f.quad:release()
                end
            end
        end
    end
    paths.cache = {}
    collectgarbage()
end

function paths.getPath(key) return "assets/" .. key end

function paths.getText(key)
    local path = paths.getPath(key)
    if isFile(path) then
        return love.filesystem.read(path)
    end
    return nil
end

function paths.getFont(key, size)
    if size == nil then size = 12 end

    local path = paths.getPath("fonts/" .. key)
    local id = path .. "_" .. size
    local obj = paths.fonts[id]
    if not obj then
        obj = love.graphics.newFont(path, size)
        paths.fonts[id] = obj
    end
    return obj
end

function paths.getImage(key, cache)
    if cache == nil then cache = true end

    local path = paths.getPath("images/" .. key .. ".png")
    if cache then
        local obj = paths.cache[path]
        if not obj and isFile(path) then
            obj = {object = love.graphics.newImage(path), type = "image"}
            paths.cache[path] = obj
        end
        if obj then return obj.object end
    elseif isFile(path) then
        return love.graphics.newImage(path)
    end

    return nil
end

function paths.getAudioSource(key, type, cache)
    if cache == nil then cache = true end

    local path = paths.getPath(key .. ".ogg")
    if cache then
        local obj = paths.cache[path]
        if not obj and isFile(path) then
            obj = {object = audio:newSource(path, type), type = "source"}
            paths.cache[path] = obj
        end
        if obj then return obj.object end
    elseif isFile(path) then
        return audio:newSource(path, type)
    end

    return nil
end

function paths.getMusic(key, cache)
    return paths.getAudioSource("music/" .. key, "stream", cache)
end

function paths.getSound(key, cache)
    return paths.getAudioSource("sounds/" .. key, "static", cache)
end

function paths.playSound(key, cache)
    local sound = paths.getSound(key, cache)
    if sound then sound:play() end
    return sound
end

function paths.getSparrowFrames(key, cache)
    if cache == nil then cache = true end

    local xmlKey = "images/" .. key .. ".xml"
    local img, path = paths.getImage(key, cache), paths.getPath(xmlKey)
    if cache then
        local obj = paths.cache[path]
        if not obj and img and isFile(path) then
            obj = {
                object = Sprite.getFramesFromSparrow(img, paths.getText(xmlKey)),
                type = "frames"
            }
            paths.cache[path] = obj
        end
        if obj then return obj.object end
    elseif img and isFile(path) then
        return Sprite.getFramesFromSparrow(img, paths.getText(xmlKey))
    end

    return nil
end

return paths