
let CBCProjectileBurst = Java.loadClass("rbasamoyai.createbigcannons.munitions.fragment_burst.CBCProjectileBurst");
let Vec3 = Java.loadClass("net.minecraft.world.phys.Vec3");
let CBCModernWarfareEntityTypes = Java.loadClass("riftyboi.cbcmodernwarfare.index.CBCModernWarfareEntityTypes");

const spalling_projectiles = [
    "cbcmodernwarfare:apds_shot",
    "cbcmodernwarfare:apfsds_mediumshell"
]

let shrapnel_spread = 2.0
let shrapnel_count = 10

let CANNON_BURST = CBCModernWarfareEntityTypes.CANISTER_BURST.get()

function spalling(shell) {
    let level = shell.level
    let pos = shell.position()
    let oldDelta = shell.orientation.scale(2.0)

    //spawnConeBurst(level, EntityType, Vec3, Vec3, int, double)
    CBCProjectileBurst.spawnConeBurst(level, CANNON_BURST, pos, oldDelta, shrapnel_count, shrapnel_spread)
}

let spalledEntites = new Map()

ServerEvents.tick(event => {
    let server = event.server
    let level = server.overworld()

    if (level.time % 3 !== 0) return // every 3 ticks

    let cannonProjectiles = level.entities.filter(entity => 
        spalling_projectiles.includes(entity.type)
    )

    cannonProjectiles.forEach(shell => {
        let uuid = shell.uuid

        let canSpall = (!spalledEntites[uuid]) && (shell.isInGround())

        if (canSpall) {
            spalledEntites[uuid] = true

            spalling(shell)
        }

    })
})