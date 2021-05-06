#################################################################################
# CSCB58 Winter 2021 Assembly Final Project
# University of Toronto, Scarborough
# 
# Student: Ian Xu, 1006319208, xuian
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 512
# - Display height in pixels: 512
# - Base address for display: 0x10008000 ($gp) 
#
# Which milestones have been reaches in this submission?
# - Milestone 4
#
# Which approved features have been implemented for milestone 4?
# 1. Increase in difficulty as the game progresses
# 2. Scoring System
# 3. Shoot Obstacles
# 4. Smooth graphics
#
# Link to video demonstration for final submission:
# https://play.library.utoronto.ca/0f13990e103b8ec7e4cf6662418c1372
#
# Are you OK with us sharing the video with other people outside course staff?
# - yes
#
# Any additional information that the TA needs to know:
# - None
#
#################################################################################

.eqv BASE_ADDRESS 0x10008000	# Top left corner of graphics display
.eqv END_ADDRESS  0x10009f00	# 1 pixel down of Bottom left corner of game window
.eqv KEY_PRESS    0xffff0000	# Detecting keypress
.eqv NONE	  0		# Blank color for erasing pictures
.eqv HEIGHT 	  128		# Height of graphics display
.eqv WIDTH        256		# Width of graphics display
.eqv CWIDTH	  768		# 3x Width of graphics display
.eqv BWIDTH	  512		# 2x Width of graphics display
.eqv A	          97		# ASCII equivalent of a
.eqv W            119		# ASCII equivalent of w
.eqv S            115		# ASCII equivalent of s
.eqv D            100		# ASCII equivalent of d
.eqv SPACE	  32		# ASCII equivalent of space
.eqv METEOR	  0x00AD6F17	# HEX equivalent of Meteor color
.eqv WHITE 	  0xffffff	# HEX equivalent of white
.eqv RED	  0xff0000	# HEX equivalent of red

.data	
ship: 		.word	0x5707AF, 0x51F1FF, 0x51F1FF, 0x000000, 0x5707AF, 0x5707AF, 0x5707AF, 0xFF0000	# Spaceship colors
shipCollide:	.word	0xEA5A35, 0xC329F1, 0xC329F1, 0x000000, 0xEA5A35, 0xEA5A35, 0xEA5A35, 0xFF0000	# Damaged spaceship colors
obstaclepos:	.word 	0:40		# Initializes an array of 20 (size, location) pairs for meteors
scores:		.word   0:5		# Initializes the values of the 5 scores
hiScore:	.word   0:5		# Initializes the values of the 5 scores that are the highest across all games played
bullet:		.word	0		# Initializes an empty ship bullet
level:		.word   1		# Initializes the level of the game, level = (1 to 9)
health:		.word   0x00000BF8	# Initializes the offset from END_Address to rightmost location of the health bar
num_elements:	.word 	0 # Initializes number of meteors in obstaclepos times 8

.text

# Runs the space game
# Used Registers: $t0(Holds top left of screen), $t2(Holds the bit offset for ship),
#   
main:

startUpScreen:
	jal eraseScreen		# Function that wipes the screen
	jal getMaxHiScore	# Function that generates the new high score
	jal  drawTitle		# Function that displays press p to start; press x to exit
	addi $t0, $zero, KEY_PRESS 	# Stores the location of the key press into $t0
title:  lw   $t1, 0($t0)	# Stores if the key has been pressed into $t1
	beq  $t1, 0, title	# Continues at this screen until a key has been pressed
	lw   $t1, 4($t0)	# Stores the value of the key pressed into $t1
	beq  $t1, 112, initialization	# If the key pressed is p, then go to initialization
	beq  $t1, 120, end	# If the key pressed is backspace, then end the program
	j title  

initialization:
	jal eraseScreen		# Function that wipes the screen
	jal clearStorage	# Functino that resets all stored memory from game
	li   $s2, 0		# Sets this as the update counter
	li   $s3, 0		# Sets the move meteor check to true
	li   $s4, 0		# Sets the generate meteor check to true
	li   $s7, 0		# Sets the move ship check to true
	li   $s0, BASE_ADDRESS	# Sets $a0 to the top left address value of the screen
	li   $s1, METEOR	# Sets the color of the meteor
	li   $s5, RED		# Sets color of bullet
	addi $t0, $s0, 1020	# The initial offset from BASE_ADDRESS
	addi $s6, $zero, 0	# Sets movement offset to 0
	jal  drawGUI		# Draws the Bottom GUI
	li   $t0, END_ADDRESS
	addi $t1,  $t0, 0x2000
	li   $t2, WHITE
gameLoop:
	la   $a0, bullet	# Loads address of bullet
	lw   $a1, 0($a0)	# Loads the value of the bullet
	beqz $a1, skipMove	# Skips moving the bullet if it doesn't exist
	jal  movebullet
skipMove:
	beqz $s4, generateMeteors	# Generates a meteor of 2x2/3x3/4x4 pixel size.
genDone:
	bnez $s3, skipobstacles	# Updates obstacles every so often
	jal  moveObstacles	# Moves the obstacles across the screen
	jal  drawObstacles	# Goes to draw the obstacles helper function
skipobstacles:
	add  $a0, $s0, $s6	# Sets the position of the ship
	jal  drawship		# Function: Draws spaceship
	li   $v0, 32		# Sets syscall to wait
	li   $a0, 40		# Sets the wait time of the syscall to 40ms
	syscall			# Waits for 40 ms
	
# Level Rules:
# Level 1: Meteor generation every 32 updates, Meteor movement every 4 updates, Ship movement every update, meteor size capped at 2x2
# Level 2: Meteor size capped at 3x3
# Level 3: Meteor size capped at 4x4
# Level 4: Meteor movement every 2 updates
# Level 5: Meteor generation every 16 updates
# Level 6: Meteor generation every 8 updates
# Level 7: Meteor movement every update
# Level 8: Ship movement every 2 updates
# Level 9(Final Level): Ship movement every 4 updates
updateCounterStuff:
	li   $t1, 3		# Sets the default move obstacle check to multiple of 4
	li   $t2, 31		# Sets the default meteor generation check to multiple of 32
	li   $t3, 0		# Sets the default move ship check to no check required
	lw   $t0, level		# Sets $t0 to the 
	blt  $t0, 4, check	# Checks to see if any modifications need to be made based on current level
	li   $t1, 1		# Sets the move obstacle check to multiple of 2
	blt  $t0, 5, check	# Checks to see if any modifications need to be made based on current level
	li   $t2, 15		# Sets the generate obstacle check to multiple of 16
	blt  $t0, 6, check	# Checks to see if any modifications need to be made based on current level
	li   $t2, 7		# Sets the generate obstacle check to multiple of 8
	blt  $t0, 7, check	# Checks to see if any modifications need to be made based on current level
	li   $t1, 0		# Sets move obstacle check to no check
	blt  $t0, 8, check	# Checks to see if any modifications need to be made based on current level
	li   $t3, 1		# Sets the move ship check to multiple of 2
	blt  $t0, 9, check	# Checks to see if any modifications need to be made based on current level
	li   $t3, 3		# Sets the move ship check to multiple of 4
check:
	addi $s2, $s2, 1	# Increases the update counter by 1
	and  $s3, $s2, $t1	# Checks to update counter for move obstacle
	and  $s4, $s2, $t2	# Checks to update counter for generate meteor
	and  $s7, $s2, $t3	# Checks to update counter for move ship

	la   $t0, scores	# Stores the start of scores array
	lw   $t2, 16($t0)	# Loads the value of 10,000x from scores
	mul  $t2, $t2, 10	# Multiples number by 10
	lw   $t1, 12($t0)	# Loads the value of 1,000x from scores
	add  $t2, $t2, $t1	# Adds into $t2
	mul  $t2, $t2, 10	# Multiplies number by 10
	lw   $t1, 8($t0)	# Loads the value of 100x from scores
	add  $t2, $t2, $t1	# Adds into $t2
	mul  $t2, $t2, 10	# Multiplies number by 10
	lw   $t1, 4($t0)	# Loads the value of 10x from scores
	add  $t2, $t2, $t1	# Adds into $t2
	mul  $t2, $t2, 10	# Multiplies number by 10
	lw   $t1, 0($t0)	# Loads the value of 1x from scores
	add  $t2, $t2, $t1	# Adds into $t2
	lw   $t1, level		# Loads the value of level into $t1
	addi $t1, $t1, 2	# Adds 2 to the value of $t1
	srlv $t2, $t2, $t1	# Divides by 2^(Level+2)
	bne  $t2, 1, noIncreaseLevel	# Does not increase level if it does not divide into 1
	jal  levelup		# Increases the level of the game
noIncreaseLevel:		# Goes for another loop
	lw   $t0, health	# If there is no health go back to title screen
	beq  $t0, 0xB9C startUpScreen	# ^
	add  $a2, $s0, $s6	# Sets the position of the ship to input variable $a2
	addi $a0, $zero, KEY_PRESS	# Sets $a0 to the key_press locator input
	bnez $s7, skipShip	# Does not move ship if update counter is not 0
	jal  movepixel		# Calls the move ship function 
skipShip:
	j    gameLoop
end:
	jal  eraseScreen	# Erases the screen
	li   $v0, 10		# Ends the game
	syscall			# ^

# Clears the entire screen
# Input registers: None
# Used Registers: $t0, $t1
eraseScreen:
	li $t0, BASE_ADDRESS	# Loads the top left of the screen
	addi $t1, $t0, 0x4000	# Loads the bottom right of the screen
eraseLoop:
	beq $t0, $t1, Done	# Finishes the loop if they are equal
	sw $zero, 0($t0)	# Clears pixel at location
	addi $t0, $t0, 4 	# Goes to next pixel
	j eraseLoop		# Loops

# Clears the stored values when playing the game
# Input registers: None
# Used Registers: $t0, $t1	
clearStorage:
	la   $t0, obstaclepos	# Loads start of obstaclepos
	addi $t1, $t0, 160	# Loads end of obstaclepos
loopEraseObstacles:		# Resets Obstacle Positions to empty
	beq  $t0, $t1, eraseRest	# Moves on if the end is reached 
	sw   $zero, 0($t0)	# Erases data at memory location
	addi $t0, $t0, 4	# Moves to next memory location
	j    loopEraseObstacles	# Loops
eraseRest:
	sw   $zero, bullet	# Resets bullet to 0
	li   $t0, 1		# Sets $t1 to 1
	sw   $t0, level		# Resets level to 1
	sw   $zero, num_elements# Resets number of meteors to 0
	li   $t0, 0x00000BF8	# Loads the size of the health bar into $t0
	sw   $t0, health	# Resets the size of the health bar
	la   $t0, scores	# Loads position of scores
	sw   $zero, 0($t0)	# Resets score to 0
	sw   $zero, 4($t0)	# ^
	sw   $zero, 8($t0)	# ^
	sw   $zero, 12($t0)	# ^
	sw   $zero, 16($t0)	# ^
	jr $ra			# Returns from function
	
	
# Sets HiScore to be max of current HiScore and score 
# Input Registers: None
# Used Registers: $t0, $t1, $t2. $t3
getMaxHiScore:
	la   $t0, hiScore	# Sets the hiScore array to $t0
	la   $t1, scores	# Sets the score array to $t1
	lw   $t2, 16($t0)	# Loads the 10,000s of hiScore into $t2
	lw   $t3, 16($t1)	# Loads the 10,000s of score into $t3
	blt  $t3, $t2, Done	# If score is lower than hiScore, then do nothing and end
	bgt  $t3, $t2, replace	# Replace score if score is higher than hiScore
	lw   $t2, 12($t0)	# Loads the 1,000s of hiScore into $t2
	lw   $t3, 12($t1)	# Loads the 1,000s of score into $t3
	blt  $t3, $t2, Done	# If score is lower than hiScore, end
	bgt  $t3, $t2, replace	# Replace score if score is higher than hiScore
	lw   $t2, 8($t0)	# Loads the 100s of hiScore into $t2
	lw   $t3, 8($t1)	# Loads the 100s of score into $t3
	blt  $t3, $t2, Done	# If score is lower than hiScore, end
	bgt  $t3, $t2, replace	# Replace score if score is higher than hiScore
	lw   $t2, 4($t0)	# Loads the 10s of hiScore into $t2
	lw   $t3, 4($t1)	# Loads the 10s of score into $t3
	blt  $t3, $t2, Done	# If score is lower than hiScore, end
	bgt  $t3, $t2, replace	# Replace score if score is higher than hiScore
	lw   $t2, 0($t0)	# Loads the 1s of hiScore into $t2
	lw   $t3, 0($t1)	# Loads the 1s of score into $t3
	blt  $t3, $t2, Done	# If score is lower than hiScore, end
replace:
	lw $t2, 0($t1)		# Replaces HiScore with score
	sw $t2, 0($t0)		# ^
	lw $t2, 4($t1)		# ^
	sw $t2, 4($t0)		# ^
	lw $t2, 8($t1)		# ^
	sw $t2, 8($t0)		# ^
	lw $t2, 12($t1)		# ^
	sw $t2, 12($t0)		# ^
	lw $t2, 16($t1)		# ^
	sw $t2, 16($t0)		# ^
	jr $ra			# Jump to prior function calling point
	
# Checks keyboard inputs to act on user input.
# Input Registers: $a0(Keyboard input register), $a2(Base position of ship)
# Used Registers: $a0, $a1, $a2, $a3
movepixel:
	lw   $a1, 0($a0)	# Loads if a key has been pressed
	beq  $a1, 0, Done	# Ends loop if key has not been pressed
	lw   $a1, 4($a0)	# Loads the value of the pressed key
	beq  $a1, A, left	# Performs the action based on the key pressed
	beq  $a1, D, right	# Performs the action based on the key pressed
	beq  $a1, S, down	# Performs the action based on the key pressed
	beq  $a1, W, up		# Performs the action based on the key pressed
	beq  $a1, SPACE, shoot	# Performs the action based on the key pressed  
	beq  $a1, 112, initialization	# Resets the game if p is pressed
	beq  $a1, 120, startUpScreen	# Goes to the title screen if x is pressed
	j    Done
# Moves the position of the ship up a pixel on the screen	
up:
	addi $a3, $a2, -WIDTH	# Checks if ship goes above the top of the screen
	blt  $a3, BASE_ADDRESS, Done	# Does not move ship if it does
	sw   $zero, 256($a2)	# Erases bottom 4 pixels
	sw   $zero, 260($a2)	# ^
	sw   $zero, 264($a2)	# ^
	sw   $zero, 268($a2)	# ^
	addi $s6, $s6, -WIDTH	# Changes the offset amount
	jr   $ra		# Jumps to pre function call
# Moves the position of the ship left a pixel on the screen
left:
	and  $a3, $a2, 255	# Checks if ship tries to wrap around to right side of screen
	beqz $a3, Done		# Does not move ship if it does
	sw   $zero, 8($a2)	# Erases rightmost 2 pixels
	sw   $zero, 268($a2)	# ^
	addi $s6, $s6, -4	# Changes the offset amount
	jr   $ra		# Jumps to pre function call
# Moves the position of the ship down a pixel on the screen
down:
	addi $a3, $a2, WIDTH	# Checks if ship goes below the end of screen
	bge  $a3, END_ADDRESS, Done	# Does not move ship if it does
	sw   $zero, 0($a2)	# Erases topmost 3 pixels
	sw   $zero, 4($a2)	# ^
	sw   $zero, 8($a2)	# ^
	addi $s6, $s6, WIDTH	# Changes the offset amount
	jr   $ra		# Jumps to pre function call
# Moves the position of the ship right a pixel on the screen
right:
	and  $a3, $a2, 255	# Checks if ship will try to wrap around to left side of screen
	bge  $a3, 240, Done 	# Does not move ship if it does
	sw   $zero, 0($a2)	# Erases leftmost 2 pixels
	sw   $zero, 256($a2)	# ^
	addi $s6, $s6, 4	# Changes the offset amount
	jr   $ra		# Jumps to pre function call
# Creates a bullet in front of the ship
shoot:
	la   $a0, bullet	# Loads the address of bullet
	lw   $a3, 0($a0)	# Loads location of bullet
	bnez $a3, noShoot	# If there is already a bullet, don't make another
	addi $a3, $a2, WIDTH    # Moves position of $a3 to be equal to front of shooting area
	addi $a3, $a3, 16	# ^
	la   $a0, bullet
	sw   $a3, 0($a0)	# Stores the location of the bullet
	sw   $s5, 0($a3)	# Draws the bullet
noShoot:
	jr   $ra		# Jumps to pre function call
	
# Function: Draws ship
# Input Registers: $a0(top left corner of ship)
# Used Registers: $a0, $a1, $a2, $a3
drawship:
	addi $sp, $sp, -4	# Loads the return register into stack pointer
	sw   $ra, 0($sp)	# ^
	lw   $a3, 0($a0)	# Loads pixel
	beq  $a3, METEOR, draw1	# Checks if there is meteor 
	lw   $a3, 4($a0)	# Loads pixel
	beq  $a3, METEOR, draw1 # Checks if there is meteor
	lw   $a3, 8($a0)	# Loads pixel
	beq  $a3, METEOR, draw1 # Checks if there is meteor
	lw   $a3, 12($a0)	# Loads pixel
	beq  $a3, METEOR, draw1 # Checks if there is meteor
	lw   $a3, 256($a0)	# Loads pixel
	beq  $a3, METEOR, draw1 # Checks if there is meteor
	lw   $a3, 260($a0)	# Loads pixel
	beq  $a3, METEOR, draw1 # Checks if there is meteor
	lw   $a3, 264($a0)	# Loads pixel
	beq  $a3, METEOR, draw1 # Checks if there is meteor
	lw   $a3, 268($a0)	# Loads pixel
	beq  $a3, METEOR, draw1 # Checks if there is meteor
	la   $a1 ship		# Loads in normal ship sprite
	j    draw2		# Jump to drawing ship
draw1:	addi $sp, $sp, -4	# Stores jump point into stack
	sw   $ra, 0($sp)	# ^
	jal  reduceHealth	# Reduces health of ship
	lw   $ra, 0($sp)	# Returns jump point into $ra
	addi $sp, $sp, 4	# Removes space off stack
	la   $a1, shipCollide	# Loads in damaged ship sprite
draw2:	lw   $a2, 0($a1)	# Loads pixel
	sw   $a2, 0($a0)	# Draws pixel
	lw   $a2, 4($a1)	# Loads pixel
	sw   $a2, 4($a0)	# Draws pixel
	lw   $a2, 8($a1)	# Loads pixel
	sw   $a2, 8($a0)	# Draws pixel
	lw   $a2, 12($a1)	# Loads pixel
	sw   $a2, 12($a0)	# Draws pixel
	lw   $a2, 16($a1)	# Loads pixel
	sw   $a2, 256($a0)	# Draws pixel
	lw   $a2, 20($a1)	# Loads pixel
	sw   $a2, 260($a0)	# Draws pixel
	lw   $a2, 24($a1)	# Loads pixel
	sw   $a2, 264($a0)	# Draws pixel
	lw   $a2, 28($a1)	# Loads pixel
	sw   $a2, 268($a0)	# Draws pixel
	lw   $ra, 0($sp)	# Loads the value back from the stack pointer
	addi $sp, $sp, 4	# Pops memory off of the stack pointer
	jr   $ra		# Go back to pre function definition

# Fcuntion: Checks if any meteors have collided with the bullet
# Input Registers: $a0(Address of position of bullet), $a1(Address of start of obstaclepos)
# Used Registers: $t0, $t1, $t2
# No Output
obstacleCollision:
	addi $t0, $zero, 0	# Sets loop initial to 0
	lw $a0, 0($a0)		# Loads position of bullet into $a0
checkCollisionLoop:
	beq  $t0, 20, jumpBack	# Finishes function
	lw   $t1, 0($a1)	# Loads size of meteor
	lw   $t2, 4($a1)	# Loads position of meteor
	beq  $t1, 0, next	# If empty, move to next meteor
	beq  $t2, $a0, deon	# Checks the four squares meteors always exist on
	addi $t2, $t2, -4	# ^
	beq  $t2, $a0, deon	# ^
	addi $t2, $t2, 256	# ^
	beq  $t2, $a0, deon	# ^
	addi $t2, $t2, 4	# ^
	beq  $t2, $a0, deon	# ^
	beq  $t1, 2, next	# Finishes if meteor is of size 2
	addi $t2, $t2, 252	# Checks the two possible collision squares that size 3 and 4 meteors exist on
	beq  $t2, $a0, deon	# ^
	addi $t2, $t2, 4	# ^
	beq  $t2, $a0, deon	# ^
	beq  $t1, 3, next	# Finishes if meteor is size 3
	addi $t2, $t2, 252	# Checks the last two squares for size 4 meteors
	beq  $t2, $a0, deon	# ^
	addi $t2, $t2, 4	# ^
	beq  $t2, $a0, deon	# ^
next: 
	addi $t0, $t0, 1	# Increases value by 1
	addi $a1, $a1, 8	# Goes to next obstaclepos position	
	j checkCollisionLoop	# Loops back
deon:
	lw   $t2, 4($a1)	# Sets $t2 to the position of the meteor
	beq  $t1, 2, deleteTwo	# Jumps if the size of the meteor is 2
	beq  $t1, 3, deleteThree# Jumps if the size of the meteor is 3
	sw   $zero, 12($t2)	# Reduces meteor size to 3
	sw   $zero, 268($t2)	# ^
	sw   $zero, 524($t2)	# ^
	sw   $zero, CWIDTH($t2)	# ^
	sw   $zero, 772($t2)	# ^
	sw   $zero, 776($t2)	# ^
	sw   $zero, 780($t2)	# ^
	addi $t1, $t1, -1	# ^
	sw   $t1, 0($a1)	# ^
	j    jumpBack		# Only 1 collision can happen at a time, so jump back after it deletes
deleteTwo:
	sw   $zero, 0($t2)	# Deletes meteor
	sw   $zero, 4($t2)	# ^
	sw   $zero, WIDTH($t2)	# ^
	sw   $zero, 260($t2)	# ^
	sw   $zero, 0($t2)	# ^
	sw   $zero, 0($a1)	# ^
	sw   $zero, 4($a1)	# ^
	j    jumpBack		# Only 1 collision can happen at a time, so jump back after it deletes
deleteThree:
	sw   $zero, 8($t2)	# Reduces meteor size to 2
	sw   $zero, 264($t2)	# ^
	sw   $zero, BWIDTH($t2)	# ^
	sw   $zero, 516($t2)	# ^
	sw   $zero, 520($t2)	# ^
	addi $t1, $t1, -1	# ^
	sw   $t1, 0($a1)	# ^
	j    jumpBack		# Only 1 collision can happen at a time, so jump back after it deletes
jumpBack:
	jr   $ra		# Returns

# Function: Moves the bullet from its position
# Input Registers: $a0(Address of position of bullet)
# Used Registers: $a0, $a1, $a2, $a3, $t0
# No Output
movebullet:
	lw   $a3, 0($a0)	# Loads value from address
	addi $a1, $a3, 4	# Moves to the next position of the bullet
	and  $a2, $a1, 255	# Checks to see if it is on the right side of the screen
	beqz $a2, storeAndFinish# Stores 0 into it if is wraps to the left side
	lw   $a3, 0($a1)	# Loads the value from next address
	bnez $a3, ReduceMeteor	# If it collides with a meteor, then delete part of that meteor
	lw   $a3, 0($a0)	# Loads value of bullet from address
	sw   $zero, 0($a3)	# Erases bullet at location
	sw   $a1, 0($a0)	# Else stores the new position of the bullet back and finishes
	sw   $s5, 0($a1)	# Stores the location of the new bullet
	j    finish		# Finishes
ReduceMeteor:
	addi $sp, $sp, -4	# Adds space on stack pointer
	sw   $ra, 0($sp)	# Pushes jump location into stack
	addi $sp, $sp, -4	# Adds space ont stack pointer
	sw   $a0, 0($sp)	# Pushes the bullet position into stack
	la   $a1, obstaclepos	# Stores start of obstaclepos into $a1
	jal  obstacleCollision	# Calls the obstacleCollision function
	jal  change		# Increases score by 1
	lw   $a0, 0($sp)	# Pops the bullet position into $a0
	addi $sp, $sp, 4	# Removes space from stack
	lw   $ra, 0($sp)	# Pops jump location in $ra
	addi $sp, $sp, 4	# Removes space from stack
storeAndFinish:
	lw   $a3, 0($a0)	# Loads position of bullet
	sw   $zero, 0($a3)	# Sets graphics of bullet to 0
	# Fix ghost bullet problem here by checking if the pixel to the right is meteor coloured
	sw   $zero, 0($a0)	# Stores the position of bullet as 0
finish:	jr   $ra		# Finishes

# Function: Redraws all obstacles in the game
# Input: $a0(Color of fill) 0 = empty, METEOR = obstacle color
# Used registers: $a0(size of meteors), $a1(array pointer), $a2(array pointer), $a3(Position of meteors), 
#                 $t0(Pointer checker)
# No Output
drawObstacles:
	li   $a1, 0
	la   $a2, obstaclepos		# Sets the start of obstaclepos
drawObstaclesLoop: 			# For loop through the words in obstaclepos array
	beq  $a1, 20, Done 		# Go back to main loop if there are no more elements in the array
	lw   $a0, 0($a2)		# Loads size of meteor into $s0
	beqz $a0, noErase		# Skips the meteor if it doesn't exist
	sll  $a0, $a0, 2		# Multiples size of meteor by 4
	lw   $a3, 4($a2)		# Loads position of meteor into $s1 
	beq  $a0, 8, drawTwo		# Draws two bits down from position of meteor 
	beq  $a0, 12, drawThree		# Draws three bits down from position of meteor
	sw   $s1, CWIDTH($a3)		# Draws four bits down from the position of the meteor
drawThree: 
	sw   $s1, BWIDTH($a3)		# Draws meteor
drawTwo: 
	sw   $s1, WIDTH($a3)		# Draws meteor
	sw   $s1, 0($a3)		# Draws meteor
					
	and  $t0, $a3, 255		# Checks which pixel the pointer is on
	add  $t0, $t0, $a0		# augments the position check by the size of the meteor
	bgt  $t0, 252, noErase		# Checks if less or equals to 252, if greater then continue with next meteor
					# If it is less or equals, then erase the meteor residue
	add  $a3, $a3, $a0		# Moves pointer to residue column
	beq  $a0, 8, eraseTwo		# Erases two pixels down from position of meteor 
	beq  $a0, 12, eraseThree	# Erases three pixels down from position of meteor
	sw   $zero, CWIDTH($a3)		# Erases four pixels down from the position of the meteor
eraseThree: 
	sw   $zero, BWIDTH($a3)		# Erases residue
eraseTwo: 
	sw   $zero, WIDTH($a3)		# Erases residue
	sw   $zero, 0($a3)		# Erases residue
noErase: 
	addi $a2, $a2, 8		# Moves to next meteor pointer
	addi $a1, $a1, 1		# Increases the counter by 1
	j drawObstaclesLoop		# Not all elements in the array have been reached, continue with the loop

	
# Function: Moves all obstacles one pixel to the left
# Input: None
# Used registers: $a0, $a1, $a2, $a3
# No Output
moveObstacles:
	li $a1, 0			# Starts the counter at 0
	la $a2, obstaclepos		# Sets the start of obstaclepos
moveObstaclesLoop:			# For loop through the words in obstaclepos array
	beq  $a1, 20, Done 		# Go back to main loop if there are no more elements in the array
	lw   $a3, 4($a2)		# Loads the position of the meteor from the array
	beqz $a3, store			# Skips the movement if the object doesn't exist
skip2:	addi $a3, $a3, -4		# Moves the meteor left one pixel
	andi $a0, $a3, 255		# Tests if meteor is at left side of screen
	bne  $a0, 252, store		# If it is at left side of screen remove it from obstaclepos
	addi $sp, $sp, -4		# Adds space into the stack
	sw   $ra, 0($sp)		# Saves the previous register link into the stack
	addi $sp, $sp, -4		# Adds space into the stack
	sw   $a2, 0($sp)		# Adds the size of the meteor into the stack
	addi $a2, $a2, 4		# Sets $a2 to the position of the meteor
	addi $sp, $sp, -4		# Adds space into the stack
	sw   $a2, 0($sp)		# Adds the position of the meteor into the stack
	addi $a2, $a2, -4
	jal  Remove			# Calls the Remove function which removes a meteor
	lw   $ra, 0($sp)		# Returns the previous register link into the stack
	addi $sp, $sp, 4		# Pops word off of the stack
	j    store2
store:	sw   $a3, 4($a2)		# Stores the new location back into the obstaclepos array
store2:	addi $a2, $a2, 8		# Goes to the next element in the array
	addi $a1, $a1, 1		# Increments counter by 1
	j    moveObstaclesLoop		# Not all elements in the array have been reached, continue with the loop

# Function: Deletes a meteor
# Input: Stack registers: 1. Size of meteor, 2. Position of meteor
# Output: None
# Used Registers: $t0, $t1

Remove: 
	lw   $t0, 4($sp)		# Loads meteor size
	lw   $t0, 0($t0)		# ^
	lw   $t1, 0($sp)		# Loads meteor position
	lw   $t1, 0($t1)		# ^
	
	beq  $t0, 2, deletetwo		# Erases a meteor of size 2 from meteor position $s1
	beq  $t0, 3, deletethree	# Erases a meteor of size 3 from meteor position $s1
	sw   $zero, CWIDTH($t1)		# Erasing outer four layer
	addi $t1, $t1, 4		# ^
	sw   $zero, CWIDTH($t1)		# ^
	addi $t1, $t1, 4		# ^
	sw   $zero, CWIDTH($t1)		# ^
	addi $t1, $t1, 4		# ^
	sw   $zero, CWIDTH($t1)		# ^
	sw   $zero, BWIDTH($t1)		# ^
	sw   $zero, WIDTH($t1)		# ^
	sw   $zero, 0($t1)		# ^
	addi $t1, $t1, -12		# ^
deletethree:
	sw   $zero, BWIDTH($t1)		# Erasing outer three layer
	addi $t1, $t1, 4		# ^
	sw   $zero, BWIDTH($t1)		# ^
	addi $t1, $t1, 4		# ^
	sw   $zero, BWIDTH($t1)		# ^
	sw   $zero, WIDTH($t1)		# ^
	sw   $zero, 0($t1)		# ^
	addi $t1, $t1, -8		# ^
deletetwo:
	sw   $zero, WIDTH($t1)		# Erasing base
	sw   $zero, 0($t1)		# ^
	addi $t1, $t1, 4		# ^
	sw   $zero, 0($t1)		# ^
	sw   $zero, WIDTH($t1)		# ^
	lw   $t0, 4($sp)			# Loads meteor size
	lw   $t1, 0($sp)			# Loads meteor position
	addi $sp, $sp, 8		# Pops the word off of the stack
	sw   $zero, 0($t0)		# Erases the meteor size at this location
	sw   $zero, 0($t1)		# Erases the meteor position at this location
	jr   $ra

# Function: Generate random number
# Input: $a1(upper bound)
# Return: $v0
# Used registers: $a0, $a1, $v0
generateRandom:
	li   $v0, 42	# Loads the generate random number function into syscall
	li   $a0, 0	# Selects the RNG generator 0
	syscall		# Calls the number generator
	j    Done	# Returns the value in $v0
	
	
# Function that generates a meteor of size 1-4 on the right side of the screen
# Input: None
# Used Registers: $a0, $v0, $a1, $a2, $a3, $t0, $t1, $t2, $t3, $t4
generateMeteors:
	la   $t2, obstaclepos	# Loads the obstaclepos array
	li   $t1, 0		# Starts counter
	lw   $t4, level		# Loads the current level
checkVacancy:
	lw   $t3, 0($t2)	# Loads the value into $s3
	beqz $t3, startRandom	# If vacant, then start randomization
	addi $t1, $t1, 1	# Increments counter by 1
	addi $t2, $t2, 8	# Goes to next array storage
	bne  $t1, 20, checkVacancy # Loops back 
	j    genDone		# No empty spaces, don't generate a meteor
startRandom:
	li   $a1, 1		# Sets the upper bound of the generator
	blt  $t4, 2, noBiggerMeteor	# Generates only size 2 meteors on level 1
	addi $a1, $a1, 1	# Sets the upper bound of the generator 1 higher
	blt  $t4, 3, noBiggerMeteor	# Generates only size 2 and 3 meteors if less than level 3
	addi $a1, $a1, 1	# Sets the upper bound of the generator 1 higher
noBiggerMeteor:
	li   $a0, 0		# Sets the RNG generator to 0th generator
	jal  generateRandom	# Generates a random meteor size from 1 to max meteor size
	addi $a0, $a0, 2	# Modifies the randomly generated size (0 -> 2, 1 -> 3, 2 -> 4)
	sw   $a0, 0($t2)	# Stores the size in the array
	li   $a1, 32		# Sets the upper range of screen meteor generation location
	sub  $a1, $a1, $a0	# ^
	li   $a0, 0		# Sets the RNG generator to 0th generator
	jal  generateRandom	# Generates a random meteor spawn location
	la   $a2, BASE_ADDRESS	# Gets pointer to top left of screen
	addi $a2, $a2, 252	# Sets location to top right side of screen
getActualOffSet:		# Shifts the location the proper number of pixels down
	beqz $a0, offsetDone	# If no more shifts down are needed, end the program
	addi $a2, $a2, WIDTH	# Shifts the offset down a pixel
	addi $a0, $a0, -1	# Decreases the number of pixels left to shift down
	j    getActualOffSet	# Continues looping
offsetDone:
	sw   $a2, 4($t2)	# Stores location in the array
	j    genDone		# Finishes the loop
	

# Function: Draws the bottom part of the game that keeps track of score and life
# Input: None
# Used registers: $t0, $t1, $t2
# Output: None
drawGUI:
	li   $t0, 0		# Start
	li   $t1, WHITE		# Loads the white color into $s1
	li   $t2, END_ADDRESS	# Loads the start of the GUI into $s2
	addi $t2, $t2, WIDTH	# Loads it 1 down so ship won't collide with it
line:
	sw   $t1, 0($t2)	# Draws the separation between game screen and GUI screen
	addi $t2, $t2, 4	# Increments counter
	addi $t0, $t0, 1	# ^
	beq  $t0, 64, score
	j    line
score:  addi $t2, $t2, 260 	# Sets line to top left of score and Health
	sw   $t1, 0($t2)	# Draws the score(S Line1) 
	sw   $t1, 4($t2)	# ^
	sw   $t1, 8($t2)	# ^
	sw   $t1, 16($t2)	# (C Line1)
	sw   $t1, 20($t2)	# ^
	sw   $t1, 24($t2)	# ^
	sw   $t1, 32($t2)	# (O Line1)
	sw   $t1, 36($t2)	# ^
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# (R Line1)
	sw   $t1, 52($t2)	# ^
	sw   $t1, 56($t2)	# ^
	sw   $t1, 64($t2)	# (E Line1)
	sw   $t1, 68($t2)	# ^
	sw   $t1, 72($t2)	# ^
	sw   $t1, 156($t2)	# (H Line1)
	sw   $t1, 164($t2)	# ^
	sw   $t1, 172($t2)	# (E2 Line1)
	sw   $t1, 176($t2)	# ^
	sw   $t1, 180($t2)	# ^
	sw   $t1, 192($t2)	# (A Line1)
	sw   $t1, 204($t2)	# (L Line1)
	sw   $t1, 220($t2)	# (T Line1)
	sw   $t1, 224($t2)	# ^
	sw   $t1, 228($t2)	# ^
	sw   $t1, 236($t2)	# (H2 Line1)
	sw   $t1, 244($t2)	# ^
	addi $t2, $t2, WIDTH	# Moves pointer down 1 line
	sw   $t1, 0($t2)	# (S Line2)
	sw   $t1, 16($t2)	# (C Line2)
	sw   $t1, 32($t2)	# (O Line2)
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# (R Line2)
	sw   $t1, 56($t2)	# ^
	sw   $t1, 64($t2)	# ^(E Line2)
	sw   $t1, 156($t2)	# (H Line2)
	sw   $t1, 164($t2)	# ^
	sw   $t1, 172($t2)	# (E2 Line2)
	sw   $t1, 188($t2)	# (A Line2)
	sw   $t1, 196($t2)	# ^
	sw   $t1, 204($t2)	# (L Line2)
	sw   $t1, 224($t2)	# (T Line2)
	sw   $t1, 236($t2)	# (H2 Line2)
	sw   $t1, 244($t2)	# ^
	addi $t2, $t2, WIDTH	# Moves pointer down 1 line
	sw   $t1, 0($t2)	# (S Line3)
	sw   $t1, 4($t2)	# ^
	sw   $t1, 8($t2)	# ^
	sw   $t1, 16($t2)	# (C Line3)
	sw   $t1, 32($t2)	# (O Line3)
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# (R Line3)
	sw   $t1, 52($t2)	# ^
	sw   $t1, 64($t2)	# (E Line3)
	sw   $t1, 68($t2)	# ^
	sw   $t1, 156($t2)	# (H Line3)
	sw   $t1, 160($t2)	# ^
	sw   $t1, 164($t2)	# ^
	sw   $t1, 172($t2)	# (E2 Line3)
	sw   $t1, 176($t2)	# ^
	sw   $t1, 188($t2)	# (A Line3)
	sw   $t1, 192($t2)	# ^
	sw   $t1, 196($t2)	# ^
	sw   $t1, 204($t2)	# (L Line3)
	sw   $t1, 224($t2)	# (T Line3)
	sw   $t1, 236($t2)	# (H2 Line3)
	sw   $t1, 240($t2)	# ^
	sw   $t1, 244($t2)	# ^
	addi $t2, $t2, WIDTH	 # Moves pointer down 1 line
	sw   $t1, 8($t2)	# (S Line4)
	sw   $t1, 16($t2)	# (C Line4)
	sw   $t1, 32($t2)	# (O Line4)
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# (R Line4)
	sw   $t1, 56($t2)	# ^
	sw   $t1, 64($t2)	# (E Line4)
	sw   $t1, 156($t2)	# (H Line4)
	sw   $t1, 164($t2)	# ^
	sw   $t1, 172($t2)	# (E2 Line4)
	sw   $t1, 188($t2)	# (A Line4)
	sw   $t1, 196($t2)	# ^
	sw   $t1, 204($t2)	# (L Line4)
	sw   $t1, 224($t2)	# (T Line4)
	sw   $t1, 236($t2)	# (H2 Line4)
	sw   $t1, 244($t2)	# ^
	addi $t2, $t2, WIDTH 	# Moves pointer down 1 line
	sw   $t1, 0($t2)	# (S Line5)
	sw   $t1, 4($t2)	# ^
	sw   $t1, 8($t2)	# ^
	sw   $t1, 16($t2)	# (C Line5)
	sw   $t1, 20($t2)	# ^
	sw   $t1, 24($t2)	# ^
	sw   $t1, 32($t2)	# (O Line5)
	sw   $t1, 36($t2)	# ^
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# (R Line5)
	sw   $t1, 56($t2)	# ^
	sw   $t1, 64($t2)	# (E Line5)
	sw   $t1, 68($t2)	# ^
	sw   $t1, 72($t2)	# ^
	sw   $t1, 156($t2)	# (H Line2)
	sw   $t1, 164($t2)	# ^
	sw   $t1, 172($t2)	# (E2 Line2)
	sw   $t1, 176($t2)	# ^
	sw   $t1, 180($t2)	# ^
	sw   $t1, 188($t2)	# (A Line2)
	sw   $t1, 196($t2)	# ^
	sw   $t1, 204($t2)	# (L Line2)
	sw   $t1, 208($t2)	# ^
	sw   $t1, 212($t2)	# ^
	sw   $t1, 224($t2)	# (T Line2)
	sw   $t1, 236($t2)	# (H2 Line2)
	sw   $t1, 244($t2)	# ^
	addi $t2, $t2, BWIDTH 	# Moves pointer down 2 lines
	sw   $t1, 0($t2)	# Loads the zeroes after score(Line 1)
	sw   $t1, 4($t2)	# ^
	sw   $t1, 8($t2)	# ^
	sw   $t1, 16($t2)	# ^
	sw   $t1, 20($t2)	# ^
	sw   $t1, 24($t2)	# ^
	sw   $t1, 32($t2)	# ^
	sw   $t1, 36($t2)	# ^
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# ^
	sw   $t1, 52($t2)	# ^
	sw   $t1, 56($t2)	# ^
	sw   $t1, 64($t2)	# ^
	sw   $t1, 68($t2)	# ^
	sw   $t1, 72($t2)	# ^
	addi $t2, $t2, WIDTH 	# Moves pointer down 1 line
	sw   $t1, 0($t2)	# Loads the zeroes after score(Line 2)
	sw   $t1, 8($t2)	# ^
	sw   $t1, 16($t2)	# ^
	sw   $t1, 24($t2)	# ^
	sw   $t1, 32($t2)	# ^
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# ^
	sw   $t1, 56($t2)	# ^
	sw   $t1, 64($t2)	# ^
	sw   $t1, 72($t2)	# ^
	addi $t2, $t2, WIDTH 	# Moves pointer down 1 line
	sw   $t1, 0($t2)	# Loads the zeroes after score(Line 3)
	sw   $t1, 8($t2)	# ^
	sw   $t1, 16($t2)	# ^
	sw   $t1, 24($t2)	# ^
	sw   $t1, 32($t2)	# ^
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# ^
	sw   $t1, 56($t2)	# ^
	sw   $t1, 64($t2)	# ^
	sw   $t1, 72($t2)	# ^
	sw   $t1, 156($t2)	# Loads Health Bar
	sw   $t1, 160($t2)	# ^
	sw   $t1, 164($t2)	# ^
	sw   $t1, 168($t2)	# ^
	sw   $t1, 172($t2)	# ^
	sw   $t1, 176($t2)	# ^
	sw   $t1, 180($t2)	# ^
	sw   $t1, 184($t2)	# ^
	sw   $t1, 188($t2)	# ^
	sw   $t1, 192($t2)	# ^
	sw   $t1, 196($t2)	# ^
	sw   $t1, 200($t2)	# ^
	sw   $t1, 204($t2)	# ^
	sw   $t1, 208($t2)	# ^
	sw   $t1, 212($t2)	# ^
	sw   $t1, 216($t2)	# ^
	sw   $t1, 220($t2)	# ^
	sw   $t1, 224($t2)	# ^
	sw   $t1, 228($t2)	# ^
	sw   $t1, 232($t2)	# ^
	sw   $t1, 236($t2)	# ^
	sw   $t1, 240($t2)	# ^
	sw   $t1, 244($t2)	# ^
	addi $t2, $t2, WIDTH	# Moves pointer down 1 line
	sw   $t1, 0($t2)	# Loads the zeroes after score(Line 4)
	sw   $t1, 8($t2)	# ^
	sw   $t1, 16($t2)	# ^
	sw   $t1, 24($t2)	# ^
	sw   $t1, 32($t2)	# ^
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# ^
	sw   $t1, 56($t2)	# ^
	sw   $t1, 64($t2)	# ^
	sw   $t1, 72($t2)	# ^
	addi $t2, $t2, WIDTH 	# Moves pointer down 1 line
	sw   $t1, 0($t2)	# Loads the zeroes after score(Line 5)
	sw   $t1, 4($t2)	# ^
	sw   $t1, 8($t2)	# ^
	sw   $t1, 16($t2)	# ^
	sw   $t1, 20($t2)	# ^
	sw   $t1, 24($t2)	# ^
	sw   $t1, 32($t2)	# ^
	sw   $t1, 36($t2)	# ^
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# ^
	sw   $t1, 52($t2)	# ^
	sw   $t1, 56($t2)	# ^
	sw   $t1, 64($t2)	# ^
	sw   $t1, 68($t2)	# ^
	sw   $t1, 72($t2)	# ^
	addi $t2, $t2, BWIDTH 	# Moves pointer down 2 lines
	sw   $t1, 0($t2)	# (L Line1)
	sw   $t1, 16($t2)	# (E Line1)
	sw   $t1, 20($t2)	# ^
	sw   $t1, 24($t2)	# ^
	sw   $t1, 32($t2)	# (V Line1)
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# (E2 Line1)
	sw   $t1, 52($t2)	# ^
	sw   $t1, 56($t2)	# ^
	sw   $t1, 64($t2)	# (L2 Line1)
	addi $t2, $t2, WIDTH 	# Moves pointer down 1 line
	sw   $t1, 0($t2)	# (L Line2)
	sw   $t1, 16($t2)	# (E Line2)
	sw   $t1, 32($t2)	# (V Line2)
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# (E2 Line2)
	sw   $t1, 64($t2)	# (L2 Line2)
	addi $t2, $t2, WIDTH 	# Moves pointer down 1 line
	sw   $t1, 0($t2)	# (L Line1)
	sw   $t1, 16($t2)	# (E Line1)
	sw   $t1, 20($t2)	# ^
	sw   $t1, 32($t2)	# (V Line1)
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# (E2 Line1)
	sw   $t1, 52($t2)	# ^
	sw   $t1, 64($t2)	# (L2 Line1)
	addi $t2, $t2, WIDTH 	# Moves pointer down 1 line
	sw   $t1, 0($t2)	# (L Line1)
	sw   $t1, 16($t2)	# (E Line1)
	sw   $t1, 32($t2)	# (V Line1)
	sw   $t1, 40($t2)	# ^
	sw   $t1, 48($t2)	# (E2 Line1)
	sw   $t1, 64($t2)	# (L2 Line1)
	addi $t2, $t2, WIDTH 	# Moves pointer down 1 line
	sw   $t1, 0($t2)	# (L Line1)
	sw   $t1, 4($t2)	# ^
	sw   $t1, 8($t2)	# ^
	sw   $t1, 16($t2)	# (E Line1)
	sw   $t1, 20($t2)	# ^
	sw   $t1, 24($t2)	# ^
	sw   $t1, 36($t2)	# (V Line1)
	sw   $t1, 48($t2)	# (E2 Line1)
	sw   $t1, 52($t2)	# ^
	sw   $t1, 56($t2)	# ^
	sw   $t1, 64($t2)	# (L2 Line1)
	sw   $t1, 68($t2)	# ^
	sw   $t1, 72($t2)	# ^
	addi $t2, $t2, BWIDTH 	# Moves pointer down 2 lines
	sw   $t1, 8($t2)	# Draws 1(Line 1)
	addi $t2, $t2, WIDTH	# Moves pointer down 1 line
	sw   $t1, 8($t2)	# Draws 1(Line 2)
	addi $t2, $t2, WIDTH	# Moves pointer down 1 line
	sw   $t1, 8($t2)	# Draws 1(Line 3)
	addi $t2, $t2, WIDTH	# Moves pointer down 1 line
	sw   $t1, 8($t2)	# Draws 1(Line 4)
	addi $t2, $t2, WIDTH	# Moves pointer down 1 line
	sw   $t1, 8($t2)	# Draws 1(Line 5)
	jr   $ra
	
# Function: Draws the title screen
# Input: None
# Used Registers: $t0, $t1, $a2, $t2
drawTitle:
	addi $sp, $sp, -4	# Adds space into stack pointer
	sw   $ra, 0($sp)	# Stores the return position into stack
	li   $t0, BASE_ADDRESS	# Sets initial location for title
	addi $t0, $t0, CWIDTH	# ^
	addi $t0, $t0, WIDTH	# ^
	addi $t0, $t0, 4 	# ^
	li   $t1, WHITE		# Loads color of title screen
	# Draws the title screen: Press p to start; Press x to quit; SCORE : (scores); SCOREHI : (hiScore)
	sw   $t1, 0($t0)	# P1 line 1
	sw   $t1, 4($t0)	# ^
	sw   $t1, 16($t0)	# R1 line 1
	sw   $t1, 20($t0)	# ^
	sw   $t1, 32($t0)	# E line 1
	sw   $t1, 36($t0)	# ^
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# S1 line 1
	sw   $t1, 52($t0)	# ^
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# S2 line 1
	sw   $t1, 68($t0)	# ^
	sw   $t1, 72($t0)	# ^
	sw   $t1, 96($t0)	# P2 line 1
	sw   $t1, 100($t0)	# ^
	sw   $t1, 128($t0)	# T1 line 1
	sw   $t1, 132($t0)	# ^
	sw   $t1, 136($t0)	# ^
	sw   $t1, 148($t0)	# O line 1
	sw   $t1, 176($t0)	# S3 line 1
	sw   $t1, 180($t0)	# ^
	sw   $t1, 184($t0)	# ^
	sw   $t1, 192($t0)	# T2 line1
	sw   $t1, 196($t0)	# ^
	sw   $t1, 200($t0)	# ^
	sw   $t1, 212($t0)	# A line 1
	sw   $t1, 224($t0)	# R line 1
	sw   $t1, 228($t0)	# ^
	sw   $t1, 240($t0)	# T3 line 1
	sw   $t1, 244($t0)	# ^
	sw   $t1, 248($t0)	# ^
	addi $t0, $t0, WIDTH	# Move down one line
	sw   $t1, 0($t0)	# P1 line 2
	sw   $t1, 8($t0)	# ^
	sw   $t1, 16($t0)	# R1 line 2
	sw   $t1, 24($t0)	# ^
	sw   $t1, 32($t0)	# E line 2
	sw   $t1, 48($t0)	# S1 line 2
	sw   $t1, 64($t0)	# S2 line 2
	sw   $t1, 96($t0)	# P2 line 2
	sw   $t1, 104($t0)	# ^
	sw   $t1, 132($t0)	# T1 line 2
	sw   $t1, 144($t0)	# O line 2
	sw   $t1, 152($t0)	# ^
	sw   $t1, 176($t0)	# S3 line 2
	sw   $t1, 196($t0)	# T2 line2
	sw   $t1, 208($t0)	# A line 2
	sw   $t1, 216($t0)
	sw   $t1, 224($t0)	# R line 2
	sw   $t1, 232($t0)	# ^
	sw   $t1, 244($t0)	# T3 line 2
	addi $t0, $t0, WIDTH	# Move down one line
	sw   $t1, 0($t0)	# P1 line 3
	sw   $t1, 4($t0)	# ^
	sw   $t1, 16($t0)	# R1 line 3
	sw   $t1, 20($t0)	# ^
	sw   $t1, 32($t0)	# E line 3
	sw   $t1, 36($t0)	# ^
	sw   $t1, 48($t0)	# S1 line 3
	sw   $t1, 52($t0)	# ^
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# S2 line 3
	sw   $t1, 68($t0)	# ^
	sw   $t1, 72($t0)	# ^
	sw   $t1, 96($t0)	# P2 line 3
	sw   $t1, 100($t0)	# ^
	sw   $t1, 132($t0)	# T1 line 3
	sw   $t1, 144($t0)	# O line 3
	sw   $t1, 152($t0)	# ^
	sw   $t1, 176($t0)	# S3 line 3
	sw   $t1, 180($t0)	# ^
	sw   $t1, 184($t0)	# ^
	sw   $t1, 196($t0)	# T2 line 3 
	sw   $t1, 208($t0)	# A line 3
	sw   $t1, 212($t0)	# ^
	sw   $t1, 216($t0)	# ^
	sw   $t1, 224($t0)	# R line 3
	sw   $t1, 228($t0)	# ^
	sw   $t1, 244($t0)	# T3 line 3
	addi $t0, $t0, WIDTH	# Move down one line
	sw   $t1, 0($t0)	# P1 line 4
	sw   $t1, 16($t0)	# R1 line 4
	sw   $t1, 24($t0)	# ^
	sw   $t1, 32($t0)	# E line 4
	sw   $t1, 56($t0)	# S1 line 4
	sw   $t1, 72($t0)	# S2 line 4
	sw   $t1, 96($t0)	# P2 line 4
	sw   $t1, 132($t0)	# T1 line 4
	sw   $t1, 144($t0)	# O line 4
	sw   $t1, 152($t0)	# ^
	sw   $t1, 184($t0)	# S3 line 4
	sw   $t1, 196($t0)	# T2 line 4 
	sw   $t1, 208($t0)	# A line 4
	sw   $t1, 216($t0)	# ^
	sw   $t1, 224($t0)	# R line 4
	sw   $t1, 232($t0)	# ^
	sw   $t1, 244($t0)	# T3 line 4
	addi $t0, $t0, WIDTH	# Move down one line
	sw   $t1, 0($t0)	# P1 line 5
	sw   $t1, 16($t0)	# R1 line 5
	sw   $t1, 24($t0)	# ^
	sw   $t1, 32($t0)	# E line 5
	sw   $t1, 36($t0)	# ^
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# S1 line 5
	sw   $t1, 52($t0)	# ^
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# S2 line 5
	sw   $t1, 68($t0)	# ^
	sw   $t1, 72($t0)	# ^
	sw   $t1, 96($t0)	# P2 line 5
	sw   $t1, 132($t0)	# T1 line 5
	sw   $t1, 148($t0)	# O line 5
	sw   $t1, 176($t0)	# S3 line 5
	sw   $t1, 180($t0)	# ^
	sw   $t1, 184($t0)	# ^
	sw   $t1, 196($t0)	# T2 line 5 
	sw   $t1, 208($t0)	# A line 5
	sw   $t1, 216($t0)	# ^
	sw   $t1, 224($t0)	# R line 5
	sw   $t1, 232($t0)	# ^
	sw   $t1, 244($t0)	# T3 line 5
	addi $t0, $t0, CWIDTH	# Move to next line
	sw   $t1, 0($t0)	# P line 1
	sw   $t1, 4($t0)	# ^
	sw   $t1, 16($t0)	# R1 line 1
	sw   $t1, 20($t0)	# ^
	sw   $t1, 32($t0)	# E1 line 1
	sw   $t1, 36($t0)	# ^
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# S1 line 1
	sw   $t1, 52($t0)	# ^
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# S2 line 1
	sw   $t1, 68($t0)	# ^
	sw   $t1, 72($t0)	# ^
	sw   $t1, 96($t0)	# X1 line 1
	sw   $t1, 104($t0)	# ^
	sw   $t1, 128($t0)	# T1 line 1
	sw   $t1, 132($t0)	# ^
	sw   $t1, 136($t0)	# ^
	sw   $t1, 148($t0)	# O line 1
	sw   $t1, 176($t0)	# E2 line 1
	sw   $t1, 180($t0)	# ^
	sw   $t1, 184($t0)	# ^
	sw   $t1, 192($t0)	# X2 line1
	sw   $t1, 200($t0)	# ^
	sw   $t1, 212($t0)	# I line 1
	sw   $t1, 224($t0)	# T2 line 1
	sw   $t1, 228($t0)	# ^
	sw   $t1, 232($t0)	# ^
	addi $t0, $t0, WIDTH	# Move down one line
	sw   $t1, 0($t0)	# P line 2
	sw   $t1, 8($t0)	# ^
	sw   $t1, 16($t0)	# R1 line 2
	sw   $t1, 24($t0)	# ^
	sw   $t1, 32($t0)	# E1 line 2
	sw   $t1, 48($t0)	# S1 line 2
	sw   $t1, 64($t0)	# S2 line 2
	sw   $t1, 96($t0)	# X1 line 2
	sw   $t1, 104($t0)	# ^
	sw   $t1, 132($t0)	# T1 line 2
	sw   $t1, 144($t0)	# O line 2
	sw   $t1, 152($t0)	# ^
	sw   $t1, 176($t0)	# E2 line 2
	sw   $t1, 192($t0)	# X2 line2
	sw   $t1, 200($t0)	# ^
	sw   $t1, 212($t0)	# I line 2
	sw   $t1, 228($t0)	# T line 2
	addi $t0, $t0, WIDTH	# Move down one line
	sw   $t1, 0($t0)	# P line 3
	sw   $t1, 4($t0)	# ^
	sw   $t1, 16($t0)	# R1 line 3
	sw   $t1, 20($t0)	# ^
	sw   $t1, 32($t0)	# E1 line 3
	sw   $t1, 36($t0)	# ^
	sw   $t1, 48($t0)	# S1 line 3
	sw   $t1, 52($t0)	# ^
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# S2 line 3
	sw   $t1, 68($t0)	# ^
	sw   $t1, 72($t0)	# ^
	sw   $t1, 100($t0)	# X1 line 3
	sw   $t1, 132($t0)	# T1 line 3
	sw   $t1, 144($t0)	# O line 3
	sw   $t1, 152($t0)	# ^
	sw   $t1, 176($t0)	# E2 line 3
	sw   $t1, 180($t0)	# ^
	sw   $t1, 184($t0)	# ^
	sw   $t1, 196($t0)	# X2 line 3 
	sw   $t1, 212($t0)	# I line 3
	sw   $t1, 228($t0)	# T2 line 3
	addi $t0, $t0, WIDTH	# Move down one line
	sw   $t1, 0($t0)	# P line 4
	sw   $t1, 16($t0)	# R1 line 4
	sw   $t1, 24($t0)	# ^
	sw   $t1, 32($t0)	# E1 line 4
	sw   $t1, 56($t0)	# S1 line 4
	sw   $t1, 72($t0)	# S2 line 4
	sw   $t1, 96($t0)	# X1 line 4
	sw   $t1, 104($t0)	# ^
	sw   $t1, 132($t0)	# T1 line 4
	sw   $t1, 144($t0)	# O line 4
	sw   $t1, 152($t0)	# ^
	sw   $t1, 176($t0)	# E2 line 4
	sw   $t1, 192($t0)	# X2 line 4
	sw   $t1, 200($t0)	# ^ 
	sw   $t1, 212($t0)	# I line 4
	sw   $t1, 228($t0)	# T2 line 4
	addi $t0, $t0, WIDTH	# Move down one line
	sw   $t1, 0($t0)	# P line 5
	sw   $t1, 16($t0)	# R1 line 5
	sw   $t1, 24($t0)	# ^
	sw   $t1, 32($t0)	# E1 line 5
	sw   $t1, 36($t0)	# ^
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# S1 line 5
	sw   $t1, 52($t0)	# ^
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# S2 line 5
	sw   $t1, 68($t0)	# ^
	sw   $t1, 72($t0)	# ^
	sw   $t1, 96($t0)	# X1 line 5
	sw   $t1, 104($t0)	# ^
	sw   $t1, 132($t0)	# T1 line 5
	sw   $t1, 148($t0)	# O line 5
	sw   $t1, 176($t0)	# E2 line 5
	sw   $t1, 180($t0)	# ^
	sw   $t1, 184($t0)	# ^
	sw   $t1, 192($t0)	# X2 line 5
	sw   $t1, 200($t0)	# ^ 
	sw   $t1, 212($t0)	# I line 5
	sw   $t1, 228($t0)	# T2 line 5
	addi $t0, $t0, CWIDTH	# Go to score display
	addi $a0, $t0, 92	# Goes to first score number position 
	la   $a2, scores	# Loads the address of scores into $a2
	lw   $a1, 16($a2)	# Loads the first score
	addi $t2, $t0, 0	# Moves $t0 to $t2
	jal  drawNumbers	# Draws the first score
	addi $t0, $t2, 0	# Moves $t2 back to $t0
	addi $a0, $t0, 108	# Goes to the second score number position
	lw   $a1, 12($a2)	# Loads the second score
	addi $t2, $t0, 0	# Moves $t0 to $t2
	jal  drawNumbers	# Draws the second score
	addi $t0, $t2, 0	# Moves $t2 back to $t0
	addi $a0, $t0, 124	# Goes to the third score number position
	lw   $a1, 8($a2)	# Loads the third score
	addi $t2, $t0, 0	# Moves $t0 to $t2
	jal  drawNumbers	# Draws the third score
	addi $t0, $t2, 0	# Moves $t2 back to $t0
	addi $a0, $t0, 140	# Goes to the fourth score number position
	lw   $a1, 4($a2)	# Loads the fourth score
	addi $t2, $t0, 0	# Moves $t0 to $t2
	jal  drawNumbers	# Draws the fourth score
	addi $t0, $t2, 0	# Moves $t2 back to $t0
	addi $a0, $t0, 156	# Goes to the fifth score number position
	lw   $a1, 0($a2)	# Loads the fifth score
	addi $t2, $t0, 0	# Moves $t0 to $t2
	jal  drawNumbers	# Draws the fifth score
	addi $t0, $t2, 0	# Moves $t2 back to $t0
	sw   $t1, 0($t0)	# Draws the score(S Line1) 
	sw   $t1, 4($t0)	# ^
	sw   $t1, 8($t0)	# ^
	sw   $t1, 16($t0)	# (C Line1)
	sw   $t1, 20($t0)	# ^
	sw   $t1, 24($t0)	# ^
	sw   $t1, 32($t0)	# (O Line1)
	sw   $t1, 36($t0)	# ^
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# (R Line1)
	sw   $t1, 52($t0)	# ^
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# (E Line1)
	sw   $t1, 68($t0)	# ^
	sw   $t1, 72($t0)	# ^
	addi $t0, $t0, WIDTH	# Moves pointer down 1 line
	sw   $t1, 0($t0)	# (S Line2)
	sw   $t1, 16($t0)	# (C Line2)
	sw   $t1, 32($t0)	# (O Line2)
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# (R Line2)
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# (E Line2)
	sw   $t1, 80($t0)	# Colon Line2
	addi $t0, $t0, WIDTH	# Moves pointer down 1 line
	sw   $t1, 0($t0)	# (S Line3)
	sw   $t1, 4($t0)	# ^
	sw   $t1, 8($t0)	# ^
	sw   $t1, 16($t0)	# (C Line3)
	sw   $t1, 32($t0)	# (O Line3)
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# (R Line3)
	sw   $t1, 52($t0)	# ^
	sw   $t1, 64($t0)	# (E Line3)
	sw   $t1, 68($t0)	# ^
	sw   $t1, 72($t0)	# ^
	addi $t0, $t0, WIDTH	 # Moves pointer down 1 line
	sw   $t1, 8($t0)	# (S Line4)
	sw   $t1, 16($t0)	# (C Line4)
	sw   $t1, 32($t0)	# (O Line4)
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# (R Line4)
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# (E Line4)
	sw   $t1, 80($t0)	# Colon Line4
	addi $t0, $t0, WIDTH 	# Moves pointer down 1 line
	sw   $t1, 0($t0)	# (S Line5)
	sw   $t1, 4($t0)	# ^
	sw   $t1, 8($t0)	# ^
	sw   $t1, 16($t0)	# (C Line5)
	sw   $t1, 20($t0)	# ^
	sw   $t1, 24($t0)	# ^
	sw   $t1, 32($t0)	# (O Line5)
	sw   $t1, 36($t0)	# ^
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# (R Line5)
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# (E Line5)
	sw   $t1, 68($t0)	# ^
	sw   $t1, 72($t0)	# ^
	addi $t0, $t0, CWIDTH	# Go to score display
	addi $a0, $t0, 140	# Goes to first score number position 
	la   $a2, hiScore	# Loads the address of hiScore into $a2
	lw   $a1, 16($a2)	# Loads the first score
	addi $t2, $t0, 0	# Moves $t0 to $t2
	jal  drawNumbers	# Draws the first score
	addi $t0, $t2, 0	# Moves $t2 back to $t0
	addi $a0, $t0, 156	# Goes to the second score number position
	lw   $a1, 12($a2)	# Loads the second score
	addi $t2, $t0, 0	# Moves $t0 to $t2
	jal  drawNumbers	# Draws the second score
	addi $t0, $t2, 0	# Moves $t2 back to $t0
	addi $a0, $t0, 172	# Goes to the third score number position
	lw   $a1, 8($a2)	# Loads the third score
	addi $t2, $t0, 0	# Moves $t0 to $t2
	jal  drawNumbers	# Draws the third score
	addi $t0, $t2, 0	# Moves $t2 back to $t0
	addi $a0, $t0, 188	# Goes to the fourth score number position
	lw   $a1, 4($a2)	# Loads the fourth score
	addi $t2, $t0, 0	# Moves $t0 to $t2
	jal  drawNumbers	# Draws the fourth score
	addi $t0, $t2, 0	# Moves $t2 back to $t0
	addi $a0, $t0, 204	# Goes to the fifth score number position
	lw   $a1, 0($a2)	# Loads the fifth score
	addi $t2, $t0, 0	# Moves $t0 to $t2
	jal  drawNumbers	# Draws the fifth score
	addi $t0, $t2, 0	# Moves $t2 back to $t0
	sw   $t1, 0($t0)	# Draws the score(S Line1) 
	sw   $t1, 4($t0)	# ^
	sw   $t1, 8($t0)	# ^
	sw   $t1, 16($t0)	# (C Line1)
	sw   $t1, 20($t0)	# ^
	sw   $t1, 24($t0)	# ^
	sw   $t1, 32($t0)	# (O Line1)
	sw   $t1, 36($t0)	# ^
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# (R Line1)
	sw   $t1, 52($t0)	# ^
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# (E Line1)
	sw   $t1, 68($t0)	# ^
	sw   $t1, 72($t0)	# ^
	sw   $t1, 80($t0)	# H Line1
	sw   $t1, 88($t0)	# ^
	sw   $t1, 100($t0)	# I Line1
	addi $t0, $t0, WIDTH	# Moves pointer down 1 line
	sw   $t1, 0($t0)	# (S Line2)
	sw   $t1, 16($t0)	# (C Line2)
	sw   $t1, 32($t0)	# (O Line2)
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# (R Line2)
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# (E Line2)
	sw   $t1, 80($t0)	# H Line2
	sw   $t1, 88($t0)	# ^
	sw   $t1, 100($t0)	# I Line2
	sw   $t1, 116($t0)	# Colon Line2
	addi $t0, $t0, WIDTH	# Moves pointer down 1 line
	sw   $t1, 0($t0)	# (S Line3)
	sw   $t1, 4($t0)	# ^
	sw   $t1, 8($t0)	# ^
	sw   $t1, 16($t0)	# (C Line3)
	sw   $t1, 32($t0)	# (O Line3)
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# (R Line3)
	sw   $t1, 52($t0)	# ^
	sw   $t1, 64($t0)	# (E Line3)
	sw   $t1, 68($t0)	# ^
	sw   $t1, 72($t0)	# ^
	sw   $t1, 80($t0)	# H Line3
	sw   $t1, 84($t0)	# ^
	sw   $t1, 88($t0)	# ^
	sw   $t1, 100($t0)	# I Line3
	addi $t0, $t0, WIDTH	 # Moves pointer down 1 line
	sw   $t1, 8($t0)	# (S Line4)
	sw   $t1, 16($t0)	# (C Line4)
	sw   $t1, 32($t0)	# (O Line4)
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# (R Line4)
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# (E Line4)
	sw   $t1, 80($t0)	# H Line4
	sw   $t1, 88($t0)	# ^
	sw   $t1, 100($t0)	# I Line4
	sw   $t1, 116($t0)	# Colon Line4
	addi $t0, $t0, WIDTH 	# Moves pointer down 1 line
	sw   $t1, 0($t0)	# (S Line5)
	sw   $t1, 4($t0)	# ^
	sw   $t1, 8($t0)	# ^
	sw   $t1, 16($t0)	# (C Line5)
	sw   $t1, 20($t0)	# ^
	sw   $t1, 24($t0)	# ^
	sw   $t1, 32($t0)	# (O Line5)
	sw   $t1, 36($t0)	# ^
	sw   $t1, 40($t0)	# ^
	sw   $t1, 48($t0)	# (R Line5)
	sw   $t1, 56($t0)	# ^
	sw   $t1, 64($t0)	# (E Line5)
	sw   $t1, 68($t0)	# ^
	sw   $t1, 72($t0)	# ^
	sw   $t1, 80($t0)	# H Line5
	sw   $t1, 88($t0)	# ^
	sw   $t1, 100($t0)	# I Line5
	lw   $ra, 0($sp)	# Pops return position from stack
	addi $sp, $sp, 4	# Reduces size of stack
	jr   $ra		# Jump back

# Function: Changes the score in the Game GUI
# Input: None
# Used Registers: $a0, $a1, $a2
change:
	addi $sp, $sp, -4		# Adds space onto the stack pointer
	sw   $ra, 0($sp)		# Stores the jump back location into the stack pointer
	li   $a2, END_ADDRESS		# Initializes where the scoreGUI is
	addi $a2, $a2, CWIDTH		# ^
	addi $a2, $a2, CWIDTH		# ^
	addi $a2, $a2, CWIDTH		# ^
	addi $a0, $a2, 68		# ^
	la   $a1, scores		# Initializes the score number location
	jal  increase
	beqz $v0, endchange		# If there is no carry over, then finish the changes
	la   $a1, scores		# Initializes the score number location
	addi $a1, $a1, 4		# Goes to the next number in the array
	addi $a0, $a2, 52		# initializes scoreGUI location
	jal  increase
	beqz $v0, endchange		# If there is no carray over, then finish the changes
	la   $a1, scores		# Initializes the score number location
	addi $a1, $a1, 8		# Goes to the next number in the array
	addi $a0, $a2, 36		# initializes scoreGUI location
	jal  increase
	beqz $v0, endchange		# If there is no carray over, then finish the changes
	la   $a1, scores		# Initializes the score number location
	addi $a1, $a1, 12		# Goes to the next number in the array
	addi $a0, $a2, 20		# initializes scoreGUI location
	jal  increase
	beqz $v0, endchange		# If there is no carray over, then finish the changes
	la   $a1, scores		# Initializes the score number location
	addi $a1, $a1, 16		# Goes to the next number in the array
	addi $a0, $a2, 4		# initializes scoreGUI location
	jal  increase
endchange:
	lw   $ra, 0($sp)		# loads the stored jump back location from the stack pointer
	addi $sp, $sp, 4		# Pops off the stack pointer
	jr   $ra
# Function: Increments the Score in game GUI
# Input: $a0(Location of GUI number), $a1(Location of stored number)
# Return Register: $v0(Stores whether next number should also be increased)
# Used Registers: $a0, $a1, $s0, $t1, $v0
increase: 
	li   $v0, 0			# Sets return to 0
	lw   $t1, 0($a1)		# Stores the score in $s2
	addi $t1, $t1, 1		# Increases score by 1
	bne  $t1, 10, here		# Checks if score becomes 10
	addi $v0, $v0, 1		# Increases $v0 by 1
	li   $t1, 0			# Sets score back to 0
here:	sw   $t1, 0($a1)		# Stores the score back into the scores array
	lw   $a1, 0($a1)		# Stores the value into $a1
drawNumbers:
	beq  $a1, 1, drawone		# Draws the number accordingly
	beq  $a1, 2, drawtwo		# Draws the number accordingly
	beq  $a1, 3, drawthree		# Draws the number accordingly
	beq  $a1, 4, drawfour		# Draws the number accordingly
	beq  $a1, 5, drawfive		# Draws the number accordingly
	beq  $a1, 6, drawsix		# Draws the number accordingly
	beq  $a1, 7, drawseven		# Draws the number accordingly
	beq  $a1, 8, draweight		# Draws the number accordingly
	beq  $a1, 9, drawnine		# Draws the number accordingly
	j    drawzero
drawzero: 
	li   $t0, WHITE		# Loads the color white
	sw   $t0, 0($a0)	# Changes number to 0
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $zero, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	jr   $ra
drawone: 
	li   $t0, WHITE		# Loads the color white
	sw   $zero, 0($a0)	# Changes number to 1
	sw   $zero, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $zero, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $zero, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	jr   $ra
drawtwo: 
	li   $t0, WHITE		# Loads the color white
	sw   $t0, 0($a0)	# Changes number to 2
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $zero, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	jr   $ra
drawthree: 
	li   $t0, WHITE		# Loads the color white
	sw   $t0, 0($a0)	# Changes number to 3
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	jr   $ra
drawfour: 
	li   $t0, WHITE		# Loads the color white
	sw   $t0, 0($a0)	# Changes number to 4
	sw   $zero, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $zero, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	jr   $ra
drawfive: 
	li   $t0, WHITE		# Loads the color white
	sw   $t0, 0($a0)	# Changes number to 5
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $zero, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	jr   $ra
drawsix: 
	li   $t0, WHITE		# Loads the color white
	sw   $t0, 0($a0)	# Changes number to 6
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $zero, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	jr   $ra
drawseven: 
	li   $t0, WHITE		# Loads the color white
	sw   $t0, 0($a0)	# Changes number to 7
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $zero, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $zero, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	jr   $ra
draweight: 
	li   $t0, WHITE		# Loads the color white
	sw   $t0, 0($a0)	# Changes number to 8
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	jr   $ra
drawnine: 
	li   $t0, WHITE		# Loads the color white
	sw   $t0, 0($a0)	# Changes number to 9
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $zero, 0($a0)	# ^
	sw   $t0, 8($a0)	# ^
	addi $a0, $a0, WIDTH	# ^
	sw   $t0, 0($a0)	# ^
	sw   $t0, 4($a0)	# ^
	sw   $t0, 8($a0)	# ^
	jr   $ra
	
# Function: Increases the level the player is on
# Input: None
# Used Registers: $t2, $a0, $a1
# Output: None
levelup:
	addi $sp, $sp, -4	# Adds space into stack
	sw   $ra, 0($sp)	# Stores jump into stack
	li   $t2, END_ADDRESS	# Stores the value of the GUI part of the screen
	addi $t2, $t2, 0x1504	# Jumps down to level number
	addi $a0, $t2, 0	# Stores $t2 into $a0 for score increment function
	la   $a1, level		# Stores the value of the level
	
	jal  increase		# Calls function that increases number by 1
	
	lw   $ra, 0($sp)	# Puts jump back into stack
	addi $sp, $sp, 4	# Removes space from stack
	jr   $ra
	
# Function: Removes health off of health bar for every hit taken
# Input: None
# Output: $v0(0 if there is health left, 1 if there is no health left)
# Used Registers: $v0, $t0
reduceHealth:
	lw   $t0, health	# Loads the health offset into $t0
	addi $t0, $t0, END_ADDRESS	# Sets $t0 to point to rightmost part of health bar
	sw   $zero, 0($t0)	# Erases health at location chosen
	subi $t0, $t0, END_ADDRESS	# Removes the end address to get health offset
	addi $t0, $t0, -4	# Goes to the left 1 pixel
	sw   $t0, health	# Stores the new rightmost part back into health
	beqz $t0, returnDead	# Checks if there is health left
	li   $v0, 0		# Returns that there is health left
	jr   $ra		# ^
returnDead:
	li   $v0, 1		# Returns that there is no health left
	jr   $ra		# ^

# Helper function that when jumped to, always jumps back to where function was called
Done:   jr   $ra		# Finishes a function
