local RunService = game:GetService("RunService")

local AUTO_PICKUP_INTERVAL = 0.2

return function(deps)
    local isAutoPickupEnabled = deps.isAutoPickupEnabled
    local getTrackedTargets = deps.getTrackedTargets
    local forgetTarget = deps.forgetTarget
    local isWithinPromptDistance = deps.isWithinPromptDistance

    local AutoPickup = {}
    local connection

    local function triggerPrompt(prompt)
        if not prompt or not prompt.Parent or not prompt.Enabled then
            return false
        end

        if typeof(fireproximityprompt) == "function" then
            return pcall(function()
                fireproximityprompt(prompt, 0, true)
            end)
        end

        return false
    end

    function AutoPickup.start()
        if connection then
            return
        end

        local elapsed = 0
        connection = RunService.Heartbeat:Connect(function(deltaTime)
            elapsed = elapsed + deltaTime
            if elapsed < AUTO_PICKUP_INTERVAL then
                return
            end
            elapsed = 0

            if not isAutoPickupEnabled() then
                return
            end

            for target, targetData in pairs(getTrackedTargets()) do
                if not target or not target.Parent then
                    forgetTarget(target)
                elseif targetData.shouldAutoPickup
                    and targetData.prompt
                    and isWithinPromptDistance(targetData.instance, targetData.prompt) then
                    triggerPrompt(targetData.prompt)
                end
            end
        end)
    end

    function AutoPickup.stop()
        if connection then
            connection:Disconnect()
            connection = nil
        end
    end

    return AutoPickup
end
