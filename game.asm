#####################################################################
#
# CSCB58 Winter 2021 Assembly Final Project
# University of Toronto, Scarborough
#
# Student: Kyle Lewis, 1006113215, lewisky2
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8 (update this as needed)
# - Unit height in pixels: 8 (update this as needed)
# - Display width in pixels: 256 (update this as needed)
# - Display height in pixels: 256 (update this as needed)
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 4 (choose the one the applies)
#
# Which approved features have been implemented for milestone 4?
# (See the assignment handout for the list of additional features)
# 1. b. Increase in difficulty as game progresses.
# 2. c. Scoring system: add a score to the game based on survival time, near misses, or any idea you may have
# 3. Add “pick-ups” that the ship can pick up
# ... (add more if necessary)
#
# Link to video demonstration for final submission:
# - https://play.library.utoronto.ca/07f0a9cdb6cae0766941b9f92b20932a  Make sure we can view it!
#
# Are you OK with us sharing the video with people outside course staff?
# yes, (need an email/user name to send gitHub page to because directory is private)
#
# Any additional information that the TA needs to know:
# - (write here, if any)
# I only started uploading to gitHub when i was mostly done the assignment
#####################################################################


# Bitmap display starter code
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
.eqv BASE_ADDRESS 0x10008000
.eqv rightEdge 128
.eqv rowSize 128
.eqv maxPix 4092
.eqv randPixCap 1023
.eqv w 119
.eqv a 97
.eqv s 115
.eqv d 100
.eqv p 112
.eqv pickupSpawnOdds 1000 #pickups have a 1/pickupSpawnOdds chance of spawning every tick
.eqv updateRate 40
.eqv maxSpeed 2
.eqv maxAst 5
.eqv startSpeed 1
.eqv startAstNum 1
.data
#variable data for colours
Yellow: .word 0xffff00
Blue: .word 0x0000ff
Green: .word 0x00ff00
Grey: .word 0x808080
Brown: .word 0x492623
Red: .word 0xff0000
Black: .word 0x000000
White: .word 0xffffff
Magenta: .word 0xa20067
Cyan: .word 0x2aebef
#variable for position of ship on screen
shipPos: .word  2064
#variable for number of asteroids on screen
asteroidNum: .word  1
asteroidPos: .word 248:5
#variable for speed of asteroids
asteroidSpeeds: .word 1:5
#variable for speed cap
speedCap: .word 1
shipHealth: .word 3
#score?
size: .word 3096
Score: .word 0:5

hit: .word 0

HealthPickupPos: .word -1
ScorePickupPos: .word -1

.text
.globl main
main:

init:	
	#reset important positions, variables
	li $a0, -1
	sw $a0, HealthPickupPos
	sw $a0, ScorePickupPos
	li $t0, startSpeed
	sw $t0, speedCap
	li $t0, startAstNum
	sw $t0, asteroidNum
	li $s1, rightEdge
	li $s0, BASE_ADDRESS # $t0 stores the base address for display
	
	
	#resetting hit detection
	li $t0, 0
	sw $t0, hit
	
	li $s2, 0 #register for number of ticks passed
	#resettting other vaiables
	jal resetShip 
	jal resetHealth
	jal resetScore
	jal fullClear
	jal resetAsteroids
	
	
	#enter main loop for screen
loop:
	#intended order:
	#erase
	#check for input
	#update positions
	#check for collisions
	#update game state
	#redraw
	
	addi $s2, $s2, 1 #one tick has passed	
clear:
	#erase all screen entities (not full screen)
	jal ClearScreen	
	
	

checkInput:
	#check to see if key was pressed
	li $t9, 0xffff0000
	lw $t8, 0($t9)
	beq $t8, 0, noKeyPress
keyPress:
	#do in a function instead
	#check for inputs
	lw $a0, shipPos
	lw $a1, 4($t9) # this assumes $t9 is set to 0xfff0000 from before
	
	beq $a1, p, init
	
	jal updateShip
	
noKeyPress:

	#depending, update position of ship or game
	
	
	#go through each entry in Asteroid array
	#update then draw asteroid
	
	lw $t0, asteroidNum
	addi $t0, $t0, -1
	
aLoop:  bltz $t0, exitAst
	#mult i by 4 to get offset in Asteroid array
	li $t3, 4
	mult $t0, $t3
	mflo $t2
	
	move $a0, $t2
	jal updateAsteroid
	
	#check to see if updated asteroid collided with ship
	
	la $t1, asteroidPos
	#get AsteroidPos[i] and load it as argument
	add $t1, $t2, $t1
	lw $a0, 0($t1)
	jal checkCollision
	beqz $v0, noCollision
	jal resetShip
	lw $t9, shipHealth
	addi $t9, $t9, -1
	sw $t9, shipHealth
	
	jal fullClear
	jal resetAsteroids
	
	li $t3, 1
	sw $t3, hit
	
noCollision:	
	lw $a0, 0($t1)
	#move asteroid first
	
	#draw asteroid
	jal drawAsteroid
	addi $t0, $t0, -1
	
	j aLoop

exitAst:
	
	#check if ship has collided with any asteroids
checkPickups:
	jal HealthPickupCollision
	jal ScorePickupCollision
	
	#try to spawn pickups
checkPickupSpawns:
	jal spawnPickups
	
	#draw pickups (function itself covers whether or not they have spawned)
drawPickups:
	jal drawPickupHealth
	jal drawPickupScore
	
	#manage health of ship
manageHealth:
	lw $a0, shipHealth
	blez $a0, gameOver
	jal drawHealth
	
	#draw ship
	lw $a0, shipPos
	jal drawShip
	jal drawHit

#check to see if difficulty should be increased
checkDifficulty:
	#if 10 seconds have passed (10,000 ms)
	li $t8, 10000
	li $t7, updateRate
	mult $s2, $t7
	mflo $t7
	ble $t7, $t8, endIncrease

#increase difficulty by spawning more asteroids / increasing potential speed
increaseDifficulty:
	li $s2, 0
	lw $t8, speedCap
	lw $t9, asteroidNum
	li $t7, maxSpeed
	#if both have hit their max do nothing
	bge $t8, $t7, endIncreaseSpeed	 	
	addi $t8, $t8, 1
	sw $t8, speedCap
endIncreaseSpeed:
	li $t7, maxAst
	bge $t9, $t7, endIncrease
	addi $t9, $t9, 1
	sw $t9, asteroidNum
endIncrease:

#increase score
increaseScore:
	la $a0, Score
	lw $a1, 16($a0)
	addi $a1, $a1, 1
	sw $a1, 16($a0)
	jal updateScore
	
sleep:	li $a0, updateRate	
	li $v0, 32 
	syscall
	j loop

gameOver:
	#fully clear screen and draw game over screen
	jal ClearScreen
	jal drawGameOver
	
displayScore:
	jal drawScore
	
gameOverLoop:
	#while p isn't pressed do nothing
	li $t9, 0xffff0000
	lw $t8, 0($t9)
	beq $t8, 0, noGOKeyPress
GOkeyPress:
	#do in a function instead
	#check for inputs
	lw $a1, 4($t9) # this assumes $t9 is set to 0xfff0000 from before
	
	beq $a1, p, init
	
noGOKeyPress:
	j gameOverLoop	

##--------Functions below this line-----------##

#--functions related to functionality of the ship--#

#function responsible for updating the position of the ship, a0 = ship pos, a1 = key pressed
updateShip:
	beq $a1, w, respond_to_w # ASCII code of 'a' is 0x61 or 97 in decimal
	beq $a1, a, respond_to_a
	beq $a1, s, respond_to_s
	beq $a1, d, respond_to_d

	j endShipUpdate

respond_to_w:
	#set new position of ship
	addi $a2, $a0, -128
	#if ship not outside of range of screen update
	li $a1, 128
	ble $a2, $a1, endShipUpdate
	la $a0, shipPos
	sw $a2, 0($a0)
	j endShipUpdate

respond_to_a:
	addi $a2, $a0, -4
	#if ship not outside of range of screen update
	li $a1, rightEdge
	div $a2, $a1
	mfhi $a1
	blez $a1, endShipUpdate
	la $a0, shipPos
	sw $a2, 0($a0)
	j endShipUpdate

respond_to_s:
	addi $a2, $a0, 128
	li $a1, maxPix
	subi $a1, $a1, 128
	bge $a2, $a1, endShipUpdate
	la $a0, shipPos
	sw $a2, 0($a0)
	j endShipUpdate
	
respond_to_d:
	addi $a2, $a0, 4
	li $a1, rightEdge
	#if ship not aligned with right edge
	div $a2, $a1
	mfhi $a1
	li $v1, 124
	bge $a1, $v1, endShipUpdate
	la $a0, shipPos
	sw $a2, 0($a0)
	j endShipUpdate
	
endShipUpdate:
	jr $ra

#function resets ship to default position
resetShip:
	li $a0, 2064
	sw $a0, shipPos
	jr $ra

#function responsible for drawing the ship, a0 = ship pos
drawShip:
	
	add $a0, $a0, $s0
	lw $a1, Blue
	sw $a1, 0($a0) # paint the first (top-left) unit red.
	sw $a1, 4($a0)
	lw $a1, Yellow
	sw $a1, -128($a0) # paint the second unit on the first row green. Why $t0+4?
	sw $a1, 128($a0) # paint the first unit on the second row blue. Why +128?
	sw $a1, -132($a0)
	sw $a1, 124($a0)
	jr $ra

#function responsivle for drawing the ship being hit
drawHit:
	lw $a0, hit
	beqz $a0 endDrawHit
	lw $a0, shipPos
	lw $a1, Red
	
	add $a0, $a0, $s0
	
	sw $a1, 0($a0)
	sw $a1, 132($a0)
	sw $a1, 124($a0)
	sw $a1, -132($a0)
	sw $a1, -124($a0)
	
	li $a0, 0
	sw $a0, hit
endDrawHit:	
	jr $ra

#function responsible for clearing the ship being hit
clearHit:
	lw $a0, shipPos
	lw $a1, Black
	
	add $a0, $a0, $s0
	
	sw $a1, 0($a0)
	sw $a1, 132($a0)
	sw $a1, 124($a0)
	sw $a1, -132($a0)
	sw $a1, -124($a0)
	
	jr $ra

#Function responsible for clearing ship from screen, a0 = shipPos
clearShip:
	add $a0, $a0, $s0
	lw $v1, Black
	sw $v1, 0($a0) # paint the first (top-left) unit red.
	sw $v1, 4($a0)
	sw $v1, -128($a0) # paint the second unit on the first row green. Why $t0+4?
	sw $v1, 128($a0) # paint the first unit on the second row blue. Why +128?
	sw $v1, -132($a0)
	sw $v1, 124($a0)
	jr $ra
	

#---functions related to functionality of Asteroids---#

#initaties and asteroid, a0 = asteroidPos[i] a1 = asteroidSpeeds[i]
initAst:
	addi $sp, $sp, -4
	sw $a1, 0($sp)
	addi $sp, $sp, -4
	sw $a0, 0($sp)
	
	#get random number between 0 and 32
	li $a0, 0
	li $a1, 32
	li $v0, 42
	syscall
	#multiply by rightEdge so right edge aligned
	mult $a0, $s1
	mflo $a0
	#offset by 8 to get asteroid fully on screen
	addi $a0, $a0, -8
	#pop arg off stack
	lw $v1, 0($sp)
	addi $sp, $sp, 4
	
	#save new position of asteroid to memory
	sw $a0, 0($v1)
	move $a2, $a0
	#get random number between 0 and speedcap
	li $a0, 0
	lw $a1, speedCap
	syscall
	
	move $v0, $a2
	#add 1 to speed cap (prevent speeds of 0)
	addi $a0, $a0, 1 
	
	lw $v1, 0($sp)
	addi $sp, $sp, 4
	
	
	sw $a0, 0($v1)
	
	
	#return to caller
	jr $ra

#function responsible for updating the position of an asteroid where a0 = asteroidPos[i]	
updateAsteroid:
	#a0 = offset to arrays
	#load array for asteroid speeds and positions
	la $a1, asteroidSpeeds
	la $a2, asteroidPos
	#add offset to arrays (given by a0)
	add $a1, $a1, $a0
	add $a2, $a2, $a0
	#load speed of current asteroid
	lw $a0, 0($a1)
	li $v1, 4
	mult $a0, $v1
	mflo $a0
	#load position of current asteroid
	lw $v0, 0($a2)
	#update position by subtracting speed
	sub $v0, $v0, $a0
	
	addi $sp, $sp, -4
	sw $v0, 0($sp)
	
	#get y coord of new position by dividing by row size
	#add offset of -4 to prevent screen wrap
	addi $v0, $v0, -4
	li $v1, rowSize
	div $v0, $v1
	mflo $v1
	
	#save said y coordinate
	addi $sp, $sp, -4
	sw $v1, 0($sp)
	
	#get y coordinate of current position
	lw $v0, 0($a2)
	#add offset of -4 to prevent screen wraping
	addi $v0, $v0, -4
	li $v1, rowSize
	div $v0, $v1
	mflo $v1
	
	#get back y coordinate of new position
	lw $a0, 0($sp)
	addi $sp, $sp, 4
	
	#get back former new position
	lw $v0, 0($sp)
	addi $sp, $sp, 4
	
	#if y coord of new position is equal to that of y positon then wrap around hasnt occured
	beq $a0, $v1, endUpdate
resetA:	
	#store old return address
	addi $sp, $sp, -4
	sw $ra 0($sp)
	#store address of asteroid position and old ra
	addi $sp, $sp -4
	sw $a2, 0($sp)
	
	move $a0, $a2
	
	jal initAst
	
	#pop a2 and ra from stack
	lw $a2, 0($sp)
	addi $sp, $sp, 4
	
	lw $ra 0($sp)
	addi $sp, $sp, 4 
	
endUpdate:	
	sw $v0, 0($a2)
	jr $ra

#function responsible for checking if asteroid collided with ship, a0 = position of asteroid
checkCollision:
	#if position - 256 , position + 256, position -8 or position + 8 = ship, mark collision
	lw $a1, shipPos
	#check if in range on x axis (remainder of deivind by 128)
	li $a2, rightEdge
	#save ship's x in v1
	div $a1, $a2
	mfhi $v1
	div $a0, $a2
	mfhi $a2
	#save asteroid's x in $a2
	sub $a2, $v1, $a2 #find ship[x] - asteroid[x]
	abs $a2, $a2
	li $v1, 8
	bgt $a2, $v1, noCollision
	#do the same thing with y axis
	
	lw $a1, shipPos
	#check if in range on x axis (remainder of deivind by 128)
	li $a2, rightEdge
	#save ship's x in v1
	div $a1, $a2
	mflo $v1
	div $a0, $a2
	mflo $a2
	#save asteroid's x in $a2
	sub $a2, $v1, $a2 #find ship[y] - asteroid[y]
	abs $a2, $a2
	li $v1, 2
	bgt $a2, $v1, noCollision
	j Collision
	
noCollsion:
	li $v0, 0
	jr $ra
Collision:
	li $v0, 1
	jr $ra
	
#function used to reset Asteroid Positions
resetAsteroids:
	addi $sp, $sp, -4
	sw $ra 0($sp)
	
	lw $a0, asteroidNum
	addi $a0, $a0, -1
resetAstLoop:
	bltz  $a0, exitResetAsLoop
	#multiply i by 4 to get offset
	li $a1, 4
	mult $a0, $a1
	mflo $a1
	#get start of asteroid array
	la $v0, asteroidPos
	la $v1, asteroidSpeeds
	add $v0, $a1, $v0
	add $v1, $a1, $v1
	
	addi $sp, $sp, -4
	sw $a0, 0($sp)
	#move a+i to function arg
	move $a0, $v0
	move $a1, $v1
	jal initAst
	
	lw $a0, 0($sp)
	addi $sp, $sp, 4
	
	addi $a0, $a0, -1
	j resetAstLoop
	
exitResetAsLoop:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra


#function responsible for drawing the asteroid, a0 = asteroidpos[i]
drawAsteroid:
	add $a0, $a0, $s0
	
	lw $a1, Brown
	sw $a1, 0($a0)
	sw $a1, -4($a0)
	lw $a1, Grey
	sw $a1, 128($a0)
	sw $a1, 4($a0)
	sw $a1, -128($a0)	
	jr $ra

#Function responsible for clearing ship from screen, a0 = asteroid Pos
clearAsteroid:
	#a0 = positon of asteroid
	add $a0, $a0, $s0
	
	lw $v1, Black
	sw $v1, 0($a0)
	sw $v1, -4($a0)
	sw $v1, 128($a0)
	sw $v1, 4($a0)
	sw $v1, -128($a0)
	
	jr $ra


#---Functions related to pickups---#

#Managing Drawing and Clearing for HealthPickups, No Intended return values or Params
drawPickupHealth:
	lw $a0, HealthPickupPos
	blez $a0, endDrawHealthPickup
	add $a0, $a0, $s0
	lw $a1, Magenta
	sw $a1, 0($a0)

endDrawHealthPickup:
	jr $ra

clearPickupHealth:
	lw $a0, HealthPickupPos
	blez $a0, endClearHealthPickup
	add $a0, $a0, $s0
	lw $a1, Black
	sw $a1, 0($a0)

endClearHealthPickup:
	jr $ra
	
#function that sees if ship has collided with health pickup
HealthPickupCollision:
	lw $a0, shipPos
	lw $a1, HealthPickupPos
	#check if pickup has been spawned, if not end collision logic
	blez $a1, endHealthCollision
	#if pickup is within 1 on the x or y axis then it has collided with ship
	#check if collided on y axis by divining by rowsize and seeing if their difference is within 1
	li $v0, rightEdge
	div $a1, $v0
	mflo $v0
	
	li $v1, rightEdge
	div $a0, $v1
	mflo $v1
	
	sub $v0, $v1, $v0
	abs $v0, $v0
	li $v1, 1
	
	bgt $v0, $v1, endHealthCollision
	
	#check if collided on x axis by modulus by rowsize and seeing if their difference is within 4
	li $v0, rightEdge
	div $a1, $v0
	mfhi $v0
	
	li $v1, rightEdge
	div $a0, $v1
	mfhi $v1
	
	sub $v0, $v1, $v0
	abs $v0, $v0
	li $v1, 8
	ble $v0, $v1, HealthCollision
	#if neither condiitons we met, end collision logic
	j endHealthCollision
HealthCollision:
	#if collided, despawn healthpickup and reset health
	li $a0, -1
	sw $a0, HealthPickupPos
	addi $sp, $sp, -4
	sw $ra , 0($sp)
	jal resetHealth
	lw $ra, 0($sp)
	addi $sp, $sp, 4
endHealthCollision:
	jr $ra

#Managing Drawing and Clearing for Score Pickups, No Intended return values or Params
drawPickupScore:
	lw $a0, ScorePickupPos
	blez $a0, endDrawScorePickup
	add $a0, $a0, $s0
	lw $a1, Cyan
	sw $a1, 0($a0)

endDrawScorePickup:
	jr $ra

clearPickupScore:
	lw $a0, ScorePickupPos
	blez $a0, endClearScorePickup
	add $a0, $a0, $s0
	lw $a1, Black
	sw $a1, 0($a0)

endClearScorePickup:
	jr $ra

#function that sees if ship has collided with score pickup
ScorePickupCollision:
	lw $a0, shipPos
	lw $a1, ScorePickupPos
	#check if pickup has been spawned, if not end collision logic
	blez $a1, endScoreCollision
	#if pickup is within 1 on the x or y axis then it has collided with ship
	#check if collided on y axis by divining by rowsize and seeing if their difference is within 1
	li $v0, rightEdge
	div $a1, $v0
	mflo $v0
	
	li $v1, rightEdge
	div $a0, $v1
	mflo $v1
	
	sub $v0, $v1, $v0
	abs $v0, $v0
	li $v1, 1
	
	bgt $v0, $v1, endScoreCollision
	
	#check if collided on x axis by modulus by rowsize and seeing if their difference is within 8
	li $v0, rightEdge
	div $a1, $v0
	mfhi $v0
	
	li $v1, rightEdge
	div $a0, $v1
	mfhi $v1
	
	sub $v0, $v1, $v0
	abs $v0, $v0
	li $v1, 8
	ble $v0, $v1, ScoreCollision
	#if neither condiitons we met, end collision logic
	j endScoreCollision
ScoreCollision:
	#if collided, despawn healthpickup and reset health
	li $a0, -1
	sw $a0, ScorePickupPos
	#add 100 points to the score
	la $a1, Score
	lw $a2, 8($a1)
	addi $a2, $a2, 1
	
	sw $a2, 8($a1)
	
endScoreCollision:
	jr $ra

#function responsible for spawning pickups
spawnPickups:
	#if health hasnt been spawned yet
	lw $a0, HealthPickupPos
	bgtz $a0, spawnScore
	#randomly spawn health
	li $v0, 42
	li $a0, 0
	li $a1, pickupSpawnOdds
	syscall
	#if random number != 1 then move to trying to spawn score
	li $a2, 1
	bne $a0, $a2 spawnScore
	#if hit random chance choose a random pixel on screen and set its position to that
	li $v0, 42
	li $a0, 0
	li $a1, randPixCap
	syscall
	
	li $a2, 4
	mult $a0, $a2
	mflo $a0
	
	la $a1, HealthPickupPos
	sw $a0, 0($a1)
spawnScore:
	#if score has not been spawned yet
	lw $a0, ScorePickupPos
	bgtz $a0, endSpawn
	#randomly spawn score
	li $v0, 42
	li $a0, 0
	li $a1, pickupSpawnOdds
	syscall
	#if random number != 1 then move to trying to spawn score
	li $a2, 1
	bne $a0, $a2 endSpawn
	#if hit random chance choose a random pixel on screen and set its position to that
	li $v0, 42
	li $a0, 0
	li $a1, randPixCap
	syscall
	
	li $a2, 4
	mult $a0, $a2
	mflo $a0
	
	la $a1, ScorePickupPos
	sw $a0, 0($a1)
endSpawn:
	jr $ra

#--functions keeping track of score--#

#function responisble for keeping track of score
updateScore:
	la $a0, Score
	#load last digit of score see if its over 10
checkOne:
	lw $a1, 16($a0)
	li $a2, 10
	blt $a1, $a2, endCheck
	div $a1, $a2
	mfhi $a2
	#load remainder of score / div into last digit
	sw $a2 16($a0)
	lw $a1, 12($a0)
	addi $a1, $a1, 1
	sw $a1, 12($a0)
checkTen:
	lw $a1, 12($a0)
	li $a2, 10
	blt $a1, $a2, endCheck
	div $a1, $a2
	mfhi $a2
	#load remainder of score / div into last digit
	sw $a2 12($a0)
	lw $a1, 8($a0)
	addi $a1, $a1, 1
	sw $a1, 8($a0)
checkHundred:
	lw $a1, 8($a0)
	li $a2, 10
	blt $a1, $a2, endCheck
	div $a1, $a2
	mfhi $a2
	#load remainder of score / div into last digit
	sw $a2 8($a0)
	lw $a1, 4($a0)
	addi $a1, $a1, 1
	sw $a1, 4($a0)
checkThousand:
	lw $a1, 4($a0)
	li $a2, 10
	blt $a1, $a2, endCheck
	div $a1, $a2
	mfhi $a2
	#load remainder of score / div into last digit
	sw $a2 4($a0)
	lw $a1, 0($a0)
	addi $a1, $a1, 1
	sw $a1, 0($a0)
endCheck:
	jr $ra

#function used to reset score of ship
resetScore:
	la $a0, Score
	li $a1, 0
	sw $a1, 16($a0)
	sw $a1, 12($a0)
	sw $a1, 8($a0)
	sw $a1, 4($a0)
	sw $a1, 0($a0)
	jr $ra

#--functions used for keeping track of health--#
#function responsible for drawing health of ship
drawHealth:
	lw $a0, Green
	lw $a1, shipHealth
	sw $a0, 0($s0)
	li $a2, 2
	blt $a1, $a2, end
	sw $a0, 4($s0)
	li $a2, 3
	blt $a1, $a2, end
	sw $a0, 8($s0)
end:
	jr $ra
#function responsible for erasing health of ship
clearHealth:
	lw $a0, Black
	sw $a0, 0($s0)
	sw $a0, 4($s0)
	sw $a0, 8($s0)
	jr $ra

#function used to reset health of ship
resetHealth:
	li $a0, 3
	sw $a0, shipHealth
	jr $ra

#--general use functions--#

#Function responsible for clearing all entities on screen (but not full screen)
ClearScreen:
	#push return address onto stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	#load asteroid array and num asteroids
	la $a0, asteroidPos
	lw $a2, asteroidNum
	addi $a2, $a2, -1
ClearLoop:
	bltz $a2, ClearExit
	#get offset of asteroid array
	li $a1, 4
	mult $a2, $a1
	mflo $a1
	add $a1, $a1, $a0
	#store current address on stack
	addi $sp, $sp, -4
	sw $a0, 0($sp)
	
	lw $a0, 0($a1)
	jal clearAsteroid
	
	lw $a0, 0($sp)
	addi $sp, $sp, 4
	
	addi $a2, $a2, -1
	j ClearLoop
ClearExit:
	#clear ship
	lw $a0, shipPos
	jal clearShip
	
	jal clearHealth
	
	jal clearPickupHealth
	jal clearPickupScore
	
	jal clearHit
	#load return address from bottom of stack
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	#return to caller
	jr $ra

#function responsible for fully clearing screen
fullClear:
	move $a0, $s0
	li $a1, 0
	lw $a2, Black
fullClearLoop:
	bge $a1, maxPix, endFullLoop
	
	sw $a2, 0($a0)
	addi $a0, $a0, 4
	addi $a1, $a1, 4
	j fullClearLoop
endFullLoop:
	jr $ra

#--functions called when game over happens--#

#function responsible for drawing game over screen (except score)
drawGameOver:
	lw $a0, White
	move $a1, $s0
	#Drawing an E
	addi $a1, $a1, 260
	move $a2, $a1
	
	sw $a0, 0($a1)
	sw $a0, 4($a1)
	sw $a0, 8($a1)
	sw $a0, 12($a1)
	addi $a1, $a1 128
	sw $a0, 0($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 4($a1)
	sw $a0, 8($a1)
	sw $a0, 12($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 4($a1)
	sw $a0, 8($a1)
	sw $a0, 12($a1)
	
	#Drawing an N
	
	addi $a1, $a2, 20
	sw $a0, 0($a1)
	sw $a0, 4($a1)
	sw $a0, 28($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 8($a1)
	sw $a0, 28($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 12($a1)
	sw $a0, 28($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 16($a1)
	sw $a0, 28($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 20($a1)
	sw $a0, 28($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 24($a1)
	sw $a0, 28($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 28($a1)
	
	#Drawing a D
	addi $a1, $a2, 56
	sw $a0, 0($a1)
	sw $a0, 4($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 8($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 8($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 8($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 8($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 8($a1)
	addi $a1, $a1, 128
	sw $a0, 0($a1)
	sw $a0, 4($a1)
	
	jr $ra

#function responsible for drawing score on game over screen
drawScore:
	#get seconds survived
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $a1, Score
	lw $a1, 0($a1)
	la $a0, 1940($s0)
	jal drawNumber
	
	la $a1, Score
	lw $a1, 4($a1)
	la $a0, 1960($s0)
	jal drawNumber
	
	la $a1, Score
	lw $a1, 8($a1)
	la $a0, 1980($s0)
	jal drawNumber
	
	la $a1, Score
	lw $a1, 12($a1)
	la $a0, 2000($s0)
	jal drawNumber
	
	la $a1, Score
	lw $a1, 16($a1)
	la $a0, 2020($s0)
	jal drawNumber
	
	lw $ra 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

#function responsible for drawing a number, a0 = coordinate of center of number, a1 = the number (0-9)
drawNumber:
	
	lw $a2, White
	
	li $v0, 0
	beq $a1, $v0, drawZero
	li $v0, 1
	beq $a1, $v0, drawOne
	li $v0, 2
	beq $a1, $v0, drawTwo
	li $v0, 3
	beq $a1, $v0, drawThree
	li $v0, 4
	beq $a1, $v0, drawFour
	li $v0, 5
	beq $a1, $v0, drawFive
	li $v0, 6
	beq $a1, $v0, drawSix
	li $v0, 7
	beq $a1, $v0, drawSeven
	li $v0, 8
	beq $a1, $v0, drawEight
	li $v0, 9
	beq $a1, $v0, drawNine

drawZero:
	#draw a zero
	sw $a2, 4($a0)
	sw $a2, -4($a0)
	sw $a2, 132($a0)
	sw $a2, 124($a0)
	sw $a2, -132($a0)
	sw $a2, -124($a0)
	sw $a2, 260($a0)
	sw $a2, 256($a0)
	sw $a2, 252($a0)
	sw $a2, -260($a0)
	sw $a2, -256($a0)
	sw $a2, -252($a0)
	jr $ra
	
drawOne:
	#draw one
	sw $a2, 0($a0)
	sw $a2, 128($a0)
	sw $a2, -128($a0)
	sw $a2, 256($a0)
	sw $a2, -256($a0)
	jr $ra

drawTwo:
	#draw two
	sw $a2, 0($a0)
	sw $a2, 4($a0)
	sw $a2, -4($a0)
	sw $a2, 124($a0)
	sw $a2, -124($a0)
	sw $a2, 260($a0)
	sw $a2, 256($a0)
	sw $a2, 252($a0)
	sw $a2, -260($a0)
	sw $a2, -256($a0)
	sw $a2, -252($a0)
	jr $ra

drawThree:
	#draw three
	sw $a2, 0($a0)
	sw $a2, 4($a0)
	sw $a2, -4($a0)
	sw $a2, 132($a0)
	sw $a2, -124($a0)
	sw $a2, 260($a0)
	sw $a2, 256($a0)
	sw $a2, 252($a0)
	sw $a2, -260($a0)
	sw $a2, -256($a0)
	sw $a2, -252($a0)
	jr $ra

drawFour:
	#draw four
	sw $a2, 0($a0)
	sw $a2, 4($a0)
	sw $a2, -4($a0)
	sw $a2, 132($a0)
	sw $a2, -132($a0)
	sw $a2, -124($a0)
	sw $a2, 260($a0)
	sw $a2, -260($a0)
	sw $a2, -252($a0)
	jr $ra

drawFive:
	sw $a2, 0($a0)
	sw $a2, 4($a0)
	sw $a2, -4($a0)
	sw $a2, 132($a0)
	sw $a2, -132($a0)
	sw $a2, 260($a0)
	sw $a2, 256($a0)
	sw $a2, 252($a0)
	sw $a2, -260($a0)
	sw $a2, -256($a0)
	sw $a2, -252($a0)
	jr $ra

drawSix:
	sw $a2, 0($a0)
	sw $a2, 4($a0)
	sw $a2, -4($a0)
	sw $a2, 132($a0)
	sw $a2, 124($a0)
	sw $a2, -132($a0)
	sw $a2, 260($a0)
	sw $a2, 256($a0)
	sw $a2, 252($a0)
	sw $a2, -260($a0)
	sw $a2, -256($a0)
	jr $ra

drawSeven:
	sw $a2, 4($a0)
	sw $a2, 132($a0)
	sw $a2, -124($a0)
	sw $a2, 260($a0)
	sw $a2, -260($a0)
	sw $a2, -256($a0)
	sw $a2, -252($a0)
	jr $ra

drawEight:
	sw $a2, 0($a0)
	sw $a2, 4($a0)
	sw $a2, -4($a0)
	sw $a2, 132($a0)
	sw $a2, 124($a0)
	sw $a2, -132($a0)
	sw $a2, -124($a0)
	sw $a2, 260($a0)
	sw $a2, 256($a0)
	sw $a2, 252($a0)
	sw $a2, -260($a0)
	sw $a2, -256($a0)
	sw $a2, -252($a0)
	jr $ra

drawNine:
	sw $a2, 0($a0)
	sw $a2, 4($a0)
	sw $a2, -4($a0)
	sw $a2, 132($a0)
	sw $a2, -132($a0)
	sw $a2, -124($a0)
	sw $a2, 260($a0)
	sw $a2, -260($a0)
	sw $a2, -256($a0)
	sw $a2, -252($a0)
	jr $ra
	
