local Workspace = game:GetService("Workspace")

local ANGLER_WATCH_NAMES = {
    angler = true,
    froger = true,
    pinkie = true,
    blitz = true,
    chainsmoker = true,
}

return function(deps)
    local ITEM_COLORS = deps.ITEM_COLORS
    local findPrompt = deps.findPrompt
    local getPaperPassword = deps.getPaperPassword
    local onTrack = deps.onTrack
    local onForget = deps.onForget

    local trackedTargets = {}
    local promptStateConnections = {}
    local workspaceAddedConnection
    local workspaceRemovingConnection

    local Tracker = {}

    local function isAnglerEntity(instance)
        if not instance or instance:IsA("Attachment") or instance:IsA("Beam") then
            return false
        end

        local lowerName = string.lower(instance.Name or "")
        for fragment in pairs(ANGLER_WATCH_NAMES) do
            if string.find(lowerName, fragment, 1, true) then
                return true
            end
        end

        return false
    end

    local function isDoorOpened(doorInstance)
        if not doorInstance then
            return false
        end

        local openAttribute = doorInstance:GetAttribute("Opened")
            or doorInstance:GetAttribute("Open")
            or doorInstance:GetAttribute("IsOpen")
        if typeof(openAttribute) == "boolean" then
            return openAttribute
        end

        local openFlag = doorInstance:FindFirstChild("Opened", true)
            or doorInstance:FindFirstChild("Open", true)
            or doorInstance:FindFirstChild("IsOpen", true)
        if openFlag and openFlag:IsA("BoolValue") then
            return openFlag.Value
        end

        local prompt = findPrompt(doorInstance)
        if prompt then
            return not prompt.Enabled
        end

        return false
    end

    local function getOriginalPromptState(prompt, existingTarget)
        if existingTarget and existingTarget.originalPromptState then
            return existingTarget.originalPromptState
        end

        return {
            maxActivationDistance = prompt.MaxActivationDistance,
            requiresLineOfSight = prompt.RequiresLineOfSight,
            holdDuration = prompt.HoldDuration,
        }
    end

    local function buildTargetData(target, prompt, color, label, shouldAutoPickup, existingTarget, kind)
        return {
            id = target,
            instance = target,
            prompt = prompt,
            color = color,
            label = label,
            shouldAutoPickup = shouldAutoPickup,
            allowRemoteUse = true,
            kind = kind or "item",
            originalPromptState = getOriginalPromptState(prompt, existingTarget),
        }
    end

    local function classify(instance)
        if not instance or not instance.Parent or instance:IsA("Attachment") or instance:IsA("Beam") then
            return nil
        end

        local existingTarget = trackedTargets[instance]
        local name = instance.Name or ""

        if isAnglerEntity(instance) then
            return {
                id = instance,
                instance = instance,
                color = ITEM_COLORS.angler,
                label = "ANGLER: " .. name,
                shouldAutoPickup = false,
                allowRemoteUse = false,
                kind = "angler",
            }
        end

        if name == "Locker" then
            local prompt = findPrompt(instance)
            if prompt and prompt.Enabled then
                return buildTargetData(instance, prompt, ITEM_COLORS.locker, "Locker", false, existingTarget, "locker")
            end
            return nil
        end

        if name == "PasswordPaper" then
            local prompt = findPrompt(instance)
            if prompt and prompt.Enabled then
                local password = getPaperPassword(instance)
                local target = buildTargetData(
                    instance,
                    prompt,
                    ITEM_COLORS.paper,
                    "Pass: " .. password,
                    false,
                    existingTarget,
                    "password"
                )
                target.password = password
                return target
            end
            return nil
        end

        if string.find(name, "KeyCard", 1, true) then
            local prompt = findPrompt(instance)
            if prompt and prompt.Enabled then
                return buildTargetData(instance, prompt, ITEM_COLORS.default, name, false, existingTarget, "keycard")
            end

            local proxy = instance:FindFirstChild("ProxyPart", true)
            prompt = findPrompt(proxy)
            if proxy and prompt and prompt.Enabled then
                return buildTargetData(instance, prompt, ITEM_COLORS.default, name, false, existingTarget, "keycard")
            end
            return nil
        end

        if name == "Generator" then
            local prompt = findPrompt(instance)
            if prompt and prompt.Enabled then
                return buildTargetData(instance, prompt, ITEM_COLORS.generator, "Generator", false, existingTarget, "generator")
            end
            return nil
        end

        if name == "ProxyPart" then
            local prompt = findPrompt(instance)
            if not prompt or not prompt.Enabled then
                return nil
            end

            local target = (instance.Parent and instance.Parent:IsA("Model")) and instance.Parent or instance
            if target ~= instance and string.find(target.Name or "", "KeyCard", 1, true) then
                return nil
            end

            local targetName = target.Name or ""
            local isCurrency = string.find(targetName, "Currency", 1, true) ~= nil
            local isKeyCard = string.find(targetName, "KeyCard", 1, true) ~= nil
            local isPasswordPaper = targetName == "PasswordPaper"
            local targetKind = "item"
            if isCurrency then
                targetKind = "currency"
            elseif isKeyCard then
                targetKind = "keycard"
            elseif isPasswordPaper then
                targetKind = "password"
            end

            local data = buildTargetData(
                target,
                prompt,
                ITEM_COLORS.default,
                (target.Name or "Item"),
                isCurrency or isKeyCard or isPasswordPaper,
                trackedTargets[target],
                targetKind
            )

            if isPasswordPaper then
                data.password = getPaperPassword(target)
                data.label = "Pass: " .. data.password
            end

            return data
        end

        if string.find(name, "Currency", 1, true) then
            local prompt = findPrompt(instance)
            if prompt and prompt.Enabled then
                return buildTargetData(instance, prompt, ITEM_COLORS.default, name, true, existingTarget, "currency")
            end
            return nil
        end

        if instance.Parent and instance.Parent.Name == "Entrances" and (instance:IsA("Model") or instance:IsA("BasePart")) then
            return {
                id = instance,
                instance = instance,
                color = ITEM_COLORS.door,
                label = "Door",
                shouldAutoPickup = false,
                allowRemoteUse = false,
                kind = "door",
                isDoorOpened = isDoorOpened(instance),
            }
        end

        return nil
    end

    function Tracker.forgetTarget(target)
        local tracked = trackedTargets[target]
        if tracked then
            onForget(target, tracked)
        end

        trackedTargets[target] = nil

        local entry = promptStateConnections[target]
        local connection = entry and entry.connection or entry
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
        promptStateConnections[target] = nil
    end

    local function attachPromptWatcher(targetData)
        if not targetData.prompt then
            return
        end

        local existingEntry = promptStateConnections[targetData.id]
        if existingEntry and existingEntry.prompt == targetData.prompt then
            return
        end

        if existingEntry and existingEntry.connection and existingEntry.connection.Disconnect then
            existingEntry.connection:Disconnect()
        end

        promptStateConnections[targetData.id] = {
            prompt = targetData.prompt,
            connection = targetData.prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
                local refreshed = classify(targetData.instance)
                if not refreshed then
                    Tracker.forgetTarget(targetData.id)
                    return
                end

                trackedTargets[targetData.id] = refreshed
                onTrack(refreshed)
                attachPromptWatcher(refreshed)
            end),
        }
    end

    local function refreshTarget(instance)
        local targetData = classify(instance)
        if not targetData then
            return
        end

        trackedTargets[targetData.id] = targetData
        onTrack(targetData)
        attachPromptWatcher(targetData)
    end

    function Tracker.scanWorkspace()
        for _, descendant in ipairs(Workspace:GetDescendants()) do
            refreshTarget(descendant)
        end
    end

    function Tracker.syncTargets()
        for target, targetData in pairs(trackedTargets) do
            if not target or not target.Parent then
                Tracker.forgetTarget(target)
            else
                local refreshed = classify(targetData.instance)
                if refreshed then
                    trackedTargets[target] = refreshed
                    onTrack(refreshed)
                    attachPromptWatcher(refreshed)
                else
                    Tracker.forgetTarget(target)
                end
            end
        end
    end

    function Tracker.start()
        Tracker.scanWorkspace()
        Tracker.syncTargets()

        if not workspaceAddedConnection then
            workspaceAddedConnection = Workspace.DescendantAdded:Connect(function(descendant)
                task.defer(refreshTarget, descendant)
            end)
        end

        if not workspaceRemovingConnection then
            workspaceRemovingConnection = Workspace.DescendantRemoving:Connect(function(descendant)
                if trackedTargets[descendant] then
                    Tracker.forgetTarget(descendant)
                elseif descendant.Name == "ProxyPart" and descendant.Parent and trackedTargets[descendant.Parent] then
                    Tracker.forgetTarget(descendant.Parent)
                end
            end)
        end
    end

    function Tracker.stop()
        if workspaceAddedConnection then
            workspaceAddedConnection:Disconnect()
            workspaceAddedConnection = nil
        end

        if workspaceRemovingConnection then
            workspaceRemovingConnection:Disconnect()
            workspaceRemovingConnection = nil
        end

        for target in pairs(promptStateConnections) do
            Tracker.forgetTarget(target)
        end

        trackedTargets = {}
    end

    function Tracker.getTrackedTargets()
        return trackedTargets
    end

    return Tracker
end
