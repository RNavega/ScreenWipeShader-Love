--[[
    Screen wipe shader example, for use with in-game cinematics, screen transitions and such.
    Version 1.0.0.
    
    Code:
        Rafael Navega (2020)
        LICENSE: Public domain.
        
    Other assets with their own licenses:
        Pixel art image:
            Luiz Zuno (ansimuz.com) on OpenGameArt.com
        Wipe background image:
            Based on the LÖVE logo by Rude (https://love2d.org/wiki/L%C3%B6ve_Logo_Graphics)
]]
io.stdout:setvbuf("no")

local image = nil 
local mesh = nil
local currentShader = 'circle'
local useBlack = false

local dir = -1
local value = 0.0
local wipeCenter = {0.5, 0.5}
local maxRadius = 1.415 -- Start with the maximum radius possible, sqrt(2).


local circleWipePixelShaderCode = [[
// Comment the define below if you don't want a feathered edge.
#define FEATHER 0.05

// Uniform float in range [0.0, 1.0] that controls the wipe effect. The wipe
// will be invisible at 0.0 and fully formed at 1.0.
uniform float time;

// A 2D location on the UV space (ie normalized screen coordinates, (0,0) -> (1,1)), where
// the wipe circle should close at.
uniform vec2 wipeCenter;

// The BIGGEST distance, in UV units, from the 'wipeCenter' point to any other point on the UV space,
// as the reference radius. Since the UV space is a square, this is going to be the biggest
// distance from 'wipeCenter' to any of the 4 corners of the screen.
uniform float maxRadius;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec2 centerOffset = texture_coords - wipeCenter;
    // Make the iris shape a circle, otherwise it's an ellipse with the same ratio as the window.
    // 'love_ScreenSize' is an internal uniform set in (LÖVE v11.3): 
    // https://github.com/love2d/love/blob/master/src/modules/graphics/opengl/Shader.cpp#L718
    centerOffset.y *= (love_ScreenSize.y / love_ScreenSize.x);

#ifdef FEATHER
    // To avoid division-by-zero, we only divide by FEATHER if it's defined at all.
    float shiftedRadius = maxRadius * (1.0 - time);
    float centerOffsetLength = length(centerOffset) + FEATHER * time;
    float alpha = smoothstep(shiftedRadius, shiftedRadius + FEATHER, centerOffsetLength);
#else
    float shiftedRadius = maxRadius * (1.0 - time);
    float centerOffsetLength = length(centerOffset);
    float alpha = 1.0 - step(centerOffsetLength, shiftedRadius);
#endif
   
    vec4 texturecolor = Texel(tex, texture_coords);
    return vec4(texturecolor.rgb, alpha) * color;
}
]]


local horizontalWipePixelShaderCode = [[
// Comment the define below if you don't want a feathered edge.
#define FEATHER 0.25

uniform float time;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
#ifdef FEATHER
    float shiftedRadius = (1.0 - time);
    float shiftedU = texture_coords.x + FEATHER * time;
    float alpha = smoothstep(shiftedRadius, shiftedRadius + FEATHER, shiftedU);
#else
    float shiftedRadius = 1.0 - time;
    float alpha = 1.0 - step(texture_coords.x, shiftedRadius);
#endif
   
    vec4 texturecolor = Texel(tex, texture_coords);
    return vec4(texturecolor.rgb, alpha) * color;
}
]]


function love.load()
    love.window.setTitle('Screen Wipe Shader Example')
    love.window.setMode(704, 576 + 30)
    
    image = love.graphics.newImage('tiles-map_by_Luis_Zuno_(ansimuz).png')
    image:setFilter('nearest', 'nearest')
    pixelSize = {image:getPixelWidth()*2, image:getPixelHeight()*2}
    
    wipeBackground = love.graphics.newImage('wipe_background.png')
    wipeBackground:setFilter('nearest', 'nearest')    
    
    -- Simple quad mesh with position and UV data.
    mesh = love.graphics.newMesh(
        {
            {'VertexPosition', 'float', 2},
            {'VertexTexCoord', 'float', 2},
        },
        {
            {0.0, 0.0, 0.0, 0.0},
            {pixelSize[1], 0.0, 1.0, 0.0},
            {pixelSize[1], pixelSize[2], 1.0, 1.0},
            {0.0, pixelSize[2], 0.0, 1.0}
        },
        'fan',
        'static'
    )
    -- Use a texture for the wipe background.
    mesh:setTexture(wipeBackground)
    
    circleWipeShader = love.graphics.newShader(circleWipePixelShaderCode)
    horizontalWipeShader = love.graphics.newShader(horizontalWipePixelShaderCode)
end


function love.update(dt)
    value = value + dir*dt*0.75
    value = math.max(0.0, math.min(1.0, value))
end


function love.draw()
    love.graphics.setColor(1.0, 1.0, 1.0)
    love.graphics.draw(image, 0, 30, 0, 2.0, 2.0)
    
    if currentShader == 'circle' then
        love.graphics.setShader(circleWipeShader)
        circleWipeShader:send('time', value)
        circleWipeShader:send('wipeCenter', wipeCenter)    
        circleWipeShader:send('maxRadius', maxRadius)
    elseif currentShader == 'horizontal' then
        love.graphics.setShader(horizontalWipeShader)
        horizontalWipeShader:send('time', value)
    --elseif currentShader == (...) if more shader types are to be added.
    end
    
    -- Set a flat color if no texture is being used.
    if useBlack then
        love.graphics.setColor(0.0, 0.0, 0.0)
    end    
    love.graphics.draw(mesh, 0, 30)

    love.graphics.setShader(nil)
    love.graphics.setColor(0.0, 0.0, 0.0)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), 30)
    love.graphics.setColor(1.0, 1.0, 1.0)
    love.graphics.print(
        'Press Left/Right for the circle wipe, Up/Down for the horizontal wipe, hold Space for black color.', 9, 9
    )
end


function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'space' then
        useBlack = true
        mesh:setTexture(nil)
    else
        dir = -dir
        if key == 'left' or key == 'right' then
            currentShader = 'circle'
            if value == 0.0 or value == 1.0 then
                -- Recalculate some values for the circle wipe shader.
                wipeCenter[1], wipeCenter[2] = 0.5, 0.5
                -- The center of the circular wipe can be any 2D point on the UV space, that is, using
                -- normalized coordinates in range [0.0, 1.0].
                --wipeCenter[1], wipeCenter[2] = math.random(), math.random()
                -- Get the farthest distance from the wipe center to any of the four UV-space corners.
                local _farthestOffsetU = math.max(wipeCenter[1], 1.0-wipeCenter[1])
                local _farthestOffsetV = math.max(wipeCenter[2], 1.0-wipeCenter[2])
                maxRadius = math.sqrt(_farthestOffsetU*_farthestOffsetU + _farthestOffsetV*_farthestOffsetV)
            end
        elseif key == 'up' or key == 'down' then
            currentShader = 'horizontal'
        end
    end
end


function love.keyreleased(key)
    if key == 'space' then
        useBlack = false
        mesh:setTexture(wipeBackground)
    end
end
