resource.AddFile( "models/cfc/trampoline.mdl" )
resource.AddFile( "materials/models/cfc/trampoline.vmt" )

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

-- this is so we get slightly above the trampoline
-- because the GetPos returns a position near the ground, we get
-- the point [self:GetUp()] * [HEIGHT_TO_BOUNCY_SURFACE] from it
local HEIGHT_TO_BOUNCY_SURFACE = 34.5

-- maximum radius the trampoline will allow
-- this is used in DistToSqr
local MAXIMUM_RADIUS = 48 ^ 2

local IsValid = IsValid
local function isBouncyPart( position, trampoline )
    if not IsValid( trampoline ) then return end

    local trampolinePos = trampoline:GetPos()
    local trampolineUp = trampoline:GetUp()
    local bouncyOrigin = trampolinePos + trampolineUp * HEIGHT_TO_BOUNCY_SURFACE

    local dist = position:DistToSqr( bouncyOrigin )
    if dist > MAXIMUM_RADIUS then return false end -- Too far from center of the bouncy part

    local bouncyToPos = ( position - bouncyOrigin ):GetNormalized()

    local dot = bouncyToPos:Dot( trampolineUp )
    if dot <= 0 then return false end -- Hitting from below

    return true
end

local MIN_SPEED = CreateConVar( "cfc_trampoline_min_speed", 320, FCVAR_NONE, "Minimum required speed for a player to get bounced", 0, 50000 )
local BOUNCE_MULT = CreateConVar( "cfc_trampoline_bounce_mult", 0.8, FCVAR_NONE, "How much a player will be bounced up relative to their falling velocity", 0, 50000 )
local BOUNCE_MULT_JUMPING = CreateConVar( "cfc_trampoline_bounce_mult_jumping", 1.2, FCVAR_NONE, "How much a player will be bounced up relative to their falling velocity while holding their jump button", 0, 50000 )
local BOUNCE_MAX = CreateConVar( "cfc_trampoline_bounce_max", 1500, FCVAR_NONE, "Maximum resulting speed of a bounce", 0, 50000 )
local BOUNCE_RECOIL = CreateConVar( "cfc_trampoline_bounce_mult_recoil", 0.4, FCVAR_NONE, "The force multiplier applied in the opposite direction when bouncing on an unfrozen trampoline", 0, 50000 )

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
    local up = self:GetUp()
    local entVelocity = colData.TheirOldVelocity
    local collidingSpeed = math.max( entVelocity:Length(), MIN_SPEED:GetFloat() )
    local appliedVelocity = vector_origin
    local otherEntPhys = ent:GetPhysicsObject()
    if not IsValid( otherEntPhys ) then return end

    local otherEntMass = otherEntPhys:GetMass()

    if isPlayer then
        local isHoldingJump = ent:KeyDown( IN_JUMP )

        local bounceMult = isHoldingJump and BOUNCE_MULT_JUMPING:GetFloat() or BOUNCE_MULT:GetFloat()
        local bounceSpeed = math.min( collidingSpeed * bounceMult, BOUNCE_MAX:GetFloat() )

        if isUnfrozen then
            -- hacky solution to bounce players when the trampoline is unfrozen
            otherEntPhys:SetPos( otherEntPhys:GetPos() + up * 5 )
        end

        appliedVelocity = up * bounceSpeed

        ent:SetVelocity( appliedVelocity )
    elseif not ent:IsNPC() then
        local bounceSpeed = math.min( collidingSpeed, BOUNCE_MAX:GetFloat() )
        appliedVelocity = up * bounceSpeed

        otherEntPhys:ApplyForceCenter( appliedVelocity * otherEntMass )
    end

    if isUnfrozen then
        selfPhys:ApplyForceCenter( -appliedVelocity * BOUNCE_RECOIL:GetFloat() * otherEntMass )
    end
end

function ENT:Initialize()
    self:SetModel( "models/cfc/trampoline.mdl" )
    self:SetTrigger( true )

    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:PhysicsInit( SOLID_VPHYSICS )

    self:PhysWake()
    local phys = self:GetPhysicsObject()

    if not phys:IsValid() then return end
    phys:SetMass( 250 )
end

local world = game.GetWorld()
hook.Add( "GetFallDamage", "Trampoline_FallDamage", function( ply )
    if not IsValid( ply ) then return end

    local groundEnt = ply:GetGroundEntity()
    if not groundEnt then return end
    if groundEnt == world then return end

    if not groundEnt.IsTrampoline then return end

    local isBouncy = isBouncyPart( ply:GetPos(), groundEnt )
    if not isBouncy then return end

    return 0
end )
