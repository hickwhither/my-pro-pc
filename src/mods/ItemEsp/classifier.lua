return function(deps)
    local ITEM_COLORS = deps.ITEM_COLORS
    local findPrompt = deps.findPrompt
    local getPaperPassword = deps.getPaperPassword

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

    local function buildTargetData(target, prompt, color, label, shouldAutoPickup, existingTarget)
        return {
            id = target,
            instance = target,
            prompt = prompt,
            color = color,
            label = label,
            shouldAutoPickup = shouldAutoPickup,
            allowRemoteUse = true,
            originalPromptState = getOriginalPromptState(prompt, existingTarget),
        }
    end

    return function(instance, trackedTargets)
        if not instance or not instance.Parent or instance:IsA("Attachment") or instance:IsA("Beam") then
            return nil
        end

        local existingTarget = trackedTargets[instance]
        local name = instance.Name or ""
        if name == "Locker" then
            local prompt = findPrompt(instance)
            if prompt and prompt.Enabled then
                return buildTargetData(instance, prompt, ITEM_COLORS.locker, "Locker", false, existingTarget)
            end
            return nil
        end

        if name == "PasswordPaper" then
            local prompt = findPrompt(instance)
            if prompt and prompt.Enabled then
                return buildTargetData(
                    instance,
                    prompt,
                    ITEM_COLORS.paper,
                    "Pass: " .. getPaperPassword(instance),
                    false,
                    existingTarget
                )
            end
            return nil
        end

        if string.find(name, "KeyCard", 1, true) then
            local prompt = findPrompt(instance)
            if prompt and prompt.Enabled then
                return buildTargetData(instance, prompt, ITEM_COLORS.default, name, false, existingTarget)
            end

            local proxy = instance:FindFirstChild("ProxyPart", true)
            prompt = findPrompt(proxy)
            if proxy and prompt and prompt.Enabled then
                return buildTargetData(instance, prompt, ITEM_COLORS.default, name, false, existingTarget)
            end
            return nil
        end

        if name == "Generator" then
            local prompt = findPrompt(instance)
            if prompt and prompt.Enabled then
                return buildTargetData(instance, prompt, ITEM_COLORS.generator, "Generator", false, existingTarget)
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

            local isCurrency = string.find(target.Name or "", "Currency", 1, true) ~= nil
            local isKeyCard = string.find(name, "KeyCard", 1, true)
            local isPasswordPaper = target.name == "PasswordPaper"
            return buildTargetData(
                target,
                prompt,
                ITEM_COLORS.default,
                (target.Name or "Item"),
                isCurrency or isKeyCard or isPasswordPaper,
                trackedTargets[target]
            )
        end

        if string.find(name, "Currency", 1, true) then
            local prompt = findPrompt(instance)
            if prompt and prompt.Enabled then
                return buildTargetData(instance, prompt, ITEM_COLORS.default, name, true, existingTarget)
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
            }
        end

        return nil
    end
end
