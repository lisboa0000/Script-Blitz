local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")

cRP = {}
Tunnel.bindInterface("lisboa_blitz", cRP)
vSERVER = Tunnel.getInterface("lisboa_blitz")

local open = false
local colocando = false
local previewObject = nil
local currentObjHash = nil
local currentObjName = ""
local currentType = ""

local objCoords = { x = 0.0, y = 0.0, z = 0.0, h = 0.0 }

local props = {
    ["cone"] = "prop_mp_cone_02",
    ["cone2"] = "prop_barrier_wat_03a",
    ["cone3"] = "prop_mp_cone_04",
    ["barricada"] = "prop_mp_barrier_02b",
    ["barricadab"] = "prop_mp_barrier_01",
    ["barricadac"] = "prop_mp_conc_barrier_01",
    ["barricadas"] = "prop_mp_arrow_barrier_01",
    ["spike"] = "p_ld_stinger_s"
}

function closeBlitz()
    open = false
    colocando = false
    deletePreview()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'fecharBlitz' })
    SendNUIMessage({ type = 'fecharInfo' })
end

function deletePreview()
    if previewObject then
        DeleteObject(previewObject)
        previewObject = nil
    end
end

RegisterNUICallback("ButtonClick", function(data, cb)
    if data.action == "fecharBlitz" then
        closeBlitz()
    end

    if data.action == "setObstaculo" then
        if data.nome == "d" then
            removeObstaculo(data.obstaculo)
        else
            startPlacement(data.obstaculo, data.nome)
        end
    end

    if data.action == "clearArea" then
        clearAll()
    end
end)

RegisterCommand('blitz', function()
    if vSERVER.checkPermission("policia.permissao") then
        open = true
        SetNuiFocus(true, true)
        SendNUIMessage({ type = 'abrirBlitz' })
    end
end)

function clearAll()
    local pPed = PlayerPedId()
    local pCoord = GetEntityCoords(pPed)
    
    -- Usamos um raio de 15 metros para a limpeza
    local radius = 15.0
    
    for _, model in pairs(props) do
        local hash = GetHashKey(model)
        -- Buscamos o objeto mais próximo uma vez por modelo para evitar loops infinitos
        -- Se houver muitos, o jogador pode clicar novamente ou usamos um método mais seguro
        local object = GetClosestObjectOfType(pCoord.x, pCoord.y, pCoord.z, radius, hash, false, false, false)
        
        -- Limite de segurança para evitar travar o jogo se houver centenas de objetos
        local safetyCounter = 0
        while DoesEntityExist(object) and safetyCounter < 20 do
            SetEntityAsMissionEntity(object, true, true)
            DeleteObject(object)
            
            -- Busca o próximo
            object = GetClosestObjectOfType(pCoord.x, pCoord.y, pCoord.z, radius, hash, false, false, false)
            safetyCounter = safetyCounter + 1
            Citizen.Wait(1) -- Pequena pausa para não travar a thread
        end
    end
end

function removeObstaculo(type)
    local model = props[type]
    if not model then return end
    local pPed = PlayerPedId()
    local pCoord = GetOffsetFromEntityInWorldCoords(pPed, 0.0, 1.5, 0.0)
    local hash = GetHashKey(model)
    if DoesObjectOfTypeExistAtCoords(pCoord.x, pCoord.y, pCoord.z, 2.0, hash, true) then
        local object = GetClosestObjectOfType(pCoord.x, pCoord.y, pCoord.z, 2.0, hash, false, false, false)
        SetEntityAsMissionEntity(object, true, true)
        DeleteObject(object)
    end
end

function startPlacement(type, name)
    closeBlitz()
    currentType = type
    currentObjName = name
    currentObjHash = GetHashKey(props[type])
    
    RequestModel(currentObjHash)
    while not HasModelLoaded(currentObjHash) do
        Citizen.Wait(1)
    end

    local pPed = PlayerPedId()
    local pCoord = GetOffsetFromEntityInWorldCoords(pPed, 0.0, 2.0, 0.0)
    objCoords.x, objCoords.y, objCoords.z = pCoord.x, pCoord.y, pCoord.z
    objCoords.h = GetEntityHeading(pPed)

    previewObject = CreateObject(currentObjHash, objCoords.x, objCoords.y, objCoords.z, false, false, false)
    SetEntityAlpha(previewObject, 150, false)
    SetEntityCollision(previewObject, false, false)
    SetEntityHeading(previewObject, objCoords.h)
    
    colocando = true
    SendNUIMessage({ type = 'abrirInfo', obj = name })
end

Citizen.CreateThread(function()
    while true do
        local sleep = 500
        if colocando and previewObject then
            sleep = 0
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 140, true) -- Melee
            DisableControlAction(0, 44, true) -- Q
            DisableControlAction(0, 38, true) -- E
            
            -- Ajuste de velocidade (SHIFT para ajuste fino)
            local speed = 0.02
            local rotSpeed = 2.5
            if IsControlPressed(0, 21) then -- SHIFT Esquerdo
                speed = 0.005
                rotSpeed = 0.5
            end

            -- Movimentação via Setinhas
            if IsControlPressed(0, 172) then -- Seta Cima
                objCoords.y = objCoords.y + speed
            end
            if IsControlPressed(0, 173) then -- Seta Baixo
                objCoords.y = objCoords.y - speed
            end
            if IsControlPressed(0, 174) then -- Seta Esquerda
                objCoords.x = objCoords.x - speed
            end
            if IsControlPressed(0, 175) then -- Seta Direita
                objCoords.x = objCoords.x + speed
            end

            -- Rotação via Q e E
            if IsDisabledControlPressed(0, 44) then -- Q
                objCoords.h = objCoords.h + rotSpeed
            end
            if IsDisabledControlPressed(0, 38) then -- E
                objCoords.h = objCoords.h - rotSpeed
            end

            -- Ajuste de Altura via PageUp/PageDown
            if IsControlPressed(0, 10) then -- PageUp
                objCoords.z = objCoords.z + 0.01
            end
            if IsControlPressed(0, 11) then -- PageDown
                objCoords.z = objCoords.z - 0.01
            end

            SetEntityCoords(previewObject, objCoords.x, objCoords.y, objCoords.z)
            SetEntityHeading(previewObject, objCoords.h)
            PlaceObjectOnGroundProperly(previewObject)

            -- Confirmar (Enter)
            if IsControlJustPressed(0, 191) then
                local finalObj = CreateObject(currentObjHash, objCoords.x, objCoords.y, objCoords.z, true, true, true)
                
                -- GARANTIR PERSISTÊNCIA:
                SetEntityAsMissionEntity(finalObj, true, true) -- Marca como entidade de missão (não some)
                SetEntityAsMissionEntity(finalObj, true, true) -- Reforço
                SetModelAsNoLongerNeeded(currentObjHash) -- Libera o modelo da memória, mas mantém o objeto
                
                SetEntityHeading(finalObj, objCoords.h)
                PlaceObjectOnGroundProperly(finalObj)
                FreezeEntityPosition(finalObj, true)
                
                -- ALINHAMENTO INTELIGENTE:
                -- Ao colocar, movemos o preview levemente para o lado baseado na rotação atual
                -- Isso permite colocar vários em linha reta apenas apertando Enter
                local forwardX = math.sin(math.rad(-objCoords.h))
                local forwardY = math.cos(math.rad(-objCoords.h))
                
                -- Deslocamento lateral (para a direita do objeto)
                local sideX = math.cos(math.rad(-objCoords.h))
                local sideY = -math.sin(math.rad(-objCoords.h))
                
                -- Ajustamos a posição para o próximo objeto (ex: 1.2 metros para o lado)
                objCoords.x = objCoords.x + (sideX * 1.2)
                objCoords.y = objCoords.y + (sideY * 1.2)
            end

            -- Voltar para o Menu (F)
            if IsControlJustPressed(0, 23) then
                deletePreview()
                colocando = false
                SendNUIMessage({ type = 'fecharInfo' })
                
                open = true
                SetNuiFocus(true, true)
                SendNUIMessage({ type = 'abrirBlitz' })
            end

            -- Cancelar (Backspace ou ESC)
            if IsControlJustPressed(0, 177) then
                closeBlitz()
            end
        end
        Citizen.Wait(sleep)
    end
end)

-- Lógica do Spike
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        local pPed = PlayerPedId()
        if IsPedInAnyVehicle(pPed, false) then
            local veh = GetVehiclePedIsIn(pPed, false)
            local vCoord = GetEntityCoords(veh)
            local hash = GetHashKey("p_ld_stinger_s")
            
            if DoesObjectOfTypeExistAtCoords(vCoord.x, vCoord.y, vCoord.z, 1.5, hash, true) then
                for i = 0, 7 do
                    SetVehicleTyreBurst(veh, i, true, 1000.0)
                end
                
                -- REMOVIDO: Deleção automática do spike. 
                -- Agora ele permanece no chão até ser removido manualmente.
            end
        end
    end
end)
