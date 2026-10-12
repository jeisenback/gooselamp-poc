class_name Groups
## Group names, so a typo is a compile error and the hygiene test can check them.
const HITTABLE := "hittable" # anything the swing lands on
const BOUNCY := "bouncy"     # hittables the swing rebounds from: pogo in gravity, ricochet in zero-g (enemies, hazards)
const ENEMY := "enemy"
const SPAWNER := "spawner"   # Spawner markers; respawn_all spawns on every one
const PLAYER := "player"
