local window = {
    translateX = 0,
    translateY = 0,
    scale = 1,
    width = 1280,
    height = 720,
    physicalWidth = 1280,
    physicalHeight = 720,
}

local function resize(w, h)
    if not w and not h then
        w, h = love.graphics.getDimensions()
    end

    local w1, h1 = window.width, window.height
    window.scale = math.min(w / w1, h / h1)
    window.translateX = math.floor((w - w1 * window.scale) / 2)
    window.translateY = math.floor((h - h1 * window.scale) / 2)
    window.physicalWidth = w
    window.physicalHeight = h
end

window.resize = resize

return window