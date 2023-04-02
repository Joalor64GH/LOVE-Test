local parseXml = require "lib.xmlParser"

local stencilSprite, stencilX, stencilY = {}, 0, 0
local function stencil()
	if stencilSprite then
		love.graphics.push()
		love.graphics.translate(
			stencilX + stencilSprite.clipRect.x +
			stencilSprite.clipRect.width * 0.5,
			stencilY + stencilSprite.clipRect.y +
			stencilSprite.clipRect.height * 0.5)
		love.graphics.rotate(stencilSprite.angle)
		love.graphics.translate(-stencilSprite.clipRect.width * 0.5, -stencilSprite.clipRect.height * 0.5)
		love.graphics.rectangle("fill", -stencilSprite.width * 0.5, -stencilSprite.height * 0.5,
			stencilSprite.clipRect.width, stencilSprite.clipRect.height)
		love.graphics.pop()
	end
end

local Sprite = Object:extend()

Sprite.defaultCamera = nil

function Sprite.newFrame(name, x, y, w, h, sw, sh, ox, oy, ow, oh)
	local aw, ah = x + w, y + h
	return {
		name = name,
		quad = love.graphics.newQuad(x, y, aw > sw and w - (aw - sw) or w,
			ah > sh and h - (ah - sh) or h, sw, sh),
		width = ow == nil and w or ow,
		height = oh == nil and h or oh,
		offset = { x = ox == nil and 0 or ox, y = oy == nil and 0 or oy }
	}
end

function Sprite.getFramesFromSparrow(texture, description)
	if type(texture) == "string" then texture = love.graphics.newImage(texture) end

	local frames = { texture = texture, frames = {} }
	local sw, sh = texture:getDimensions()
	for _, c in pairs(parseXml(description).TextureAtlas.children) do
		if c.name == "SubTexture" then
			table.insert(frames.frames,
				Sprite.newFrame(c.attrs.name, tonumber(c.attrs.x),
					tonumber(c.attrs.y), tonumber(c.attrs.width),
					tonumber(c.attrs.height), sw, sh,
					tonumber(c.attrs.frameX),
					tonumber(c.attrs.frameY),
					tonumber(c.attrs.frameWidth),
					tonumber(c.attrs.frameHeight)))
		end
	end

	return frames
end

function Sprite:new(x, y, texture)
	if x == nil then x = 0 end
	if y == nil then y = 0 end
	self.x = x
	self.y = y

	self.texture = nil
	self.width, self.height = 0, 0
	self.antialiasing = true

	self.camera = nil

	self.alive = true
	self.exists = true

	self.origin = { x = 0, y = 0 }
	self.offset = { x = 0, y = 0 }
	self.scale = { x = 1, y = 1 }
	self.shear = { x = 0, y = 0 }
	self.scrollFactor = { x = 1, y = 1 }
	self.clipRect = nil
	self.flipX = false
	self.flipY = false

	self.color = { 1, 1, 1 }
	self.alpha = 1
	self.angle = 0

	self.__frames = nil
	self.__animations = nil

	self.curAnim = nil
	self.curFrame = nil
	self.animFinished = nil
	self.animPaused = false

	if texture then self:load(texture) end
end

function Sprite:load(texture, width, height)
	if type(texture) == "string" then texture = love.graphics.newImage(texture) end
	self.texture = texture

	self.width = width
	if self.width == nil then self.width = self.texture:getWidth() end
	self.height = height
	if self.height == nil then self.height = self.texture:getHeight() end

	self.curAnim = nil
	self.curFrame = nil
	self.animFinished = nil

	return self
end

function Sprite:setFrames(frames)
	self.__frames = frames.frames
	self.texture = frames.texture

	self:load(frames.texture)
	self.width, self.height = self:getFrameDimensions()
	self:centerOrigin()
end

function Sprite:getCurrentFrame()
	if self.curAnim then
		return self.curAnim.frames[math.floor(self.curFrame)]
	elseif self.__frames then
		return self.__frames[1]
	end
	return nil
end

function Sprite:getFrameWidth()
	local f = self:getCurrentFrame()
	if f then
		return f.width
	else
		return self.texture:getWidth()
	end
end

function Sprite:getFrameHeight()
	local f = self:getCurrentFrame()
	if f then
		return f.height
	else
		return self.texture:getHeight()
	end
end

function Sprite:getFrameDimensions()
	return self:getFrameWidth(), self:getFrameHeight()
end

function Sprite:setGraphicSize(width, height)
	if width == nil then width = 0 end
	if height == nil then height = 0 end

	self.scale = {
		x = width / self:getFrameWidth(),
		y = height / self:getFrameHeight()
	}

	if width <= 0 then
		self.scale.x = self.scale.y
	elseif height <= 0 then
		self.scale.y = self.scale.x
	end
end

function Sprite:updateHitbox()
	local w, h = self:getFrameDimensions()

	self.width = math.abs(self.scale.x) * w
	self.height = math.abs(self.scale.y) * h

	self.offset = { x = -0.5 * (self.width - w), y = -0.5 * (self.height - h) }
	self:centerOrigin()
end

function Sprite:centerOffsets()
	self.offset.x, self.offset.y = (self:getFrameWidth() - self.width) * 0.5,
		(self:getFrameHeight() - self.height) * 0.5
end

function Sprite:centerOrigin()
	self.origin.x, self.origin.y = self:getFrameWidth() * 0.5,
		self:getFrameHeight() * 0.5
end

function Sprite:setScrollFactor(value)
	self.scrollFactor.x, self.scrollFactor.y = value, value
end

-- IF THE SPRITE HAS A CAMERA, MAKE SURE THE CAMERA IS ATTACHED!!
function Sprite:getScreenPosition(camera)
	local tx, ty = 0, 0
	if camera then
		tx, ty = camera:getPosition(0, 0)
		tx, ty = tx * self.scrollFactor.x, ty * self.scrollFactor.y
	end
	return self.x + tx, self.y + ty
end

function Sprite:getMidpoint()
	return { x = self.x + self.width * 0.5, y = self.y + self.height * 0.5 }
end

function Sprite:getGraphicMidpoint()
	return {
		x = self.x + self:getFrameWidth() * 0.5,
		y = self.y + self:getFrameHeight() * 0.5
	}
end

function Sprite:screenCenter(axes)
	if axes == nil then axes = "xy" end
	if axes:find("x") then self.x = (push.getWidth() - self.width) * 0.5 end
	if axes:find("y") then self.y = (push.getHeight() - self.height) * 0.5 end
	return self
end

function Sprite:addAnimByPrefix(name, prefix, framerate, looped)
	if framerate == nil then framerate = 30 end
	if looped == nil then looped = true end

	local anim = { name = name, framerate = framerate, looped = looped, frames = {} }
	for _, f in ipairs(self.__frames) do
		if f.name:startsWith(prefix) then table.insert(anim.frames, f) end
	end

	if not self.__animations then self.__animations = {} end
	self.__animations[name] = anim
end

function Sprite:addAnimByIndices(name, prefix, indices, framerate, looped)
	if framerate == nil then framerate = 30 end
	if looped == nil then looped = true end

	local anim = { name = name, framerate = framerate, looped = looped, frames = {} }
	local subEnd = #prefix + 1
	for _, i in ipairs(indices) do
		for _, f in ipairs(self.__frames) do
			if f.name:startsWith(prefix) and tonumber(string.sub(f.name, subEnd)) == i then
				table.insert(anim.frames, f)
				break
			end
		end
	end

	if not self.__animations then self.__animations = {} end
	self.__animations[name] = anim
end

function Sprite:play(anim, force)
	if not force and self.curAnim and self.curAnim.name == anim and
		not self.animFinished then
		self.animFinished = false
		self.animPaused = false
		return
	end

	self.curAnim = self.__animations[anim]
	self.curFrame = 1
	self.animFinished = false
	self.animPaused = false
end

function Sprite:stop()
	if self.curAnim then
		self.animFinished = true
		self.animPaused = true
	end
end

function Sprite:finish()
	if self.curAnim then
		self:stop()
		self.curFrame = #self.curAnim.frames
	end
end

function Sprite:destroy()
	self.exists = false

	self.texture = nil

	self.origin.x, self.origin.y = 0, 0
	self.offset.x, self.offset.y = 0, 0
	self.scale.x, self.scale.y = 1, 1

	self.__frames = nil
	self.__animations = nil

	self.curAnim = nil
	self.curFrame = nil
	self.animFinished = nil
	self.animPaused = false
end

function Sprite:kill()
	self.alive = false
	self.exists = false
end

function Sprite:revive()
	self.alive = true
	self.exists = true
end

function Sprite:update(dt)
	if self.alive and self.exists and self.curAnim and not self.animFinished and
		not self.animPaused then
		self.curFrame = self.curFrame + self.curAnim.framerate * dt
		if self.curFrame >= #self.curAnim.frames then
			if self.curAnim.looped then
				self.curFrame = 1
			else
				self.animFinished = true
			end
		end
	end
end

function Sprite:draw()
	if self.exists and self.alive and self.texture and
		(self.alpha > 0 or self.scale.x > 0 or self.scale.y > 0) then
		local cam = self.camera or Sprite.defaultCamera
		local x, y = self:getScreenPosition(cam)
		local f, r, sx, sy, ox, oy, kx, ky = self:getCurrentFrame(), self.angle,
			self.scale.x, self.scale.y,
			self.origin.x, self.origin.y,
			self.shear.x, self.shear.y

		love.graphics
			.setColor(self.color[1], self.color[2], self.color[3], self.alpha)

		local min, mag, anisotropy = self.texture:getFilter()
		local mode = self.antialiasing and "linear" or "nearest"
		self.texture:setFilter(mode, mode, anisotropy)

		if cam then cam:attach() end

		if self.flipX then sx = -sx end
		if self.flipY then sy = -sy end

		x, y = x + ox - self.offset.x, y + oy - self.offset.y

		if f then
			ox, oy = ox + f.offset.x, oy + f.offset.y
		end

		if self.clipRect then
			stencilSprite, stencilX, stencilY = self, x, y
			love.graphics.stencil(stencil, "replace", 1)
			love.graphics.setStencilTest("greater", 0)
		end

		if not f then
			love.graphics.draw(self.texture, x, y, r, sx, sy, ox, oy, kx, ky)
		else
			love.graphics.draw(self.texture, f.quad, x, y, r, sx, sy, ox, oy, kx, ky)
		end

		if cam then cam:detach() end

		if self.clipRect then
			love.graphics.setStencilTest()
		end

		love.graphics.setColor(1, 1, 1)

		self.texture:setFilter(min, mag, anisotropy)
	end
end

return Sprite