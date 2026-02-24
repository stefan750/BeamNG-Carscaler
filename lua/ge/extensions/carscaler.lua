-- Scales an entire vehicle before it is spawned
-- Author: stefan750

local M = {}

local max = math.max
local min = math.min
local random = math.random

local im = ui_imgui

local BEAM_ANISOTROPIC = 1
local BEAM_BOUNDED = 2
local BEAM_PRESSURED = 3
local BEAM_LBEAM = 4
local BEAM_BROKEN = 5
local BEAM_SUPPORT = 7

local nextObjID = nil
local nextVehicleConfig = nil

local windowOpen = im.BoolPtr(false)
local uiData = {
    scale = im.FloatPtr(1),
    weightMultiplier = im.FloatPtr(1),
    stiffnessMultiplier = im.FloatPtr(1),
    strengthMultiplier = im.FloatPtr(1),
    powerMultiplier = im.FloatPtr(1),
    gearRatioMultiplier = im.FloatPtr(1),
    aeroMultiplier = im.FloatPtr(1),
    disablePressureGroupsOverride = im.BoolPtr(false),
    disablePressureGroups = im.BoolPtr(false),
    disableSelfCollisionOverride = im.BoolPtr(false),
    disableSelfCollision = im.BoolPtr(false)
}
local uiRandomizer = {
    scaleEnabled = im.BoolPtr(true),
    scaleMin = im.FloatPtr(0.5),
    scaleMax = im.FloatPtr(2),
    multipliersEnabled = im.BoolPtr(false),
    weightMultiplierMin = im.FloatPtr(0.5),
    weightMultiplierMax = im.FloatPtr(2),
    stiffnessMultiplierMin = im.FloatPtr(1),
    stiffnessMultiplierMax = im.FloatPtr(1),
    strengthMultiplierMin = im.FloatPtr(1),
    strengthMultiplierMax = im.FloatPtr(1),
    powerMultiplierMin = im.FloatPtr(0.5),
    powerMultiplierMax = im.FloatPtr(2),
    gearRatioMultiplierMin = im.FloatPtr(0.5),
    gearRatioMultiplierMax = im.FloatPtr(2),
    aeroMultiplierMin = im.FloatPtr(0.5),
    aeroMultiplierMax = im.FloatPtr(2),
    autoApply = im.BoolPtr(true)
}

local function scaleJBeam(objID, vehicleObj, vehicle, vehicleConfig)
    local vars = vehicleConfig.carscaler
    if not vars or not next(vars) then
        log("I", "carscaler.scaleJBeam", "No config variables for vehicle "..vehicle.model.." with ID "..tostring(objID))
        return
    end

    log("I", "carscaler.scaleJBeam", "Scaling data for vehicle "..vehicle.model
        ..": scale = "..tostring(vars.scale)
        ..", weightMultiplier = "..tostring(vars.weightMultiplier)
        ..", stiffnessMultiplier = "..tostring(vars.stiffnessMultiplier)
        ..", strengthMultiplier = "..tostring(vars.strengthMultiplier)
        ..", powerMultiplier = "..tostring(vars.powerMultiplier)
        ..", gearRatioMultiplier = "..tostring(vars.gearRatioMultiplier)
        ..", aeroMultiplier = "..tostring(vars.aeroMultiplier)
        ..", disablePressureGroups = "..tostring(vars.disablePressureGroups)
        ..", disableSelfCollision = "..tostring(vars.disableSelfCollision))

    local scale = vars.scale or 1
    local scaleArea = scale^2
    local scaleVolume = scale^3

    local weightScale = scaleVolume * (vars.weightMultiplier or 1)
    local stiffnessScale = weightScale / max(scale, 1) * (vars.stiffnessMultiplier or 1)
    local strengthScale = weightScale * (vars.strengthMultiplier or 1)
    local powerScale = weightScale * (vars.powerMultiplier or 1)
    local gearRatioScale = scale * (vars.gearRatioMultiplier or 1)

    local pressureGroupScale = weightScale / max(scaleArea, 1)
    local aeroScale = weightScale / scaleArea * (vars.aeroMultiplier or 1)

    local disablePressureGroups = pressureGroupScale < 0.05
    if vars.disablePressureGroups ~= nil then disablePressureGroups = vars.disablePressureGroups end
    local disableSelfCollision = scale < 0.7
    if vars.disableSelfCollision ~= nil then disableSelfCollision = vars.disableSelfCollision end

    -- Increase render distance for larger vehicles
    vehicleObj.renderDistance = 500 * max(scale, 1)

    -- MARK: props
    if vehicle.props then
        local removeProps = scale < 0.9 or scale > 1.1

        local newCid = 0
        for i = 0, tableSizeC(vehicle.props) - 1 do
            local p = vehicle.props[i]

            -- Scale lights
            if p.mesh and (p.mesh == "SPOTLIGHT" or p.mesh == "POINTLIGHT") then
                p.lightRange = (p.lightRange or 10) * scale
                p.flareScale = (p.flareScale or 1) * scale

                -- Disable shadows when scaled up for performance reasons
                if scale > 1 then p.lightCastShadows = false end

                if p.nodeMove then
                    p.nodeMove.x = (p.nodeMove.x or 0) * scale
                    p.nodeMove.y = (p.nodeMove.y or 0) * scale
                    p.nodeMove.z = (p.nodeMove.z or 0) * scale
                end
                if p.nodeOffset then
                    p.nodeOffset.x = (p.nodeOffset.x or 0) * scale
                    p.nodeOffset.y = (p.nodeOffset.y or 0) * scale
                    p.nodeOffset.z = (p.nodeOffset.z or 0) * scale
                end
                if p.nodeRotate then
                    p.nodeRotate.px = (p.nodeRotate.px or 0) * scale
                    p.nodeRotate.py = (p.nodeRotate.py or 0) * scale
                    p.nodeRotate.pz = (p.nodeRotate.pz or 0) * scale
                end
                if p.translation then
                    p.translation.x = (p.translation.x or 0) * scale
                    p.translation.y = (p.translation.y or 0) * scale
                    p.translation.z = (p.translation.z or 0) * scale
                end
                if p.translationGlobal then
                    p.translationGlobal.x = (p.translationGlobal.x or 0) * scale
                    p.translationGlobal.y = (p.translationGlobal.y or 0) * scale
                    p.translationGlobal.z = (p.translationGlobal.z or 0) * scale
                end
                if p.baseTranslation then
                    --p.baseTranslation.x = (p.baseTranslation.x or 0) * scale
                    --p.baseTranslation.y = (p.baseTranslation.y or 0) * scale
                    p.baseTranslation.z = (p.baseTranslation.z or 0) * scale
                end
                if p.baseTranslationGlobal then
                    p.baseTranslationGlobal.x = (p.baseTranslationGlobal.x or 0) * scale
                    p.baseTranslationGlobal.y = (p.baseTranslationGlobal.y or 0) * scale
                    p.baseTranslationGlobal.z = (p.baseTranslationGlobal.z or 0) * scale
                end
                if p.baseTranslationGlobalElastic then
                    p.baseTranslationGlobalElastic.x = (p.baseTranslationGlobalElastic.x or 0) * scale
                    p.baseTranslationGlobalElastic.y = (p.baseTranslationGlobalElastic.y or 0) * scale
                    p.baseTranslationGlobalElastic.z = (p.baseTranslationGlobalElastic.z or 0) * scale
                end
                if p.baseTranslationGlobalRigid then
                    p.baseTranslationGlobalRigid.x = (p.baseTranslationGlobalRigid.x or 0) * scale
                    p.baseTranslationGlobalRigid.y = (p.baseTranslationGlobalRigid.y or 0) * scale
                    p.baseTranslationGlobalRigid.z = (p.baseTranslationGlobalRigid.z or 0) * scale
                end
                if p.translationOffset then
                    p.translationOffset.x = (p.translationOffset.x or 0) * scale
                    p.translationOffset.y = (p.translationOffset.y or 0) * scale
                    p.translationOffset.z = (p.translationOffset.z or 0) * scale
                end

                -- Make sure there are no holes in the props table and the cids match
                if removeProps and i > newCid then
                    p.cid = newCid
                    vehicle.props[newCid] = p
                    vehicle.props[i] = nil
                    vehicle.maxIDs.props = newCid
                    newCid = newCid + 1
                end

            -- Remove other props
            elseif removeProps then
                vehicle.props[i] = nil
            end
        end
    end

    -- MARK: flexbodies
    if vehicle.flexbodies then
        for i = 0, tableSizeC(vehicle.flexbodies) - 1 do
            local fb = vehicle.flexbodies[i]

            if fb.pos then
                fb.pos.x = (fb.pos.x or 0) * scale
                fb.pos.y = (fb.pos.y or 0) * scale
                fb.pos.z = (fb.pos.z or 0) * scale
            end
            fb.scale = fb.scale or {}
            fb.scale.x = (fb.scale.x or 1) * scale
            fb.scale.y = (fb.scale.y or 1) * scale
            fb.scale.z = (fb.scale.z or 1) * scale
            if fb.nodeMove then
                fb.nodeMove.x = (fb.nodeMove.x or 0) * scale
                fb.nodeMove.y = (fb.nodeMove.y or 0) * scale
                fb.nodeMove.z = (fb.nodeMove.z or 0) * scale
            end
            if fb.nodeOffset then
                fb.nodeOffset.x = (fb.nodeOffset.x or 0) * scale
                fb.nodeOffset.y = (fb.nodeOffset.y or 0) * scale
                fb.nodeOffset.z = (fb.nodeOffset.z or 0) * scale
            end
            if fb.nodeRotate then
                fb.nodeRotate.px = (fb.nodeRotate.px or 0) * scale
                fb.nodeRotate.py = (fb.nodeRotate.py or 0) * scale
                fb.nodeRotate.pz = (fb.nodeRotate.pz or 0) * scale
            end
        end
    end

    -- MARK: options
    if vehicle.options then
        if vehicle.options.nodeWeight then vehicle.options.nodeWeight = vehicle.options.nodeWeight * weightScale end

        if vehicle.options.beamSpring then vehicle.options.beamSpring = vehicle.options.beamSpring * stiffnessScale end
        if vehicle.options.beamDamp then vehicle.options.beamDamp = vehicle.options.beamDamp * stiffnessScale end

        if vehicle.options.beamStrength then vehicle.options.beamStrength = vehicle.options.beamStrength * strengthScale end
        if vehicle.options.beamDeform then vehicle.options.beamDeform = vehicle.options.beamDeform * strengthScale end
    end

    -- MARK: nodes
    if vehicle.nodes then
        for i = 0, tableSizeC(vehicle.nodes) - 1 do
            local n = vehicle.nodes[i]

            if n.pos then n.pos = n.pos * scale end

            if n.nodeWeight then n.nodeWeight = n.nodeWeight * weightScale end
            if n.loadSensitivitySlope then n.loadSensitivitySlope = n.loadSensitivitySlope / weightScale end

            -- couplers
            if n.couplerTag or n.tag then
                n.couplerRadius = (n.couplerRadius or 0.3) * scale
                n.couplerLatchSpeed = (n.couplerLatchSpeed or 0.3) * scale
                n.couplerLockRadius = (n.couplerLockRadius or 0.025) * max(scale, 1)
                if n.couplerStartRadius then n.couplerStartRadius = n.couplerStartRadius * scale end

                n.couplerStrength = (n.couplerStrength or 1000000) * strengthScale
            end

            if disableSelfCollision then n.selfCollision = false end
        end
    end

    -- MARK: slidenodes
    if vehicle.slidenodes then
        for i = 0, tableSizeC(vehicle.slidenodes) - 1 do
            local sn = vehicle.slidenodes[i]

            if sn.tolerance then sn.tolerance = sn.tolerance * scale end

            if sn.spring then sn.spring = sn.spring * stiffnessScale end

            if sn.strength then sn.strength = sn.strength * strengthScale end
            if sn.capStrength then sn.capStrength = sn.capStrength * strengthScale end
        end
    end

    -- MARK: beams
    local lBeamMult = 1--min(scale, 1)
    local pressureBeamScale = stiffnessScale / max(scale, 1)
    if vehicle.beams then
        for i = 0, tableSizeC(vehicle.beams) - 1 do
            local b = vehicle.beams[i]

            if b.precompressionRange then b.precompressionRange = b.precompressionRange * scale end

            if b.beamSpring then b.beamSpring = b.beamSpring * stiffnessScale end
            if b.beamDamp then b.beamDamp = b.beamDamp * stiffnessScale end
            if b.deformLimitStress then b.deformLimitStress = b.deformLimitStress * stiffnessScale end

            if b.maxStress then b.maxStress = b.maxStress * stiffnessScale * scaleArea end

            if b.beamStrength then b.beamStrength = b.beamStrength * strengthScale end
            if b.beamDeform then b.beamDeform = b.beamDeform * strengthScale end

            if (b.beamType == BEAM_ANISOTROPIC) then
                b.boundZone = (b.boundZone or 1) * scale
                if b.beamLongExtent then b.beamLongExtent = b.beamLongExtent * scale end
                if b.transitionZone then b.transitionZone = b.transitionZone * scale end

                if b.springExpansion then b.springExpansion = b.springExpansion * stiffnessScale end
                if b.dampExpansion then b.dampExpansion = b.dampExpansion * stiffnessScale end
            elseif (b.beamType == BEAM_BOUNDED) then
                if b.longBoundRange then b.longBoundRange = b.longBoundRange * scale end
                if b.shortBoundRange then b.shortBoundRange = b.shortBoundRange * scale end
                if b.beamDampVelocitySplit then b.beamDampVelocitySplit = b.beamDampVelocitySplit * scale end
                if b.beamDampVelocitySplitRebound then b.beamDampVelocitySplitRebound = b.beamDampVelocitySplitRebound * scale end

                if b.beamLimitSpring then b.beamLimitSpring = (b.beamLimitSpring or 1) * stiffnessScale end
                if b.beamLimitDamp then b.beamLimitDamp = (b.beamLimitDamp or 1) * stiffnessScale end
                if b.beamLimitDampRebound then b.beamLimitDampRebound = b.beamLimitDampRebound * stiffnessScale end
                if b.beamDampRebound then b.beamDampRebound = b.beamDampRebound * stiffnessScale end
                if b.beamDampFast then b.beamDampFast = b.beamDampFast * stiffnessScale end
                if b.beamDampReboundFast then b.beamDampReboundFast = b.beamDampReboundFast * stiffnessScale end
            elseif (b.beamType == BEAM_SUPPORT) then
                if b.beamLongExtent then b.beamLongExtent = b.beamLongExtent * scale end
            elseif (b.beamType == BEAM_PRESSURED) then
                if b.pressure == nil and b.pressurePSI == nil then b.pressurePSI = 30 end

                if b.pressure then b.pressure = b.pressure * pressureBeamScale end
                if b.pressurePSI then b.pressurePSI = b.pressurePSI * pressureBeamScale end
                if b.maxPressure then b.maxPressure = b.maxPressure * pressureBeamScale end
                if b.maxPressurePSI then b.maxPressurePSI = b.maxPressurePSI * pressureBeamScale end
                if b.pressureLimit then b.pressureLimit = b.pressureLimit * pressureBeamScale end
                if b.pressureLimitPSI then b.pressureLimitPSI = b.pressureLimitPSI * pressureBeamScale end

                b.surface = (b.surface or 1) * scaleArea
            -- TODO: LBeam values may need some more tuning
            elseif (b.beamType == BEAM_LBEAM) then
                if b.beamSpring then b.beamSpring = b.beamSpring * lBeamMult end
                if b.beamDamp then b.beamDamp = b.beamDamp * lBeamMult end
                if b.deformLimitStress then b.deformLimitStress = b.deformLimitStress * lBeamMult end
                if b.maxStress then b.maxStress = b.maxStress * lBeamMult end

                if b.springExpansion then b.springExpansion = b.springExpansion * stiffnessScale * lBeamMult end
                if b.dampExpansion then b.dampExpansion = b.dampExpansion * stiffnessScale * lBeamMult end

                if b.beamStrength then b.beamStrength = b.beamStrength * lBeamMult end
                if b.beamDeform then b.beamDeform = b.beamDeform * lBeamMult end
            end
        end
    end

    -- MARK: hydros
    if vehicle.hydros then
        for i = 0, tableSizeC(vehicle.hydros) - 1 do
            local h = vehicle.hydros[i]

            if h.precompressionRange then h.precompressionRange = h.precompressionRange * scale end

            h.inRate = (h.inRate or 2) / scale
            if h.outRate then h.outRate = h.outRate / scale end
            if h.autoCenterRate then h.autoCenterRate = h.autoCenterRate / scale end

            if h.beamSpring then h.beamSpring = h.beamSpring * stiffnessScale end
            if h.beamDamp then h.beamDamp = h.beamDamp * stiffnessScale end
            if h.beamDeformLimitStress then h.beamDeformLimitStress = h.beamDeformLimitStress * stiffnessScale end

            if h.beamStrength then h.beamStrength = h.beamStrength * strengthScale end
            if h.beamDeform then h.beamDeform = h.beamDeform * strengthScale end
        end
    end

    -- MARK: powertrain hydros
    if vehicle.powertrainHydros then
        for i = 0, tableSizeC(vehicle.powertrainHydros) - 1 do
            local ph = vehicle.powertrainHydros[i]

            if ph.pistonDiameter then ph.pistonDiameter = ph.pistonDiameter * scale end
            if ph.shaftDiameter then ph.shaftDiameter = ph.shaftDiameter * scale end
            if ph.minExtend then ph.minExtend = ph.minExtend * scale end
            if ph.maxExtend then ph.maxExtend = ph.maxExtend * scale end
            ph.cylinderReliefSlipSpeedLimit = (ph.cylinderReliefSlipSpeedLimit or 0.1) * scale
            if ph.maxBypassSpeed then ph.maxBypassSpeed = ph.maxBypassSpeed * scale end

            if ph.virtualMass then ph.virtualMass = ph.virtualMass * weightScale end
            if ph.virtualMassOut then ph.virtualMassOut = ph.virtualMassOut * weightScale end
        end
    end

    -- MARK: torsion bars
    -- Compensate for the stability and stiffness of torsion bars being affected by the distance between the arm nodes
    local torsionScale = stiffnessScale * scaleArea
    local torsionStrengthScale = strengthScale * scaleArea
    if vehicle.torsionbars then
        for i = 0, tableSizeC(vehicle.torsionbars) - 1 do
            local tb = vehicle.torsionbars[i]

            if tb.spring then tb.spring = tb.spring * torsionScale end
            if tb.damp then tb.damp = tb.damp * torsionScale end
            if tb.spring2 then tb.spring2 = tb.spring2 * torsionScale end
            if tb.damp2 then tb.damp2 = tb.damp2 * torsionScale end

            if tb.strength then tb.strength = tb.strength * torsionStrengthScale end
            if tb.deform then tb.deform = tb.deform * torsionStrengthScale end
        end
    end

    -- MARK: torsion hydros
    if vehicle.torsionHydros then
        for i = 0, tableSizeC(vehicle.torsionHydros) - 1 do
            local th = vehicle.torsionHydros[i]

            th.inRate = (th.inRate or 2) / scale
            if th.outRate then th.outRate = th.outRate / scale end

            if th.spring then th.spring = th.spring * torsionScale end
            if th.damp then th.damp = th.damp * torsionScale end
            if th.spring2 then th.spring2 = th.spring2 * torsionScale end
            if th.damp2 then th.damp2 = th.damp2 * torsionScale end

            if th.strength then th.strength = th.strength * torsionStrengthScale end
            if th.deform then th.deform = th.deform * torsionStrengthScale end
        end
    end

    -- MARK: wheels
    if vehicle.wheels then
        for i = 0, tableSizeC(vehicle.wheels) - 1 do
            local w = vehicle.wheels[i]

            --w.tireSoundVolumeCoef = (w.tireSoundVolumeCoef or 1) * scale^0.5
            if w.hubRadiusSimple then w.hubRadiusSimple = w.hubRadiusSimple * scale end
            if w.hubRadius then w.hubRadius = w.hubRadius * scale end
            if w.radius then w.radius = w.radius * scale end
            if w.tireWidth then w.tireWidth = w.tireWidth * scale end
            if w.hubWidth then w.hubWidth = w.hubWidth * scale end
            if w.brakeDiameter then w.brakeDiameter = w.brakeDiameter * scale end

            if w.brakeMass then w.brakeMass = w.brakeMass * weightScale end

            --if w.brakeSpring then w.brakeSpring = w.brakeSpring * stiffnessScale end

            if w.brakeTorque then w.brakeTorque = w.brakeTorque * weightScale * scale end
            if w.parkingTorque then w.parkingTorque = w.parkingTorque * weightScale * scale end
        end
    end

    -- MARK: rotators
    if vehicle.rotators then
        for i = 0, tableSizeC(vehicle.rotators) - 1 do
            local r = vehicle.rotators[i]

            if r.brakeDiameter then r.brakeDiameter = r.brakeDiameter * scale end

            if r.brakeMass then r.brakeMass = r.brakeMass * weightScale end

            --if r.brakeSpring then r.brakeSpring = r.brakeSpring * stiffnessScale end

            if r.brakeTorque then r.brakeTorque = r.brakeTorque * weightScale * scale end
            if r.parkingTorque then r.parkingTorque = r.parkingTorque * weightScale * scale end
        end
    end

    -- MARK: thrusters
    if vehicle.thrusters then
        for i = 0, tableSizeC(vehicle.thrusters) - 1 do
            local th = vehicle.thrusters[i]

            if th.factor then th.factor = th.factor * powerScale end
            if th.thrustLimit then th.thrustLimit = th.thrustLimit * powerScale end
        end
    end

    -- MARK: triangles
    if vehicle.triangles then
        for i = 0, tableSizeC(vehicle.triangles) - 1 do
            local t = vehicle.triangles[i]

            if t.pressure then t.pressure = t.pressure * pressureGroupScale end
            if t.pressurePSI then t.pressurePSI = t.pressurePSI * pressureGroupScale end

            if t.dragCoef then t.dragCoef = t.dragCoef * aeroScale end
            if t.liftCoef then t.liftCoef = t.liftCoef * aeroScale end

            -- Pressure groups become unstable if the nodes are too light, even at low pressures
            if disablePressureGroups then t.pressureGroup = nil end
        end
    end

    -- MARK: controllers
    if vehicle.controller then
        for i = 0, tableSizeC(vehicle.controller) - 1 do
            local c = vehicle.controller[i]

            if c.fileName == "advancedCouplerControl" then
                local acc = vehicle[c.name]

                if acc then
                    acc.openForceDuration = (acc.openForceDuration or 0.2) * scale
                    acc.closeForceDuration = (acc.closeForceDuration or 0.3) * scale

                    acc.openForceMagnitude = (acc.openForceMagnitude or 100) * weightScale
                    acc.closeForceMagnitude = (acc.closeForceMagnitude or 100) * weightScale

                    -- TODO: fully parse header table to verify the correct values are scaled
                    if acc.couplerNodes then
                        for _, cn in ipairs(acc.couplerNodes) do
                            for ci, entry in ipairs(cn) do
                                if type(entry) == "number" then
                                    cn[ci] = entry * weightScale
                                end
                            end
                        end
                    end
                end
            elseif c.fileName == "pneumatics/crossFlowValve" then
                local cfv = vehicle[c.name]

                if cfv then
                    cfv.flowPipeRadius = (cfv.flowPipeRadius or 0.0075) * scale
                end
            elseif c.fileName == "pneumatics/airbrakes" then
                local ab = vehicle[c.name]

                if ab then
                    ab.brakePipeRadius = (ab.brakePipeRadius or 0.0075) * scale
                    ab.brakeActuatorDiameter = (ab.brakeActuatorDiameter or 0.16) * scale
                    ab.brakeActuatorStroke = (ab.brakeActuatorStroke or 0.0635) * scale
                    ab.quickReleaseFlowRate = (ab.quickReleaseFlowRate or 0.01) * scaleVolume
                end
            elseif c.fileName == "pneumatics/actuators" then
                local act = vehicle[c.name]

                if act then
                    act.supplyHoseRadius = (act.supplyHoseRadius or 0.0075) * scale
                    act.virtualBufferCapacity = (act.virtualBufferCapacity or 0.005) * scaleVolume
                    act.pressureDumpFlowRate = (act.pressureDumpFlowRate or 0.01) * scaleVolume

                    if (act.crossFlowGroups and vehicle[act.crossFlowGroups]) then
                        for cfgi = 0, tableSizeC(vehicle[act.crossFlowGroups]) - 1 do
                            local cfg = vehicle[act.crossFlowGroups][cfgi]

                            cfg.virtualBufferCapacity = (cfg.virtualBufferCapacity or 0.005) * scaleVolume
                        end
                    end

                    if (act.pressureBeamData and vehicle[act.pressureBeamData]) then
                        for pbdi = 0, tableSizeC(vehicle[act.pressureBeamData]) - 1 do
                            local pbd = vehicle[act.pressureBeamData][pbdi]

                            pbd.supplyHoseRadius = (pbd.supplyHoseRadius or act.supplyHoseRadius) * scale
                        end
                    end
                end
            elseif c.fileName == "bypassDampers" then
                local bd = vehicle[c.name]

                if bd then
                    -- TODO: fully parse header table to verify the correct values are scaled
                    -- TODO: this also scales the velocity values by the stiffnessScale at the moment, it should be using the scale value instead
                    if bd.zones then
                        for _, z in ipairs(bd.zones) do
                            for zi, entry in ipairs(z) do
                                if type(entry) == "number" then
                                    z[zi] = entry * stiffnessScale
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- MARK: cameras
    if vehicle.cameraData then
        if vehicle.cameraData.orbit then
            local cam = vehicle.cameraData.orbit
            if cam.offset then
                cam.offset.x = (cam.offset.x or 0) * scale
                cam.offset.y = (cam.offset.y or 0) * scale
                cam.offset.z = (cam.offset.z or 0) * scale
            end
            if cam.distance then cam.distance = cam.distance * scale end
            if cam.distanceMin then cam.distanceMin = cam.distanceMin * scale end
        end

        if vehicle.cameraData.chase then
            local cam = vehicle.cameraData.chase
            if cam.offset then
                cam.offset.x = (cam.offset.x or 0) * scale
                cam.offset.y = (cam.offset.y or 0) * scale
                cam.offset.z = (cam.offset.z or 0) * scale
            end
            if cam.distance then cam.distance = cam.distance * scale end
            if cam.distanceMin then cam.distanceMin = cam.distanceMin * scale end
        end

        if vehicle.cameraData.onboard then
            for _, cam in ipairs(vehicle.cameraData.onboard) do
                cam.x = (cam.x or 0) * scale
                cam.y = (cam.y or 0) * scale
                cam.z = (cam.z or 0) * scale

                if cam.nodeOffset then
                    cam.nodeOffset.x = (cam.nodeOffset.x or 0) * scale
                    cam.nodeOffset.y = (cam.nodeOffset.y or 0) * scale
                    cam.nodeOffset.z = (cam.nodeOffset.z or 0) * scale
                end

                if cam.beamSpring then cam.beamSpring = cam.beamSpring * stiffnessScale end
                if cam.beamDamp then cam.beamDamp = cam.beamDamp * stiffnessScale end

                if cam.beamStrength then cam.beamStrength = cam.beamStrength * strengthScale end
                if cam.beamDeform then cam.beamDeform = cam.beamDeform * strengthScale end

                if cam.nodeWeight then cam.nodeWeight = cam.nodeWeight * weightScale end
            end
        end

        if vehicle.cameraData.relative then
            for _, cam in ipairs(vehicle.cameraData.relative) do
                if cam.pos then
                    cam.pos.x = (cam.pos.x or 0) * scale
                    cam.pos.y = (cam.pos.y or 0) * scale
                    cam.pos.z = (cam.pos.z or 0) * scale
                end
            end
        end
    end

    -- MARK: powertrain
    if vehicle.powertrain then
        for i = 0, tableSizeC(vehicle.powertrain) - 1 do
            local device = vehicle.powertrain[i]

            if device.type == "combustionEngine" then
                local ce = vehicle[device.name]
                if ce then
                    -- Cylinder wall and oil sometimes overheat on scaled up engines
                    if powerScale > 1 then
                        ce.thermalsEnabled = false
                    end

                    ce.inertia = (ce.inertia or 0.1) * weightScale
                    if ce.friction then ce.friction = ce.friction * weightScale end
                    if ce.dynamicFriction then ce.dynamicFriction = ce.dynamicFriction * weightScale end
                    if ce.starterTorque then ce.starterTorque = ce.starterTorque * weightScale end
                    if ce.engineBrakeTorque then ce.engineBrakeTorque = ce.engineBrakeTorque * weightScale end
                    if ce.coolantVolume then ce.coolantVolume = ce.coolantVolume * weightScale end
                    if ce.oilVolume then ce.oilVolume = ce.oilVolume * weightScale end

                    if ce.maxTorqueRating then ce.maxTorqueRating = ce.maxTorqueRating * powerScale end
                    if ce.radiatorArea then ce.radiatorArea = ce.radiatorArea * powerScale end
                    if ce.radiatorFanVolume then ce.radiatorFanVolume = ce.radiatorFanVolume * powerScale end
                    if ce.oilRadiatorArea then ce.oilRadiatorArea = ce.oilRadiatorArea * powerScale end

                    -- TODO: fully parse header tables to verify the correct values are scaled
                    if ce.torque then
                        for _, entry in ipairs(ce.torque) do
                            if entry[2] and type(entry[2]) == "number" then entry[2] = entry[2] * powerScale end
                        end
                    end
                    if ce.torqueModExhaust then
                        for _, entry in ipairs(ce.torqueModExhaust) do
                            if entry[2] and type(entry[2]) == "number" then entry[2] = entry[2] * powerScale end
                        end
                    end
                    if ce.torqueModIntake then
                        for _, entry in ipairs(ce.torqueModIntake) do
                            if entry[2] and type(entry[2]) == "number" then entry[2] = entry[2] * powerScale end
                        end
                    end
                    if ce.torqueCompressionBrake then
                        for _, entry in ipairs(ce.torqueCompressionBrake) do
                            if entry[2] and type(entry[2]) == "number" then entry[2] = entry[2] * powerScale end
                        end
                    end

                    if ce.nitrousOxideInjection and vehicle[ce.nitrousOxideInjection] then vehicle[ce.nitrousOxideInjection].addedPower = (vehicle[ce.nitrousOxideInjection].addedPower or 0) * powerScale end

                    -- Sound volume
                    if ce.shutOffVolumeEngine then ce.shutOffVolumeEngine = ce.shutOffVolumeEngine * scale end
                    if ce.shutOffVolumeExhaust then ce.shutOffVolumeExhaust = ce.shutOffVolumeExhaust * scale end
                    if ce.starterVolume then ce.starterVolume = ce.starterVolume * scale end
                    if ce.starterVolumeExhaust then ce.starterVolumeExhaust = ce.starterVolumeExhaust * scale end
                    if ce.sustainedAfterfireVolumeCoef then ce.sustainedAfterfireVolumeCoef = ce.sustainedAfterfireVolumeCoef * scale end

                    if ce.soundConfig and vehicle[ce.soundConfig] then vehicle[ce.soundConfig].mainGain = (vehicle[ce.soundConfig].mainGain or 0) + 7 * (scale-1) end
                    if ce.soundConfigExhaust and vehicle[ce.soundConfigExhaust] then vehicle[ce.soundConfigExhaust].mainGain = (vehicle[ce.soundConfigExhaust].mainGain or 0) + 7 * (scale-1) end
                end
            elseif device.type == "electricMotor" then
                local em = vehicle[device.name]
                if em then
                    em.inertia = (em.inertia or 0.1) * weightScale
                    if em.friction then em.friction = em.friction * weightScale end
                    if em.dynamicFriction then em.dynamicFriction = em.dynamicFriction * weightScale end

                    if em.maxTorqueRating then em.maxTorqueRating = em.maxTorqueRating * powerScale end
                    if em.maxRegenPower then em.maxRegenPower = em.maxRegenPower * powerScale end
                    if em.maxRegenTorque then em.maxRegenTorque = em.maxRegenTorque * powerScale end
                    if em.minumWantedRegenTorque then em.minimumWantedRegenTorque = em.minimumWantedRegenTorque * powerScale end
                    if em.maximumWantedRegenTorque then em.maximumWantedRegenTorque = em.maximumWantedRegenTorque * powerScale end

                    -- TODO: fully parse header table to verify the correct values are scaled
                    if em.torque then
                        for _, entry in ipairs(em.torque) do
                            if entry[2] and type(entry[2]) == "number" then entry[2] = entry[2] * powerScale end
                        end
                    end
                    if em.regenTorquCurve then
                        for _, entry in ipairs(em.regenTorquCurve) do
                            if entry[2] and type(entry[2]) == "number" then entry[2] = entry[2] * powerScale end
                        end
                    end

                    -- Sound volume
                    if em.soundConfig and vehicle[em.soundConfig] then vehicle[em.soundConfig].mainGain = (vehicle[em.soundConfig].mainGain or 0) + 7 * (scale-1) end
                end
            elseif device.type == "electricServo" then
                local es = vehicle[device.name]
                if es then
                    if es.friction then es.friction = es.friction * weightScale end
                    if es.dynamicFriction then es.dynamicFriction = es.dynamicFriction * weightScale end

                    es.angularSpring = (es.angularSpring or 1) * stiffnessScale

                    es.stallTorque = (es.stallTorque or 1000) * powerScale
                end
            elseif device.type == "frictionClutch" then
                local fc = vehicle[device.name]
                if fc then
                    if fc.additionalEngineInertia then fc.additionalEngineInertia = fc.additionalEngineInertia * weightScale end
                    fc.clutchMass = (fc.clutchMass or 10) * weightScale

                    if fc.lockTorque then fc.lockTorque = fc.lockTorque * powerScale end
                    fc.coolingCoef = (fc.coolingCoef or 1) * powerScale

                    --fc.clutchStiffness = (fc.clutchStiffness or 1) * stiffnessScale
                    --fc.lockSpringCoef = (fc.lockSpringCoef or 1) * stiffnessScale
                    --if fc.lockSpring then fc.lockSpring = fc.lockSpring * stiffnessScale end
                end
            elseif device.type == "centrifugalClutch" then
                local cc = vehicle[device.name]
                if cc then
                    if cc.additionalEngineInertia then cc.additionalEngineInertia = cc.additionalEngineInertia * weightScale end
                    cc.clutchMass = (cc.clutchMass or 1) * weightScale

                    if cc.lockTorque then cc.lockTorque = cc.lockTorque * powerScale end
                    cc.coolingCoef = (cc.coolingCoef or 0.8) * powerScale

                    --if cc.lockSpring then cc.lockSpring = cc.lockSpring * stiffnessScale end
                end
            elseif device.type == "torqueConverter" then
                local tc = vehicle[device.name]
                if tc then
                    if tc.additionalEngineInertia then tc.additionalEngineInertia = tc.additionalEngineInertia * weightScale end

                    if tc.converterTorque then tc.converterTorque = tc.converterTorque * powerScale end
                    tc.converterDiameter = (tc.converterDiameter or 0.30) * powerScale^(1/5)
                    tc.lockupClutchTorque = (tc.lockupClutchTorque or 100) * powerScale
                end
            elseif device.type == "viscousClutch" then
                local vc = vehicle[device.name]
                if vc then
                    if vc.additionalEngineInertia then vc.additionalEngineInertia = vc.additionalEngineInertia * weightScale end

                    vc.viscousCoef = (vc.viscousCoef or 10) * powerScale
                    if vc.viscousTorque then vc.viscousTorque = vc.viscousTorque * powerScale end
                end
            elseif device.type == "manualGearbox" then
                local mg = vehicle[device.name]
                if mg then
                    if mg.friction then mg.friction = mg.friction * weightScale end
                    if mg.dynamicFriction then mg.dynamicFriction = mg.dynamicFriction * weightScale end
                    if mg.neutralFriction then mg.neutralFriction = mg.neutralFriction * weightScale end
                    if mg.neutralDynamicFriction then mg.neutralDynamicFriction = mg.neutralDynamicFriction * weightScale end
                end
            elseif device.type == "automaticGearbox" then
                local ag = vehicle[device.name]
                if ag then
                    if ag.friction then ag.friction = ag.friction * weightScale end
                    if ag.dynamicFriction then ag.dynamicFriction = ag.dynamicFriction * weightScale end

                    ag.parkLockTorque = (ag.parkLockTorque or 1000) * powerScale
                    ag.oneWayViscousCoef = (ag.oneWayViscousCoef or 5) * powerScale

                    --if ag.parkLockSpring then ag.parkLockSpring = ag.parkLockSpring * stiffnessScale end
                end
            elseif device.type == "cvtGearbox" then
                local cvt = vehicle[device.name]
                if cvt then
                    if cvt.friction then cvt.friction = cvt.friction * weightScale end
                    if cvt.dynamicFriction then cvt.dynamicFriction = cvt.dynamicFriction * weightScale end

                    cvt.parkLockTorque = (cvt.parkLockTorque or 1000) * powerScale
                    cvt.oneWayViscousCoef = (cvt.oneWayViscousCoef or 5) * powerScale

                    --if cvt.parkLockSpring then cvt.parkLockSpring = cvt.parkLockSpring * stiffnessScale end
                end
            elseif device.type == "dctGearbox" then
                local dct = vehicle[device.name]
                if dct then
                    if dct.friction then dct.friction = dct.friction * weightScale end
                    if dct.dynamicFriction then dct.dynamicFriction = dct.dynamicFriction * weightScale end
                    if dct.additionalEngineInertia then dct.additionalEngineInertia = dct.additionalEngineInertia * weightScale end

                    if dct.lockTorque then dct.lockTorque = dct.lockTorque * powerScale end
                    dct.parkLockTorque = (dct.parkLockTorque or 1000) * powerScale

                    --dct.clutchStiffness = (dct.clutchStiffness or 1) * stiffnessScale
                    --if dct.lockSpring then dct.lockSpring = dct.lockSpring * stiffnessScale end
                    --if dct.parkLockSpring then dct.parkLockSpring = dct.parkLockSpring * stiffnessScale end
                end
            elseif device.type == "sequentialGearbox" then
                local seq = vehicle[device.name]
                if seq then
                    if seq.friction then seq.friction = seq.friction * weightScale end
                    if seq.dynamicFriction then seq.dynamicFriction = seq.dynamicFriction * weightScale end
                end
            elseif device.type == "rangeBox" then
                local rb = vehicle[device.name]
                if rb then
                    if rb.friction then rb.friction = rb.friction * weightScale end
                    if rb.dynamicFriction then rb.dynamicFriction = rb.dynamicFriction * weightScale end
                end
            elseif device.type == "compressor" then
                local comp = vehicle[device.name]
                if comp then
                    if comp.friction then comp.friction = comp.friction * weightScale end
                    if comp.dynamicFriction then comp.dynamicFriction = comp.dynamicFriction * weightScale end

                    comp.pumpDisplacement = (comp.pumpDisplacement or 0.00035) * scaleVolume
                end
            elseif device.type == "electricWinch" then
                local ew = vehicle[device.name]
                if ew then
                    if ew.friction then ew.friction = ew.friction * weightScale end
                    if ew.dynamicFriction then ew.dynamicFriction = ew.dynamicFriction * weightScale end
                end
            elseif device.type == "hydraulicPump" then
                local hp = vehicle[device.name]
                if hp then
                    if hp.friction then hp.friction = hp.friction * weightScale end
                    if hp.dynamicFriction then hp.dynamicFriction = hp.dynamicFriction * weightScale end

                    hp.reliefValveArea = (hp.reliefValveArea or 0.00001) * scaleArea

                    hp.pumpMaxDisplacement = (hp.pumpMaxDisplacement or 0.0002) * scaleVolume
                    hp.accumulatorMaxVolume = (hp.accumulatorMaxVolume or 0.001) * scaleVolume
                    if hp.initialAccumulatorOilVolume then hp.initialAccumulatorOilVolume = hp.initialAccumulatorOilVolume * scaleVolume end

                    --hp.showDebugGraph = true
                end
            elseif device.type == "hydraulicAccumulator" then
                local ha = vehicle[device.name]
                if ha then
                    if ha.friction then ha.friction = ha.friction * weightScale end
                    if ha.dynamicFriction then ha.dynamicFriction = ha.dynamicFriction * weightScale end

                    ha.reliefValveArea = (ha.reliefValveArea or 0.00001) * scaleArea

                    ha.accumulatorMaxVolume = (ha.accumulatorMaxVolume or 0.001) * scaleVolume
                    if ha.initialAccumulatorOilVolume then ha.initialAccumulatorOilVolume = ha.initialAccumulatorOilVolume * scaleVolume end
                end
            elseif device.type == "linearActuator" then
                local la = vehicle[device.name]
                if la then
                    if la.friction then la.friction = la.friction * weightScale end
                    if la.dynamicFriction then la.dynamicFriction = la.dynamicFriction * weightScale end
                    la.virtualInertia = (la.virtualInertia or 2) * weightScale

                    la.screwDiameter = (la.screwDiameter or 0.05) * scale
                    if la.leadMillimeterPerRevolution then la.leadMillimeterPerRevolution = la.leadMillimeterPerRevolution * scale end
                end
            elseif device.type == "differential" then
                local diff = vehicle[device.name]
                if diff then
                    if diff.friction then diff.friction = diff.friction * weightScale end
                    if diff.dynamicFriction then diff.dynamicFriction = diff.dynamicFriction * weightScale end
                    if diff.defaultVirtualInertia then diff.defaultVirtualInertia = diff.defaultVirtualInertia * weightScale end
                    diff.lsdPreload = (diff.lsdPreload or 50) * weightScale

                    diff.lockTorque = (diff.lockTorque or 500) * powerScale
                    if diff.activeLockTorque then diff.activeLockTorque = diff.activeLockTorque * powerScale end
                    diff.viscousCoef = (diff.viscousCoef or 5) * powerScale
                    if diff.viscousTorque then diff.viscousTorque = diff.viscousTorque * powerScale end

                    --if diff.lockSpring then diff.lockSpring = diff.lockSpring * stiffnessScale end
                else
                    -- Diffs sometimes have values set directly on the device
                    if device.friction then device.friction = device.friction * weightScale end
                    if device.dynamicFriction then device.dynamicFriction = device.dynamicFriction * weightScale end
                    if device.defaultVirtualInertia then device.defaultVirtualInertia = device.defaultVirtualInertia * weightScale end
                    device.lsdPreload = (device.lsdPreload or 50) * weightScale

                    device.lockTorque = (device.lockTorque or 500) * powerScale
                    if device.activeLockTorque then device.activeLockTorque = device.activeLockTorque * powerScale end
                    device.viscousCoef = (device.viscousCoef or 5) * powerScale
                    if device.viscousTorque then device.viscousTorque = device.viscousTorque * powerScale end

                    --if device.lockSpring then device.lockSpring = device.lockSpring * stiffnessScale end
                end
            elseif device.type == "splitShaft" then
                    local ss = vehicle[device.name]
                    if ss then
                    if ss.friction then ss.friction = ss.friction * weightScale end
                    if ss.dynamicFriction then ss.dynamicFriction = ss.dynamicFriction * weightScale end
                    if ss.defaultVirtualInertia then ss.defaultVirtualInertia = ss.defaultVirtualInertia * weightScale end

                    ss.lockTorque = (ss.lockTorque or 500) * powerScale
                    ss.viscousCoef = (ss.viscousCoef or 10) * powerScale
                    if ss.viscousTorque then ss.viscousTorque = ss.viscousTorque * powerScale end

                    --ss.clutchStiffness = (ss.clutchStiffness or 1) * stiffnessScale
                    --if ss.lockSpring then ss.lockSpring = ss.lockSpring * stiffnessScale end
                    --ss.lockSpringCoef = (ss.lockSpringCoef or 1) * stiffnessScale
                end
            elseif device.type == "shaft" then
                local shaft = vehicle[device.name]
                if shaft then
                    if shaft.friction then shaft.friction = shaft.friction * weightScale end
                    if shaft.dynamicFriction then shaft.dynamicFriction = shaft.dynamicFriction * weightScale end
                    if shaft.defaultVirtualInertia then shaft.defaultVirtualInertia = shaft.defaultVirtualInertia * weightScale end

                    -- Adjust wheel axle gear ratio to compensate for scaled wheel size
                    if shaft.connectedWheel then shaft.gearRatio = (shaft.gearRatio or 1) * gearRatioScale end
                else
                    -- Shafts sometimes have values set directly on the device
                    if device.friction then device.friction = device.friction * weightScale end
                    if device.dynamicFriction then device.dynamicFriction = device.dynamicFriction * weightScale end
                    if device.defaultVirtualInertia then device.defaultVirtualInertia = device.defaultVirtualInertia * weightScale end

                    -- Adjust wheel axle gear ratio to compensate for scaled wheel size
                    if device.connectedWheel then device.gearRatio = (device.gearRatio or 1) * gearRatioScale end
                end
            -- Me262 compatibility
            elseif device.type == "simpleJetEngine" then
                local jet = vehicle[device.name]
                if jet then
                    if jet.maxThrust then jet.maxThrust = jet.maxThrust * powerScale end
                    if jet.boosterThrust then jet.boosterThrust = jet.boosterThrust * powerScale end
                end
            end
        end
    end

    -- MARK: energy storage
    if vehicle.energyStorage then
        for i = 0, tableSizeC(vehicle.energyStorage) - 1 do
            local es = vehicle.energyStorage[i]

            local tank = vehicle[es.name]
            if tank then
                if tank.fuelCapacity then tank.fuelCapacity = tank.fuelCapacity * weightScale end
                if tank.startingFuelCapacity then tank.startingFuelCapacity = tank.startingFuelCapacity * weightScale end
                if tank.batteryCapacity then tank.batteryCapacity = tank.batteryCapacity * weightScale end
                if tank.startingBatteryCapacity then tank.startingBatteryCapacity = tank.startingBatteryCapacity * weightScale end
                if tank.capacity then tank.capacity = tank.capacity * weightScale end
                if tank.startingCapacity then tank.startingCapacity = tank.startingCapacity * weightScale end
            end
        end
    end

    -- MARK: triggers
    if vehicle.triggers then
        for i = 0, tableSizeC(vehicle.triggers) - 1 do
            local t = vehicle.triggers[i]

            if t.translation then
                t.translation.x = (t.translation.x or 0) * scale
                t.translation.y = (t.translation.y or 0) * scale
                t.translation.z = (t.translation.z or 0) * scale
            end

            if t.baseTranslation then
                t.baseTranslation.x = (t.baseTranslation.x or 0) * scale
                t.baseTranslation.y = (t.baseTranslation.y or 0) * scale
                t.baseTranslation.z = (t.baseTranslation.z or 0) * scale
            end

            if t.size then
                -- Sphere triggers use single number for size
                if type(t.size) == "number" then
                    t.size = t.size * scale
                else
                    t.size.x = (t.size.x or 0) * scale
                    t.size.y = (t.size.y or 0) * scale
                    t.size.z = (t.size.z or 0) * scale
                end
            end
        end
    end

    -- MARK: old powertrain
    if vehicle.engine then
        local e = vehicle.engine

        if powerScale > 1 then
            e.thermalsEnabled = false
        end

        e.inertia = (e.inertia or 0.2) * weightScale
        e.friction = (e.friction or e.engineFriction or 20) * weightScale
        e.brakingCoefRPS = (e.brakingCoefRPS or 0.2) * weightScale
        if e.coolantVolume then e.coolantVolume = e.coolantVolume * weightScale end
        if e.oilVolume then e.oilVolume = e.oilVolume * weightScale end
        if e.fuelCapacity then e.fuelCapacity = e.fuelCapacity * weightScale end
        if e.axleFriction then e.axleFriction = e.axleFriction * weightScale end

        e.viscousCoupling = (e.viscousCoupling or 10) * powerScale
        if e.engineBlockAirCoolingEfficiency then e.engineBlockAirCoolingEfficiency = e.engineBlockAirCoolingEfficiency * powerScale end
        if e.radiatorArea then e.radiatorArea = e.radiatorArea * powerScale end
        if e.oilRadiatorArea then e.oilRadiatorArea = e.oilRadiatorArea * powerScale end

        -- Compensate gear ratio for changed wheel size
        e.differential = (e.differential or 1) * gearRatioScale
    end

    if vehicle.enginetorque then
        for _, et in ipairs(vehicle.enginetorque) do
            if et.torque then et.torque = et.torque * powerScale end
        end
    end

    if vehicle.differentials then
        for _, d in ipairs(vehicle.differentials) do
            if d.closedTorque then d.closedTorque = d.closedTorque * powerScale end
        end
    end
end

-- MARK: extension loading
local function onExtensionLoaded()
    core_input_categories.carscaler = {order = 100, icon = "settings", title = "Carscaler", desc = "Options for the Carscaler mod"}

    log("D", "carscaler.onExtensionLoaded", "checking jbeam/sections/events hook")

    local jbeamEvents = require("jbeam/sections/events")
    if jbeamEvents and not jbeamEvents.carscalerHook then
        log("I", "carscaler.onExtensionLoaded", "hooking jbeam/sections/events.process")

        local origProcess = jbeamEvents.process

        jbeamEvents.process = function(objID, vehicleObj, vehicle, ...)
            if objID == nextObjID and nextVehicleConfig then
                scaleJBeam(objID, vehicleObj, vehicle, nextVehicleConfig)
            else
                log("E", "carscaler jbeam/sections/events.process hook", "Failed to assign vehicle config, IDs: "..tostring(objID).." ~= "..tostring(nextObjID))
            end

            return origProcess(objID, vehicleObj, vehicle, ...)
        end

        jbeamEvents.carscalerHook = true
        package.loaded["jbeam/sections/events"] = jbeamEvents
    end

    log("D", "carscaler.onExtensionLoaded", "checking jbeam/loader hook")

    local jbeamLoader = require("jbeam/loader")
    if jbeamLoader and not jbeamLoader.carscalerHook then
        log("I", "carscaler.onExtensionLoaded", "hooking jbeam/loader.process")

        local origLoadVehicleStage1 = jbeamLoader.loadVehicleStage1

        jbeamLoader.loadVehicleStage1 = function(objID, vehicleDir, vehicleConfig, ...)
            log("D", "carscaler jbeam/loader.loadVehicleStage1 hook", "Next spawn object id: "..tostring(objID))

            -- Keep track of id and config for next vehicle spawn
            nextObjID = objID
            nextVehicleConfig = vehicleConfig

            return origLoadVehicleStage1(objID, vehicleDir, vehicleConfig, ...)
        end

        jbeamLoader.carscalerHook = true
        package.loaded["jbeam/loader"] = jbeamLoader
    end
end

local function onExtensionUnloaded()
    log("I", "carscaler.onExtensionUnloaded", "unloading patched modules")

    -- Unload the patched modules so the original ones will be loaded next time
    unrequire("jbeam/sections/events")
    unrequire("jbeam/loader")
end

-- MARK: UI
local function resetUIValues()
    uiData.scale[0] = 1
    uiData.weightMultiplier[0] = 1
    uiData.stiffnessMultiplier[0] = 1
    uiData.strengthMultiplier[0] = 1
    uiData.powerMultiplier[0] = 1
    uiData.gearRatioMultiplier[0] = 1
    uiData.aeroMultiplier[0] = 1
    uiData.disablePressureGroupsOverride[0] = false
    uiData.disablePressureGroups[0] = false
    uiData.disableSelfCollisionOverride[0] = false
    uiData.disableSelfCollision[0] = false
end

local function updateUIValues()
    local config = core_vehicle_partmgmt and core_vehicle_partmgmt.getConfig()
    if not config or not config.carscaler then
        log("E", "carscaler.updateUIValues", "No player vehicle config")
        resetUIValues()
        return
    end

    local vars = config.carscaler
    uiData.scale[0] = vars.scale or 1
    uiData.weightMultiplier[0] = vars.weightMultiplier or 1
    uiData.stiffnessMultiplier[0] = vars.stiffnessMultiplier or 1
    uiData.strengthMultiplier[0] = vars.strengthMultiplier or 1
    uiData.powerMultiplier[0] = vars.powerMultiplier or 1
    uiData.gearRatioMultiplier[0] = vars.gearRatioMultiplier or 1
    uiData.aeroMultiplier[0] = vars.aeroMultiplier or 1
    uiData.disablePressureGroupsOverride[0] = vars.disablePressureGroups ~= nil
    uiData.disablePressureGroups[0] = vars.disablePressureGroups or false
    uiData.disableSelfCollisionOverride[0] = vars.disableSelfCollision ~= nil
    uiData.disableSelfCollision[0] = vars.disableSelfCollision or false
end

local function applyUIValues()
    local config = core_vehicle_partmgmt and core_vehicle_partmgmt.getConfig()
    if not config then
        log("E", "carscaler.applyUIValues", "No player vehicle config")
        return
    end

    local vars = config.carscaler or {}

    vars.scale = uiData.scale[0] ~= 1 and uiData.scale[0] or nil
    vars.weightMultiplier = uiData.weightMultiplier[0] ~= 1 and uiData.weightMultiplier[0] or nil
    vars.stiffnessMultiplier = uiData.stiffnessMultiplier[0] ~= 1 and uiData.stiffnessMultiplier[0] or nil
    vars.strengthMultiplier = uiData.strengthMultiplier[0] ~= 1 and uiData.strengthMultiplier[0] or nil
    vars.powerMultiplier = uiData.powerMultiplier[0] ~= 1 and uiData.powerMultiplier[0] or nil
    vars.gearRatioMultiplier = uiData.gearRatioMultiplier[0] ~= 1 and uiData.gearRatioMultiplier[0] or nil
    vars.aeroMultiplier = uiData.aeroMultiplier[0] ~= 1 and uiData.aeroMultiplier[0] or nil
    if uiData.disablePressureGroupsOverride[0] then
        vars.disablePressureGroups = uiData.disablePressureGroups[0]
    else
        vars.disablePressureGroups = nil
    end
    if uiData.disableSelfCollisionOverride[0] then
        vars.disableSelfCollision = uiData.disableSelfCollision[0]
    else
        vars.disableSelfCollision = nil
    end

    if core_vehicle_partmgmt then core_vehicle_partmgmt.setConfig({carscaler = vars}, true) end

    -- BeamMP compatibility
    if MPCoreNetwork and MPCoreNetwork.isMPSession() and MPVehicleGE then
        local vehID = be:getPlayerVehicleID(0)
        if vehID > 0 then 
            MPVehicleGE.sendVehicleEdit(vehID)
        end
    end
end

local function resetScaling()
    if core_vehicle_partmgmt then core_vehicle_partmgmt.setConfig({carscaler = {}}, true) end
    updateUIValues()

    -- BeamMP compatibility
    if MPCoreNetwork and MPCoreNetwork.isMPSession() and MPVehicleGE then
        local vehID = be:getPlayerVehicleID(0)
        if vehID > 0 then 
            MPVehicleGE.sendVehicleEdit(vehID)
        end
    end
end

local function randomizeUIValues()
    if uiRandomizer.scaleEnabled[0] then
        uiData.scale[0] = random(uiRandomizer.scaleMin[0]*100, uiRandomizer.scaleMax[0]*100)/100
    end
    if uiRandomizer.multipliersEnabled[0] then
        uiData.weightMultiplier[0] = random(uiRandomizer.weightMultiplierMin[0]*100, uiRandomizer.weightMultiplierMax[0]*100)/100
        uiData.stiffnessMultiplier[0] = random(uiRandomizer.stiffnessMultiplierMin[0]*100, uiRandomizer.stiffnessMultiplierMax[0]*100)/100
        uiData.strengthMultiplier[0] = random(uiRandomizer.strengthMultiplierMin[0]*100, uiRandomizer.strengthMultiplierMax[0]*100)/100
        uiData.powerMultiplier[0] = random(uiRandomizer.powerMultiplierMin[0]*100, uiRandomizer.powerMultiplierMax[0]*100)/100
        uiData.gearRatioMultiplier[0] = random(uiRandomizer.gearRatioMultiplierMin[0]*100, uiRandomizer.gearRatioMultiplierMax[0]*100)/100
        uiData.aeroMultiplier[0] = random(uiRandomizer.aeroMultiplierMin[0]*100, uiRandomizer.aeroMultiplierMax[0]*100)/100
    end
    if uiRandomizer.autoApply[0] then
        applyUIValues()
    end
end

local function resetRandomizerSettings()
    uiRandomizer.scaleEnabled[0] = true
    uiRandomizer.scaleMin[0] = 0.5
    uiRandomizer.scaleMax[0] = 2
    uiRandomizer.multipliersEnabled[0] = false
    uiRandomizer.weightMultiplierMin[0] = 0.5
    uiRandomizer.weightMultiplierMax[0] = 2
    uiRandomizer.stiffnessMultiplierMin[0] = 1
    uiRandomizer.stiffnessMultiplierMax[0] = 1
    uiRandomizer.strengthMultiplierMin[0] = 1
    uiRandomizer.strengthMultiplierMax[0] = 1
    uiRandomizer.powerMultiplierMin[0] = 0.5
    uiRandomizer.powerMultiplierMax[0] = 2
    uiRandomizer.gearRatioMultiplierMin[0] = 0.5
    uiRandomizer.gearRatioMultiplierMax[0] = 2
    uiRandomizer.aeroMultiplierMin[0] = 0.5
    uiRandomizer.aeroMultiplierMax[0] = 2
    uiRandomizer.autoApply[0] = true
end

local function onPreRender(dt)
    if not windowOpen[0] then return end

    if im.Begin("Carscaler by stefan750 (v1.0.1)", windowOpen, im.WindowFlags_AlwaysAutoResize) then
        im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(4, 2))
        im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(4, 6))

        im.SetNextItemWidth(200)
        im.PushFont3("cairo_semibold_large")
        im.DragFloat("Vehicle Scale", uiData.scale, 0.01, 0.1, 10, "%.2f")
        im.PopFont()
        if im.IsItemHovered() then im.SetTooltip("Scales the entire vehicle while trying to keep the overall behaviour similar to the original") end
        im.Separator()

        if im.CollapsingHeader1("Advanced options") then
            im.PushItemWidth(200)
            im.Text("Additional multipliers")
            im.DragFloat("Weight", uiData.weightMultiplier, 0.01, 0.01, 10, "%.2f")
            if im.IsItemHovered() then im.SetTooltip("Scales the weight of the vehicle (also affects the other values)") end
            im.DragFloat("Stiffness", uiData.stiffnessMultiplier, 0.01, 0.01, 1, "%.2f")
            if im.IsItemHovered() then im.SetTooltip("Scales the force needed to bend parts of the vehicle, values above 1 will cause instability") end
            im.DragFloat("Strength", uiData.strengthMultiplier, 0.01, 0.01, 10, "%.2f")
            if im.IsItemHovered() then im.SetTooltip("Scales the force needed to deform or break parts of the vehicle") end
            im.DragFloat("Engine Power", uiData.powerMultiplier, 0.01, 0, 10, "%.2f")
            if im.IsItemHovered() then im.SetTooltip("Scales the engine power of the vehicle") end
            im.DragFloat("Gear Ratio", uiData.gearRatioMultiplier, 0.01, 0.01, 10, "%.2f")
            if im.IsItemHovered() then im.SetTooltip("Scales the gear ratio of the vehicle") end
            im.DragFloat("Drag/Lift", uiData.aeroMultiplier, 0.01, 0, 10, "%.2f")
            if im.IsItemHovered() then im.SetTooltip("Scales the lift and drag coefficients of the vehicle") end
            im.PopItemWidth()
            im.Separator()

            im.Text("Stability options")
            im.Columns(2, "stabilityOptions", false)
            im.SetColumnWidth(0, 100)
            im.Checkbox("Override", uiData.disablePressureGroupsOverride)
            if im.IsItemHovered() then im.SetTooltip("Override the automatic setting (only touch this if you know what you are doing!)") end
            im.NextColumn()
            im.BeginDisabled(not uiData.disablePressureGroupsOverride[0])
            im.Checkbox("Disable PressureGroups", uiData.disablePressureGroups)
            if im.IsItemHovered() then im.SetTooltip("Disabling PressureGroups will deflate tires and other things that contain air, but may help with instabilities") end
            im.EndDisabled()
            im.NextColumn()
            im.Checkbox("Override##2", uiData.disableSelfCollisionOverride)
            if im.IsItemHovered() then im.SetTooltip("Override the automatic setting (only touch this if you know what you are doing!)") end
            im.NextColumn()
            im.BeginDisabled(not uiData.disableSelfCollisionOverride[0])
            im.Checkbox("Disable SelfCollision", uiData.disableSelfCollision)
            if im.IsItemHovered() then im.SetTooltip("Disables parts of the vehicle colliding with itself, may help with instabilities and vehicles breaking/deforming on spawn") end
            im.EndDisabled()
            im.NextColumn()
            im.Columns(1)
        else
            if im.IsItemHovered() then im.SetTooltip("Show advanced options for more fine grained control") end
        end

        if im.CollapsingHeader1("Randomizer settings") then
            im.PushItemWidth(100)
            im.Checkbox("Randomize scale", uiRandomizer.scaleEnabled)
            if im.IsItemHovered() then im.SetTooltip("Set if the overall vehicle size should be randomized") end
            im.BeginDisabled(not uiRandomizer.scaleEnabled[0])
            im.DragFloat("##1", uiRandomizer.scaleMin, 0.01, 0.1, max(uiRandomizer.scaleMax[0], 0.1+1e-6), "Min: %.2f")
            im.SameLine()
            im.DragFloat("Vehicle Scale##2", uiRandomizer.scaleMax, 0.01, min(uiRandomizer.scaleMin[0], 10-1e-6), 10, "Max: %.2f")
            im.EndDisabled()
            im.Separator()
            im.Checkbox("Randomize multipliers", uiRandomizer.multipliersEnabled)
            if im.IsItemHovered() then im.SetTooltip("Set if the additional multipliers should be randomized") end
            im.BeginDisabled(not uiRandomizer.multipliersEnabled[0])
            im.DragFloat("##2", uiRandomizer.weightMultiplierMin, 0.01, 0.01, max(uiRandomizer.weightMultiplierMax[0], 0.01+1e-6), "Min: %.2f")
            im.SameLine()
            im.DragFloat("Weight", uiRandomizer.weightMultiplierMax, 0.01, min(uiRandomizer.weightMultiplierMin[0], 10-1e-6), 10, "Max: %.2f")
            im.DragFloat("##3", uiRandomizer.stiffnessMultiplierMin, 0.01, 0.01, max(uiRandomizer.stiffnessMultiplierMax[0], 0.01+1e-6), "Min: %.2f")
            im.SameLine()
            im.DragFloat("Stiffness", uiRandomizer.stiffnessMultiplierMax, 0.01, min(uiRandomizer.stiffnessMultiplierMin[0], 1-1e-6), 1, "Max: %.2f")
            im.DragFloat("##4", uiRandomizer.strengthMultiplierMin, 0.01, 0.01, max(uiRandomizer.strengthMultiplierMax[0], 0.01+1e-6), "Min: %.2f")
            im.SameLine()
            im.DragFloat("Strength", uiRandomizer.strengthMultiplierMax, 0.01, min(uiRandomizer.strengthMultiplierMin[0], 10-1e-6), 10, "Max: %.2f")
            im.DragFloat("##5", uiRandomizer.powerMultiplierMin, 0.01, 0, max(uiRandomizer.powerMultiplierMax[0], 0.01+1e-6), "Min: %.2f")
            im.SameLine()
            im.DragFloat("Engine Power", uiRandomizer.powerMultiplierMax, 0.01, min(uiRandomizer.powerMultiplierMin[0], 10-1e-6), 10, "Max: %.2f")
            im.DragFloat("##6", uiRandomizer.gearRatioMultiplierMin, 0.01, 0.01, max(uiRandomizer.gearRatioMultiplierMax[0], 0.01+1e-6), "Min: %.2f")
            im.SameLine()
            im.DragFloat("Gear Ratio", uiRandomizer.gearRatioMultiplierMax, 0.01, min(uiRandomizer.gearRatioMultiplierMin[0], 10-1e-6), 10, "Max: %.2f")
            im.DragFloat("##7", uiRandomizer.aeroMultiplierMin, 0.01, 0, max(uiRandomizer.aeroMultiplierMax[0], 0.01+1e-6), "Min: %.2f")
            im.SameLine()
            im.DragFloat("Drag/Lift", uiRandomizer.aeroMultiplierMax, 0.01, min(uiRandomizer.aeroMultiplierMin[0], 10-1e-6), 10, "Max: %.2f")
            im.EndDisabled()
            im.PopItemWidth()
            im.Separator()
            im.Checkbox("Auto apply", uiRandomizer.autoApply)
            if im.IsItemHovered() then im.SetTooltip("Set if the randomized values should be applied automatically after clicking the Randomize button") end
            im.PushStyleColor2(im.Col_Button, im.ImVec4(0.8,0,0,0.1))
            if im.Button("Reset randomizer settings") then
                resetRandomizerSettings()
            end
            if im.IsItemHovered() then im.SetTooltip("Resets the minimum and maximum values of the randomizer") end
            im.PopStyleColor()
        else
            if im.IsItemHovered() then im.SetTooltip("Show settings for adjusting minimum and maximum values of the randomizer") end
        end

        im.Separator()
        im.PushFont3("cairo_regular_medium")
        im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(16, 0))
        im.PushStyleColor2(im.Col_Button, im.ImVec4(0,0,0.8,0.1))
        if im.Button("Randomize") then
            randomizeUIValues()
        end
        im.PopStyleColor()
        im.PopStyleVar()
        im.PopFont()
        if im.IsItemHovered() then im.SetTooltip("Randomizes scale values") end
        im.SameLine(180)
        im.PushFont3("cairo_regular_medium")
        im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(16, 0))
        im.PushStyleColor2(im.Col_Button, im.ImVec4(0.8,0,0,0.1))
        if im.Button("Reset") then
            resetScaling()
        end
        im.PopStyleColor()
        im.PopStyleVar()
        im.PopFont()
        if im.IsItemHovered() then im.SetTooltip("Resets the vehicle scale") end
        im.SameLine(0,8)
        im.PushFont3("cairo_regular_medium")
        im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(16, 0))
        im.PushStyleColor2(im.Col_Button, im.ImVec4(0,0.8,0,0.1))
        if im.Button("Apply") then
            applyUIValues()
        end
        im.PopStyleColor()
        im.PopStyleVar()
        im.PopFont()
        if im.IsItemHovered() then im.SetTooltip("Apply changed values to the vehicle") end

        im.PopStyleVar(2)
        im.End()
    end
end

local function onVehicleSwitched()
    if windowOpen[0] then
        updateUIValues()
    end
end

local function openGui()
    updateUIValues()
    windowOpen = im.BoolPtr(true)
end

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onPreRender = onPreRender
M.onVehicleSwitched = onVehicleSwitched
M.openGui = openGui

return M