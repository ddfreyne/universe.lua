-- config

local config = {
    -- how much bigger/smaller the bucket should be than the default
    bucketSizeFactor = 1 / 10.0,

    -- how many surrounding buckets to consider when distributing
    -- smaller == faster but less accurate
    bucketSearchDistance = 1,

    -- how much the forces should be made stronger than the default
    -- larger == faster but less accurate
    forceFactor = 1000.0,
}

-- input

-- size of the world in pixels
local width   = 800
local height  = 600

-- how many points per pixel you want
local density = 0.001

--------------------------------------------------------------------------------

-- data

local points
local buckets
local bucketSize

-- helper

printf = function(s, ...)
  return io.write(s:format(...))
end

--

function love.load()
    math.randomseed(os.time())

    love.graphics.setBackgroundColor(150, 225, 255)

    points = generateRandomPoints(width, height, density)
    buckets, bucketSize = bucketizePoints(points, width, height, density)
end

function love.update(dt)
    distributePoints(buckets, width, height, density)
end

function love.draw()
    for i1, subBuckets in pairs(buckets) do
        for i2, bucket in pairs(subBuckets) do
            love.graphics.setColor(255-32*i1, 255-32*i2, 255, 255)
            love.graphics.rectangle("fill", i1*bucketSize, i2*bucketSize, bucketSize, bucketSize)
        end
    end

    for i1, subBuckets in pairs(buckets) do
        for i2, bucket in pairs(subBuckets) do
            for _, point in pairs(bucket) do
                love.graphics.setColor(64*i1, 64*i2, 0, 255)
                love.graphics.circle("fill", point.x, point.y, 3, 14)
            end
        end
    end
end

-- generating

function generateRandomPoints(width, height, density)
    local number = width * height * density
    local points = {}

    for i=1, number do
        local x = math.random() * width
        local y = math.random() * height
        local q = 0.2 + math.random() * 1.8
        table.insert(points, { x = x, y = y, q = q })
    end

    return points
end

function bucketizePoints(points, width, height, density)
    local bucketSize = 1 / density * config.bucketSizeFactor
    local buckets = {}

    -- generate buckets
    for x=0, width, bucketSize do
        local bx = math.floor(x / bucketSize)
        buckets[bx] = {}
        for y=0, height, bucketSize do
            local by = math.floor(y / bucketSize)
            buckets[bx][by] = {}
        end
    end

    -- distribute into buckets
    for _, point in ipairs(points) do
        local bx = math.floor(point.x / bucketSize)
        local by = math.floor(point.y / bucketSize)

        table.insert(buckets[bx][by], point)
    end

    return buckets, bucketSize
end

function distance(p1, p2)
    return math.sqrt(math.pow(p1.x - p2.x, 2.0) + math.pow(p1.y - p2.y, 2.0))
end

function forceVector(p1, p2)
    local d = distance(p1, p2)
    local dsq = math.pow(math.pow(d, 2.0), 1.55)
    local mq = (p1.q + p2.q) / 2.0
    local x = mq * (p1.x - p2.x) / dsq
    local y = mq * (p1.y - p2.y) / dsq

    return { x = x*config.forceFactor, y = y*config.forceFactor }
end

function distributePoints(_, width, height, density)
    local bucketSize = 1 / density * config.bucketSizeFactor
    local maxDistance = config.bucketSearchDistance * bucketSize

    -- generate force vectors
    local forceVectors = {}
    for bx, subBuckets in pairs(buckets) do
        for by, bucket in pairs(subBuckets) do
            for pi, point in pairs(bucket) do
                forceVectors[point] = { x = 0.0, y = 0.0 }
                for nbx=bx-config.bucketSearchDistance, bx+config.bucketSearchDistance do
                    for nby=by-config.bucketSearchDistance, by+config.bucketSearchDistance do
                        if buckets[nbx] and buckets[nbx][nby] then
                            for npi, npoint in pairs(buckets[nbx][nby]) do
                                local d = distance(point, npoint)

                                if d > 0.01 and d < maxDistance then
                                    local f = forceVector(point, npoint)
                                    local fv = forceVectors[point]
                                    fv.x = fv.x + f.x
                                    fv.y = fv.y + f.y
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- add canceling vectors
    for _, point in pairs(points) do
        local forceVector = forceVectors[point]

        local declineStart = 50.0

        if point.x < declineStart then
            local factor = 3 * point.x / 2 / declineStart - 1 / 2
            forceVector.x = forceVector.x * factor
        end

        if point.y < declineStart then
            local factor = 3 * point.y / 2 / declineStart - 1 / 2
            forceVector.y = forceVector.y * factor
        end

        if (width-point.x) < declineStart then
            local factor = 3 * (width-point.x) / 2 / declineStart - 1 / 2
            forceVector.x = forceVector.x * factor
        end

        if (height-point.y) < declineStart then
            local factor = 3 * (height-point.y) / 2 / declineStart - 1 / 2
            forceVector.y = forceVector.y * factor
        end
    end

    -- apply force vectors
    for _, point in pairs(points) do
        local forceVector = forceVectors[point]

        point.x = point.x + forceVector.x
        point.y = point.y + forceVector.y

        if point.x < 0.0 then
            point.x = 0.0
        elseif point.x > width then
            point.x = width
        end

        if point.y < 0.0 then
            point.y = 0.0
        elseif point.y > height then
            point.y = height
        end
    end

    -- rebucketize
    buckets, bucketSize = bucketizePoints(points, width, height, density)
end
