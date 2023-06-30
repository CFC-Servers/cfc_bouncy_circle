resource.AddFile( "models/cfc_trampoline/trampoline.mdl" )

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

-- this is so we get slightly above the trampoline
-- because the GetPos returns a position near the ground, we get
-- the point [self:GetUp()] * [HEIGHT_TO_BOUNCY_SURFACE] from it
local HEIGHT_TO_BOUNCY_SURFACE = 31

local MINIMUM_BOUNCE_SPEED = 320

-- maximum radius the trampoline will allow
-- this is used in DistToSqr
local MAXIMUM_RADIUS = 1900

local function isBouncyPart( position, trampoline )
    if not IsValid( trampoline ) then return end

    local trampolinePos = trampoline:GetPos()
    local trampolineUp = trampoline:GetUp()
    local bouncyOrigin = trampolinePos + trampolineUp * HEIGHT_TO_BOUNCY_SURFACE

    if position:DistToSqr( bouncyOrigin ) > MAXIMUM_RADIUS then return false end -- Too far from center of the bouncy part

    local bouncyToPos = ( position - bouncyOrigin ):GetNormalized()

    if bouncyToPos:Dot( trampolineUp ) <= 0 then return false end -- Hitting from below

    return true
end

function ENT:PhysicsCollide( colData, selfPhys )
    local ent = colData.HitEntity
    if not IsValid( ent ) then return end

    local isPlayer = ent:IsPlayer()

    -- if this entity is a player, and the ground entity is us
    -- then we use their GetPos()
    -- otherwise, we use colData.HitPos
    local pos = isPlayer and ent:GetGroundEntity() == self and ent:GetPos() or colData.HitPos

    local shouldBounce = isBouncyPart( pos, self )

    if not shouldBounce then return end

    local isUnfrozen = selfPhys:IsMotionEnabled()

    local collidingVelocity = math.max( colData.TheirOldVelocity:Length(), MINIMUM_BOUNCE_SPEED )

    local up = self:GetUp()
    local velocity = up * collidingVelocity
    if isPlayer then
        local isHoldingJump = ent:KeyDown( IN_JUMP )

        if isUnfrozen then
            -- hacky solution to bounce players when the trampoline is unfrozen
            local phys = ent:GetPhysicsObject()
            if IsValid( phys ) then
                phys:SetPos( phys:GetPos() + up * 5 )
            end

        end
        local vel = velocity * ( isHoldingJump and 1.2 or 0.8 )

        ent:SetVelocity( vel )
    elseif not ent:IsNPC() then
        local phys = ent:GetPhysicsObject()
        if not IsValid( phys ) then return end

        phys:ApplyForceCenter( velocity * phys:GetMass() )
    end

    if isUnfrozen then
        selfPhys:ApplyForceCenter( -velocity * 0.4 * selfPhys:GetMass() )
    end
end

function ENT:Initialize()
    self:SetModel( "models/cfc_trampoline/trampoline.mdl" )
    self:SetTrigger( true )

    self:SetColor( Color( 200, 255, 200 ) )

    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )

    self:PhysicsInit( SOLID_VPHYSICS )

    self:PhysWake()
    local phys = self:GetPhysicsObject()

    if not IsValid( phys ) then return end
    phys:SetMass( 250 )
end

local world = game.GetWorld()
hook.Add( "GetFallDamage", "Trampoline_FallDamage", function( ply )
    local groundEnt = ply:GetGroundEntity()
    if not groundEnt then return end
    if groundEnt == world then return end

    if not groundEnt.IsTrampoline then return end

    local isBouncy = isBouncyPart( ply:GetPos(), groundEnt )
    if not isBouncy then return end

    return 0
end )
