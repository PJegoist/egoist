--[[
	Egoist - Project Egoist script for Potassium (by Potent)

	Contents
	  1. Services & constants        8. Ability cooldowns
	  2. Air dribble                 9. Enemy shot preview
	  3. Ball visuals               10. Auto dribble
	  4. Keeper AI                  11. Interface (window, themes, controls)
	  5. Keeper shot recorder       12. Tabs
	  6. Curve preview & best aim   13. Config, settings & search
	  7. Shot spots                 14. Window, keybinds & unload

	Saved files: EgoistConfig.json, EgoistCurves.json, EgoistSpots.json, EgoistGKLog.txt
]]

-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

-- Shared state for helpers (keeps top-level locals under Luau's 200 limit).
local S = {}

--[[ ================================================================
	SERVICES & CONSTANTS
================================================================== ]]
-- Services.
local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local virtualInputManager = game:GetService("VirtualInputManager")
local statsService = game:GetService("Stats")
local coreGui = game:GetService("CoreGui")
local httpService = game:GetService("HttpService")

-- Constants.
local VERSION = "v2.0"
local ACCENT = Color3.fromRGB(70, 160, 255)
local ACCENT_DARK = Color3.fromRGB(40, 95, 170)
local BACKGROUND = Color3.fromRGB(12, 14, 19)
local PANEL = Color3.fromRGB(21, 24, 32)
local ELEMENT = Color3.fromRGB(32, 36, 48)
local HOVER = Color3.fromRGB(40, 45, 60)
local TEXT = Color3.fromRGB(235, 240, 250)
local SUBTEXT = Color3.fromRGB(140, 148, 165)
local DANGER = Color3.fromRGB(255, 90, 90)
local TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local localPlayer = playersService.LocalPlayer
local mouse = localPlayer:GetMouse()
local world = workspace:WaitForChild("World")
local liveFolder = world:WaitForChild("Live")
local ballsFolder = world:WaitForChild("Balls")

local Egoist = {
	connections = {},
	config = {
		ballEsp = false,
		holderEsp = false,
		prediction = false,
		cleanBall = false,
		autoGrab = false,
		grabRange = 15,
		autoTackle = false,
		tackleRange = 10,
		tackleKey = "Q",
		autoGk = false,
		gkPositioning = false,
		gkLine = 2,
		gkReaction = 0.14,
		gkPreset = 5,
		gkMinShotSpeed = 90,
		gkTrackTime = 1.2,
		gkWideLead = 0.013,
		gkHighLead = 0.015,
		gkMovement = false,
		gkFace = true,
		gkSprint = true,
		sprintKey = "LeftShift",
		gkRecord = false,
		gkTurnSpeed = 16,
		gkWatchCarrier = true,
		gkWatchRange = 60,
		gkJumpHeight = 5.5,
		gkSideJumpHeight = 8,
		gkRushDive = false,
		gkRushRange = 12,
		gkMaxHeight = 16,
		gkForwardWidth = 17,
		gkDelay = 0,
		gkJitter = 0,
		gkMaxRoam = 10,
		gkMarker = false,
		gkKey = "G",
		gkReach = 2.8,
		gkDiveRange = 20,
		diveKey = "E",
		airDribble = false,
		airKey = "LeftAlt",
		airAngle = 60,
		shootKey = "MouseButton1",
		shootHold = 0,
		featureList = true,
		autoLoadConfig = true,
		enemyPreview = false,
		autoDribble = false,
		dribbleKey = "E",
		dodgeRange = 14,
		lungeSpeed = 34,
		dodgeReaction = 0.12,
		dodgeContact = 9,
		dribbleDebug = true,
		dodgeInstant = false,
		dodgeKeypress = false,
		dodgeDelay = 0.15,
		dribblePreset = 11,
		radiusLead = 0,
		radiusTacklesOnly = false,
		radiusLungeSpeed = 85,
		proximityDodge = true,
		proximityRadius = 12,
		showDodgeRadius = true,
		useGameDribbleKey = true,
		earlyDodge = false,
		earlyDodgeRange = 22,
		earlyDodgeSpeed = 12,
		tackleWatchRange = 25,
		shotSpots = false,
		showOtherSpots = false,
		autoSaveSpots = true,
		spotRadius = 3,
		theme = "Ocean",
		styleOverride = "",
		curvePreview = false,
		curveBestAim = true,
		showGoalBox = false,
		goalMargin = 2,
		curveTrustRange = 10,
		curveKeeperCheck = true,
		curveKeeperReach = 8,
		goalWidth = 46,
		goalHeight = 17,
		goalLineOffset = 0,
		curveRecord = false,
		curveLearn = true,
		curveExtend = 12,
		curveKey = "Z",
		speed = false,
		speedValue = 26,
		autoSkill = false,
		skillKeys = "One,Two,Three,Four",
		skillDelay = 0.5,
	},
}

-- Copy of the defaults for "Reset to Defaults".
local DEFAULT_CONFIG = table.clone(Egoist.config)

-- Detach previous execution.
if shared.Egoist then
	pcall(shared.Egoist.detach)
end
shared.Egoist = Egoist

---Get local character parts.
local function getCharacter()
	local character = localPlayer.Character
	if not character then
		return
	end
	return character, character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
end

---Check if a character physically has the ball (it moves into Character.Ball.Holding).
local function isHolding(character)
	local ballSlot = character:FindFirstChild("Ball")
	local holding = ballSlot and ballSlot:FindFirstChild("Holding")
	return holding ~= nil and holding:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

---Get the visible ball part a holder carries.
local function getHeldPart(character)
	local ballSlot = character:FindFirstChild("Ball")
	local holding = ballSlot and ballSlot:FindFirstChild("Holding")
	return holding and holding:FindFirstChildWhichIsA("BasePart", true) or ballSlot
end

---Find the ball part and whoever holds it.
local function findBall()
	-- Someone physically carrying a ball wins; there can be extra loose balls (practice, lobby).
	local localCharacter = localPlayer.Character
	if localCharacter and isHolding(localCharacter) then
		return getHeldPart(localCharacter) or localCharacter:FindFirstChild("HumanoidRootPart"), localCharacter
	end
	for _, character in liveFolder:GetChildren() do
		if isHolding(character) then
			return getHeldPart(character) or character:FindFirstChild("HumanoidRootPart"), character
		end
	end

	-- Otherwise the loose ball in World.Balls.
	for _, container in ballsFolder:GetChildren() do
		local ballPart = container:FindFirstChild("BallPart")
		if ballPart then
			return ballPart, nil
		end
	end
end

---Get our goal's centre, mirrored from the enemy keeper across the centre spot.
local function getOwnGoalPosition(character)
	local team = character:GetAttribute("Team")
	local enemyKeeper = liveFolder:FindFirstChild(team == 1 and "GoalKeeper2" or "GoalKeeper1")
	local enemyRoot = enemyKeeper and enemyKeeper:FindFirstChild("HumanoidRootPart")
	local locations = world.Map:FindFirstChild("Field") and world.Map.Field:FindFirstChild("Locations")
	local centre = locations and locations:FindFirstChild("BallPoint")
	if not enemyRoot or not centre then
		return
	end
	local mirrored = centre.Position * 2 - enemyRoot.Position
	return Vector3.new(mirrored.X, enemyRoot.Position.Y, mirrored.Z)
end

---Check if a character is an opponent.
local function isOpponent(character, other)
	return other ~= character and other:GetAttribute("Team") ~= character:GetAttribute("Team")
end

---Press or hold a key or mouse button.
local function press(keyName, holdTime)
	holdTime = holdTime or 0.05
	if keyName == "MouseButton1" then
		local viewport = workspace.CurrentCamera.ViewportSize
		local x, y = viewport.X / 2, viewport.Y / 2
		virtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
		task.wait(holdTime)
		virtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
		return
	end
	local keyCode = Enum.KeyCode[keyName]
	if not keyCode then
		return
	end
	virtualInputManager:SendKeyEvent(true, keyCode, false, game)
	task.wait(holdTime)
	virtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

--[[ ================================================================
	AIR DRIBBLE (aim spoofing hooks)
================================================================== ]]
-- Aim spoofing for air dribble: game scripts see an upward camera, real camera is untouched.
local spoofing = false
local spoofCamera
local cameraScriptCache = setmetatable({}, { __mode = "k" })

---Build the upward-pitched aim CFrame from the real camera.
local function getSpoofedAim(realCFrame)
	local look = realCFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0 and flat.Unit or Vector3.new(0, 0, -1)
	local angle = math.rad(Egoist.config.airAngle)
	local direction = flat * math.cos(angle) + Vector3.yAxis * math.sin(angle)
	return CFrame.lookAt(realCFrame.Position, realCFrame.Position + direction)
end

local oldIndex

---Check if the calling script drives the camera (those must see the real CFrame).
local function isCameraScript()
	local caller = getcallingscript()
	if not caller then
		return true
	end
	local cached = cameraScriptCache[caller]
	if cached ~= nil then
		return cached
	end
	local name = oldIndex(caller, "Name")
	local fullName = caller:GetFullName()
	local result = name:find("Cam") ~= nil or fullName:find("PlayerModule") ~= nil or fullName:find("Camera") ~= nil
	cameraScriptCache[caller] = result
	return result
end

---Check whether aim spoofing applies to this call.
local function shouldSpoof()
	return spoofing and not checkcaller() and not isCameraScript()
end

oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
	-- Cheap flag check first so normal gameplay has no overhead.
	if not spoofing or not shouldSpoof() then
		return oldIndex(self, key)
	end

	if self == spoofCamera and (key == "CFrame" or key == "Focus") then
		return getSpoofedAim(oldIndex(spoofCamera, "CFrame"))
	end

	if self == mouse and (key == "Hit" or key == "UnitRay" or key == "Origin") then
		local aim = getSpoofedAim(oldIndex(spoofCamera, "CFrame"))
		if key == "Hit" then
			return CFrame.new(aim.Position + aim.LookVector * 500)
		elseif key == "UnitRay" then
			return Ray.new(aim.Position, aim.LookVector)
		end
		return aim
	end

	return oldIndex(self, key)
end))

-- Block camera writes from the kick code while spoofing.
local oldNewIndex
oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
	if spoofing and self == spoofCamera and (key == "CFrame" or key == "Focus") and shouldSpoof() then
		return
	end
	return oldNewIndex(self, key, value)
end))

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
	if spoofing and self == spoofCamera and shouldSpoof() then
		local method = getnamecallmethod()
		if method == "ScreenPointToRay" or method == "ViewportPointToRay" then
			local aim = getSpoofedAim(oldIndex(self, "CFrame"))
			return Ray.new(aim.Position, aim.LookVector)
		end
	end
	return oldNamecall(self, ...)
end))

---Perform an air dribble kick, only while holding the ball.
local function airDribble()
	local character = getCharacter()
	if not character or spoofing then
		return
	end
	local _, holder = findBall()
	if holder ~= character then
		return
	end

	spoofCamera = workspace.CurrentCamera
	local startLook = spoofCamera.CFrame.LookVector
	local startPitch = math.asin(math.clamp(startLook.Y, -1, 1))
	spoofing = true

	-- Hold the camera's vertical angle after all camera scripts run.
	runService:BindToRenderStep("EgoistPitchLock", Enum.RenderPriority.Camera.Value + 10, function()
		local current = spoofCamera.CFrame
		local look = current.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then
			return
		end
		flat = flat.Unit
		local direction = flat * math.cos(startPitch) + Vector3.yAxis * math.sin(startPitch)
		spoofCamera.CFrame = CFrame.lookAt(current.Position, current.Position + direction)
	end)

	task.spawn(function()
		press(Egoist.config.shootKey, Egoist.config.shootHold)
		task.wait(0.3)
		spoofing = false
		task.wait(0.15)
		runService:UnbindFromRenderStep("EgoistPitchLock")
	end)
end

--[[ ================================================================
	BALL VISUALS (ESP, landing prediction)
================================================================== ]]
-- Visual objects.
local visualsFolder = Instance.new("Folder")
visualsFolder.Name = "EgoistVisuals"
visualsFolder.Parent = workspace

-- Adornment avoids highlight conflicts when the ball sits inside a highlighted holder.
local ballAdornment = Instance.new("SphereHandleAdornment")
ballAdornment.Color3 = ACCENT
ballAdornment.Transparency = 0.35
ballAdornment.AlwaysOnTop = true
ballAdornment.ZIndex = 5

local holderHighlight = Instance.new("Highlight")
holderHighlight.FillTransparency = 1
holderHighlight.OutlineColor = DANGER
holderHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

---Create an anchored visual part.
local function createVisualPart(shape, transparency)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = shape
	part.Color = ACCENT
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	return part
end

local predictionMarker = createVisualPart(Enum.PartType.Cylinder, 0.35)
predictionMarker.Size = Vector3.new(0.2, 5, 5)

-- Trajectory line segments.
S.SEGMENTS = 24
local trajectorySegments = {}
for index = 1, S.SEGMENTS do
	trajectorySegments[index] = createVisualPart(Enum.PartType.Block, 0.3)
end

---Hide prediction visuals.
local function hidePrediction()
	predictionMarker.Parent = nil
	for _, segment in trajectorySegments do
		segment.Parent = nil
	end
end

-- Velocity measured from position deltas, since the ball isn't moved by physics.
local lastBallPosition, lastBallTime
local measuredVelocity, measuredGravity = Vector3.zero, workspace.Gravity
local smoothedLanding

---Reset tracking state.
local function resetTracking()
	lastBallPosition, smoothedLanding = nil, nil
	measuredVelocity = Vector3.zero
end

---Track ball velocity and gravity from frame deltas.
local function trackBall(ball)
	local now = os.clock()
	if not lastBallPosition then
		lastBallPosition, lastBallTime = ball.Position, now
		return
	end
	local deltaTime = now - lastBallTime
	if deltaTime < 1 / 240 then
		return
	end
	local velocity = (ball.Position - lastBallPosition) / deltaTime
	lastBallPosition, lastBallTime = ball.Position, now

	-- Ignore teleports and replication spikes.
	if velocity.Magnitude > 400 then
		return
	end

	local acceleration = (measuredVelocity.Y - velocity.Y) / deltaTime
	if acceleration > 5 and acceleration < 600 then
		measuredGravity += (acceleration - measuredGravity) * 0.05
	end
	-- Snap to the first real reading so fresh shots register immediately.
	if measuredVelocity.Magnitude < 2 then
		measuredVelocity = velocity
	else
		measuredVelocity = measuredVelocity:Lerp(velocity, 0.35)
	end
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

---Predict landing point and flight time.
local function predictLanding(ball)
	local position, velocity = ball.Position, measuredVelocity
	raycastParams.FilterDescendantsInstances = { ballsFolder, liveFolder, visualsFolder }

	local groundHit = workspace:Raycast(position, Vector3.new(0, -500, 0), raycastParams)
	local floor = groundHit and groundHit.Position.Y or position.Y - 50

	-- Solve y(t) = floor.
	local a, b, c = -0.5 * measuredGravity, velocity.Y, position.Y - floor
	local discriminant = b * b - 4 * a * c
	if discriminant < 0 then
		return
	end
	local time = (-b - math.sqrt(discriminant)) / (2 * a)
	if time <= 0 then
		return
	end
	return Vector3.new(position.X + velocity.X * time, floor, position.Z + velocity.Z * time), time
end

---Position along the predicted arc at time t.
local function arcPoint(origin, t)
	return origin + measuredVelocity * t + Vector3.new(0, -0.5 * measuredGravity * t * t, 0)
end

---Draw the trajectory line from the ball to the landing point.
local function drawTrajectory(origin, flightTime, landing)
	local previous = origin
	for index, segment in trajectorySegments do
		local point = index == S.SEGMENTS and landing or arcPoint(origin, flightTime * index / S.SEGMENTS)
		local length = (point - previous).Magnitude
		if length > 0.01 then
			segment.Size = Vector3.new(0.18, 0.18, length)
			segment.CFrame = CFrame.lookAt((previous + point) / 2, point)
			segment.Parent = visualsFolder
		else
			segment.Parent = nil
		end
		previous = point
	end
end

-- Visual loop.
Egoist.connections.render = runService.RenderStepped:Connect(function()
	local config = Egoist.config
	local ball, holder = findBall()

	ballAdornment.Adornee = ball
	if ball then
		ballAdornment.Radius = math.max(ball.Size.X, 1.5) / 2 + 0.4
	end
	ballAdornment.Parent = config.ballEsp and ball and coreGui or nil
	holderHighlight.Adornee = holder
	holderHighlight.Parent = config.holderEsp and holder and coreGui or nil

	if not ball or holder then
		resetTracking()
		hidePrediction()
		return
	end

	trackBall(ball)

	if not config.prediction or measuredVelocity.Magnitude < 5 then
		smoothedLanding = nil
		hidePrediction()
		return
	end

	local landing, flightTime = predictLanding(ball)
	if not landing then
		hidePrediction()
		return
	end

	-- Smooth the marker so it doesn't jitter.
	smoothedLanding = smoothedLanding and smoothedLanding:Lerp(landing, 0.2) or landing
	predictionMarker.CFrame = CFrame.new(smoothedLanding + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	predictionMarker.Parent = visualsFolder
	drawTrajectory(ball.Position, flightTime, smoothedLanding)
end)

-- Clean ball: hide every special-move effect on the ball (client side only).
S.cleanBall = {
	hidden = {},
	candidates = {},
	effectClasses = { ParticleEmitter = true, Trail = true, Beam = true, Fire = true, Smoke = true, Sparkles = true, Highlight = true, SelectionBox = true, PointLight = true, SpotLight = true, SurfaceLight = true },
	linkClasses = { Weld = true, WeldConstraint = true, Motor6D = true, RigidConstraint = true, ManualWeld = true },
}

---Is this object part of a player's body or our own visuals?
function S.isProtected(object)
	if object:IsDescendantOf(visualsFolder) or object:IsDescendantOf(world.Map) then
		return true
	end
	local model = object:FindFirstAncestorOfClass("Model")
	if not model or not model:FindFirstChildOfClass("Humanoid") then
		return false
	end
	-- A player's body is off limits, but the ball they're holding isn't.
	local ballSlot = model:FindFirstChild("Ball")
	return not (ballSlot and object:IsDescendantOf(ballSlot))
end

---Hide one object (remembering how to bring it back). The ball itself is never touched.
function S.hideEffect(object, ballPart)
	if S.cleanBall.hidden[object] ~= nil or object == ballPart then
		return
	end
	if S.cleanBall.effectClasses[object.ClassName] then
		S.cleanBall.hidden[object] = object.Enabled
		object.Enabled = false
	elseif object:IsA("BasePart") and object ~= ballPart and not object:IsDescendantOf(ballsFolder) then
		S.cleanBall.hidden[object] = object.LocalTransparencyModifier
		object.LocalTransparencyModifier = 1
	end
end

---Hide an object and everything inside it.
function S.hideTree(root, ballPart)
	S.hideEffect(root, ballPart)
	for _, object in root:GetDescendants() do
		S.hideEffect(object, ballPart)
	end
end

---Bring every hidden effect back.
function S.restoreEffects()
	for object, original in S.cleanBall.hidden do
		if object.Parent then
			if object:IsA("BasePart") then
				object.LocalTransparencyModifier = original
			else
				object.Enabled = original
			end
		end
	end
	table.clear(S.cleanBall.hidden)
	table.clear(S.cleanBall.candidates)
end

---Does this object point at the ball (welded to it, or a beam/trail anchored on it)?
function S.isLinkedToBall(object, ball)
	if S.cleanBall.linkClasses[object.ClassName] then
		local part0, part1 = object.Part0, object.Part1
		if part0 == ball or part1 == ball then
			return part0 == ball and part1 or part0
		end
	elseif object:IsA("Beam") or object:IsA("Trail") then
		local a0, a1 = object.Attachment0, object.Attachment1
		if a0 and a0:IsDescendantOf(ball) or a1 and a1:IsDescendantOf(ball) then
			return object
		end
	end
end

-- New effects anywhere in the world: hide anything stuck to the ball, and watch the rest to see if it follows the ball.
Egoist.connections.cleanBallSpawn = workspace.DescendantAdded:Connect(function(object)
	if not Egoist.config.cleanBall then
		return
	end
	task.defer(function()
		if not object.Parent or S.isProtected(object) then
			return
		end
		local ball = findBall()
		if not ball then
			return
		end
		-- Anything added inside the ball or its container.
		if object:IsDescendantOf(ball) or ball.Parent and ball.Parent:IsDescendantOf(ballsFolder) and object:IsDescendantOf(ball.Parent) then
			S.hideEffect(object, ball)
			return
		end
		local linked = S.isLinkedToBall(object, ball)
		-- The grip weld joins the ball to your hand; never follow a link onto a player's body.
		if linked and S.isProtected(linked) then
			return
		end
		if linked then
			local model = linked:IsA("BasePart") and linked:FindFirstAncestorOfClass("Model")
			if model and (model:FindFirstChildOfClass("Humanoid") or model == workspace) then
				model = nil
			end
			S.hideTree(model or linked, ball)
			return
		end
		-- Loose VFX parts: hide them if they travel with the ball.
		if object:IsA("BasePart") or object:IsA("Model") and object.Parent == workspace or object:IsA("Attachment") then
			local position = object:IsA("BasePart") and object.Position or object:IsA("Attachment") and object.WorldPosition or object:GetPivot().Position
			S.cleanBall.candidates[object] = { start = os.clock(), ballStart = ball.Position, maxGap = (position - ball.Position).Magnitude }
		end
	end)
end)

-- Effects attached to the ball itself, plus deciding which watched parts follow the ball.
S.cleanBall.lastScan = 0
Egoist.connections.cleanBall = runService.Heartbeat:Connect(function()
	if not Egoist.config.cleanBall then
		if next(S.cleanBall.hidden) then
			S.restoreEffects()
		end
		return
	end
	local ball = findBall()
	if not ball then
		return
	end

	for object, info in S.cleanBall.candidates do
		if not object.Parent then
			S.cleanBall.candidates[object] = nil
			continue
		end
		local position = object:IsA("BasePart") and object.Position or object:IsA("Attachment") and object.WorldPosition or object:GetPivot().Position
		info.maxGap = math.max(info.maxGap, (position - ball.Position).Magnitude)
		local ballTravel = (ball.Position - info.ballStart).Magnitude
		-- Stayed glued to a moving ball, or spawned right on a ball that's held/still: it's a ball effect.
		if info.maxGap <= 10 and (ballTravel >= 4 or os.clock() - info.start >= 0.25 and info.maxGap <= 4) then
			S.cleanBall.candidates[object] = nil
			S.hideTree(object, ball)
		elseif info.maxGap > 10 or os.clock() - info.start > 0.6 then
			S.cleanBall.candidates[object] = nil
		end
	end

	if os.clock() - S.cleanBall.lastScan < 0.15 then
		return
	end
	S.cleanBall.lastScan = os.clock()
	-- Everything inside the ball and its container (aura meshes there aren't the ball, so they go too).
	S.hideTree(ball, ball)
	if ball.Parent and ball.Parent:IsDescendantOf(ballsFolder) then
		for _, object in ball.Parent:GetDescendants() do
			if not object:IsA("BasePart") then
				S.hideEffect(object, ball)
			end
		end
	end
	for object, original in S.cleanBall.hidden do
		if not object.Parent then
			S.cleanBall.hidden[object] = nil
		elseif S.isProtected(object) then
			-- Undo anything that ended up on a body part.
			if object:IsA("BasePart") then
				object.LocalTransparencyModifier = original
			else
				object.Enabled = original
			end
			S.cleanBall.hidden[object] = nil
		end
	end
end)

--[[ ================================================================
	KEEPER AI
================================================================== ]]
-- Auto GK: keeper AI that positions and dives using the game's own controls.
S.MOVEMENT_KEYS = { "W", "A", "S", "D" }
S.heldKeys = {}
local gkState = { diving = false, lastDive = 0, lastHeld = 0, manualUntil = 0, status = "Idle" }

---Press or release a key only when its state changes.
function S.setKey(keyName, down)
	if (S.heldKeys[keyName] or false) == down then
		return
	end
	S.heldKeys[keyName] = down or nil
	virtualInputManager:SendKeyEvent(down, Enum.KeyCode[keyName], false, game)
end

---Release every movement key we hold.
local function releaseMovement()
	for _, keyName in S.MOVEMENT_KEYS do
		S.setKey(keyName, false)
	end
	if Egoist.config.sprintKey ~= "" then
		S.setKey(Egoist.config.sprintKey, false)
	end
end

-- Real WASD presses (ones we didn't send) hand control back to the player.
Egoist.connections.manualOverride = userInputService.InputBegan:Connect(function(input)
	local keyName = input.KeyCode.Name
	if table.find(S.MOVEMENT_KEYS, keyName) and not S.heldKeys[keyName] then
		gkState.manualUntil = os.clock() + 0.75
	end
end)

---Check whether the player is steering right now.
function S.isManual()
	if os.clock() < gkState.manualUntil then
		return true
	end
	for _, keyName in S.MOVEMENT_KEYS do
		if not S.heldKeys[keyName] and userInputService:IsKeyDown(Enum.KeyCode[keyName]) then
			gkState.manualUntil = os.clock() + 0.75
			return true
		end
	end
	return false
end

---Camera-relative basis on the ground plane.
local function getCameraBasis()
	local cameraCFrame = workspace.CurrentCamera.CFrame
	local look = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z)
	local right = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z)
	if look.Magnitude < 1e-3 or right.Magnitude < 1e-3 then
		return
	end
	return look.Unit, right.Unit
end

---Hold WASD so the character walks in a world direction.
function S.walkToward(direction)
	local look, right = getCameraBasis()
	if not look or direction.Magnitude < 1e-3 then
		releaseMovement()
		return
	end
	direction = direction.Unit
	local forward, side = direction:Dot(look), direction:Dot(right)
	S.setKey("W", forward > 0.38)
	S.setKey("S", forward < -0.38)
	S.setKey("D", side > 0.38)
	S.setKey("A", side < -0.38)
end

---Side dive key (A or D) that sends us toward a world direction.
function S.getSideKey(direction)
	local _, right = getCameraBasis()
	if not right then
		return "D"
	end
	return direction:Dot(right) >= 0 and "D" or "A"
end

---Forward dive key: W when the camera faces the field, otherwise the closest key.
function S.getForwardKey(direction)
	local look, right = getCameraBasis()
	if not look then
		return "W"
	end
	local forward, side = direction:Dot(look), direction:Dot(right)
	if forward >= math.abs(side) * 0.6 then
		return "W"
	end
	return side >= 0 and "D" or "A"
end

---Find when the ball passes closest to a point along its predicted arc.
function S.getClosestApproach(ball, point)
	local bestTime, bestPosition, bestDistance = 0, ball.Position, math.huge
	for step = 0, 50 do
		local t = step * 0.025
		local position = arcPoint(ball.Position, t)
		local flat = Vector3.new(position.X - point.X, 0, position.Z - point.Z)
		if flat.Magnitude < bestDistance then
			bestTime, bestPosition, bestDistance = t, position, flat.Magnitude
		end
	end
	return bestTime, bestPosition, bestDistance
end

---Perform a dive with a direction key held, optionally jumping first.
function S.dive(directionKey, kind, jump)
	gkState.diving = true
	gkState.lastDive = os.clock()
	gkState.status = (jump and "Jump " or "") .. kind .. " dive (" .. directionKey .. ")"
	releaseMovement()
	task.spawn(function()
		S.setKey(directionKey, true)
		if jump then
			press("Space", 0.04)
			task.wait(0.06)
		end
		task.wait(0.03)
		press(Egoist.config.diveKey, 0.05)
		task.wait(0.08)
		S.setKey(directionKey, false)
		task.wait(0.9)
		gkState.diving = false
	end)
end

-- Camera turning: moves the mouse like a player would, so the game's camera follows naturally.
S.radiansPerPixel = 0.004
S.lastTurn = { pixels = 0, yaw = nil }

---Yaw of the camera on the ground plane.
function S.getCameraYaw()
	local look = workspace.CurrentCamera.CFrame.LookVector
	return math.atan2(-look.X, -look.Z)
end

---Rotate the camera toward a world direction; returns the remaining angle in radians.
local function turnCameraToward(direction, speed, deltaTime)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		return 0
	end
	local currentYaw = S.getCameraYaw()

	-- Learn how far one pixel turns the camera from the last movement.
	if S.lastTurn.yaw and math.abs(S.lastTurn.pixels) > 2 then
		local turned = (currentYaw - S.lastTurn.yaw + math.pi) % (2 * math.pi) - math.pi
		local observed = -turned / S.lastTurn.pixels
		if observed > 0.0003 and observed < 0.03 then
			S.radiansPerPixel += (observed - S.radiansPerPixel) * 0.3
		end
	end

	local targetYaw = math.atan2(-flat.X, -flat.Z)
	local error = (targetYaw - currentYaw + math.pi) % (2 * math.pi) - math.pi
	-- Ease toward the target: fast when far off, gentle near the end.
	local step = error * (1 - math.exp(-(speed or 14) * (deltaTime or 1 / 60)))
	local pixels = math.clamp(-step / S.radiansPerPixel, -400, 400)

	if math.abs(error) < math.rad(2) then
		S.lastTurn.pixels, S.lastTurn.yaw = 0, nil
		return error
	end

	if mousemoverel and userInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		mousemoverel(pixels, 0)
		S.lastTurn.pixels, S.lastTurn.yaw = pixels, currentYaw
	else
		-- Fallback when the mouse isn't locked: rotate the camera around the character.
		local camera = workspace.CurrentCamera
		local _, rootPart = getCharacter()
		if rootPart then
			local subject = rootPart.Position + Vector3.new(0, 1.5, 0)
			local distance = (camera.CFrame.Position - subject).Magnitude
			local pitch = math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))
			local look = flat.Unit * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
			camera.CFrame = CFrame.lookAt(subject - look * distance, subject)
		end
		S.lastTurn.pixels, S.lastTurn.yaw = 0, nil
	end
	return error
end

-- Marker showing where the AI expects to stop the shot.
S.interceptMarker = createVisualPart(Enum.PartType.Cylinder, 0.3)
S.interceptMarker.Size = Vector3.new(0.2, 3, 3)
S.interceptMarker.Color = DANGER

---Check whether an opponent touched the ball last (ignores our throws and team passes).
function S.isThreat(ball, character)
	if os.clock() - gkState.lastHeld < 1.5 then
		return false
	end
	local info = ball.Parent and ball.Parent:FindFirstChild("Info")
	local lastOwner = info and info:FindFirstChild("LastOwner")
	local owner = lastOwner and lastOwner.Value
	if not owner then
		return true
	end
	local ownerCharacter = owner:IsA("Player") and owner.Character or owner
	if not ownerCharacter or ownerCharacter == character then
		return false
	end
	return ownerCharacter:GetAttribute("Team") ~= character:GetAttribute("Team")
end

---Clamp a point so the keeper never wanders far from goal.
function S.clampToGoal(point, goalPosition, maxDistance)
	local offset = Vector3.new(point.X - goalPosition.X, 0, point.Z - goalPosition.Z)
	if offset.Magnitude <= maxDistance then
		return point
	end
	local clamped = goalPosition + offset.Unit * maxDistance
	return Vector3.new(clamped.X, point.Y, clamped.Z)
end

---Get the field centre spot.
local function getCentreSpot()
	local field = world.Map:FindFirstChild("Field")
	local locations = field and field:FindFirstChild("Locations")
	local centre = locations and locations:FindFirstChild("BallPoint")
	return centre and centre.Position
end

---Get our fixed goal anchor: where we stand when the game puts us in goal.
function S.getGoalAnchor(character, rootPart)
	-- The game teleports the keeper into goal at kickoff; re-anchor after each teleport.
	local stamp = character:GetAttribute("TeleportSince")
	if stamp ~= gkState.anchorStamp then
		gkState.anchorStamp = stamp
		gkState.anchor = nil
		gkState.captureAt = os.clock() + 0.4
	end
	if not gkState.anchor and os.clock() >= (gkState.captureAt or 0) then
		local mirrored = getOwnGoalPosition(character)
		-- Prefer our spawn spot; fall back to the mirrored estimate if we've already wandered.
		if not mirrored or (rootPart.Position - mirrored).Magnitude < 25 then
			gkState.anchor = rootPart.Position
		else
			gkState.anchor = mirrored
		end
	end
	return gkState.anchor
end

---Field axes for our goal: toward the field, and across the goal mouth.
function S.getGoalAxes(anchor)
	local centre = getCentreSpot()
	local forward = centre and Vector3.new(centre.X - anchor.X, 0, centre.Z - anchor.Z)
	if not forward or forward.Magnitude < 1 then
		return
	end
	forward = forward.Unit
	return forward, forward:Cross(Vector3.yAxis)
end

---Walk toward a point (unless the player is steering), or stand still when close.
function S.settleAt(rootPart, point, label)
	if S.isManual() then
		releaseMovement()
		gkState.status = "Manual"
		return
	end
	local move = Vector3.new(point.X - rootPart.Position.X, 0, point.Z - rootPart.Position.Z)
	if move.Magnitude > 1.5 then
		S.walkToward(move)
		gkState.status = label
	else
		releaseMovement()
		gkState.status = "Set"
	end
end

---Read a shot along its ground line: where it crosses us, when, and how high.
function S.readShot(ball, rootPart, velocity)
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flatVelocity.Magnitude
	local direction = flatVelocity / speed
	local relative = Vector3.new(rootPart.Position.X - ball.Position.X, 0, rootPart.Position.Z - ball.Position.Z)
	local along = relative:Dot(direction)
	if along <= 0 then
		return
	end
	local crossing = Vector3.new(ball.Position.X, 0, ball.Position.Z) + direction * along
	local lateral = Vector3.new(crossing.X - rootPart.Position.X, 0, crossing.Z - rootPart.Position.Z)
	local arrival = along / speed
	-- Height from the ball's true vertical speed and the game's real gravity.
	local height = ball.Position.Y + velocity.Y * arrival - 0.5 * workspace.Gravity * arrival * arrival - rootPart.Position.Y
	height = math.clamp(height, -20, 60)
	return arrival, lateral, height, Vector3.new(crossing.X, rootPart.Position.Y, crossing.Z)
end

--[[ ================================================================
	KEEPER SHOT RECORDER
================================================================== ]]
-- Shot recorder: logs what the keeper AI sees and does, for tuning from real shots.
S.shotLog = {}
S.shotRecorder = { id = 0, postUntil = 0, startClock = 0 }

---Totals from the game's match stats: our saves, and goals scored by the other team.
function S.getMatchTotals(character)
	local totals = { saves = 0, conceded = 0 }
	local myTeam = character and character:GetAttribute("Team")
	for _, player in playersService:GetPlayers() do
		local stats = player:FindFirstChild("MatchStats")
		if stats then
			if player == localPlayer and stats:FindFirstChild("saves") then
				totals.saves = stats.saves.Value
			end
			local team = player.Character and player.Character:GetAttribute("Team")
			if team and team ~= myTeam and stats:FindFirstChild("goals") then
				totals.conceded += stats.goals.Value
			end
		end
	end
	return totals
end

---Add a line to the shot log (only while recording).
function S.logShot(format, ...)
	if not Egoist.config.gkRecord then
		return
	end
	local line = string.format("[#%d +%.3f] ", S.shotRecorder.id, os.clock() - S.shotRecorder.startClock) .. string.format(format, ...)
	table.insert(S.shotLog, line)
	if #S.shotLog > 4000 then
		table.remove(S.shotLog, 1)
	end
end

---Save the log to a file and the clipboard.
function S.exportShotLog()
	local text = table.concat(S.shotLog, "\n")
	pcall(writefile, "EgoistGKLog.txt", text)
	pcall(setclipboard, text)
	return #S.shotLog
end

---Best velocity for the ball: the game's own mover is exact; fall back when the ball has slowed.
function S.getBallVelocity(ball)
	local mover = ball.Parent and ball.Parent:FindFirstChildOfClass("LinearVelocity")
	local moverVelocity = mover and mover.VectorVelocity
	if moverVelocity and moverVelocity.Magnitude > 6 then
		local trackedFor = gkState.threatSince and os.clock() - gkState.threatSince or 0
		-- A rolling ball that stopped still reports its old mover speed; trust measurement then.
		if trackedFor < 0.3 or measuredVelocity.Magnitude > moverVelocity.Magnitude * 0.35 then
			return moverVelocity
		end
	end
	return measuredVelocity
end

Egoist.connections.goalkeeper = runService.Heartbeat:Connect(function(deltaTime)
	local config = Egoist.config
	local character, rootPart = getCharacter()
	if os.clock() < S.shotRecorder.postUntil and rootPart then
		local ball = findBall()
		if ball then
			S.logShot("POST flatDist=%.2f heightDiff=%.2f", Vector3.new(ball.Position.X - rootPart.Position.X, 0, ball.Position.Z - rootPart.Position.Z).Magnitude, ball.Position.Y - rootPart.Position.Y)
		end
	end
	S.interceptMarker.Parent = nil

	if not config.autoGk or not rootPart or character:GetAttribute("Playing") ~= "GK" then
		if next(S.heldKeys) and not gkState.diving then
			releaseMovement()
		end
		gkState.status = config.autoGk and "Not in goal" or "Idle"
		return
	end
	if gkState.diving then
		return
	end

	local anchor = S.getGoalAnchor(character, rootPart)
	local ball, holder = findBall()
	if holder == character then
		gkState.lastHeld = os.clock()
	end
	if not anchor or not ball then
		releaseMovement()
		gkState.status = "Waiting for ball"
		return
	end

	-- Rush dive: an attacker carrying the ball got too close, so dive straight at their feet.
	if config.gkRushDive and holder and holder ~= character and isOpponent(character, holder) then
		local holderRoot = holder:FindFirstChild("HumanoidRootPart")
		if holderRoot then
			S.trackVelocity(holder, holderRoot)
			local tracked = S.dribble.velocities[holder]
			local ping = statsService.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
			-- Aim where they really are (their shown position lags behind) plus a little of their run.
			local predicted = holderRoot.Position + (tracked and tracked.velocity or Vector3.zero) * (ping * 0.5 + 0.12)
			local toTarget = Vector3.new(predicted.X - rootPart.Position.X, 0, predicted.Z - rootPart.Position.Z)
			if toTarget.Magnitude <= config.gkRushRange and toTarget.Magnitude > 0.5 and os.clock() - gkState.lastDive > 1.2 then
				local facingError = config.gkFace and turnCameraToward(toTarget, 30, deltaTime) or 0
				gkState.status = string.format("Rushing %s (%.1f)", holder.Name, toTarget.Magnitude)
				if math.abs(facingError) < math.rad(25) or toTarget.Magnitude < 6 then
					S.logShot("RUSH DIVE at %s dist=%.1f facingErr=%.1f", holder.Name, toTarget.Magnitude, math.deg(facingError))
					S.dive(S.getForwardKey(toTarget.Unit), "Rush", false)
				end
				return
			end
		end
	end

	-- Shot reading: opponent's ball moving toward our goal.
	local tracking = false
	local ballVelocity = S.getBallVelocity(ball)
	local flatVelocity = Vector3.new(ballVelocity.X, 0, ballVelocity.Z)
	local toGoal = Vector3.new(anchor.X - ball.Position.X, 0, anchor.Z - ball.Position.Z)
	-- Real shots only: fast enough and arriving soon. Slow rollers from far away are ignored.
	if not holder and flatVelocity.Magnitude > config.gkMinShotSpeed and flatVelocity:Dot(toGoal) > 0 and S.isThreat(ball, character) then
		local arrival, lateral, height, crossing = S.readShot(ball, rootPart, ballVelocity)
		if arrival and arrival <= config.gkTrackTime and lateral.Magnitude < config.gkDiveRange and height < config.gkMaxHeight then
			tracking = true
			if not gkState.threatSince then
				gkState.threatSince = os.clock()
				gkState.jitter = math.random() * config.gkJitter
				S.shotRecorder.id += 1
				S.shotRecorder.startClock = os.clock()
				S.shotRecorder.dived = false
				S.shotRecorder.baseline = S.getMatchTotals(character)
				S.logShot("START dist=%.1f measured=%.1f used=%.1f | movement=%s positioning=%s face=%s width=%.1f reaction=%.2f jumpAt=%.1f", (ball.Position - rootPart.Position).Magnitude, measuredVelocity.Magnitude, ballVelocity.Magnitude, tostring(config.gkMovement), tostring(config.gkPositioning), tostring(config.gkFace), config.gkForwardWidth, config.gkReaction, config.gkJumpHeight)
			end
			-- Close shots skip the humanize delay; there is no time for it.
			local close = arrival < 0.35
			local reacted = close or os.clock() - gkState.threatSince >= config.gkDelay + gkState.jitter

			if config.gkMarker then
				S.interceptMarker.CFrame = CFrame.new(crossing.X, rootPart.Position.Y - 2.9, crossing.Z) * CFrame.Angles(0, 0, math.rad(90))
				S.interceptMarker.Parent = visualsFolder
			end

			-- Forward dive at the crossing point when it's within reach, side dive when really wide.
			local lateralDistance = lateral.Magnitude
			local isForward = lateralDistance <= config.gkForwardWidth
			local toBall = Vector3.new(ball.Position.X - rootPart.Position.X, 0, ball.Position.Z - rootPart.Position.Z)
			local faceDirection = toBall
			if isForward and lateralDistance > 2 then
				-- Aim slightly ahead of us along the shot so the dive meets the ball.
				local forwardBias = toBall.Magnitude > 0 and toBall.Unit * 3 or Vector3.zero
				faceDirection = lateral + forwardBias
			end

			local facingError = 0
			if config.gkFace and reacted then
				facingError = turnCameraToward(faceDirection, close and 30 or config.gkTurnSpeed, deltaTime)
			end

			-- Left/right measured against where the camera is turning to, so it can't flip mid-turn.
			local faceFlat = Vector3.new(faceDirection.X, 0, faceDirection.Z)
			local faceRight = faceFlat.Magnitude > 1e-3 and faceFlat.Unit:Cross(Vector3.yAxis) or Vector3.xAxis
			local side = lateral:Dot(faceRight)
			-- Wide shots need extra time to cover ground; high shots need time for the jump to rise.
			local triggerTime = config.gkReaction
				+ math.max(0, lateralDistance - 4) * config.gkWideLead
				+ math.max(0, height - 6) * config.gkHighLead
			-- Close shots can't wait for the camera to finish turning.
			local faced = not config.gkFace or math.abs(facingError) < math.rad(30) or arrival < 0.3

			gkState.status = string.format("Reading shot (%.2fs, %s)", arrival, isForward and "forward" or (side > 0 and "right" or "left"))
			S.logShot("READ arrival=%.3f lateral=%.2f side=%.2f height=%.2f facingErr=%.1f flatDist=%.2f speed=%.1f trigger=%.3f faced=%s", arrival, lateralDistance, side, height, math.deg(facingError), toBall.Magnitude, flatVelocity.Magnitude, triggerTime, tostring(faced))

			-- Dive once facing; if the turn runs late, commit anyway before it's too late.
			if reacted and (faced or arrival <= triggerTime * 0.6) and arrival <= triggerTime and os.clock() - gkState.lastDive > 0.8 then
				-- Forward dives jump earlier (flat ones went under ~7 high shots); side dives stay low longer.
				local jump = height > (isForward and config.gkJumpHeight or config.gkSideJumpHeight)
				S.shotRecorder.dived = true
				S.shotRecorder.postUntil = os.clock() + 1.5
				S.logShot("DIVE %s lateral=%.2f height=%.2f arrival=%.3f jump=%s", isForward and "FORWARD" or (side > 0 and "RIGHT" or "LEFT"), lateralDistance, height, arrival, tostring(jump))
				-- Dive keys follow the camera; if it hasn't finished turning, pick keys from where it points now.
				local forwardKey, sideKey = "W", side > 0 and "D" or "A"
				if math.abs(facingError) > math.rad(30) then
					local _, cameraRight = getCameraBasis()
					local toCrossing = Vector3.new(crossing.X - rootPart.Position.X, 0, crossing.Z - rootPart.Position.Z)
					if toCrossing.Magnitude > 0.5 then
						forwardKey = S.getForwardKey(toCrossing.Unit)
					end
					if cameraRight then
						sideKey = lateral:Dot(cameraRight) > 0 and "D" or "A"
					end
				end
				if isForward then
					S.dive(forwardKey, "Forward", jump)
				else
					S.dive(sideKey, "Side", jump)
				end
				return
			end

			-- Shuffle toward where the shot will cross, staying near goal.
			if reacted and config.gkMovement then
				S.settleAt(rootPart, S.clampToGoal(crossing, anchor, config.gkMaxRoam), "Tracking shot")
				-- Sprint toward wide shots to cover more ground before diving.
				if config.gkSprint and config.sprintKey ~= "" and gkState.status == "Tracking shot" then
					S.setKey(config.sprintKey, true)
				end
				return
			end
		end
	end
	if not tracking then
		if gkState.threatSince then
			S.logShot("END dived=%s", tostring(S.shotRecorder.dived))
			S.shotRecorder.postUntil = os.clock() + 0.8
			local shotId = S.shotRecorder.id
			task.delay(2.5, function()
				local held = os.clock() - gkState.lastHeld < 2.5
				local now = S.getMatchTotals(localPlayer.Character)
				local before = S.shotRecorder.baseline or now
				local outcome = "MISSED/DEFLECTED (no goal)"
				if now.conceded > before.conceded then
					outcome = "GOAL CONCEDED"
				elseif now.saves > before.saves or held then
					outcome = "SAVED" .. (held and " (held)" or "")
				end
				table.insert(S.shotLog, string.format("[#%d] RESULT %s", shotId, outcome))
				if Egoist.config.gkRecord then
					S.exportShotLog()
				end
			end)
		end
		gkState.threatSince = nil

		-- Keep facing an opponent on the ball so close shots don't need a big turn.
		local carrierRoot = holder and holder ~= character and isOpponent(character, holder) and holder:FindFirstChild("HumanoidRootPart")
		if config.gkFace and config.gkWatchCarrier and carrierRoot and (carrierRoot.Position - anchor).Magnitude < config.gkWatchRange then
			local toCarrier = Vector3.new(carrierRoot.Position.X - rootPart.Position.X, 0, carrierRoot.Position.Z - rootPart.Position.Z)
			turnCameraToward(toCarrier, config.gkTurnSpeed * 0.45, deltaTime)
			gkState.status = "Watching " .. holder.Name
		else
			S.lastTurn.pixels, S.lastTurn.yaw = 0, nil
			gkState.status = "Watching"
		end
	end

	-- Without Auto Movement the player moves freely; the AI only dives.
	if not config.gkMovement then
		releaseMovement()
		if not tracking and not gkState.status:find("^Watching ") then
			gkState.status = "Watching"
		end
		return
	end

	if not config.gkPositioning then
		S.settleAt(rootPart, anchor, "Returning to goal")
		return
	end

	-- Cut the angle: stand on the line from the ball to the point that splits the goal mouth
	-- in proportion to the ball's distance to each post (the angle bisector).
	local goalFrame, halfWidth = S.getOwnGoalFrame(character)
	local localBall = goalFrame and goalFrame:PointToObjectSpace(ball.Position)
	if not goalFrame or localBall.Z <= 0 then
		S.settleAt(rootPart, anchor, "Returning to goal")
		return
	end
	local flatBall = Vector3.new(localBall.X, 0, localBall.Z)
	local leftDistance = (flatBall - Vector3.new(-halfWidth, 0, 0)).Magnitude
	local rightDistance = (flatBall - Vector3.new(halfWidth, 0, 0)).Magnitude
	local splitX = -halfWidth + 2 * halfWidth * leftDistance / (leftDistance + rightDistance)
	local onLine = Vector3.new(splitX, 0, 0)
	local towardBall = (flatBall - onLine).Magnitude > 0 and (flatBall - onLine).Unit or Vector3.new(0, 0, 1)
	local target = onLine + towardBall * config.gkLine
	target = Vector3.new(math.clamp(target.X, -halfWidth + 2, halfWidth - 2), 0, math.max(target.Z, 0.5))
	local worldTarget = goalFrame:PointToWorldSpace(target)
	S.settleAt(rootPart, Vector3.new(worldTarget.X, rootPart.Position.Y, worldTarget.Z), "Positioning")
end)

-- Movement and grab loop.
Egoist.connections.physics = runService.Heartbeat:Connect(function()
	local config = Egoist.config
	local character, rootPart, humanoid = getCharacter()
	if not rootPart then
		return
	end

	if config.speed and humanoid then
		humanoid.WalkSpeed = config.speedValue
	end

	if not config.autoGrab then
		return
	end

	-- Step onto a loose ball in range.
	local ball, holder = findBall()
	if not ball or holder then
		return
	end
	local offset = ball.Position - rootPart.Position
	if offset.Magnitude > config.grabRange or offset.Magnitude < 2 then
		return
	end
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > 0 then
		local target = Vector3.new(ball.Position.X, rootPart.Position.Y, ball.Position.Z)
		rootPart.CFrame = CFrame.lookAt(target - flat.Unit * 1.5, target)
	end
	local leg = character:FindFirstChild("Right Leg")
	if leg then
		firetouchinterest(leg, ball, 0)
		firetouchinterest(leg, ball, 1)
	end
end)

-- Combat loop.
task.spawn(function()
	while shared.Egoist == Egoist do
		local config = Egoist.config
		local character, rootPart = getCharacter()
		local ball, holder = findBall()

		-- Tackle an opponent carrying the ball.
		if config.autoTackle and rootPart and ball and holder and isOpponent(character, holder) then
			if (ball.Position - rootPart.Position).Magnitude <= config.tackleRange then
				press(config.tackleKey)
			end
		end

		-- Cycle skill keys during matches.
		if config.autoSkill and character and character:GetAttribute("Playing") then
			for keyName in config.skillKeys:gmatch("[^,%s]+") do
				press(keyName)
				task.wait(config.skillDelay)
			end
		end

		task.wait(0.1)
	end
end)

--[[ ================================================================
	CURVE SHOT PREVIEW, GOAL BOX & BEST AIM
================================================================== ]]
-- Curve shot preview: learns an ability's flight path from recordings, then draws it from your facing.
local curveData = {}
local curveState = { pendingSince = nil, recording = nil, wasHolding = false }
S.CURVE_SEGMENTS = 40

---File used to keep recordings between executions.
function S.getCurveFile()
	return "EgoistCurves.json"
end

---Load saved recordings.
function S.loadCurves()
	local ok, content = pcall(readfile, S.getCurveFile())
	if not ok or not content then
		return
	end
	local decoded = select(2, pcall(httpService.JSONDecode, httpService, content))
	if type(decoded) == "table" then
		curveData = decoded
	end
end

---Save recordings.
function S.saveCurves()
	pcall(writefile, S.getCurveFile(), httpService:JSONEncode(curveData))
end

---Keep only the part of a recording where the ball was really flying: cut at teleports (goal resets)
---and, for old recordings, once the ball went farther than the goal was.
function S.cleanRecording(recording)
	if type(recording) ~= "table" then
		return
	end
	-- Last version's jitter bug stopped shots mid-air and called them short.
	if recording.gl and recording.o == "short" and not recording.v then
		recording.bad = true
		return
	end
	if recording.c then
		return
	end
	local points = recording.p or recording
	local kept = {}
	for index, point in points do
		local previous = points[index - 1]
		if previous then
			local jump = Vector3.new(point[2] - previous[2], point[3] - previous[3], point[4] - previous[4]).Magnitude
			if jump > 20 then
				break
			end
		end
		table.insert(kept, point)
		if recording.d and not recording.g and Vector3.new(point[2], 0, point[4]).Magnitude > recording.d + 10 then
			break
		end
	end
	if recording.p then
		recording.p = kept
		recording.c = true
	end
end

---Drop frames where the ball hadn't updated yet (they make fast shots wobble) and cut at the first
---ricochet (ball reverses off a wall, post or player), which Kaiser-type long shots always hit.
function S.trimRicochet(points)
	local kept = {}
	for _, point in points do
		local previous = kept[#kept]
		if not previous or Vector3.new(point[2] - previous[2], point[3] - previous[3], point[4] - previous[4]).Magnitude > 0.05 then
			table.insert(kept, point)
		end
	end
	-- Compare travel direction over ~6 stud chords so network jitter can't look like a bounce.
	local anchor, chord = kept[1], nil
	for index = 2, #kept do
		local point = kept[index]
		local delta = Vector3.new(point[2] - anchor[2], 0, point[4] - anchor[4])
		if delta.Magnitude >= 6 then
			if chord and delta.Unit:Dot(chord) < 0.2 then
				local trimmed = {}
				for keep = 1, index - 1 do
					trimmed[keep] = kept[keep]
				end
				return trimmed
			end
			chord = delta.Unit
			anchor = point
		end
	end
	return kept
end

S.loadCurves()
do
	for _, sides in curveData do
		for _, recordings in type(sides) == "table" and sides or {} do
			for _, recording in type(recordings) == "table" and recordings or {} do
				if type(recording) == "table" and recording.p and not recording.c2 then
					recording.p = S.trimRicochet(recording.p)
					recording.c2 = true
				end
			end
		end
	end
end
do
	for _, sides in curveData do
		for _, recordings in type(sides) == "table" and sides or {} do
			for _, recording in type(recordings) == "table" and recordings or {} do
				S.cleanRecording(recording)
			end
			for index = type(recordings) == "table" and #recordings or 0, 1, -1 do
				if type(recordings[index]) == "table" and recordings[index].bad then
					table.remove(recordings, index)
				end
			end
		end
	end
	S.saveCurves()
end

---Current character style (e.g. Rin), so each character keeps its own curves.
local function getStyle()
	-- A typed override wins, for games that don't update Style when you switch characters.
	local override = Egoist.config.styleOverride
	if type(override) == "string" and override:gsub("%s", "") ~= "" then
		return override
	end
	local data = localPlayer:FindFirstChild("Data")
	local style = data and data:FindFirstChild("Style")
	return style and style.Value ~= "" and style.Value or "Default"
end

---Which half of the field we're on, relative to the goal we attack ("Left" or "Right").
function S.getFieldSide(character, rootPart)
	local centre = getCentreSpot()
	local team = character:GetAttribute("Team")
	local enemyKeeper = liveFolder:FindFirstChild(team == 1 and "GoalKeeper2" or "GoalKeeper1")
	local keeperRoot = enemyKeeper and enemyKeeper:FindFirstChild("HumanoidRootPart")
	if not centre or not keeperRoot then
		return "Right"
	end
	local attack = Vector3.new(keeperRoot.Position.X - centre.X, 0, keeperRoot.Position.Z - centre.Z)
	if attack.Magnitude < 1 then
		return "Right"
	end
	local across = attack.Unit:Cross(Vector3.yAxis)
	local offset = Vector3.new(rootPart.Position.X - centre.X, 0, rootPart.Position.Z - centre.Z)
	return offset:Dot(across) >= 0 and "Right" or "Left"
end

---Flat facing frame of the character (position + yaw only).
function S.getFacingFrame(rootPart)
	local look = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(rootPart.Position, rootPart.Position + look.Unit)
end

---What actually happened to your shots at about this distance: goals vs. saves/misses, and your farthest goal.
function S.getRangeStats(style, distance, window)
	local styleData = curveData[style]
	local stats = { goals = 0, fails = 0, farthestGoal = 0, known = 0 }
	if not styleData or not distance then
		return stats
	end
	for _, recordings in styleData do
		for _, recording in type(recordings) == "table" and recordings or {} do
			if type(recording) == "table" and recording.o and recording.d then
				stats.known += 1
				if recording.o == "goal" then
					stats.farthestGoal = math.max(stats.farthestGoal, recording.d)
				end
				if math.abs(recording.d - distance) <= window then
					if recording.o == "goal" then
						stats.goals += 1
					else
						stats.fails += 1
					end
				end
			end
		end
	end
	return stats
end

---Root of the enemy goalkeeper (a player in goal, or the NPC keeper).
function S.getEnemyKeeperRoot(character)
	local team = character:GetAttribute("Team")
	for _, other in liveFolder:GetChildren() do
		if other ~= character and other:GetAttribute("Playing") == "GK" and other:GetAttribute("Team") ~= team then
			local root = other:FindFirstChild("HumanoidRootPart")
			if root then
				return root
			end
		end
	end
	local npc = liveFolder:FindFirstChild(team == 1 and "GoalKeeper2" or "GoalKeeper1")
	return npc and npc:FindFirstChild("HumanoidRootPart")
end

---Average all recordings for a style and side into one path of local points.
function S.getAveragePath(style, side, goalDistance, goalLocal)
	local styleData = curveData[style]
	local recordings = styleData and styleData[side]
	local mirrored = false
	if not recordings or #recordings == 0 then
		-- Fall back to the other side, mirrored.
		recordings = styleData and styleData[side == "Left" and "Right" or "Left"]
		mirrored = true
	end
	if not recordings or #recordings == 0 then
		return
	end
	if goalLocal and mirrored then
		goalLocal = Vector3.new(-goalLocal.X, goalLocal.Y, goalLocal.Z)
	end

	-- Score each recording by how similar its shooting spot was: where the goal sat relative to your facing.
	local entries, nearestGap = {}, math.huge
	for _, recording in recordings do
		local points = recording.p or recording
		if #points < 2 then
			continue
		end
		local gap
		if recording.gl and goalLocal then
			gap = Vector3.new(recording.gl[1] - goalLocal.X, 0, recording.gl[2] - goalLocal.Z).Magnitude
		elseif recording.d and goalDistance then
			gap = math.abs(goalDistance - recording.d) + 6
		end
		local weight = gap and 1 / (1 + (gap / 12) ^ 2) or 0.05
		-- Goals are the shots worth copying.
		if recording.o == "goal" then
			weight *= 1.5
		elseif recording.o == "blocked" then
			weight *= 0.3
		end
		-- Shots that never reached the line say nothing about range; they'd cut the line short.
		if not recording.g and recording.o ~= nil then
			weight *= 0.05
		end
		nearestGap = math.min(nearestGap, gap or math.huge)
		table.insert(entries, { points = points, weight = weight })
	end
	if #entries == 0 then
		return
	end

	-- Only the 3 closest matches: averaging every shot ever taken bends the line into shapes no shot makes.
	table.sort(entries, function(a, b)
		return a.weight > b.weight
	end)
	while #entries > 3 do
		table.remove(entries)
	end
	-- Draw only as far as all of them flew, so the line never kinks when one ends early.
	local duration = math.huge
	for _, entry in entries do
		duration = math.min(duration, entry.points[#entry.points][1])
	end

	local path = {}
	local cursors = {}
	local step = duration / S.CURVE_SEGMENTS
	for index = 0, S.CURVE_SEGMENTS do
		local t = index * step
		local sum, totalWeight = Vector3.zero, 0
		for entryIndex, entry in entries do
			local points = entry.points
			local pointIndex = cursors[entryIndex] or 2
			while pointIndex < #points and points[pointIndex][1] < t do
				pointIndex += 1
			end
			cursors[entryIndex] = pointIndex
			local pointA, pointB = points[pointIndex - 1], points[pointIndex]
			local span = pointB[1] - pointA[1]
			local alpha = span > 0 and math.clamp((t - pointA[1]) / span, 0, 1) or 1
			local position = Vector3.new(pointA[2], pointA[3], pointA[4]):Lerp(Vector3.new(pointB[2], pointB[3], pointB[4]), alpha)
			sum += position * entry.weight
			totalWeight += entry.weight
		end
		local point = sum / totalWeight
		table.insert(path, mirrored and Vector3.new(-point.X, point.Y, point.Z) or point)
	end

	-- Still flying fast at the end: carry on in a straight line a bit (corners sit a few studs farther than the middle).
	local extend = Egoist.config.curveExtend
	if #path >= 2 and extend > 0 and step > 0 then
		local last, before = path[#path], path[#path - 1]
		local velocity = (last - before) / step
		local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		if flatSpeed > 40 then
			local direction = velocity / flatSpeed
			for piece = 1, 4 do
				table.insert(path, last + direction * (extend * piece / 4))
			end
		end
	end
	return path, #entries, mirrored, nearestGap
end

-- Preview visuals.
S.CURVE_ORANGE = Color3.fromRGB(255, 150, 60)
S.CURVE_GREEN = Color3.fromRGB(70, 230, 120)
S.CURVE_RED = Color3.fromRGB(255, 80, 80)
S.CURVE_YELLOW = Color3.fromRGB(255, 220, 60)
S.DRAW_SEGMENTS = 72

S.curveSegments = {}
for index = 1, S.DRAW_SEGMENTS do
	S.curveSegments[index] = createVisualPart(Enum.PartType.Cylinder, 0.2)
end
S.curveDots = {}
for index = 1, 8 do
	local dot = createVisualPart(Enum.PartType.Ball, 0.1)
	dot.Size = Vector3.new(0.55, 0.55, 0.55)
	S.curveDots[index] = dot
end
S.curveMarker = createVisualPart(Enum.PartType.Cylinder, 0.35)
S.curveMarker.Size = Vector3.new(0.15, 4, 4)
S.goalHitMarker = createVisualPart(Enum.PartType.Ball, 0.15)
S.goalHitMarker.Size = Vector3.new(2.2, 2.2, 2.2)
-- Best-aim guide line.
S.GUIDE_SEGMENTS = 30
S.guideSegments = {}
for index = 1, S.GUIDE_SEGMENTS do
	local segment = createVisualPart(Enum.PartType.Block, 0.55)
	segment.Color = Color3.fromRGB(200, 255, 220)
	S.guideSegments[index] = segment
end

---Hide the best-aim guide.
function S.hideGuide()
	for _, segment in S.guideSegments do
		segment.Parent = nil
	end
end

-- Distance readout shown at the end of the curve line.
S.curveInfo = Instance.new("BillboardGui")
S.curveInfo.Size = UDim2.fromOffset(260, 34)
S.curveInfo.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
S.curveInfo.AlwaysOnTop = true
S.curveInfoLabel = Instance.new("TextLabel")
S.curveInfoLabel.Size = UDim2.fromScale(1, 1)
S.curveInfoLabel.BackgroundTransparency = 1
S.curveInfoLabel.Font = Enum.Font.GothamBold
S.curveInfoLabel.TextSize = 13
S.curveInfoLabel.TextStrokeTransparency = 0.4
S.curveInfoLabel.TextColor3 = Color3.new(1, 1, 1)
S.curveInfoLabel.Parent = S.curveInfo

S.goalBoxEdges = {}
for index = 1, 4 do
	S.goalBoxEdges[index] = createVisualPart(Enum.PartType.Block, 0.35)
end

---Hide the curve preview.
function S.hideCurve()
	for _, segment in S.curveSegments do
		segment.Parent = nil
	end
	for _, dot in S.curveDots do
		dot.Parent = nil
	end
	S.curveMarker.Parent = nil
	S.goalHitMarker.Parent = nil
	S.curveInfo.Parent = nil
	S.hideGuide()
end

---Hide the goal box outline.
function S.hideGoalBox()
	for _, edge in S.goalBoxEdges do
		edge.Parent = nil
	end
end

---Catmull-Rom point between p1 and p2.
function S.catmullRom(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

---Resample a point list into a smooth curve with a fixed number of points.
function S.smoothPath(points, count)
	local smooth = {}
	local spans = #points - 1
	for index = 0, count do
		local position = index / count * spans
		local span = math.min(math.floor(position), spans - 1)
		local t = position - span
		local p0 = points[math.max(span, 1)]
		local p1 = points[span + 1]
		local p2 = points[span + 2]
		local p3 = points[math.min(span + 3, #points)]
		table.insert(smooth, S.catmullRom(p0, p1, p2, p3, t))
	end
	return smooth
end

---The game's own goal zone we shoot into: Field.Locations.Team<ourTeam>Goal.
function S.getTargetGoalPart(character)
	local field = world.Map:FindFirstChild("Field")
	local locations = field and field:FindFirstChild("Locations")
	local team = character:GetAttribute("Team")
	return locations and team and locations:FindFirstChild("Team" .. tostring(team) .. "Goal")
end

---Goal mouth frame (centre of the goal line on the ground, LookVector into the goal) plus its size.
---Goal mouth frame for a goal zone part (LookVector points into the goal), half width, height.
function S.getGoalFrameFromPart(goalPart)
	local centre = getCentreSpot()
	if not goalPart or not centre then
		return
	end
	local toCentre = goalPart.CFrame:VectorToObjectSpace(centre - goalPart.Position)
	local size = goalPart.Size
	local normal, depth, width
	if math.abs(toCentre.X) > math.abs(toCentre.Z) then
		normal = Vector3.new(math.sign(toCentre.X), 0, 0)
		depth, width = size.X, size.Z
	else
		normal = Vector3.new(0, 0, math.sign(toCentre.Z))
		depth, width = size.Z, size.X
	end
	local worldNormal = goalPart.CFrame:VectorToWorldSpace(normal)
	local mouth = goalPart.Position + worldNormal * (depth / 2)
	mouth = Vector3.new(mouth.X, goalPart.Position.Y - size.Y / 2, mouth.Z)
	return CFrame.lookAt(mouth, mouth - worldNormal), width / 2, size.Y
end

---Our own goal: the zone the other team shoots into.
function S.getOwnGoalFrame(character)
	local field = world.Map:FindFirstChild("Field")
	local locations = field and field:FindFirstChild("Locations")
	local team = character:GetAttribute("Team")
	local otherTeam = team == 1 and 2 or 1
	return S.getGoalFrameFromPart(locations and locations:FindFirstChild("Team" .. otherTeam .. "Goal"))
end

local function getEnemyGoalFrame(character)
	local goalPart = S.getTargetGoalPart(character)
	local centre = getCentreSpot()
	if goalPart and centre then
		-- Find which horizontal face of the zone looks toward the pitch.
		local toCentre = goalPart.CFrame:VectorToObjectSpace(centre - goalPart.Position)
		local size = goalPart.Size
		local normal, depth, width
		if math.abs(toCentre.X) > math.abs(toCentre.Z) then
			normal = Vector3.new(math.sign(toCentre.X), 0, 0)
			depth, width = size.X, size.Z
		else
			normal = Vector3.new(0, 0, math.sign(toCentre.Z))
			depth, width = size.Z, size.X
		end
		local worldNormal = goalPart.CFrame:VectorToWorldSpace(normal)
		local mouth = goalPart.Position + worldNormal * (depth / 2)
		mouth = Vector3.new(mouth.X, goalPart.Position.Y - size.Y / 2, mouth.Z)
		return CFrame.lookAt(mouth, mouth - worldNormal), width / 2, size.Y
	end

	-- Fallback when the zone isn't found: estimate from sliders.
	local team = character:GetAttribute("Team")
	local enemyKeeper = liveFolder:FindFirstChild(team == 1 and "GoalKeeper2" or "GoalKeeper1")
	local keeperRoot = enemyKeeper and enemyKeeper:FindFirstChild("HumanoidRootPart")
	if not centre or not keeperRoot then
		return
	end
	local attack = Vector3.new(keeperRoot.Position.X - centre.X, 0, keeperRoot.Position.Z - centre.Z)
	if attack.Magnitude < 10 then
		return
	end
	local direction = attack.Unit
	local lineCentre = Vector3.new(centre.X, keeperRoot.Position.Y - 3, centre.Z) + direction * (attack.Magnitude + Egoist.config.goalLineOffset)
	return CFrame.lookAt(lineCentre, lineCentre + direction), Egoist.config.goalWidth / 2, Egoist.config.goalHeight
end

---Draw the goal mouth outline.
function S.drawGoalBox(goalFrame, halfWidth, height, color)
	local corners = {
		goalFrame:PointToWorldSpace(Vector3.new(-halfWidth, 0, 0)),
		goalFrame:PointToWorldSpace(Vector3.new(-halfWidth, height, 0)),
		goalFrame:PointToWorldSpace(Vector3.new(halfWidth, height, 0)),
		goalFrame:PointToWorldSpace(Vector3.new(halfWidth, 0, 0)),
	}
	for index, edge in S.goalBoxEdges do
		local a, b = corners[index], corners[index % 4 + 1]
		edge.Size = Vector3.new(0.25, 0.25, (b - a).Magnitude)
		edge.CFrame = CFrame.lookAt((a + b) / 2, b)
		edge.Color = color
		edge.Parent = visualsFolder
	end
end

---Check where a world path crosses the goal line. Returns "goal", "edge", "miss" or "short", plus the crossing point.
function S.judgeShot(worldPoints, goalFrame, halfWidth, height)
	for index = 2, #worldPoints do
		local a = goalFrame:PointToObjectSpace(worldPoints[index - 1])
		local b = goalFrame:PointToObjectSpace(worldPoints[index])
		-- Goal frame looks into the goal, so crossing means local Z going from > 0 to <= 0.
		if a.Z > 0 and b.Z <= 0 then
			local alpha = a.Z / (a.Z - b.Z)
			local hit = a:Lerp(b, alpha)
			local margin = Egoist.config.goalMargin
			local inside = math.abs(hit.X) <= halfWidth and hit.Y >= -0.5 and hit.Y <= height
			local clear = math.abs(hit.X) <= halfWidth - margin and hit.Y <= height - margin
			local verdict = clear and "goal" or inside and "edge" or "miss"
			return verdict, goalFrame:PointToWorldSpace(hit)
		end
	end
	return "short"
end

---Where a path (local to a facing frame) crosses the goal line, and how much room it has.
function S.getGoalClearance(path, frame, goalFrame, halfWidth, height)
	local previous = goalFrame:PointToObjectSpace(frame:PointToWorldSpace(path[1]))
	for index = 2, #path do
		local current = goalFrame:PointToObjectSpace(frame:PointToWorldSpace(path[index]))
		if previous.Z > 0 and current.Z <= 0 then
			local hit = previous:Lerp(current, previous.Z / (previous.Z - current.Z))
			-- Smallest distance to a post, the crossbar or the ground.
			return math.min(halfWidth - math.abs(hit.X), height - hit.Y, hit.Y + 0.5), hit
		end
		previous = current
	end
end

---Search facing angles for the one that lands farthest from the frame of the goal.
function S.findBestAim(pathFor, frame, goalFrame, halfWidth, height, keeperX)
	local bestOffset, bestClearance = nil, -math.huge
	for offset = -36, 36, 2 do
		local turned = frame * CFrame.Angles(0, math.rad(offset), 0)
		-- Each facing gets its own path, matched to shots taken from that angle.
		local path = pathFor(turned)
		local clearance, hit = path and S.getGoalClearance(path, turned, goalFrame, halfWidth, height)
		-- Stay away from the keeper too, not just the posts.
		if clearance and keeperX then
			clearance = math.min(clearance, math.abs(hit.X - keeperX) - Egoist.config.curveKeeperReach)
		end
		-- Prefer smaller turns when clearance is nearly equal.
		if clearance and clearance - math.abs(offset) * 0.02 > bestClearance then
			bestOffset, bestClearance = offset, clearance - math.abs(offset) * 0.02
		end
	end
	return bestOffset, bestClearance
end

-- Start a recording window when the curve key is pressed with the ball.
Egoist.connections.curveInput = userInputService.InputBegan:Connect(function(input, processed)
	-- The game may sink the key for its ability, so don't skip processed input here.
	if not Egoist.config.curveRecord then
		return
	end
	if input.KeyCode.Name ~= Egoist.config.curveKey then
		return
	end
	local character = localPlayer.Character
	local _, holder = findBall()
	if character and holder == character then
		curveState.pendingSince = os.clock()
		Egoist.notify("Curve recorder", "Waiting for the ball to leave your feet...")
	else
		Egoist.notify("Curve recorder", "You need the ball when pressing " .. Egoist.config.curveKey)
	end
end)

Egoist.connections.curve = runService.Heartbeat:Connect(function()
	local config = Egoist.config
	local character, rootPart = getCharacter()
	if not rootPart then
		S.hideCurve()
		return
	end
	local ball, holder = findBall()

	-- Recording: starts when the ball leaves your feet, after the curve key or (Learn From Every Shot) on any release.
	local released = ball and holder == nil and not curveState.recording
	local autoStart = released and config.curveLearn and curveState.wasHolding
	if curveState.pendingSince and not curveState.recording and os.clock() - curveState.pendingSince > 3 then
		curveState.pendingSince = nil
		Egoist.notify("Curve recorder", "Ball never left your feet, nothing recorded")
	end
	if released and (autoStart or curveState.pendingSince) then
		local releaseGoalFrame, releaseHalfWidth, releaseHeight = getEnemyGoalFrame(character)
		curveState.recording = {
			goalFrame = releaseGoalFrame,
			halfWidth = releaseHalfWidth,
			height = releaseHeight,
			goalDistance = releaseGoalFrame and Vector3.new(releaseGoalFrame.Position.X - rootPart.Position.X, 0, releaseGoalFrame.Position.Z - rootPart.Position.Z).Magnitude,
			frame = S.getFacingFrame(rootPart),
			side = S.getFieldSide(character, rootPart),
			style = getStyle(),
			startClock = os.clock(),
			points = {},
			lastMove = os.clock(),
			lastPosition = ball.Position,
			maxSpeed = 0,
			lastClock = os.clock(),
			goalLocal = releaseGoalFrame and S.getFacingFrame(rootPart):PointToObjectSpace(releaseGoalFrame.Position),
			manual = curveState.pendingSince ~= nil,
		}
		curveState.pendingSince = nil
	end

	local recording = curveState.recording
	if recording then
		local elapsed = os.clock() - recording.startClock
		local finished = not ball or holder ~= nil or elapsed > 4
		-- Who stopped it decides the outcome.
		if holder and holder ~= character then
			recording.outcome = holder:GetAttribute("Playing") == "GK" and "saved" or "blocked"
		end
		-- A huge jump means the ball was reset after a goal, not flying.
		if ball and not finished and (ball.Position - recording.lastPosition).Magnitude > 20 then
			finished = true
		end
		if ball and not finished then
			local localPoint = recording.frame:PointToObjectSpace(ball.Position)
			table.insert(recording.points, { elapsed, localPoint.X, localPoint.Y, localPoint.Z })
			local deltaTime = os.clock() - recording.lastClock
			if deltaTime > 0 then
				recording.maxSpeed = math.max(recording.maxSpeed, (ball.Position - recording.lastPosition).Magnitude / deltaTime)
			end
			recording.lastClock = os.clock()
			-- Goal line: inside the frame is a goal, outside is a miss. Keep recording the free flight after it.
			if recording.goalFrame and not recording.crossed then
				local goalLocal = recording.goalFrame:PointToObjectSpace(ball.Position)
				if goalLocal.Z <= 0 then
					recording.crossed = os.clock()
					local inside = math.abs(goalLocal.X) <= (recording.halfWidth or 23) + 1 and goalLocal.Y <= (recording.height or 17) + 1
					recording.outcome = inside and "goal" or "miss"
				end
			end
			-- Stop when it hits something (net, post, player): flat speed halves or it turns sharply.
			local moved = ball.Position - (recording.sample or ball.Position)
			if moved.Magnitude > 0.3 then
				local sampleTime = os.clock() - (recording.sampleClock or os.clock())
				local velocity = sampleTime > 0 and Vector3.new(moved.X, 0, moved.Z) / sampleTime or Vector3.zero
				local previous = recording.sampleVelocity
				-- Only after the goal line (network jitter made shots "hit" things mid-flight), and confirmed twice.
				if recording.crossed and previous and previous.Magnitude > 30 and velocity.Magnitude > 0 then
					local slowed = velocity.Magnitude < previous.Magnitude * 0.4
					local turned = velocity.Unit:Dot(previous.Unit) < 0.5
					recording.impacts = (slowed or turned) and (recording.impacts or 0) + 1 or 0
					if recording.impacts >= 2 then
						table.remove(recording.points)
						table.remove(recording.points)
						finished = true
					end
				end
				recording.sampleVelocity = velocity
				recording.sample = ball.Position
				recording.sampleClock = os.clock()
			elseif not recording.sample then
				recording.sample = ball.Position
				recording.sampleClock = os.clock()
			end
			if recording.crossed and os.clock() - recording.crossed > 1 then
				finished = true
			end
			if (ball.Position - recording.lastPosition).Magnitude > 0.2 then
				recording.lastMove = os.clock()
			end
			recording.lastPosition = ball.Position
			-- Ball has come to rest.
			if elapsed > 0.5 and os.clock() - recording.lastMove > 0.4 then
				finished = true
			end
		end
		if finished then
			curveState.recording = nil
			local outcome = recording.outcome or "short"
			-- Dribble touches and soft passes aren't shots.
			local isShot = recording.maxSpeed >= 45 and #recording.points >= 6
			if isShot then
				curveData[recording.style] = curveData[recording.style] or {}
				local list = curveData[recording.style][recording.side] or {}
				local goalLocal = recording.goalLocal
				recording.points = S.trimRicochet(recording.points)
				table.insert(list, { d = recording.goalDistance, p = recording.points, g = recording.crossed and true or nil, o = outcome, c = true, c2 = true, v = 2, gl = goalLocal and { goalLocal.X, goalLocal.Z } or nil })
				-- Keep the newest 40 per side so old guesses fade out.
				while #list > 40 do
					table.remove(list, 1)
				end
				curveState.lastSaved = { style = recording.style, side = recording.side }
				curveData[recording.style][recording.side] = list
				S.saveCurves()
				Egoist.notify("Shot learned: " .. string.upper(outcome), string.format("%s · %s side · %d studs out · %d saved", recording.style, recording.side, math.floor(recording.goalDistance or 0), #list))
			elseif recording.manual then
				Egoist.notify("Curve recorder", "Shot too short (touched or reset), not saved")
			end
		end
	end
	curveState.wasHolding = holder == character

	-- Preview from current facing.
	local goalFrame, goalHalfWidth, goalHeight = getEnemyGoalFrame(character)
	if config.showGoalBox and goalFrame then
		S.drawGoalBox(goalFrame, goalHalfWidth, goalHeight, Color3.fromRGB(255, 255, 255))
	else
		S.hideGoalBox()
	end

	-- Only preview your shot while you actually have the ball.
	if not config.curvePreview or holder ~= character then
		S.hideCurve()
		return
	end
	local currentDistance = goalFrame and Vector3.new(goalFrame.Position.X - rootPart.Position.X, 0, goalFrame.Position.Z - rootPart.Position.Z).Magnitude
	local frame = S.getFacingFrame(rootPart)
	local style, side = getStyle(), S.getFieldSide(character, rootPart)
	local path, _, _, nearestGap = S.getAveragePath(style, side, currentDistance, goalFrame and frame:PointToObjectSpace(goalFrame.Position))
	if not path or #path < 2 then
		S.hideCurve()
		return
	end
	local worldPoints = {}
	for _, localPoint in path do
		table.insert(worldPoints, frame:PointToWorldSpace(localPoint))
	end
	local smooth = S.smoothPath(worldPoints, S.DRAW_SEGMENTS)

	-- Colour by outcome: green scores, red crosses the line wide/high, orange falls short.
	local verdict, crossing = "short", nil
	if goalFrame then
		verdict, crossing = S.judgeShot(smooth, goalFrame, goalHalfWidth, goalHeight)
	end
	-- Don't promise a goal from distances we have no recordings near.
	if verdict == "goal" and nearestGap and nearestGap > config.curveTrustRange then
		verdict = "edge"
	end
	-- Real results beat the drawn line: never green past your farthest goal, or where most shots failed.
	local rangeStats = S.getRangeStats(getStyle(), currentDistance, config.curveTrustRange)
	if verdict == "goal" and rangeStats.known > 0 then
		if currentDistance > rangeStats.farthestGoal + 3 then
			verdict = "toofar"
		elseif rangeStats.fails > rangeStats.goals then
			verdict = "edge"
		end
	end
	-- The enemy keeper standing near where it crosses will likely catch it.
	if verdict == "goal" and config.curveKeeperCheck and crossing then
		local keeperRoot = S.getEnemyKeeperRoot(character)
		if keeperRoot then
			local keeperLocal = goalFrame:PointToObjectSpace(keeperRoot.Position)
			local hitLocal = goalFrame:PointToObjectSpace(crossing)
			if math.abs(keeperLocal.X - hitLocal.X) <= config.curveKeeperReach and hitLocal.Y <= 11 then
				verdict = "keeper"
			end
		end
	end
	local color = verdict == "toofar" and S.CURVE_ORANGE
		or verdict == "goal" and S.CURVE_GREEN
		or (verdict == "edge" or verdict == "keeper") and S.CURVE_YELLOW
		or verdict == "miss" and S.CURVE_RED
		or S.CURVE_ORANGE

	-- Stop drawing where the ball enters the goal.
	local lastIndex = #smooth
	if crossing then
		for index = 2, #smooth do
			if goalFrame:PointToObjectSpace(smooth[index]).Z <= 0 then
				lastIndex = index
				smooth[index] = crossing
				break
			end
		end
	end

	-- Tapered, fading line.
	for index, segment in S.curveSegments do
		local a, b = smooth[index], smooth[index + 1]
		if not b or index + 1 > lastIndex then
			segment.Parent = nil
			continue
		end
		local length = (b - a).Magnitude
		if length < 0.01 then
			segment.Parent = nil
			continue
		end
		local progress = index / lastIndex
		local thickness = 0.34 - 0.16 * progress
		segment.Size = Vector3.new(length, thickness, thickness)
		segment.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		segment.Color = color
		segment.Transparency = 0.1 + 0.35 * progress
		segment.Parent = visualsFolder
	end

	-- Evenly spaced dots make the curve's speed and bend easy to read.
	for index, dot in S.curveDots do
		local point = smooth[math.floor(index / (#S.curveDots + 1) * lastIndex)]
		if point then
			dot.Position = point
			dot.Color = color
			dot.Parent = visualsFolder
		else
			dot.Parent = nil
		end
	end

	-- Marker: on the goal line when it gets there, otherwise where the ball ends up.
	if crossing then
		S.goalHitMarker.Position = crossing
		S.goalHitMarker.Color = color
		S.goalHitMarker.Parent = visualsFolder
		S.curveMarker.Parent = nil
		if config.showGoalBox then
			S.drawGoalBox(goalFrame, goalHalfWidth, goalHeight, color)
		end
	else
		S.goalHitMarker.Parent = nil
		local finalPoint = smooth[lastIndex]
		S.curveMarker.CFrame = CFrame.new(finalPoint.X, finalPoint.Y, finalPoint.Z) * CFrame.Angles(0, 0, math.rad(90))
		S.curveMarker.Color = color
		S.curveMarker.Parent = visualsFolder
	end

	-- Readout: your distance, the closest recording, and what the colour means.
	local labels = { goal = "GOAL", edge = "RISKY", miss = "MISS", short = "SHORT / UNTESTED", keeper = "GK CAN REACH", toofar = "TOO FAR" }
	local gapText = rangeStats.known > 0
		and string.format("scored %d/%d from here · farthest goal %d", rangeStats.goals, rangeStats.goals + rangeStats.fails, math.floor(rangeStats.farthestGoal))
		or (nearestGap and nearestGap < math.huge and string.format("nearest rec %d off · shoot to learn", math.floor(nearestGap)) or "no data · shoot to learn")
	local aimText = ""
	S.hideGuide()
	local tooFar = rangeStats.known > 0 and currentDistance and currentDistance > rangeStats.farthestGoal + 3
	if config.curveBestAim and goalFrame and tooFar then
		aimText = string.format("  ·  get within %d studs", math.floor(rangeStats.farthestGoal))
	elseif config.curveBestAim and goalFrame then
		local keeperRoot = config.curveKeeperCheck and S.getEnemyKeeperRoot(character)
		local keeperX = keeperRoot and goalFrame:PointToObjectSpace(keeperRoot.Position).X
		local bestOffset, bestClearance = S.findBestAim(function(turned)
			return (S.getAveragePath(style, side, currentDistance, turned:PointToObjectSpace(goalFrame.Position)))
		end, frame, goalFrame, goalHalfWidth, goalHeight, keeperX)
		if bestOffset and bestClearance > 0 then
			if math.abs(bestOffset) <= 1 then
				aimText = "  ·  AIMED"
			else
				aimText = string.format("  ·  Turn %d° %s", math.abs(bestOffset), bestOffset > 0 and "left" or "right")
				-- Faint guide of the best shot.
				local bestFrame = frame * CFrame.Angles(0, math.rad(bestOffset), 0)
				local bestPath = S.getAveragePath(style, side, currentDistance, bestFrame:PointToObjectSpace(goalFrame.Position)) or path
				local stride = math.max(1, math.floor(#bestPath / S.GUIDE_SEGMENTS))
				local previous = bestFrame:PointToWorldSpace(bestPath[1])
				for index, segment in S.guideSegments do
					local localPoint = bestPath[1 + index * stride]
					local point = localPoint and bestFrame:PointToWorldSpace(localPoint)
					if point and goalFrame:PointToObjectSpace(previous).Z > 0 then
						segment.Size = Vector3.new(0.14, 0.14, (point - previous).Magnitude)
						segment.CFrame = CFrame.lookAt((previous + point) / 2, point)
						segment.Parent = visualsFolder
						previous = point
					else
						segment.Parent = nil
					end
				end
			end
		else
			aimText = "  ·  no scoring angle"
		end
	end
	S.curveInfoLabel.Text = string.format("%s · %d studs%s\n%s", labels[verdict] or "", math.floor(currentDistance or 0), aimText, gapText)
	S.curveInfoLabel.TextColor3 = color
	S.curveInfo.Adornee = crossing and S.goalHitMarker or S.curveMarker
	S.curveInfo.Parent = coreGui
end)

--[[ ================================================================
	SHOT SPOTS
================================================================== ]]
-- Shot spots: save scoring shots as ground markers that replay the exact shot when stepped on.
S.SPOTS_FILE = "EgoistSpots.json"
S.spotList = {}
S.spotState = { candidate = nil, lastGoals = nil, executing = false, cooldownUntil = 0, armed = {} }

---Load saved spots.
function S.loadSpots()
	local ok, content = pcall(readfile, S.SPOTS_FILE)
	if not ok or not content then
		return
	end
	local decodedOk, decoded = pcall(httpService.JSONDecode, httpService, content)
	if decodedOk and type(decoded) == "table" then
		S.spotList = decoded
	end
end

---Save spots.
function S.saveSpots()
	pcall(writefile, S.SPOTS_FILE, httpService:JSONEncode(S.spotList))
end

S.loadSpots()

---Our goal tally from match stats.
function S.getMyGoals()
	local stats = localPlayer:FindFirstChild("MatchStats")
	local goals = stats and stats:FindFirstChild("goals")
	return goals and goals.Value
end

---Store a shot relative to the goal we attack, so it works from either end.
function S.makeSpot(character, rootPart, keyName)
	local goalFrame = getEnemyGoalFrame(character)
	if not goalFrame then
		return
	end
	local localPosition = goalFrame:PointToObjectSpace(rootPart.Position)
	local localLook = goalFrame:VectorToObjectSpace(rootPart.CFrame.LookVector)
	return {
		x = localPosition.X, y = localPosition.Y, z = localPosition.Z,
		lx = localLook.X, lz = localLook.Z,
		key = keyName,
		style = getStyle(),
	}
end

---Add a spot and tell the player.
function S.addSpot(spot, reason)
	table.insert(S.spotList, spot)
	S.saveSpots()
	Egoist.notify("Shot spot saved", string.format("#%d · %s · %s", #S.spotList, spot.style, reason))
end

-- Remember each shot taken with the ball as a candidate spot.
--[[ ================================================================
	ABILITY COOLDOWNS
================================================================== ]]
-- Ability cooldown learning: a press that doesn't send the ball means the ability wasn't ready.
S.abilityCooldown = { lastUse = {}, estimate = {}, fromGame = {}, lastFiredKey = nil, lastFiredAt = 0, events = {} }

-- The game's Cooldown remote tells the client about cooldowns; take the duration from it.
do
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local cooldownRemote = remotes and remotes:FindFirstChild("Cooldown")
	if cooldownRemote and cooldownRemote:IsA("RemoteEvent") then
		Egoist.connections.cooldownRemote = cooldownRemote.OnClientEvent:Connect(function(...)
			local state = S.abilityCooldown
			-- Keep a short log for tuning.
			local parts = {}
			for index, value in { ... } do
				table.insert(parts, index .. "=" .. typeof(value) .. ":" .. tostring(value))
			end
			table.insert(state.events, string.format("%.2f %s", os.clock(), table.concat(parts, " ")))
			if #state.events > 50 then
				table.remove(state.events, 1)
			end

			-- Match it to the ability we just pressed (the event can arrive before the ball leaves).
			local key = state.lastPressKey
			if not key or os.clock() - (state.lastPressAt or 0) > 1.5 then
				return
			end
			for _, value in { ... } do
				if type(value) == "number" and value >= 0.5 and value <= 120 then
					-- Treat the number as time left from now.
					state.estimate[key] = value
					state.lastUse[key] = os.clock()
					state.fromGame[key] = true
					break
				end
			end
		end)
	end
end

---Seconds until an ability key is ready (0 when ready).
function S.getAbilityWait(keyName)
	local lastUse = S.abilityCooldown.lastUse[keyName]
	local estimate = S.abilityCooldown.estimate[keyName] or 0
	if not lastUse then
		return 0
	end
	return math.max(0, estimate - (os.clock() - lastUse))
end

---After a press with the ball, check whether the shot actually happened and learn from it.
function S.verifyAbilityPress(keyName)
	local pressedAt = os.clock()
	S.abilityCooldown.lastPressKey, S.abilityCooldown.lastPressAt = keyName, pressedAt
	local character = localPlayer.Character
	task.spawn(function()
		local fired = false
		while os.clock() - pressedAt < 0.9 do
			task.wait(0.05)
			local _, holder = findBall()
			if holder ~= character then
				fired = true
				break
			end
		end
		local cooldown = S.abilityCooldown
		if fired and not (cooldown.fromGame[keyName] and os.clock() - cooldown.lastUse[keyName] < 1.5) then
			cooldown.lastUse[keyName] = pressedAt
			cooldown.lastFiredKey, cooldown.lastFiredAt = keyName, pressedAt
		elseif cooldown.lastUse[keyName] and not cooldown.fromGame[keyName] then
			-- Still on cooldown: assume generously longer so we don't freeze again and again.
			local elapsed = pressedAt - cooldown.lastUse[keyName]
			cooldown.estimate[keyName] = math.max(cooldown.estimate[keyName] or 0, elapsed * 1.6 + 1.5)
		end
	end)
end

Egoist.connections.spotCandidate = userInputService.InputBegan:Connect(function(input)
	local name = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name or input.UserInputType.Name
	local config = Egoist.config
	if name ~= config.curveKey and name ~= config.shootKey then
		return
	end
	if S.spotState.executing then
		return
	end
	local character, rootPart = getCharacter()
	local _, holder = findBall()
	if rootPart and holder == character then
		S.spotState.candidate = { spot = S.makeSpot(character, rootPart, name), clock = os.clock() }
		if name ~= "MouseButton1" then
			S.verifyAbilityPress(name)
		end
	end
end)

-- Ground marker visuals, rebuilt when spots change.
S.spotMarkers = {}

---Create the visuals for one spot.
function S.createSpotMarker()
	local ring = createVisualPart(Enum.PartType.Cylinder, 0.2)
	ring.Size = Vector3.new(0.12, 6, 6)
	local core = createVisualPart(Enum.PartType.Cylinder, 0.65)
	core.Size = Vector3.new(0.14, 4.4, 4.4)
	core.Color = BACKGROUND
	local arrow = createVisualPart(Enum.PartType.Block, 0.15)
	arrow.Size = Vector3.new(0.6, 0.15, 4)
	local tip = createVisualPart(Enum.PartType.Ball, 0.15)
	tip.Size = Vector3.new(1.1, 1.1, 1.1)

	-- Soft green glow around the marker.
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(70, 230, 120)
	glow.Brightness = 1.2
	glow.Range = 9
	glow.Shadows = false
	glow.Parent = ring

	return {
		ring = ring, core = core, arrow = arrow, tip = tip, glow = glow,
		instances = { ring, core, arrow, tip },
	}
end

---Hide or remove marker visuals beyond a count.
function S.syncSpotMarkers(count)
	for index = #S.spotMarkers, count + 1, -1 do
		local marker = S.spotMarkers[index]
		for _, item in marker.instances do
			item:Destroy()
		end
		S.spotMarkers[index] = nil
	end
	for index = #S.spotMarkers + 1, count do
		S.spotMarkers[index] = S.createSpotMarker()
	end
end

---Hide every marker.
function S.hideSpotMarkers()
	for _, marker in S.spotMarkers do
		for _, item in marker.instances do
			item.Parent = nil
		end
	end
end

---Freeze, line up and fire a saved shot.
function S.executeSpot(spot, worldPosition, worldLook)
	local character, rootPart, humanoid = getCharacter()
	if not rootPart or not humanoid then
		return
	end
	S.spotState.executing = true
	local savedSpeed, savedJump, savedRotate = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.AutoRotate
	humanoid.WalkSpeed, humanoid.JumpPower, humanoid.AutoRotate = 0, 0, false

	task.spawn(function()
		local target = Vector3.new(worldPosition.X, rootPart.Position.Y, worldPosition.Z)
		local started = os.clock()
		-- Snap onto the spot immediately; turn the camera in one big step, then fire.
		rootPart.CFrame = CFrame.lookAt(target, target + worldLook)
		rootPart.AssemblyLinearVelocity = Vector3.zero
		while os.clock() - started < 0.2 do
			local deltaTime = runService.Heartbeat:Wait()
			rootPart.CFrame = CFrame.lookAt(target, target + worldLook)
			local remaining = turnCameraToward(worldLook, 120, deltaTime)
			if math.abs(remaining) < math.rad(3) then
				break
			end
		end
		rootPart.CFrame = CFrame.lookAt(target, target + worldLook)
		task.spawn(press, spot.key, spot.key == "MouseButton1" and Egoist.config.shootHold or 0.05)
		if spot.key ~= "MouseButton1" then
			S.verifyAbilityPress(spot.key)
		end

		-- Brief hold so the shot leaves in the saved direction.
		local holdUntil = os.clock() + 0.25
		while os.clock() < holdUntil do
			runService.Heartbeat:Wait()
			rootPart.CFrame = CFrame.lookAt(Vector3.new(target.X, rootPart.Position.Y, target.Z), Vector3.new(target.X, rootPart.Position.Y, target.Z) + worldLook)
		end

		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.AutoRotate = savedSpeed, savedJump, savedRotate
		S.spotState.executing = false
		S.spotState.cooldownUntil = os.clock() + 1
	end)
end

Egoist.connections.spots = runService.Heartbeat:Connect(function()
	local config = Egoist.config
	local character, rootPart = getCharacter()
	if not rootPart then
		S.hideSpotMarkers()
		return
	end

	-- Auto-save: a goal of ours shortly after a candidate shot.
	local goals = S.getMyGoals()
	if goals and S.spotState.lastGoals and goals > S.spotState.lastGoals then
		local candidate = S.spotState.candidate
		if config.autoSaveSpots and candidate and candidate.spot and os.clock() - candidate.clock < 8 then
			S.addSpot(candidate.spot, "scored")
			S.spotState.candidate = nil
		end
	end
	S.spotState.lastGoals = goals

	if not config.shotSpots then
		S.hideSpotMarkers()
		return
	end
	local goalFrame = getEnemyGoalFrame(character)
	if not goalFrame then
		S.hideSpotMarkers()
		return
	end

	S.syncSpotMarkers(#S.spotList)
	local _, holder = findBall()
	local hasBall = holder == character
	local pulse = 0.2 + 0.15 * math.sin(os.clock() * 4)

	for index, spot in S.spotList do
		local marker = S.spotMarkers[index]
		local position = goalFrame:PointToWorldSpace(Vector3.new(spot.x, spot.y, spot.z))
		local look = goalFrame:VectorToWorldSpace(Vector3.new(spot.lx, 0, spot.lz))
		look = Vector3.new(look.X, 0, look.Z)
		look = look.Magnitude > 0 and look.Unit or Vector3.new(0, 0, -1)
		local ground = Vector3.new(position.X, rootPart.Position.Y - 2.9, position.Z)
		local matchesStyle = spot.style == getStyle()
		-- Other characters' spots are hidden (and never fire) unless asked for.
		if not matchesStyle and not config.showOtherSpots then
			for _, item in marker.instances do
				item.Parent = nil
			end
			continue
		end

		-- Green with a glow; dimmer while you don't have the ball, grey for other characters.
		local green = Color3.fromRGB(70, 230, 120)
		local color = matchesStyle and (hasBall and green or green:Lerp(BACKGROUND, 0.35)) or SUBTEXT
		marker.ring.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
		marker.ring.Color = color
		marker.ring.Transparency = pulse
		marker.core.CFrame = CFrame.new(ground + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90))
		marker.arrow.CFrame = CFrame.lookAt(ground + Vector3.new(0, 0.1, 0) + look * 2.2, ground + look * 10)
		marker.arrow.Color = color
		marker.tip.Position = ground + Vector3.new(0, 0.1, 0) + look * 4.3
		marker.tip.Color = color
		for _, item in { marker.ring, marker.core, marker.arrow, marker.tip } do
			item.Parent = visualsFolder
		end

		-- Trigger: step on with the ball; must step off before it can fire again.
		local distance = Vector3.new(rootPart.Position.X - ground.X, 0, rootPart.Position.Z - ground.Z).Magnitude
		if distance > config.spotRadius + 2 then
			S.spotState.armed[index] = true
		end
		-- Only fire when the ability is ready; show the countdown otherwise.
		local waitTime = S.getAbilityWait(spot.key)
		-- Cooling down: fade the marker and drop the glow instead of showing numbers.
		marker.glow.Enabled = matchesStyle and waitTime == 0
		marker.glow.Brightness = hasBall and 1.6 or 0.9
		if waitTime > 0 then
			marker.ring.Color = color:Lerp(SUBTEXT, 0.6)
			marker.arrow.Color = marker.ring.Color
			marker.tip.Color = marker.ring.Color
		end
		if waitTime == 0 and matchesStyle and hasBall and distance <= config.spotRadius and S.spotState.armed[index] ~= false
			and not S.spotState.executing and os.clock() > S.spotState.cooldownUntil then
			S.spotState.armed[index] = false
			S.executeSpot(spot, position, look)
		end
	end
end)

--[[ ================================================================
	ENEMY SHOT PREVIEW
================================================================== ]]
-- Enemy shot preview: draw an opponent's curve shot into our goal while they hold the ball.
S.enemyPreview = { segments = {}, marker = nil }
for index = 1, 48 do
	S.enemyPreview.segments[index] = createVisualPart(Enum.PartType.Cylinder, 0.25)
end
S.enemyPreview.marker = createVisualPart(Enum.PartType.Ball, 0.15)
S.enemyPreview.marker.Size = Vector3.new(2.4, 2.4, 2.4)

---A player's chosen style (character) from their Data folder.
function S.getPlayerStyle(player)
	local data = player and player:FindFirstChild("Data")
	local style = data and data:FindFirstChild("Style")
	return style and style.Value ~= "" and style.Value or nil
end

---Hide the enemy preview.
function S.hideEnemyPreview()
	for _, segment in S.enemyPreview.segments do
		segment.Parent = nil
	end
	S.enemyPreview.marker.Parent = nil
end

Egoist.connections.enemyPreview = runService.Heartbeat:Connect(function()
	local character = localPlayer.Character
	if not Egoist.config.enemyPreview or not character then
		S.hideEnemyPreview()
		return
	end
	local _, holder = findBall()
	if not holder or not isOpponent(character, holder) then
		S.hideEnemyPreview()
		return
	end
	local holderRoot = holder:FindFirstChild("HumanoidRootPart")
	local player = playersService:GetPlayerFromCharacter(holder)
	local style = S.getPlayerStyle(player)
	-- Their target is our goal; reuse the same helpers from their point of view.
	local goalFrame, halfWidth, height = getEnemyGoalFrame(holder)
	if not holderRoot or not style or not goalFrame then
		S.hideEnemyPreview()
		return
	end
	local distance = Vector3.new(goalFrame.Position.X - holderRoot.Position.X, 0, goalFrame.Position.Z - holderRoot.Position.Z).Magnitude
	local frame = S.getFacingFrame(holderRoot)
	local path = S.getAveragePath(style, S.getFieldSide(holder, holderRoot), distance, frame:PointToObjectSpace(goalFrame.Position))
	if not path or #path < 2 then
		S.hideEnemyPreview()
		return
	end

	local worldPoints = {}
	for _, localPoint in path do
		table.insert(worldPoints, frame:PointToWorldSpace(localPoint))
	end
	-- From far away the learned path stops short; as keeper you still need to see where it's headed, so carry it on to our goal line.
	local last, before = worldPoints[#worldPoints], worldPoints[#worldPoints - 1]
	local lastLocal = goalFrame:PointToObjectSpace(last)
	local direction = (last - before).Magnitude > 0.01 and (last - before).Unit
	local directionLocal = direction and goalFrame:VectorToObjectSpace(direction)
	if lastLocal.Z > 0 and directionLocal and directionLocal.Z < -0.05 then
		local reach = math.min(lastLocal.Z / -directionLocal.Z, 200)
		for piece = 1, 6 do
			local point = goalFrame:PointToObjectSpace(last + direction * (reach * piece / 6 + (piece == 6 and 0.5 or 0)))
			-- Keep it off the ground and within sensible height.
			point = Vector3.new(point.X, math.clamp(point.Y, 0.5, height + 6), point.Z)
			table.insert(worldPoints, goalFrame:PointToWorldSpace(point))
		end
	end
	local smooth = S.smoothPath(worldPoints, #S.enemyPreview.segments)
	local verdict, crossing = S.judgeShot(smooth, goalFrame, halfWidth, height)
	-- Danger colours from our side: red would score on us, yellow is close, grey misses.
	local color = verdict == "goal" and Color3.fromRGB(255, 70, 70)
		or verdict == "edge" and Color3.fromRGB(255, 200, 60)
		or Color3.fromRGB(150, 150, 160)

	local lastIndex = #smooth
	if crossing then
		for index = 2, #smooth do
			if goalFrame:PointToObjectSpace(smooth[index]).Z <= 0 then
				lastIndex = index
				smooth[index] = crossing
				break
			end
		end
	end
	for index, segment in S.enemyPreview.segments do
		local a, b = smooth[index], smooth[index + 1]
		if not b or index + 1 > lastIndex or (b - a).Magnitude < 0.01 then
			segment.Parent = nil
			continue
		end
		local length = (b - a).Magnitude
		segment.Size = Vector3.new(length, 0.26, 0.26)
		segment.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		segment.Color = color
		segment.Parent = visualsFolder
	end
	S.enemyPreview.marker.Position = smooth[lastIndex]
	S.enemyPreview.marker.Color = color
	S.enemyPreview.marker.Parent = visualsFolder
end)

--[[ ================================================================
	AUTO DRIBBLE
================================================================== ]]
-- Auto dribble: dodge when an opponent lunges at us while we have the ball.
S.dribble = {
	lastDodge = 0,
	-- Tackle start animation, found from your animation log (starts every tackle, 6-21 studs out).
	tackleIds = { ["rbxassetid://123167891476953"] = true },
	armed = {},
	animationLog = {},
	watched = {},
}

---Load learned tackle animation ids.
function S.loadTackleIds()
	local ok, content = pcall(readfile, "EgoistTackles.json")
	if ok and content then
		local decodedOk, decoded = pcall(httpService.JSONDecode, httpService, content)
		if decodedOk and type(decoded) == "table" then
			for _, id in decoded do
				S.dribble.tackleIds[tostring(id)] = true
			end
		end
	end
end
S.loadTackleIds()

---Do we have the ball? Checks every signal the game gives, and says which ones are on.
function S.iHaveBall(character, raw)
	if not character then
		return false, "no character"
	end
	local ballSlot = character:FindFirstChild("Ball")
	local holding = ballSlot and ballSlot:FindFirstChild("Holding")
	local heldPart = holding and holding:FindFirstChildWhichIsA("BasePart", true) ~= nil
	local info = character:FindFirstChild("Info")
	local holdingValue = info and info:FindFirstChild("HoldingBall")
	local valueSays = holdingValue ~= nil and holdingValue.Value ~= "None" and holdingValue.Value ~= ""
	local display = character:FindFirstChild("BallDisplay") ~= nil
	local attribute = character:GetAttribute("HoldBallSince")
	local attributeSays = type(attribute) == "number" and attribute > 0

	-- A loose ball right at your feet that you touched last still counts (knocked ahead while running).
	local nearLoose = false
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, container in ballsFolder:GetChildren() do
			local ballPart = container:FindFirstChild("BallPart")
			local ballInfo = container:FindFirstChild("Info") or ballPart and ballPart:FindFirstChild("Info")
			local lastOwner = ballInfo and ballInfo:FindFirstChild("LastOwner")
			local ownerValue = lastOwner and lastOwner.Value
			local mine = ownerValue == localPlayer or ownerValue == character or ownerValue == localPlayer.Name
			if ballPart and mine and (ballPart.Position - root.Position).Magnitude <= 6 then
				nearLoose = true
				break
			end
		end
	end

	-- Only the real hold signals count; the attribute stays set after you lose the ball.
	local now = heldPart or valueSays or display
	if character == localPlayer.Character then
		local sinceHeld = os.clock() - (S.dribble.lastHeld or 0)
		if now then
			S.dribble.lastHeld = os.clock()
		elseif not raw and (sinceHeld <= 0.6 or nearLoose and sinceHeld <= 1.5) then
			now = true
		end
	end

	local detail = string.format("part=%s value=%s display=%s attr=%s loose=%s held%.1fs ago", tostring(heldPart), holdingValue and tostring(holdingValue.Value) or "?", tostring(display), tostring(attributeSays), tostring(nearLoose), os.clock() - (S.dribble.lastHeld or 0))
	return now, detail
end

---The dribble key the game itself has saved for you (Data.Dribble), if it's a real key name.
function S.getGameDribbleKey()
	local data = localPlayer:FindFirstChild("Data")
	local value = data and data:FindFirstChild("Dribble")
	local name = value and tostring(value.Value)
	if name and name ~= "" then
		local ok, keyCode = pcall(function()
			return Enum.KeyCode[name]
		end)
		if ok and keyCode then
			return name
		end
	end
end

---Windows virtual-key code for a key name (letters, digits, a few specials).
function S.getVirtualKey(keyName)
	if #keyName == 1 then
		return string.byte(string.upper(keyName))
	end
	local specials = { LeftShift = 0xA0, LeftControl = 0xA2, LeftAlt = 0xA4, Space = 0x20, Tab = 0x09, Q = 0x51 }
	return specials[keyName]
end

---Press a key with either input method.
function S.pressDodgeKey(key, method)
	if method == "keypress" then
		local code = S.getVirtualKey(key)
		if not keypress or not keyrelease or not code then
			return false
		end
		keypress(code)
		task.delay(0.1, keyrelease, code)
		return true
	end
	task.spawn(press, key, 0.1)
	return true
end

---Press the dribble key once, with a short cooldown.
function S.dodge(reason)
	if os.clock() - S.dribble.lastDodge < 0.8 then
		return
	end
	S.dribble.lastDodge = os.clock()
	local key = (Egoist.config.useGameDribbleKey and S.getGameDribbleKey()) or Egoist.config.dribbleKey
	S.pressDodgeKey(key, Egoist.config.dodgeKeypress and "keypress" or "virtual")
	table.insert(S.dribble.animationLog, string.format("%.2f DODGE pressed %s (%s) [game key=%s]", os.clock(), key, reason, tostring(S.getGameDribbleKey())))
	-- Record whether the dodge worked.
	task.delay(0.8, function()
		local kept = S.iHaveBall(localPlayer.Character, true)
		table.insert(S.dribble.animationLog, string.format("%.2f RESULT %s", os.clock(), kept and "KEPT THE BALL" or "LOST THE BALL"))
	end)
	if Egoist.notify then
		Egoist.notify("Auto dribble", reason)
	end
end

---Watch an opponent's animations: log them near us, and dodge on known tackles.
function S.watchCharacter(character)
	if S.dribble.watched[character] then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	S.dribble.watched[character] = animator.AnimationPlayed:Connect(function(track)
		local myCharacter, myRoot = getCharacter()
		local theirRoot = character:FindFirstChild("HumanoidRootPart")
		if not myRoot or not theirRoot or character == myCharacter then
			return
		end
		local distance = (theirRoot.Position - myRoot.Position).Magnitude
		if distance > math.max(25, Egoist.config.tackleWatchRange) then
			return
		end
		local id = track.Animation and track.Animation.AnimationId or "?"
		local note = ""
		-- A tackle started: arm against this attacker and dodge right before the lunge reaches us.
		if S.dribble.tackleIds[id] then
			local hasBall, ballDetail = S.iHaveBall(myCharacter)
			local reason
			if not Egoist.config.autoDribble then
				reason = "Auto Dribble is off"
			elseif not hasBall then
				reason = localPlayer.Name .. " (you) didn't have the ball [" .. ballDetail .. "]"
			elseif not isOpponent(myCharacter, character) then
				reason = string.format("same team (%s)", tostring(character:GetAttribute("Team")))
			elseif distance > Egoist.config.tackleWatchRange then
				reason = "too far away"
			end
			if reason then
				note = " TACKLE-IGNORED(" .. reason .. ")"
			elseif Egoist.config.proximityDodge then
				S.dribble.armed[character] = os.clock()
				local predicted = S.radiusThreat(character, myRoot)
				if predicted and predicted <= Egoist.config.proximityRadius then
					note = " TACKLE-IN-RADIUS"
					S.dribble.fired[character] = true
					S.dodge(string.format("%s tackle inside radius (%.1f, predicted %.1f)", character.Name, distance, predicted))
				else
					note = " TACKLE-ARMED"
				end
			elseif Egoist.config.dodgeInstant then
				-- Network lag already ate most of the lunge; dodge right away.
				note = " TACKLE-DODGE-NOW"
				S.dodge(string.format("%s tackle (%.1f studs)", character.Name, distance))
			else
				-- Dodge a short, fixed time after the tackle starts (like a player reacting), or sooner if it's already close.
				note = string.format(" TACKLE-DODGE-IN-%.2fs", Egoist.config.dodgeDelay)
				S.dribble.armed[character] = os.clock()
				task.delay(Egoist.config.dodgeDelay, function()
					if S.dribble.armed[character] and S.iHaveBall(localPlayer.Character) then
						S.dribble.armed[character] = nil
						S.dodge(string.format("%s tackle +%.2fs", character.Name, Egoist.config.dodgeDelay))
					end
				end)
			end
			if Egoist.notify and Egoist.config.dribbleDebug then
				Egoist.notify("Tackle by " .. character.Name, reason and ("Ignored: " .. reason) or (Egoist.config.dodgeInstant and not Egoist.config.proximityDodge and "Dodged instantly" or string.format("Dodging at %d studs", Egoist.config.proximityRadius)))
			end
		end
		local ping = math.floor(statsService.Network.ServerStatsItem["Data Ping"]:GetValue())
		table.insert(S.dribble.animationLog, string.format("%.2f %s dist=%.1f ping=%dms id=%s%s", os.clock(), character.Name, distance, ping, id, note))
		if #S.dribble.animationLog > 80 then
			table.remove(S.dribble.animationLog, 1)
		end
	end)
end

-- Dodge radius visuals: a ring at your feet plus a readout of the nearest opponent.
S.dodgeRing = createVisualPart(Enum.PartType.Cylinder, 0.55)
S.dodgeRingLabel = Instance.new("BillboardGui")
S.dodgeRingLabel.Size = UDim2.fromOffset(320, 40)
S.dodgeRingLabel.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
S.dodgeRingLabel.AlwaysOnTop = true
do
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 13
	text.TextStrokeTransparency = 0.4
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = S.dodgeRingLabel
end
S.dribble.inside = {}
S.dribble.fired = {}
S.dribble.velocities = {}
S.dribble.closing = {}
S.dribble.ignored = {}

---Measure an opponent's real velocity from how far they moved since last frame.
function S.trackVelocity(character, root)
	local now = os.clock()
	local position = root.Position
	local tracked = S.dribble.velocities[character]
	if not tracked then
		S.dribble.velocities[character] = { position = position, time = now, velocity = Vector3.zero }
		return
	end
	local deltaTime = now - tracked.time
	if deltaTime < 1 / 240 then
		return
	end
	local measured = (position - tracked.position) / deltaTime
	-- Big gaps (teleports, lag spikes) restart the measurement instead of spiking it.
	tracked.velocity = deltaTime > 0.25 and Vector3.zero or tracked.velocity:Lerp(measured, 0.6)
	tracked.position = position
	tracked.time = now
end

---Where an opponent will REALLY be right now: their replicated position is about ping/2 + interpolation old.
---@return number? predicted, number distance, number closing
function S.radiusThreat(character, myRoot)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, math.huge, 0
	end
	local offset = Vector3.new(myRoot.Position.X - root.Position.X, 0, myRoot.Position.Z - root.Position.Z)
	local distance = offset.Magnitude
	if distance < 0.01 then
		return 0, 0, 0
	end
	-- Other players' velocity doesn't replicate (always reads 0), so use the speed measured from their movement.
	local tracked = S.dribble.velocities[character]
	local theirVelocity = tracked and tracked.velocity or Vector3.zero
	local myVelocity = myRoot.AssemblyLinearVelocity
	local relative = Vector3.new(theirVelocity.X - myVelocity.X, 0, theirVelocity.Z - myVelocity.Z)
	local closing = relative:Dot(offset.Unit)
	local ping = statsService.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
	local lead = ping * 0.5 + 0.05 + Egoist.config.radiusLead / 1000
	return distance - 1.5 - math.max(closing, 0) * lead, distance, closing
end

---Nearest opponent to us and their flat distance.
function S.getNearestOpponent(myCharacter, myRoot)
	local nearest, nearestDistance = nil, math.huge
	for _, character in liveFolder:GetChildren() do
		if character ~= myCharacter and isOpponent(myCharacter, character) then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local distance = Vector3.new(root.Position.X - myRoot.Position.X, 0, root.Position.Z - myRoot.Position.Z).Magnitude
				if distance < nearestDistance then
					nearest, nearestDistance = character, distance
				end
			end
		end
	end
	return nearest, nearestDistance
end

Egoist.connections.dribble = runService.Heartbeat:Connect(function()
	local config = Egoist.config
	local myCharacter, myRoot = getCharacter()
	if not myRoot then
		S.dodgeRing.Parent = nil
		S.dodgeRingLabel.Parent = nil
		return
	end

	-- Proximity dodge: press E the moment an opponent steps inside the radius while you have the ball.
	local hasBall = S.iHaveBall(myCharacter)
	local nearest, nearestDistance = S.getNearestOpponent(myCharacter, myRoot)
	local radius = config.proximityRadius
	local triggered = false
	for _, character in liveFolder:GetChildren() do
		if character == myCharacter or not isOpponent(myCharacter, character) then
			continue
		end
		local theirRoot = character:FindFirstChild("HumanoidRootPart")
		if theirRoot then
			S.trackVelocity(character, theirRoot)
		end
		local predicted, distance, closing = S.radiusThreat(character, myRoot)
		if not predicted then
			continue
		end
		local armedAt = S.dribble.armed[character]
		local tackling = armedAt ~= nil and os.clock() - armedAt <= 0.8
		-- Only real threats burn the dodge: a tackle in progress or someone lunging at you.
		local threat = tackling or not config.radiusTacklesOnly or closing >= config.radiusLungeSpeed
		S.dribble.closing[character] = closing
		if predicted <= radius and not threat and not S.dribble.ignored[character] then
			S.dribble.ignored[character] = true
			table.insert(S.dribble.animationLog, string.format("%.2f %s in radius (%.1f) - IGNORED: only %.0f studs/s, needs %d to count as a tackle", os.clock(), character.Name, distance, closing, config.radiusLungeSpeed))
		end
		if predicted <= radius and threat then
			if not S.dribble.fired[character] then
				S.dribble.fired[character] = true
				if config.autoDribble and config.proximityDodge and hasBall then
					S.dodge(string.format("%s %s (%.1f studs, predicted %.1f, closing %.0f)", character.Name, tackling and "tackle in radius" or "lunging into radius", distance, predicted, closing))
					triggered = true
				else
					table.insert(S.dribble.animationLog, string.format("%.2f %s in radius (%.1f) - NO DODGE: %s", os.clock(), character.Name, distance,
						not config.autoDribble and "Auto Dribble off" or not config.proximityDodge and "Radius Dodge off" or "no ball [" .. select(2, S.iHaveBall(myCharacter)) .. "]"))
				end
			end
		elseif distance > radius + 2 and not tackling then
			S.dribble.fired[character] = nil
			S.dribble.ignored[character] = nil
		end
		S.dribble.inside[character] = distance <= radius or nil
	end

	if config.showDodgeRadius then
		local ground = myRoot.Position - Vector3.new(0, 2.9, 0)
		S.dodgeRing.Size = Vector3.new(0.1, radius * 2, radius * 2)
		S.dodgeRing.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
		local danger = nearestDistance <= radius
		S.dodgeRing.Color = triggered and Color3.fromRGB(255, 255, 255)
			or danger and Color3.fromRGB(255, 80, 80)
			or hasBall and Color3.fromRGB(70, 230, 120)
			or Color3.fromRGB(150, 150, 160)
		S.dodgeRing.Parent = visualsFolder
		S.dodgeRingLabel.Adornee = myRoot
		S.dodgeRingLabel.Text.Text = string.format("%s · nearest: %s · ball: %s",
			config.autoDribble and config.proximityDodge and "Auto dodge ON" or "Auto dodge OFF",
			nearest and string.format("%s %.1f (%.0f studs/s)", nearest.Name, nearestDistance, S.dribble.closing[nearest] or 0) or "none",
			hasBall and "yes" or "no")
		if config.dribbleDebug then
			S.dodgeRingLabel.Text.Text ..= "\n" .. select(2, S.iHaveBall(myCharacter))
		end
		S.dodgeRingLabel.Parent = coreGui
	else
		S.dodgeRing.Parent = nil
		S.dodgeRingLabel.Parent = nil
	end
	-- Keep animation watchers on everyone in the match.
	for _, character in liveFolder:GetChildren() do
		if character ~= myCharacter then
			S.watchCharacter(character)
		end
	end
	for character, connection in S.dribble.watched do
		if not character.Parent then
			connection:Disconnect()
			S.dribble.watched[character] = nil
		end
	end

	if not config.autoDribble then
		return
	end
	if not S.iHaveBall(myCharacter) then
		return
	end
	-- Tackle-animation check: dodge as an armed attacker's lunge is about to connect.
	for character, armedAt in S.dribble.armed do
		if os.clock() - armedAt > 0.7 or not character.Parent then
			S.dribble.armed[character] = nil
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		local offset = Vector3.new(myRoot.Position.X - root.Position.X, 0, myRoot.Position.Z - root.Position.Z)
		local distance = offset.Magnitude
		local relative = root.AssemblyLinearVelocity - myRoot.AssemblyLinearVelocity
		local closingSpeed = distance > 0.5 and Vector3.new(relative.X, 0, relative.Z):Dot(offset.Unit) or 0
		local timeToContact = closingSpeed > 5 and distance / closingSpeed or math.huge
		if distance <= math.max(config.dodgeContact, config.proximityRadius) or timeToContact <= config.dodgeReaction then
			S.dribble.armed[character] = nil
			S.dodge(string.format("%s tackled (%.1f studs)", character.Name, distance))
			return
		end
	end

	-- Early dodge: an opponent charging straight at us inside the danger radius is about to tackle.
	if config.earlyDodge then
		for _, character in liveFolder:GetChildren() do
			if character == myCharacter or not isOpponent(myCharacter, character) then
				continue
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then
				continue
			end
			local offset = Vector3.new(myRoot.Position.X - root.Position.X, 0, myRoot.Position.Z - root.Position.Z)
			local distance = offset.Magnitude
			if distance > config.earlyDodgeRange or distance < 0.5 then
				continue
			end
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			local facing = look.Magnitude > 0 and look.Unit:Dot(offset.Unit) or 0
			-- Closing speed from how fast the gap actually shrinks (replicated velocity is unreliable).
			S.dribble.gaps = S.dribble.gaps or {}
			local previous = S.dribble.gaps[character]
			local now = os.clock()
			local closingSpeed = 0
			if previous and now - previous.clock > 0 and now - previous.clock < 0.25 then
				local measured = (previous.distance - distance) / (now - previous.clock)
				closingSpeed = previous.speed + (measured - previous.speed) * 0.4
			end
			S.dribble.gaps[character] = { distance = distance, clock = now, speed = closingSpeed }
			if facing > 0.7 and closingSpeed > config.earlyDodgeSpeed then
				S.dodge(string.format("%s charging (%.0f studs)", character.Name, distance))
				return
			end
		end
	end

	-- Lunge check: someone closing on us faster than running speed, about to make contact.
	for _, character in liveFolder:GetChildren() do
		if character == myCharacter or not isOpponent(myCharacter, character) then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		local offset = Vector3.new(myRoot.Position.X - root.Position.X, 0, myRoot.Position.Z - root.Position.Z)
		local distance = offset.Magnitude
		if distance > config.dodgeRange or distance < 0.5 then
			continue
		end
		local relative = root.AssemblyLinearVelocity - myRoot.AssemblyLinearVelocity
		local closingSpeed = Vector3.new(relative.X, 0, relative.Z):Dot(offset.Unit)
		if closingSpeed >= config.lungeSpeed and distance / closingSpeed <= config.dodgeReaction then
			S.dodge(string.format("%s lunged (%.0f studs/s)", character.Name, closingSpeed))
			return
		end
	end
end)

--[[ ================================================================
	INTERFACE (window, themes, controls)
================================================================== ]]
-- Interface.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Egoist"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = gethui and gethui() or coreGui

---Create an instance with properties and children.
local function create(className, properties, children)
	local instance = Instance.new(className)
	for key, value in properties do
		instance[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end

---Corner helper.
local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

---Fade a frame's background on hover.
local function addHover(button, normal, hovered)
	button.MouseEnter:Connect(function()
		tweenService:Create(button, FAST, { BackgroundColor3 = hovered }):Play()
	end)
	button.MouseLeave:Connect(function()
		tweenService:Create(button, FAST, { BackgroundColor3 = normal }):Play()
	end)
end

-- Notifications.
S.toastHolder = create("Frame", {
	Size = UDim2.new(0, 260, 1, -20),
	Position = UDim2.new(1, -270, 0, 10),
	BackgroundTransparency = 1,
	Parent = screenGui,
}, {
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}),
})

---Show a toast notification.
local function notify(title, message)
	-- Long messages get a taller toast and stay up a little longer.
	local lines = math.clamp(math.ceil(#message / 38), 1, 6)
	local toast = create("CanvasGroup", {
		Size = UDim2.fromOffset(250, 38 + lines * 16),
		BackgroundColor3 = PANEL,
		GroupTransparency = 1,
		Parent = S.toastHolder,
	}, {
		corner(8),
		create("UIStroke", { Color = ACCENT, Transparency = 0.6 }),
		create("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = ACCENT, BorderSizePixel = 0 }),
		create("TextLabel", {
			Size = UDim2.new(1, -24, 0, 20),
			Position = UDim2.fromOffset(14, 8),
			BackgroundTransparency = 1,
			Text = title,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		create("TextLabel", {
			Size = UDim2.new(1, -24, 0, lines * 16),
			Position = UDim2.fromOffset(14, 28),
			BackgroundTransparency = 1,
			Text = message,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = SUBTEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
		}),
	})
	tweenService:Create(toast, TWEEN, { GroupTransparency = 0 }):Play()
	task.delay(2.5 + (lines - 1) * 1.2, function()
		local fade = tweenService:Create(toast, TWEEN, { GroupTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		toast:Destroy()
	end)
end

Egoist.notify = notify

-- Themes: accent presets the whole interface can switch between.
S.THEMES = {
	Ocean = { Color3.fromRGB(70, 160, 255), Color3.fromRGB(40, 95, 170) },
	Violet = { Color3.fromRGB(160, 110, 255), Color3.fromRGB(95, 60, 175) },
	Crimson = { Color3.fromRGB(255, 80, 105), Color3.fromRGB(165, 40, 60) },
	Emerald = { Color3.fromRGB(60, 220, 140), Color3.fromRGB(30, 135, 85) },
	Gold = { Color3.fromRGB(255, 195, 70), Color3.fromRGB(175, 120, 30) },
}
S.COLOR_PROPERTIES = { "BackgroundColor3", "TextColor3", "Color", "ScrollBarImageColor3", "Color3", "ImageColor3" }

---Swap a sequence's old accent keypoints for new ones.
function S.recolorSequence(sequence, oldAccent, oldDark, newAccent, newDark)
	local keypoints = {}
	for _, keypoint in sequence.Keypoints do
		local value = keypoint.Value
		if value == oldAccent then
			value = newAccent
		elseif value == oldDark then
			value = newDark
		end
		table.insert(keypoints, ColorSequenceKeypoint.new(keypoint.Time, value))
	end
	return ColorSequence.new(keypoints)
end

---Recolour everything using the current accent to a new theme.
local function applyTheme(name)
	local theme = S.THEMES[name]
	if not theme then
		return
	end
	local newAccent, newDark = theme[1], theme[2]
	local oldAccent, oldDark = ACCENT, ACCENT_DARK
	if newAccent == oldAccent then
		return
	end
	for _, object in screenGui:GetDescendants() do
		for _, property in S.COLOR_PROPERTIES do
			local ok, value = pcall(function()
				return object[property]
			end)
			if ok and typeof(value) == "Color3" then
				if value == oldAccent then
					tweenService:Create(object, TWEEN, { [property] = newAccent }):Play()
				elseif value == oldDark then
					tweenService:Create(object, TWEEN, { [property] = newDark }):Play()
				end
			end
		end
		if object:IsA("UIGradient") then
			object.Color = S.recolorSequence(object.Color, oldAccent, oldDark, newAccent, newDark)
		end
	end
	ACCENT, ACCENT_DARK = newAccent, newDark
	ballAdornment.Color3 = newAccent
	predictionMarker.Color = newAccent
	for _, segment in trajectorySegments do
		segment.Color = newAccent
	end
end

---Material-style ripple at the mouse position inside a clipped frame.
function S.ripple(target)
	local mouseLocation = userInputService:GetMouseLocation() - Vector2.new(0, 0)
	local relative = mouseLocation - target.AbsolutePosition
	local size = math.max(target.AbsoluteSize.X, target.AbsoluteSize.Y) * 2
	local circle = create("Frame", {
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(relative.X, relative.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		ZIndex = 5,
		Parent = target,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local tween = tweenService:Create(circle, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		circle:Destroy()
	end)
end

local window = create("CanvasGroup", {
	Size = UDim2.fromOffset(600, 420),
	Position = UDim2.new(0.5, -300, 0.5, -210),
	BackgroundColor3 = BACKGROUND,
	BorderSizePixel = 0,
	Parent = screenGui,
}, {
	corner(12),
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 205, 215)),
	}),
})

-- Animated glowing border (on a frame outside the canvas so it isn't clipped).
S.borderFrame = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = window,
})
local windowScale = create("UIScale", { Scale = 1, Parent = window })
S.borderStroke = create("UIStroke", {
	Color = Color3.new(1, 1, 1),
	Thickness = 1.6,
	Transparency = 0.15,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	Parent = window,
})
S.borderGradient = create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, ACCENT),
		ColorSequenceKeypoint.new(0.5, ACCENT_DARK),
		ColorSequenceKeypoint.new(1, ACCENT),
	}),
	Parent = S.borderStroke,
})
Egoist.connections.borderSpin = runService.RenderStepped:Connect(function(deltaTime)
	S.borderGradient.Rotation = (S.borderGradient.Rotation + deltaTime * 45) % 360
end)

-- Header.
local header = create("Frame", {
	Size = UDim2.new(1, 0, 0, 48),
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
	Parent = window,
}, {
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = ACCENT,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}),
})

S.logo = create("Frame", {
	Size = UDim2.fromOffset(28, 28),
	Position = UDim2.fromOffset(12, 10),
	BackgroundColor3 = ACCENT,
	Parent = header,
}, {
	corner(8),
	create("UIGradient", { Color = ColorSequence.new(ACCENT, ACCENT_DARK), Rotation = 45 }),
	create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "E",
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
	}),
})

create("TextLabel", {
	Size = UDim2.fromOffset(200, 18),
	Position = UDim2.fromOffset(48, 8),
	BackgroundTransparency = 1,
	RichText = true,
	Text = 'EGOIST <font color="#8C94A5" size="11">' .. VERSION .. "</font>",
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextColor3 = TEXT,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = header,
}, {
	create("UIGradient", {
		Name = "Shimmer",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, ACCENT),
			ColorSequenceKeypoint.new(0.55, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		}),
	}),
})

create("TextLabel", {
	Size = UDim2.fromOffset(240, 14),
	Position = UDim2.fromOffset(48, 26),
	BackgroundTransparency = 1,
	Text = "Project Egoist  ·  Delete to toggle",
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextColor3 = SUBTEXT,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = header,
})

---Create a header icon button.
function S.createHeaderButton(text, offset, color)
	local button = create("TextButton", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, offset, 0, 10),
		BackgroundColor3 = ELEMENT,
		AutoButtonColor = false,
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = color,
		Parent = header,
	}, { corner(6) })
	addHover(button, ELEMENT, HOVER)
	return button
end

local closeButton = S.createHeaderButton("×", -40, DANGER)
local minimizeButton = S.createHeaderButton("–", -74, TEXT)

-- Search box: filters settings on the open tab.
local searchBox = create("TextBox", {
	Size = UDim2.fromOffset(170, 28),
	Position = UDim2.new(1, -258, 0, 10),
	BackgroundColor3 = ELEMENT,
	PlaceholderText = "⌕  Search settings",
	PlaceholderColor3 = SUBTEXT,
	Text = "",
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = TEXT,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false,
	Parent = header,
}, { corner(6), create("UIPadding", { PaddingLeft = UDim.new(0, 10) }), create("UIStroke", { Color = HOVER }) })

-- Dragging.
do
	local dragging, dragStart, startPosition
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, dragStart, startPosition = true, input.Position, window.Position
		end
	end)
	Egoist.connections.dragMove = userInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			window.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end
	end)
	Egoist.connections.dragEnd = userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

-- Body holds sidebar and pages; collapses on minimize.
local body = create("Frame", {
	Size = UDim2.new(1, 0, 1, -48),
	Position = UDim2.fromOffset(0, 48),
	BackgroundTransparency = 1,
	Parent = window,
})

local sidebar = create("Frame", {
	Size = UDim2.new(0, 140, 1, -44),
	Position = UDim2.fromOffset(8, 8),
	BackgroundColor3 = PANEL,
	Parent = body,
}, {
	corner(8),
	create("UIListLayout", { Padding = UDim.new(0, 4) }),
	create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
})

S.indicator = create("Frame", {
	Size = UDim2.fromOffset(3, 18),
	BackgroundColor3 = ACCENT,
	BorderSizePixel = 0,
	ZIndex = 3,
	Parent = body,
}, { corner(2) })

-- Footer status bar.
S.footer = create("Frame", {
	Size = UDim2.new(1, -16, 0, 26),
	Position = UDim2.new(0, 8, 1, -32),
	BackgroundColor3 = PANEL,
	Parent = body,
}, { corner(6) })

S.statusDot = create("Frame", {
	Size = UDim2.fromOffset(8, 8),
	Position = UDim2.new(0, 10, 0.5, -4),
	BackgroundColor3 = SUBTEXT,
	Parent = S.footer,
}, { corner(4) })

S.statusLabel = create("TextLabel", {
	Size = UDim2.new(0.6, -26, 1, 0),
	Position = UDim2.fromOffset(24, 0),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	TextColor3 = TEXT,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = S.footer,
})

S.statsLabel = create("TextLabel", {
	Size = UDim2.new(0.4, -10, 1, 0),
	Position = UDim2.new(0.6, 0, 0, 0),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	TextColor3 = SUBTEXT,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = S.footer,
})

local pages, tabButtons, tabOrder = {}, {}, {}

---Switch to a tab.
local currentTab
local applySearch

local function selectTab(name)
	currentTab = name
	for tabName, page in pages do
		local active = tabName == name
		if active and not page.Visible then
			-- Slide the page in.
			page.Position = UDim2.fromOffset(170, 8)
			tweenService:Create(page, TWEEN, { Position = UDim2.fromOffset(156, 8) }):Play()
		end
		page.Visible = active
		tweenService:Create(tabButtons[tabName], TWEEN, {
			BackgroundColor3 = active and ELEMENT or PANEL,
			TextColor3 = active and TEXT or SUBTEXT,
		}):Play()
	end
	local index = table.find(tabOrder, name) - 1
	tweenService:Create(S.indicator, TWEEN, { Position = UDim2.fromOffset(14, 20 + index * 36) }):Play()
	if applySearch then
		applySearch()
	end
end

---Create a tab page.
local function createTab(name, icon)
	local page = create("ScrollingFrame", {
		Size = UDim2.new(1, -168, 1, -48),
		Position = UDim2.fromOffset(156, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = ACCENT,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = body,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingBottom = UDim.new(0, 6) }),
	})

	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = PANEL,
		AutoButtonColor = false,
		Text = "   " .. icon .. "   " .. name,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = SUBTEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sidebar,
	}, { corner(6) })

	button.MouseButton1Click:Connect(function()
		selectTab(name)
	end)
	button.MouseEnter:Connect(function()
		if currentTab ~= name then
			tweenService:Create(button, FAST, { BackgroundColor3 = HOVER, TextColor3 = TEXT }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		if currentTab ~= name then
			tweenService:Create(button, FAST, { BackgroundColor3 = PANEL, TextColor3 = SUBTEXT }):Play()
		end
	end)

	pages[name], tabButtons[name] = page, button
	table.insert(tabOrder, name)
	return page
end

S.layoutCounter = 0

---Next layout order.
function S.nextOrder()
	S.layoutCounter += 1
	return S.layoutCounter
end

---Section header.
S.lastSection = nil

---Section header; click it to collapse or expand the rows under it.
local function createSection(parent, title, collapsed)
	local section = { parent = parent, rows = {}, collapsed = collapsed or false }
	local header = create("TextButton", {
		Size = UDim2.new(1, -8, 0, 26),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = S.nextOrder(),
		Parent = parent,
	})
	header:SetAttribute("IsSection", true)
	local arrow = create("TextLabel", {
		Size = UDim2.fromOffset(14, 26),
		Position = UDim2.fromOffset(4, 2),
		BackgroundTransparency = 1,
		Text = section.collapsed and "▸" or "▾",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = ACCENT,
		Parent = header,
	})
	create("TextLabel", {
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(20, 2),
		BackgroundTransparency = 1,
		Text = string.upper(title),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = ACCENT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	create("Frame", {
		Size = UDim2.new(1, -24 - math.min(#title * 8, 160), 0, 1),
		Position = UDim2.new(0, 24 + math.min(#title * 8, 160), 0.5, 2),
		BackgroundColor3 = ACCENT,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Parent = header,
	})

	header.MouseButton1Click:Connect(function()
		section.collapsed = not section.collapsed
		arrow.Text = section.collapsed and "▸" or "▾"
		for _, row in section.rows do
			row.Visible = not section.collapsed
		end
	end)
	S.lastSection = section
	return section
end

---Base row with title and optional description.
local function createRow(parent, title, description, height)
	local row = create("Frame", {
		Size = UDim2.new(1, -8, 0, height or (description and 48 or 38)),
		BackgroundColor3 = PANEL,
		LayoutOrder = S.nextOrder(),
		Parent = parent,
	}, { corner(6) })
	row:SetAttribute("SearchText", string.lower(title .. " " .. (description or "")))
	-- Belong to the section above it, so collapsing hides it.
	local section = S.lastSection
	if section and section.parent == parent then
		table.insert(section.rows, row)
		row.Visible = not section.collapsed
		row:SetAttribute("Collapsed", section.collapsed)
		S.rowSections = S.rowSections or {}
		S.rowSections[row] = section
	end

	create("TextLabel", {
		Size = UDim2.new(0.62, 0, 0, 18),
		Position = UDim2.fromOffset(12, description and 7 or 10),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	if description then
		create("TextLabel", {
			Size = UDim2.new(0.62, 0, 0, 14),
			Position = UDim2.fromOffset(12, 26),
			BackgroundTransparency = 1,
			Text = description,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextColor3 = SUBTEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
	end

	return row
end

local toggleRefreshers = {}
local uiRefreshers = {}
local toggleTitles = {}

---Animated toggle.
local function createToggle(parent, title, description, key)
	local row = createRow(parent, title, description)

	local track = create("Frame", {
		Size = UDim2.fromOffset(38, 20),
		Position = UDim2.new(1, -50, 0.5, -10),
		BackgroundColor3 = ELEMENT,
		Parent = row,
	}, { corner(10) })
	local knob = create("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = SUBTEXT,
		Parent = track,
	}, { corner(8) })

	local hitbox = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = row })
	hitbox.MouseEnter:Connect(function()
		tweenService:Create(row, FAST, { BackgroundColor3 = ELEMENT }):Play()
	end)
	hitbox.MouseLeave:Connect(function()
		tweenService:Create(row, FAST, { BackgroundColor3 = PANEL }):Play()
	end)
	---Sync the switch visuals with the config value.
	local function refresh()
		local enabled = Egoist.config[key]
		tweenService:Create(track, TWEEN, { BackgroundColor3 = enabled and ACCENT or HOVER }):Play()
		tweenService:Create(knob, TWEEN, {
			Position = UDim2.fromOffset(enabled and 20 or 2, 2),
			BackgroundColor3 = enabled and Color3.new(1, 1, 1) or SUBTEXT,
		}):Play()
	end
	toggleRefreshers[key] = refresh
	uiRefreshers[key] = refresh
	toggleTitles[key] = title
	refresh()

	row.ClipsDescendants = true
	hitbox.MouseButton1Click:Connect(function()
		S.ripple(row)
		Egoist.config[key] = not Egoist.config[key]
		refresh()
		notify(title, Egoist.config[key] and "Enabled" or "Disabled")
	end)
end

---Draggable slider.
local function createSlider(parent, title, key, minimum, maximum, decimals, suffix)
	local row = createRow(parent, title, nil, 52)
	suffix = suffix or ""

	local valueLabel = create("TextLabel", {
		Size = UDim2.fromOffset(70, 18),
		Position = UDim2.new(1, -82, 0, 10),
		BackgroundTransparency = 1,
		Text = tostring(Egoist.config[key]) .. suffix,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = ACCENT,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local bar = create("Frame", {
		Size = UDim2.new(1, -24, 0, 6),
		Position = UDim2.new(0, 12, 1, -14),
		BackgroundColor3 = ELEMENT,
		Parent = row,
	}, { corner(3) })
	local alpha = (Egoist.config[key] - minimum) / (maximum - minimum)
	local fill = create("Frame", {
		Size = UDim2.fromScale(alpha, 1),
		BackgroundColor3 = ACCENT,
		Parent = bar,
	}, { corner(3), create("UIGradient", { Color = ColorSequence.new(ACCENT_DARK, ACCENT) }) })
	local thumb = create("Frame", {
		Size = UDim2.fromOffset(12, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(alpha, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = bar,
	}, { corner(6) })

	local sliding = false
	local scale = 10 ^ (decimals or 0)

	-- Redraw from the stored value (used when loading a config).
	uiRefreshers[key] = function()
		local value = Egoist.config[key]
		local refreshedAlpha = math.clamp((value - minimum) / (maximum - minimum), 0, 1)
		valueLabel.Text = tostring(value) .. suffix
		tweenService:Create(fill, FAST, { Size = UDim2.fromScale(refreshedAlpha, 1) }):Play()
		tweenService:Create(thumb, FAST, { Position = UDim2.new(refreshedAlpha, 0, 0.5, 0) }):Play()
	end

	---Apply mouse position to slider.
	local function update(x)
		local newAlpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local value = math.floor((minimum + (maximum - minimum) * newAlpha) * scale + 0.5) / scale
		Egoist.config[key] = value
		valueLabel.Text = tostring(value) .. suffix
		tweenService:Create(fill, FAST, { Size = UDim2.fromScale(newAlpha, 1) }):Play()
		tweenService:Create(thumb, FAST, { Position = UDim2.new(newAlpha, 0, 0.5, 0) }):Play()
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			update(input.Position.X)
		end
	end)
	table.insert(Egoist.connections, userInputService.InputChanged:Connect(function(input)
		if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
			update(input.Position.X)
		end
	end))
	table.insert(Egoist.connections, userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = false
		end
	end))
end

---Clickable action button.
local function createButton(parent, title, description, callback)
	local row = createRow(parent, title, description)
	local button = create("TextButton", {
		Size = UDim2.fromOffset(90, 26),
		Position = UDim2.new(1, -102, 0.5, -13),
		BackgroundColor3 = ACCENT,
		AutoButtonColor = false,
		Text = "Run",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = row,
	}, { corner(6) })
	button.ClipsDescendants = true
	button.MouseEnter:Connect(function()
		tweenService:Create(button, FAST, { BackgroundColor3 = ACCENT_DARK }):Play()
	end)
	button.MouseLeave:Connect(function()
		tweenService:Create(button, FAST, { BackgroundColor3 = ACCENT }):Play()
	end)
	button.MouseButton1Click:Connect(function()
		S.ripple(button)
		callback()
	end)
end

---Text input bound to a config key.
local function createInput(parent, title, description, key)
	local row = createRow(parent, title, description)

	local box = create("TextBox", {
		Size = UDim2.fromOffset(140, 26),
		Position = UDim2.new(1, -152, 0.5, -13),
		BackgroundColor3 = ELEMENT,
		Text = tostring(Egoist.config[key]),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = TEXT,
		ClearTextOnFocus = false,
		Parent = row,
	}, { corner(6), create("UIStroke", { Color = HOVER }) })

	box.FocusLost:Connect(function()
		Egoist.config[key] = box.Text
	end)
	uiRefreshers[key] = function()
		box.Text = tostring(Egoist.config[key])
	end
end

S.listeningKeybind = nil

---Keybind picker: click, then press any key or mouse button.
local function createKeybind(parent, title, description, key)
	local row = createRow(parent, title, description)

	local button = create("TextButton", {
		Size = UDim2.fromOffset(110, 26),
		Position = UDim2.new(1, -122, 0.5, -13),
		BackgroundColor3 = ELEMENT,
		AutoButtonColor = false,
		Text = Egoist.config[key],
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = ACCENT,
		Parent = row,
	}, { corner(6), create("UIStroke", { Color = ACCENT, Transparency = 0.6 }) })
	addHover(button, ELEMENT, HOVER)

	uiRefreshers[key] = function()
		button.Text = Egoist.config[key]
	end

	button.MouseButton1Click:Connect(function()
		button.Text = "Press a key..."
		button.TextColor3 = TEXT
		task.wait()
		S.listeningKeybind = function(name)
			Egoist.config[key] = name
			button.Text = name
			button.TextColor3 = ACCENT
			notify(title, "Bound to " .. name)
		end
	end)
end

---Name of the key or mouse button from an input.
function S.getInputName(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return input.KeyCode.Name
	end
	if input.UserInputType.Name:find("MouseButton") then
		return input.UserInputType.Name
	end
end

--[[ ================================================================
	TABS
================================================================== ]]
-- Tabs (scoped so their locals don't count toward the top-level limit).
-- Layout: Ball · Attack · Defense · Keeper · Skills · Player · Tools · Settings
do
	---------------------------------------------------------------- Ball
	local ballPage = createTab("Ball", "●")
	createSection(ballPage, "Visuals")
	createToggle(ballPage, "Ball ESP", "Glowing sphere around the ball", "ballEsp")
	createToggle(ballPage, "Ball Holder ESP", "Red outline on whoever has the ball", "holderEsp")
	createToggle(ballPage, "Clean Ball", "Hides every special-move effect on the ball (only you see the change)", "cleanBall")
	createToggle(ballPage, "Landing Prediction", "Landing circle and flight path", "prediction")
	createSection(ballPage, "Control")
	createToggle(ballPage, "Auto Grab Loose Ball", "Steps onto loose balls in range", "autoGrab")
	createSlider(ballPage, "Grab Range", "grabRange", 4, 40, 0, " studs")

	---------------------------------------------------------------- Attack
	local attackPage = createTab("Attack", "➶")
	createSection(attackPage, "Curve Shot")
	createToggle(attackPage, "Curve Shot Preview", "Shows where your curve shot will go while you have the ball", "curvePreview")
	createSlider(attackPage, "Line Extension", "curveExtend", 0, 30, 0, " studs")
	createToggle(attackPage, "Keeper Check", "Shows GK CAN REACH (yellow) when the keeper is near where your shot lands", "curveKeeperCheck")
	createSlider(attackPage, "Keeper Reach", "curveKeeperReach", 2, 20, 0, " studs")
	createToggle(attackPage, "Best Aim Guide", "Finds the facing that lands farthest from the posts", "curveBestAim")
	createToggle(attackPage, "Show Goal Box", "Outlines the goal mouth used for the green/red check", "showGoalBox")

	createSection(attackPage, "Shot Spots")
	createToggle(attackPage, "Shot Spots", "Step on a saved marker with the ball to replay that shot", "shotSpots")
	createToggle(attackPage, "Auto-Save Scoring Shots", "Saves a spot whenever your shot scores", "autoSaveSpots")
	createToggle(attackPage, "Show Other Characters' Spots", "Shows spots saved with other characters (greyed out)", "showOtherSpots")
	createButton(attackPage, "Save Last Shot", "Saves your most recent shot as a spot, goal or not", function()
		local candidate = S.spotState.candidate
		if candidate and candidate.spot then
			S.addSpot(candidate.spot, "manual")
		else
			notify("Shot spot", "Take a shot with the ball first")
		end
	end)
	createButton(attackPage, "Delete Nearest Spot", "Removes the spot closest to you", function()
		local character, rootPart = getCharacter()
		local goalFrame = character and getEnemyGoalFrame(character)
		if not rootPart or not goalFrame or #S.spotList == 0 then
			notify("Shot spot", "No spots to delete")
			return
		end
		local nearestIndex, nearestDistance = nil, math.huge
		for index, spot in S.spotList do
			local position = goalFrame:PointToWorldSpace(Vector3.new(spot.x, spot.y, spot.z))
			local distance = (position - rootPart.Position).Magnitude
			if distance < nearestDistance then
				nearestIndex, nearestDistance = index, distance
			end
		end
		table.remove(S.spotList, nearestIndex)
		S.saveSpots()
		notify("Shot spot", string.format("Deleted spot (%d studs away)", math.floor(nearestDistance)))
	end)
	createButton(attackPage, "Clear All Spots", "Deletes every saved spot", function()
		table.clear(S.spotList)
		S.saveSpots()
		notify("Shot spot", "All spots cleared")
	end)

	createSection(attackPage, "Air Dribble")
	createToggle(attackPage, "Air Dribble", "Kicks the ball upward without moving your camera", "airDribble")
	createKeybind(attackPage, "Air Dribble Key", "Click, then press any key", "airKey")
	createSlider(attackPage, "Kick Angle", "airAngle", 20, 85, 0, "°")
	createSlider(attackPage, "Kick Charge", "shootHold", 0, 1.5, 2, "s")

	createSection(attackPage, "Auto Dribble")
	createToggle(attackPage, "Auto Dribble", "Dodges tackles automatically while you have the ball", "autoDribble")
	createToggle(attackPage, "Radius Dodge", "Presses your dribble key when an opponent steps inside the ring", "proximityDodge")
	createSlider(attackPage, "Dodge Radius", "proximityRadius", 4, 60, 0, " studs")
	createToggle(attackPage, "Only Dodge Tackles", "Ignores people just walking into the ring so the dodge isn't wasted", "radiusTacklesOnly")
	createSlider(attackPage, "Tackle Speed", "radiusLungeSpeed", 20, 200, 0, " studs/s")
	createSlider(attackPage, "Lag Lead", "radiusLead", -100, 150, 0, " ms")
	createToggle(attackPage, "Show Dodge Radius", "Ring around you: green = armed, red = opponent inside, white = dodged", "showDodgeRadius")
	---Press the dribble key after a short countdown so you can watch whether the move happens.
	local function testDodge(method)
		local key = (Egoist.config.useGameDribbleKey and S.getGameDribbleKey()) or Egoist.config.dribbleKey
		notify("Dodge test", "Hold the ball - pressing " .. key .. " (" .. method .. ") in 2 seconds")
		task.delay(2, function()
			local ok = S.pressDodgeKey(key, method)
			notify("Dodge test", ok and ("Pressed " .. key .. " - did your character do the move?") or "This method isn't supported by your executor")
		end)
	end
	createButton(attackPage, "Test Dodge Key (Method 1)", "Presses your dribble key in 2s using the normal method", function()
		testDodge("virtual")
	end)
	createButton(attackPage, "Test Dodge Key (Method 2)", "Same, using real keyboard events (keypress)", function()
		testDodge("keypress")
	end)
	createToggle(attackPage, "Use Method 2 For Dodges", "Turn on if only Method 2 made your character move", "dodgeKeypress")
	createToggle(attackPage, "Instant Tackle Dodge", "Dodges the moment a tackle animation arrives (best with lag)", "dodgeInstant")
	createToggle(attackPage, "Early Dodge", "Dodges when an opponent charges straight at you up close, before they tackle", "earlyDodge")
	createToggle(attackPage, "Use Game's Dribble Key", "Reads your dribble keybind from the game's settings", "useGameDribbleKey")
	createKeybind(attackPage, "Dribble Key", "Used when the game's key can't be read", "dribbleKey")

	createSection(attackPage, "Fine Tuning", true)
	createSlider(attackPage, "Post Margin", "goalMargin", 0, 6, 1, " studs")
	createSlider(attackPage, "Trusted Distance Range", "curveTrustRange", 10, 200, 0, " studs")
	createSlider(attackPage, "Spot Trigger Radius", "spotRadius", 1, 8, 1, " studs")
	createSlider(attackPage, "Dodge Range", "dodgeRange", 5, 25, 0, " studs")
	createSlider(attackPage, "Lunge Speed", "lungeSpeed", 15, 80, 0, " studs/s")
	createSlider(attackPage, "Dodge Timing", "dodgeReaction", 0.05, 0.5, 2, "s")
	createSlider(attackPage, "Dodge Delay", "dodgeDelay", 0, 0.4, 2, "s")
	createSlider(attackPage, "Dodge Distance", "dodgeContact", 2, 15, 1, " studs")
	createSlider(attackPage, "Tackle Watch Range", "tackleWatchRange", 10, 40, 0, " studs")
	createSlider(attackPage, "Early Dodge Range", "earlyDodgeRange", 5, 35, 0, " studs")
	createSlider(attackPage, "Early Dodge Speed", "earlyDodgeSpeed", 5, 40, 0, " studs/s")
	createToggle(attackPage, "Dribble Debug Messages", "Pops up a message every time a tackle is seen and why", "dribbleDebug")

	---------------------------------------------------------------- Defense
	local defensePage = createTab("Defense", "⚔")
	createSection(defensePage, "Reading")
	createToggle(defensePage, "Enemy Shot Preview", "Shows an opponent's curve shot into your goal (recorded characters only)", "enemyPreview")
	createSection(defensePage, "Tackling")
	createToggle(defensePage, "Auto Tackle", "Tackles opponents carrying the ball", "autoTackle")
	createSlider(defensePage, "Tackle Range", "tackleRange", 4, 25, 0, " studs")
	createInput(defensePage, "Tackle Key", "The key you normally tackle with", "tackleKey")

	---------------------------------------------------------------- Keeper
	local keeperPage = createTab("Keeper", "⛨")
	createSection(keeperPage, "Keeper AI")
	createButton(keeperPage, "Use Recommended Settings", "Resets every keeper tuning value to the tested numbers", function()
		S.applyKeeperPreset(false)
	end)
	createToggle(keeperPage, "Auto GK", "Reads shots and dives for you while you're in goal", "autoGk")
	createKeybind(keeperPage, "Auto GK Toggle Key", "Turns Auto GK on or off in-game", "gkKey")
	createToggle(keeperPage, "Face Shooter", "Turns your camera to the shot so dives go the right way", "gkFace")
	createToggle(keeperPage, "Watch Ball Carrier", "Gently keeps an attacker on the ball in view", "gkWatchCarrier")
	createToggle(keeperPage, "Auto Movement", "Walks you back to goal and toward shots (WASD overrides)", "gkMovement")
	createToggle(keeperPage, "Auto Positioning", "Shades along the goal line toward the ball (needs Auto Movement)", "gkPositioning")
	createToggle(keeperPage, "Rush Dive", "Dives at the attacker's feet when they carry the ball too close", "gkRushDive")
	createSlider(keeperPage, "Rush Range", "gkRushRange", 4, 60, 0, " studs")
	createToggle(keeperPage, "Show Intercept Marker", "Red circle where the AI plans to stop the shot", "gkMarker")
	createToggle(keeperPage, "Sprint To Shots", "Holds sprint while moving toward a shot (needs Auto Movement)", "gkSprint")

	createSection(keeperPage, "Dive Timing", true)
	createSlider(keeperPage, "Reaction Window", "gkReaction", 0.04, 0.5, 2, "s")
	createSlider(keeperPage, "Min Shot Speed", "gkMinShotSpeed", 20, 200, 0, " studs/s")
	createSlider(keeperPage, "Shot Tracking Time", "gkTrackTime", 0.3, 3, 1, "s")
	createSlider(keeperPage, "Forward Dive Width", "gkForwardWidth", 1, 25, 1, " studs")
	createSlider(keeperPage, "Wide Shot Lead", "gkWideLead", 0, 0.05, 3, "s/stud")
	createSlider(keeperPage, "High Shot Lead", "gkHighLead", 0, 0.05, 3, "s/stud")
	createSlider(keeperPage, "Jump Height (Forward)", "gkJumpHeight", 1.5, 12, 1, " studs")
	createSlider(keeperPage, "Jump Height (Side)", "gkSideJumpHeight", 1.5, 12, 1, " studs")
	createSlider(keeperPage, "Max Save Height", "gkMaxHeight", 5, 25, 0, " studs")
	createSlider(keeperPage, "Max Dive Distance", "gkDiveRange", 6, 30, 0, " studs")

	createSection(keeperPage, "Movement & Camera", true)
	createSlider(keeperPage, "Camera Turn Speed", "gkTurnSpeed", 4, 30, 0)
	createSlider(keeperPage, "Watch Range", "gkWatchRange", 20, 120, 0, " studs")
	createSlider(keeperPage, "Distance Off Line", "gkLine", 0, 10, 0, " studs")
	createSlider(keeperPage, "Max Distance From Goal", "gkMaxRoam", 2, 20, 0, " studs")

	createSection(keeperPage, "Humanize", true)
	createSlider(keeperPage, "Reaction Delay", "gkDelay", 0, 0.4, 2, "s")
	createSlider(keeperPage, "Random Delay", "gkJitter", 0, 0.25, 2, "s")

	---------------------------------------------------------------- Skills
	local skillsPage = createTab("Skills", "✦")
	createSection(skillsPage, "Abilities")
	createToggle(skillsPage, "Auto Skill", "Cycles your skills during matches", "autoSkill")
	createInput(skillsPage, "Skill Keys", "Comma separated, e.g. One,Two,E", "skillKeys")
	createSlider(skillsPage, "Delay Between Skills", "skillDelay", 0.1, 3, 1, "s")

	---------------------------------------------------------------- Player
	local playerPage = createTab("Player", "◆")
	createSection(playerPage, "Movement")
	createToggle(playerPage, "Speed", "Overrides your walk speed", "speed")
	createSlider(playerPage, "Walk Speed", "speedValue", 16, 60, 0)

	---------------------------------------------------------------- Tools
	local toolsPage = createTab("Tools", "⚒")
	createSection(toolsPage, "Curve Recording")
	createToggle(toolsPage, "Learn From Every Shot", "Records every shot you take and whether it scored, got saved or missed", "curveLearn")
	createToggle(toolsPage, "Record Curve Shots", "Records each curve shot you take for your current character", "curveRecord")
	createKeybind(toolsPage, "Curve Shot Key", "The key your curve shot ability uses", "curveKey")
	createButton(toolsPage, "Recording Count", "Shows how many shots are saved per side", function()
		local styleData = curveData[getStyle()] or {}
		local function describe(list)
			if not list or #list == 0 then
				return "none"
			end
			local distances = {}
			for _, recording in list do
				table.insert(distances, recording.d and tostring(math.floor(recording.d)) or "?")
			end
			return #list .. " (" .. table.concat(distances, ", ") .. ")"
		end
		notify(getStyle() .. " curves", "L: " .. describe(styleData.Left) .. "  R: " .. describe(styleData.Right))
	end)
	createButton(toolsPage, "Undo Last Shot", "Removes only the most recent recording", function()
		local last = curveState.lastSaved
		local list = last and curveData[last.style] and curveData[last.style][last.side]
		if not list or #list == 0 then
			notify("Undo", "Nothing to undo this session")
			return
		end
		table.remove(list)
		S.saveCurves()
		curveState.lastSaved = nil
		notify("Undo", string.format("Removed last %s side shot · %d left", last.side, #list))
	end)

	---Clear one side's recordings for the current character.
	local function clearSide(side)
		local styleData = curveData[getStyle()]
		if styleData then
			styleData[side] = nil
		end
		S.saveCurves()
		notify("Curves cleared", getStyle() .. " · " .. side .. " side")
	end

	createButton(toolsPage, "Clear Left Side", "Deletes only left side recordings", function()
		clearSide("Left")
	end)
	createButton(toolsPage, "Clear Right Side", "Deletes only right side recordings", function()
		clearSide("Right")
	end)
	createButton(toolsPage, "Clear All Recordings", "Deletes both sides for your current character", function()
		curveData[getStyle()] = nil
		S.saveCurves()
		notify("Curves cleared", getStyle() .. " · both sides")
	end)

	createSection(toolsPage, "Character")
	createInput(toolsPage, "Character Override", "Type a character name to force it (leave blank = auto)", "styleOverride")
	createButton(toolsPage, "Detect Character", "Shows which character the script thinks you're playing", function()
		local data = localPlayer:FindFirstChild("Data")
		local parts = { "Using: " .. getStyle() }
		for _, name in { "Style", "StyleSlot", "Awakening", "Flow" } do
			local value = data and data:FindFirstChild(name)
			if value then
				table.insert(parts, name .. "=" .. tostring(value.Value))
			end
		end
		notify("Character", table.concat(parts, "  ·  "))
	end)
	createButton(toolsPage, "Saved Characters", "Lists each character's curve recordings and spots", function()
		local summary = {}
		local styles = {}
		for style in curveData do
			styles[style] = true
		end
		for _, spot in S.spotList do
			styles[spot.style] = true
		end
		for style in styles do
			local data = curveData[style] or {}
			local curves = (data.Left and #data.Left or 0) + (data.Right and #data.Right or 0)
			local spots = 0
			for _, spot in S.spotList do
				if spot.style == style then
					spots += 1
				end
			end
			table.insert(summary, string.format("%s%s: %d curves, %d spots", style, style == getStyle() and " (you)" or "", curves, spots))
		end
		notify("Saved characters", #summary > 0 and table.concat(summary, "  ·  ") or "Nothing saved yet")
	end)

	createSection(toolsPage, "Game Controls")
	createInput(toolsPage, "Shoot Key", "The key you normally kick with", "shootKey")
	createInput(toolsPage, "Dive Key", "Pressed with a direction key to dive", "diveKey")
	createInput(toolsPage, "Sprint Key", "The key you hold to sprint", "sprintKey")

	createSection(toolsPage, "Logs & Debug", true)
	createToggle(toolsPage, "Record Keeper Shots", "Logs every shot the keeper AI reads (EgoistGKLog.txt)", "gkRecord")
	createButton(toolsPage, "Copy Keeper Log", "Copies the keeper shot log", function()
		local count = S.exportShotLog()
		notify("Shot Log", count .. " lines copied")
	end)
	createButton(toolsPage, "Clear Keeper Log", "Starts a fresh keeper log", function()
		table.clear(S.shotLog)
		notify("Shot Log", "Cleared")
	end)
	createButton(toolsPage, "Copy Cooldown Log", "Copies what the game's Cooldown remote sent", function()
		local events = S.abilityCooldown.events
		pcall(setclipboard, #events > 0 and table.concat(events, "\n") or "no cooldown events yet")
		notify("Cooldown log", #events .. " events copied")
	end)
	createButton(toolsPage, "Copy Animation Log", "Copies nearby opponents' animations, to find tackle IDs", function()
		local log = S.dribble.animationLog
		pcall(setclipboard, #log > 0 and table.concat(log, "\n") or "no animations logged yet")
		notify("Animation log", #log .. " entries copied")
	end)
end

--[[ ================================================================
	CONFIG, SETTINGS TAB & SEARCH
================================================================== ]]
-- Config saving.
S.CONFIG_FILE = "EgoistConfig.json"

---Redraw every control from the current config.
function S.refreshAllControls()
	for _, refresh in uiRefreshers do
		pcall(refresh)
	end
end

---Save the current settings to disk.
function S.saveConfig()
	local ok = pcall(writefile, S.CONFIG_FILE, httpService:JSONEncode(Egoist.config))
	notify("Config", ok and "Saved" or "Couldn't save (no file access)")
end

-- Keeper settings that are your own choices, not tuning; the preset never touches these.
S.KEEPER_PERSONAL = { gkKey = true, gkRecord = true, gkMovement = true, gkPositioning = true, autoGk = true }

---Put every keeper tuning value back to the recommended (tested) numbers.
function S.applyKeeperPreset(silent)
	for key, value in DEFAULT_CONFIG do
		if (key:sub(1, 2) == "gk" or key == "diveKey") and not S.KEEPER_PERSONAL[key] then
			Egoist.config[key] = value
		end
	end
	Egoist.config.gkPreset = DEFAULT_CONFIG.gkPreset
	S.refreshAllControls()
	pcall(writefile, S.CONFIG_FILE, httpService:JSONEncode(Egoist.config))
	if not silent then
		notify("Keeper", "Recommended settings applied")
	end
end

---Load settings from disk.
local function loadConfig(silent)
	local ok, content = pcall(readfile, S.CONFIG_FILE)
	if not ok or not content then
		if not silent then
			notify("Config", "No saved config yet")
		end
		return false
	end
	local decodedOk, decoded = pcall(httpService.JSONDecode, httpService, content)
	if not decodedOk or type(decoded) ~= "table" then
		notify("Config", "Saved config is damaged")
		return false
	end
	for key, value in decoded do
		-- Only load known settings of the same type.
		if Egoist.config[key] ~= nil and type(Egoist.config[key]) == type(value) then
			Egoist.config[key] = value
		end
	end
	S.refreshAllControls()
	if not silent then
		notify("Config", "Loaded")
	end
	return true
end

do
	-- Settings tab.
	local settingsPage = createTab("Settings", "⚙")
	createSection(settingsPage, "Config")
	createButton(settingsPage, "Save Config", "Saves every setting to EgoistConfig.json", S.saveConfig)
	createButton(settingsPage, "Load Config", "Restores your saved settings", function()
		loadConfig(false)
	end)
	createButton(settingsPage, "Reset to Defaults", "Puts every setting back to its default", function()
		for key, value in DEFAULT_CONFIG do
			Egoist.config[key] = value
		end
		S.refreshAllControls()
		notify("Config", "Reset to defaults")
	end)
	createToggle(settingsPage, "Auto-Load Config", "Loads your saved config every time you execute", "autoLoadConfig")
	createSection(settingsPage, "Interface")
	createToggle(settingsPage, "Active Features List", "Shows what's turned on in the corner of your screen", "featureList")
	createSection(settingsPage, "Theme")
	do
		local row = createRow(settingsPage, "Accent Color", "Recolours the whole interface", 74)
		local swatches = create("Frame", {
			Size = UDim2.new(1, -24, 0, 26),
			Position = UDim2.new(0, 12, 1, -34),
			BackgroundTransparency = 1,
			Parent = row,
		}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
		for _, name in { "Ocean", "Violet", "Crimson", "Emerald", "Gold" } do
			local swatch = create("TextButton", {
				Size = UDim2.fromOffset(72, 26),
				BackgroundColor3 = S.THEMES[name][1],
				AutoButtonColor = false,
				Text = name,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = Color3.fromRGB(15, 15, 20),
				Parent = swatches,
			}, { corner(6) })
			swatch.MouseButton1Click:Connect(function()
				Egoist.config.theme = name
				applyTheme(name)
				notify("Theme", name)
			end)
		end
	end

	-- Active features list (top-right).
	local featureLabel = create("TextLabel", {
		Size = UDim2.fromOffset(220, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -232, 0, 52),
		BackgroundTransparency = 1,
		RichText = true,
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = TEXT,
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = screenGui,
	})

	task.spawn(function()
		while shared.Egoist == Egoist do
			if Egoist.config.featureList then
				local enabled = {}
				for key, title in toggleTitles do
					if Egoist.config[key] and key ~= "featureList" and key ~= "autoLoadConfig" then
						table.insert(enabled, title)
					end
				end
				table.sort(enabled, function(a, b)
					return #a > #b
				end)
				for index, title in enabled do
					enabled[index] = '<font color="#46A0FF">▍</font>' .. title
				end
				featureLabel.Text = table.concat(enabled, "\n")
			else
				featureLabel.Text = ""
			end
			task.wait(0.25)
		end
	end)

	-- Search filtering on the open tab.
	applySearch = function()
		local query = string.lower(searchBox.Text)
		for name, page in pages do
			for _, child in page:GetChildren() do
				if child:GetAttribute("IsSection") then
					child.Visible = query == ""
				elseif child:GetAttribute("SearchText") then
					local section = S.rowSections and S.rowSections[child]
					if query == "" then
						-- Back to normal: respect collapsed sections.
						child.Visible = not (section and section.collapsed)
					else
						-- Searching looks inside collapsed sections too.
						child.Visible = string.find(child:GetAttribute("SearchText"), query, 1, true) ~= nil
					end
				end
			end
		end
	end
	searchBox:GetPropertyChangedSignal("Text"):Connect(applySearch)
end

-- Title shimmer sweep every few seconds.
task.spawn(function()
	while shared.Egoist == Egoist do
		local shimmer = header:FindFirstChild("Shimmer", true)
		if shimmer then
			shimmer.Offset = Vector2.new(-1, 0)
			tweenService:Create(shimmer, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) }):Play()
		end
		task.wait(4)
	end
end)

-- Live status and stats.
Egoist.connections.status = runService.Heartbeat:Connect(function(deltaTime)
	local ball, holder = findBall()
	if not ball then
		S.statusLabel.Text = "No ball in play"
		S.statusDot.BackgroundColor3 = SUBTEXT
	elseif holder == localPlayer.Character then
		S.statusLabel.Text = "You have the ball"
		S.statusDot.BackgroundColor3 = Color3.fromRGB(90, 220, 130)
	elseif holder then
		S.statusLabel.Text = "Ball: " .. holder.Name
		S.statusDot.BackgroundColor3 = DANGER
	else
		S.statusLabel.Text = "Ball: loose"
		S.statusDot.BackgroundColor3 = ACCENT
	end

	local character = localPlayer.Character
	local team = character and character:GetAttribute("Team")
	local ping = math.floor(statsService.Network.ServerStatsItem["Data Ping"]:GetValue())
	local keeperText = Egoist.config.autoGk and ("GK: " .. gkState.status .. "  ·  ") or ""
	S.statsLabel.Text = string.format("%sTeam %s  ·  %d FPS  ·  %d ms", keeperText, tostring(team or "-"), math.floor(1 / deltaTime), ping)
end)

--[[ ================================================================
	WINDOW, KEYBINDS & UNLOAD
================================================================== ]]
-- Open/close and minimize animations.
local visible = true
local minimized = false
local openPosition = window.Position
local fullSize = window.Size

---Show or hide the window.
local function setVisible(state)
	visible = state
	if state then
		window.Visible = true
		window.GroupTransparency = 1
		window.Position = openPosition + UDim2.fromOffset(0, 20)
		windowScale.Scale = 0.9
		tweenService:Create(window, TWEEN, { GroupTransparency = 0, Position = openPosition }):Play()
		tweenService:Create(windowScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		return
	end
	openPosition = window.Position
	tweenService:Create(windowScale, TWEEN, { Scale = 0.94 }):Play()
	local tween = tweenService:Create(window, TWEEN, { GroupTransparency = 1, Position = openPosition + UDim2.fromOffset(0, 20) })
	tween:Play()
	tween.Completed:Connect(function()
		if not visible then
			window.Visible = false
		end
	end)
end

minimizeButton.MouseButton1Click:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	tweenService:Create(window, TWEEN, { Size = minimized and UDim2.fromOffset(fullSize.X.Offset, 48) or fullSize }):Play()
end)

-- Keyboard: GUI toggle, keybind capture and air dribble.
Egoist.connections.input = userInputService.InputBegan:Connect(function(input, processed)
	local name = S.getInputName(input)
	if not name then
		return
	end

	if S.listeningKeybind then
		local callback = S.listeningKeybind
		S.listeningKeybind = nil
		callback(name)
		return
	end

	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Delete then
		setVisible(not visible)
		return
	end

	if name == Egoist.config.gkKey then
		Egoist.config.autoGk = not Egoist.config.autoGk
		if toggleRefreshers.autoGk then
			toggleRefreshers.autoGk()
		end
		notify("Auto GK", Egoist.config.autoGk and "Enabled" or "Disabled")
		return
	end

	if Egoist.config.airDribble and name == Egoist.config.airKey then
		airDribble()
	end
end)

---Detach the script.
function Egoist.detach()
	shared.Egoist = nil
	spoofing = false
	pcall(runService.UnbindFromRenderStep, runService, "EgoistPitchLock")
	releaseMovement()
	for _, connection in Egoist.connections do
		connection:Disconnect()
	end
	ballAdornment:Destroy()
	holderHighlight:Destroy()
	S.restoreEffects()
	visualsFolder:Destroy()
	S.curveInfo:Destroy()
	S.dodgeRingLabel:Destroy()
	for _, connection in S.dribble.watched do
		connection:Disconnect()
	end
	for _, marker in S.spotMarkers do
		marker.ring:Destroy()
	end
	screenGui:Destroy()
end

closeButton.MouseButton1Click:Connect(Egoist.detach)

if Egoist.config.autoLoadConfig then
	local savedPreset = Egoist.config.gkPreset
	local savedDribblePreset = Egoist.config.dribblePreset
	Egoist.config.gkPreset = 0
	Egoist.config.dribblePreset = 0
	local loaded = loadConfig(true)
	-- Same for auto dribble tuning (keeps your own toggles and keys).
	if not loaded then
		Egoist.config.dribblePreset = savedDribblePreset
	elseif (Egoist.config.dribblePreset or 0) < savedDribblePreset then
		for _, key in { "curveTrustRange", "proximityDodge", "proximityRadius", "radiusLead", "radiusLungeSpeed", "dodgeDelay", "earlyDodge", "dodgeInstant", "dodgeContact", "dodgeReaction", "dodgeRange", "lungeSpeed", "tackleWatchRange", "earlyDodgeRange", "earlyDodgeSpeed", "useGameDribbleKey" } do
			Egoist.config[key] = DEFAULT_CONFIG[key]
		end
		Egoist.config.dribblePreset = savedDribblePreset
		S.refreshAllControls()
		pcall(writefile, S.CONFIG_FILE, httpService:JSONEncode(Egoist.config))
		notify("Auto dribble", "Updated to the latest recommended dribble settings")
	end
	-- Older saved keeper tuning gets replaced by the newest recommended values automatically.
	if not loaded then
		Egoist.config.gkPreset = savedPreset
	elseif (Egoist.config.gkPreset or 0) < savedPreset then
		S.applyKeeperPreset(true)
		notify("Keeper", "Updated to the latest recommended keeper settings")
	end
end
applyTheme(Egoist.config.theme)
selectTab("Attack")
setVisible(true)
notify("Egoist " .. VERSION, "Loaded · press Delete to toggle")
