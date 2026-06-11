-- Estado puro de una sesion de medicion. No registra eventos ni depende de APIs ESO.
EZOMetter.MeterSession = EZOMetter.MeterSession or {}

local MeterSession = EZOMetter.MeterSession

local function NumberOrZero(value)
    value = tonumber(value)
    if value == nil or value < 0 then
        return 0
    end
    return value
end

local function NewState()
    return {
        active = false,
        startedAtMs = 0,
        endedAtMs = 0,
        damageDone = 0,
        healingDone = 0,
    }
end

MeterSession.state = MeterSession.state or NewState()

function MeterSession.Reset()
    MeterSession.state = NewState()
    return MeterSession.state
end

function MeterSession.Start(nowMs)
    local state = MeterSession.Reset()
    state.active = true
    state.startedAtMs = NumberOrZero(nowMs)
    state.endedAtMs = state.startedAtMs
    return state
end

function MeterSession.Stop(nowMs)
    local state = MeterSession.state or MeterSession.Reset()
    state.active = false
    state.endedAtMs = NumberOrZero(nowMs)
    if state.endedAtMs < state.startedAtMs then
        state.endedAtMs = state.startedAtMs
    end
    return state
end

function MeterSession.AddDamage(value)
    local state = MeterSession.state or MeterSession.Reset()
    state.damageDone = state.damageDone + NumberOrZero(value)
    return state.damageDone
end

function MeterSession.AddHealing(value)
    local state = MeterSession.state or MeterSession.Reset()
    state.healingDone = state.healingDone + NumberOrZero(value)
    return state.healingDone
end

function MeterSession.GetDurationSeconds(nowMs)
    local state = MeterSession.state or MeterSession.Reset()
    local endMs = state.active and NumberOrZero(nowMs) or state.endedAtMs
    if endMs < state.startedAtMs then
        endMs = state.startedAtMs
    end
    return (endMs - state.startedAtMs) / 1000
end

function MeterSession.GetSnapshot(nowMs)
    local state = MeterSession.state or MeterSession.Reset()
    local durationSeconds = MeterSession.GetDurationSeconds(nowMs)
    local dps = 0
    local hps = 0

    if durationSeconds > 0 then
        dps = state.damageDone / durationSeconds
        hps = state.healingDone / durationSeconds
    end

    return {
        active = state.active,
        durationSeconds = durationSeconds,
        damageDone = state.damageDone,
        healingDone = state.healingDone,
        dps = dps,
        hps = hps,
    }
end
