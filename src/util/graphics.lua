local graphics = {
    --@description To be called once before the frame is drawn.
    --@param window love.Window
    preDraw = function(window)
        love.graphics.push()
        love.graphics.translate(window.translateX, window.translateY)
        love.graphics.scale(window.scale, window.scale)
    end,
}

return graphics