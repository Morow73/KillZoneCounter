require "ISUI/Maps/ISWorldMap"

local KZC = {}
local DATA_KEY = "KillZoneCounter"
local RESIZE_HANDLE_RADIUS = 12

local function getPlayerData(create)
    local player = getPlayer()

    if not player then
        return nil
    end

    local playerModData = player:getModData()
    local data = playerModData[DATA_KEY]

    if not data and create then
        data = {}
        playerModData[DATA_KEY] = data
    end

    if not data then
        return nil
    end

    if type(data.zones) ~= "table" then
        data.zones = {}
        if data.zone then
            data.zone.kills = data.kills or 0
            data.zones[1] = data.zone
        end
    end

    data.zone = nil
    data.kills = nil

    for _, zone in ipairs(data.zones) do
        zone.kills = zone.kills or 0
    end

    return data
end

local function worldPointAt(map, x, y)
    return {
        x = map.mapAPI:uiToWorldX(x, y),
        y = map.mapAPI:uiToWorldY(x, y),
    }
end

local function makeZone(start, finish)
    return {
        x1 = math.min(start.x, finish.x),
        y1 = math.min(start.y, finish.y),
        x2 = math.max(start.x, finish.x),
        y2 = math.max(start.y, finish.y),
    }
end

local function getZoneCorners(map, zone)
    local corners = {
        { worldX = zone.x1, worldY = zone.y1, anchorX = zone.x2, anchorY = zone.y2 },
        { worldX = zone.x2, worldY = zone.y1, anchorX = zone.x1, anchorY = zone.y2 },
        { worldX = zone.x2, worldY = zone.y2, anchorX = zone.x1, anchorY = zone.y1 },
        { worldX = zone.x1, worldY = zone.y2, anchorX = zone.x2, anchorY = zone.y1 },
    }

    for _, corner in ipairs(corners) do
        corner.x = map.mapAPI:worldToUIX(corner.worldX, corner.worldY)
        corner.y = map.mapAPI:worldToUIY(corner.worldX, corner.worldY)
    end

    return corners
end

local function findZoneCorner(map, zones, mouseX, mouseY)
    local bestZone
    local bestAnchor
    local bestDistance = RESIZE_HANDLE_RADIUS * RESIZE_HANDLE_RADIUS

    for _, zone in ipairs(zones or {}) do
        for _, corner in ipairs(getZoneCorners(map, zone)) do
            local dx = mouseX - corner.x
            local dy = mouseY - corner.y
            local distance = dx * dx + dy * dy

            if distance <= bestDistance then
                bestZone = zone
                bestAnchor = { x = corner.anchorX, y = corner.anchorY }
                bestDistance = distance
            end
        end
    end

    return bestZone, bestAnchor
end

local function drawPencilLine(map, x1, y1, x2, y2, color, seed)
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    local segments = math.max(1, math.min(64, math.ceil(length / 18)))
    local normalX = length > 0 and -dy / length or 0
    local normalY = length > 0 and dx / length or 0
    local previousX = x1
    local previousY = y1

    for segment = 1, segments do
        local t = segment / segments
        local envelope = math.sin(math.pi * t)
        local noise = math.sin(segment * 12.9898 + seed * 78.233) * 43758.5453
        noise = (noise - math.floor(noise) - 0.5) * 1.6 * envelope
        local currentX = x1 + dx * t + normalX * noise
        local currentY = y1 + dy * t + normalY * noise

        map.javaObject:DrawLine(nil, previousX, previousY, currentX, currentY,
            1.4, color.r, color.g, color.b, color.a)
        previousX = currentX
        previousY = currentY
    end
end

local function drawZone(map, zone, color)
    local x1 = map.mapAPI:worldToUIX(zone.x1, zone.y1)
    local y1 = map.mapAPI:worldToUIY(zone.x1, zone.y1)
    local x2 = map.mapAPI:worldToUIX(zone.x2, zone.y1)
    local y2 = map.mapAPI:worldToUIY(zone.x2, zone.y1)
    local x3 = map.mapAPI:worldToUIX(zone.x2, zone.y2)
    local y3 = map.mapAPI:worldToUIY(zone.x2, zone.y2)
    local x4 = map.mapAPI:worldToUIX(zone.x1, zone.y2)
    local y4 = map.mapAPI:worldToUIY(zone.x1, zone.y2)
    local seed = zone.x1 * 0.013 + zone.y1 * 0.017

    drawPencilLine(map, x1, y1, x2, y2, color, seed + 1)
    drawPencilLine(map, x2, y2, x3, y3, color, seed + 2)
    drawPencilLine(map, x3, y3, x4, y4, color, seed + 3)
    drawPencilLine(map, x4, y4, x1, y1, color, seed + 4)
end

local function drawZoneHandles(map, zone)
    for _, corner in ipairs(getZoneCorners(map, zone)) do
        map.javaObject:DrawLine(nil, corner.x - 5, corner.y, corner.x + 5, corner.y, 4, 0, 0, 0, 1)
        map.javaObject:DrawLine(nil, corner.x, corner.y - 5, corner.x, corner.y + 5, 4, 0, 0, 0, 1)
        map.javaObject:DrawLine(nil, corner.x - 5, corner.y, corner.x + 5, corner.y, 2, 1, 1, 1, 1)
        map.javaObject:DrawLine(nil, corner.x, corner.y - 5, corner.x, corner.y + 5, 2, 1, 1, 1, 1)
    end
end

local function drawKillCount(map, zone, kills, index)
    local text = getText("IGUI_KZC_Zone") .. " " .. tostring(index)
        .. " - " .. getText("IGUI_KZC_Kills") .. " : " .. tostring(kills)
    local centerWorldX = (zone.x1 + zone.x2) / 2
    local centerWorldY = (zone.y1 + zone.y2) / 2
    local centerX = map.mapAPI:worldToUIX(centerWorldX, centerWorldY)
    local centerY = map.mapAPI:worldToUIY(centerWorldX, centerWorldY)
    local textManager = getTextManager()
    local textWidth = textManager:MeasureStringX(UIFont.Handwritten, text)
    local textHeight = textManager:getFontHeight(UIFont.Handwritten)

    map:drawText(text, centerX - textWidth / 2, centerY - textHeight / 2, 0, 0, 0, 1, UIFont.Handwritten)
end

function KZC.onZombieDead(zombie)
    local player = getPlayer()

    if not player or zombie:getAttackedBy() ~= player then
        return
    end

    local data = getPlayerData(false)

    if not data then
        return
    end

    local x = zombie:getX()
    local y = zombie:getY()

    for _, zone in ipairs(data.zones) do
        if x >= zone.x1 and x <= zone.x2 and y >= zone.y1 and y <= zone.y2 then
            zone.kills = zone.kills + 1
        end
    end
end

local originalMouseDown = ISWorldMap.onMouseDown
local originalMouseMove = ISWorldMap.onMouseMove
local originalMouseUp = ISWorldMap.onMouseUp
local originalRightMouseDown = ISWorldMap.onRightMouseDown
local originalRender = ISWorldMap.render

function ISWorldMap:onRightMouseDown(x, y)
    if isKeyDown(Keyboard.KEY_LSHIFT) or isKeyDown(Keyboard.KEY_RSHIFT) then
        local data = getPlayerData(false)

        if data then
            local point = worldPointAt(self, x, y)

            for index = #data.zones, 1, -1 do
                local zone = data.zones[index]

                if point.x >= zone.x1 and point.x <= zone.x2
                    and point.y >= zone.y1 and point.y <= zone.y2 then
                    table.remove(data.zones, index)
                    return true
                end
            end
        end
    end

    if originalRightMouseDown then
        return originalRightMouseDown(self, x, y)
    end
    return false
end

function ISWorldMap:onMouseDown(x, y)
    if isKeyDown(Keyboard.KEY_LSHIFT) or isKeyDown(Keyboard.KEY_RSHIFT) then
        self.kzcDrawing = true
        self.kzcStart = worldPointAt(self, x, y)
        self.kzcEnd = self.kzcStart
        return true
    end

    local data = getPlayerData(false)
    local zone, anchor = findZoneCorner(self, data and data.zones, x, y)

    if zone then
        self.kzcResizing = zone
        self.kzcResizeAnchor = anchor
        self.kzcResizeEnd = worldPointAt(self, x, y)
        return true
    end

    return originalMouseDown(self, x, y)
end

function ISWorldMap:onMouseMove(dx, dy)
    if self.kzcDrawing then
        local x = self:getMouseX()
        local y = self:getMouseY()

        self.kzcEnd = worldPointAt(self, x, y)

        return true
    end

    if self.kzcResizing then
        local x = self:getMouseX()
        local y = self:getMouseY()

        self.kzcResizeEnd = worldPointAt(self, x, y)

        return true
    end

    return originalMouseMove(self, dx, dy)
end

function ISWorldMap:onMouseUp(x, y)
    if self.kzcDrawing then
        local finish = worldPointAt(self, x, y)
        local start = self.kzcStart
        local data = getPlayerData(true)

        if data then
            local zone = makeZone(start, finish)
            zone.kills = 0
            table.insert(data.zones, zone)
        end

        self.kzcDrawing = false
        self.kzcStart = nil
        self.kzcEnd = nil
        return true
    end

    if self.kzcResizing then
        local finish = worldPointAt(self, x, y)
        local zone = makeZone(self.kzcResizeAnchor, finish)

        self.kzcResizing.x1 = zone.x1
        self.kzcResizing.y1 = zone.y1
        self.kzcResizing.x2 = zone.x2
        self.kzcResizing.y2 = zone.y2
        self.kzcResizing = nil
        self.kzcResizeAnchor = nil
        self.kzcResizeEnd = nil
        return true
    end

    if originalMouseUp then
        return originalMouseUp(self, x, y)
    end

    return false
end

function ISWorldMap:render()
    originalRender(self)

    local data = getPlayerData(false)

    if data then
        for index, zone in ipairs(data.zones) do
            local bounds = zone
            local color = { r = 1, g = 0.15, b = 0.1, a = 0.9 }

            if zone == self.kzcResizing and self.kzcResizeEnd then
                bounds = makeZone(self.kzcResizeAnchor, self.kzcResizeEnd)
                color = { r = 1, g = 0.85, b = 0.1, a = 0.9 }
            end

            drawZone(self, bounds, color)
            drawKillCount(self, bounds, zone.kills, index)
            drawZoneHandles(self, bounds)
        end
    end

    if self.kzcDrawing and self.kzcStart and self.kzcEnd then
        local preview = makeZone(self.kzcStart, self.kzcEnd)

        drawZone(self, preview, { r = 1, g = 0.85, b = 0.1, a = 0.9 })
    end

    local instruction = getText("IGUI_KZC_Instructions")
    local instructionWidth = getTextManager():MeasureStringX(UIFont.Handwritten, instruction)

    self:drawText(instruction, (self.width - instructionWidth) / 2, 12, 0, 0, 0, 1, UIFont.Handwritten)
end

Events.OnZombieDead.Add(KZC.onZombieDead)