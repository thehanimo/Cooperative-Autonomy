globals [
  lanes              ; a list of the y coordinates of different lanes
  turtlebreedset     ; a list containing all the names of breeds
  lanechangeattempts ; number of attempts to change lane.
  crashcount         ; number of total crashes
  spawncount         ; number of vehicles spawned
  car-acceleration
  car-cruising-speed
  anylaneblocked?
  total-travel-time
  avg-travel-time
  exitcount
]

breed [cars car]
breed [blockades blockade]

turtles-own [
  speed            ; (float) the current speed of the vehicle
  cruising-speed   ; (float) the maximum speed of the vehicle (different for all vehicles)
  target-lane      ; (int)   the desired lane of the vehicle
  acceleration     ; (float) the driver's average acceleration
  deceleration     ; (float) the driver's average acceleration
  crashed?         ; (bool)  if the driver has crashed the vehicle
  crash-tick       ; (int)   contains the time of crash of vehicle
  blockade?
  enter-tick
]

to spawn [ breedname ycord] ; Common spawn function for all vehicle types
  let breedshape (word breedname "-top")
  create-turtles (1)[
    run (word "set breed " breedname "s")
    set shape breedshape
    set color vehicle-color
    move-to patch ((- world-width + 1) / 2) ycord
    set target-lane ycor
    set heading 90
    set cruising-speed runresult(word breedname "-cruising-speed")
    set speed runresult(word breedname "-cruising-speed")
    set acceleration runresult(word breedname "-acceleration")
    set deceleration runresult(word breedname "-acceleration") * 3
    set crashed? false
    set blockade? false
    set enter-tick ticks
  ]
  set spawncount spawncount + 1
end

to spawn-blockade [ ycord] ; Common spawn function for all vehicle types
  let breedshape (word "car-top")
  create-turtles (1)[
    run (word "set breed blockades")
    set shape breedshape
    set color 20
    move-to patch ((- world-width + 200) / 2) ycord
    set target-lane ycor
    set heading 90
    set cruising-speed 0
    set speed 0
    set acceleration 0
    set deceleration 0
    set crashed? false
    set blockade? true
  ]
end

to toggle-blockade
  ifelse count turtles with [blockade? = true] = 0 [
    spawn-blockade one-of lanes
    set anylaneblocked? true
  ][
    ask turtles with [blockade? = true] [ die ]
    set anylaneblocked? false
  ]
end

to decide-vehicles ;Related to setups
  foreach n-values 3 [i -> i + 1][i ->
    set car-acceleration 0.028
    set car-cruising-speed 0.894
    set turtlebreedset (list "car")
  ]
end

to setup
  clear-all
  reset-ticks
  set crashcount 0     ; reset the amount of crashes
  decide-vehicles
  draw-road
  spawn-vehicles
  set anylaneblocked? false
  set avg-travel-time 0
  set total-travel-time 0
  set exitcount 0
  reset-ticks
end

to spawn-vehicles
  if not any? turtles with [ xcor <= ((- world-width + 6) / 2) ][ ;make sure there are no turtles in the first column of the world.
    let number-of-vehicles random length lanes          ; randomly select the number of lanes that will have vehicles spawning this tick.
    foreach n-of number-of-vehicles lanes[ lane ->       ; randomly select the lanes and iterate
      spawn "car" lane
    ]
  ]
end

to draw-road
  ask patches [ set pcolor green - random-float 0.5 ]    ; the road is surrounded by green grass of varying shades
  set lanes n-values number-of-lanes [ n -> number-of-lanes - (n * 2) - 1 ]
  ask patches with [ abs pycor <= number-of-lanes ] [ set pcolor grey - 2.5 + random-float 0.25 ]   ; the road itself is varying shades of grey
  draw-road-lines
end

to draw-road-lines
  let y (last lanes) - 1 ; start below the "lowest" lane
  while [ y <= first lanes + 1 ] [
    if not member? y lanes [     ; draw lines on road patches that are not part of a lane
      ifelse abs y = number-of-lanes [ draw-line y yellow 0 ] [ draw-line y white 0.5 ] ; yellow for the sides of the road and dashed white between lanes
    ]
    set y y + 1 ; move up one patch
  ]
end

to draw-line [ y line-color gap ]
  ; We use a temporary turtle to draw the line:
  ; - with a gap of zero, we get a continuous line;
  ; - with a gap greater than zero, we get a dasshed line.
  create-turtles 1 [
    setxy (min-pxcor - 0.5) y
    hide-turtle
    set color line-color
    set heading 90
    repeat world-width [
      pen-up
      forward gap
      pen-down
      forward (1 - gap)
    ]
    die
  ]
end

to go
  spawn-vehicles
  ask turtles with [ crashed? and ticks - crash-tick > 3][ die ]   ; kill turtles that are alive for more than 3 ticks after crashing
  foreach sort-on [(- xcor)] turtles [ [vehicle] ->                ; sort turtles based on xcor in decending order.
    ask vehicle [
      if not crashed?[             ; do only if turtle has not crashed.
        ;if ( patience <= 0 )[ choose-new-lane ]
        if ( ycor != target-lane ) [ move-to-target-lane ]
      ]
      move-forward
      if not crashed?[ crash-check ]
    ]
  ]
  ask turtles with [xcor > ((world-width - 4) / 2)][
    set total-travel-time total-travel-time + ticks - enter-tick
    set exitcount exitcount + 1
    set avg-travel-time total-travel-time / exitcount
    die
  ]  ;kill the turtles that reached the end of the world
  tick
end

to move-forward ; turtle procedure
  set heading 90
  ifelse not crashed?[
    speed-up-car ; we tentatively speed up, but might have to slow down
    let blocking-vehicles other turtles in-cone (2 + speed) 180 with [ y-distance <= 0.75 ]
    let blocking-vehicle min-one-of blocking-vehicles [ distance myself ]
    if blocking-vehicle != nobody [
      ; if you are able to detect a vehicle ahead,
      ; match the speed of the car ahead of you and then slow
      ; down so you are driving a bit slower than that car.
      if [ speed ] of blocking-vehicle < speed [ set speed [ speed ] of blocking-vehicle ]
      ifelse [ blockade? ] of blocking-vehicle = true [
        set speed acceleration * 2
        ifelse ( ycor != target-lane ) [ move-to-target-lane ] [ choose-new-lane ]
      ] [ slow-down-car ]
    ]
  ][ crash-slow-down ]
  forward speed
  set xcor precision xcor 3    ; avoid floating point errors.
end

to slow-down-car ; turtle procedure
  set speed precision max(list 0 (speed - deceleration)) 3 ; reduce the speed
  ;set patience patience - 1 ; every time you hit the brakes, you loose a little patience
end

to speed-up-car ; turtle procedure
  set speed precision min(list cruising-speed (speed + acceleration)) 3 ; increase the speed by the amount of acceleration but do not exceed the top speed
end

to choose-new-lane ; turtle procedure
  ; Choose a new lane among those with the minimum
  ; distance to your current lane (i.e., your ycor).
  let other-lanes remove ycor lanes
  if not empty? other-lanes [
    let min-dist min map [ y -> abs (y - ycor) ] other-lanes
    let closest-lanes filter [ y -> abs (y - ycor) = min-dist ] other-lanes
    set target-lane one-of closest-lanes
    ;set patience max-patience
    set lanechangeattempts lanechangeattempts + 1
  ]
end

to move-to-target-lane ; turtle procedure
  set heading ifelse-value target-lane < ycor [ 145 ] [ 35 ]
  let blocking-vehicles other turtles in-cone (1 + abs (ycor - target-lane)) 180 with [ x-distance <= 1.25]
  let blocking-vehicle min-one-of blocking-vehicles [ distance myself ]
  ifelse blocking-vehicle = nobody [
    forward min (list 0.1 (0.2 * speed))         ; avoid unnatural changing of lanes. (instant turn)
    set ycor precision ycor 1 ; to avoid floating point errors
  ] [
    ifelse towards blocking-vehicle < 180 and towards blocking-vehicle > 0 [
      if [ y-distance ] of blocking-vehicle < 1 and [ speed ] of blocking-vehicle < speed [ set speed [ speed ] of blocking-vehicle ]
      slow-down-car
    ] [ speed-up-car ] ; slow down if the car blocking us is behind, otherwise speed up
  ]
end

to-report x-distance
  report distancexy [ xcor ] of myself ycor
end

to-report y-distance
  report distancexy xcor [ ycor ] of myself
end

to crash-check
  if any? other turtles in-cone 1 180 with [ y-distance < 0.5 and x-distance < 1 ][ ;0.5 is taken because thats when the turtles touch.
    crash
    ask other turtles in-cone 1 180 with [ y-distance < 0.5 and x-distance < 1 ][ crash ]
    set crashcount (crashcount + 1)
  ]
end

to crash ; turtle procedure
  if not crashed? [ inccount ]
  set color yellow
  set shape "fire"
  set crashed? true
  set crash-tick ticks
end

to inccount  ; turtle procedure
end

to crash-slow-down   ; turtle procedure
  set speed max(list 0 (speed - 1))
end

to-report vehicle-color
  report one-of [ blue cyan sky ] + 1.5 + random-float 1.0 ; give all vehicles a blueish color, but still make them distinguishable
end

; Copyright 1998 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
10
10
1288
349
-1
-1
10.0
1
10
1
1
1
0
0
0
1
-63
63
-16
16
1
1
1
ticks
30.0

BUTTON
10
365
75
400
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
150
365
215
400
go
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
0

BUTTON
80
365
145
400
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
130
445
215
490
mean speed
mean [speed] of turtles
2
1
11

SLIDER
10
405
215
438
number-of-lanes
number-of-lanes
1
8
8.0
1
1
NIL
HORIZONTAL

MONITOR
10
445
130
490
Number of crashes
crashcount
0
1
11

MONITOR
697
360
842
405
Lane Change Attempts
lanechangeattempts
1
1
11

MONITOR
695
410
840
455
Number of vehicle spawned
spawncount
17
1
11

BUTTON
295
375
427
408
NIL
toggle-blockade
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1045
420
1245
570
avg-travel-time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot avg-travel-time"

PLOT
805
500
1005
650
mean-speed
NIL
NIL
0.0
10.0
0.0
2.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [speed] of turtles"

@#$#@#$#@
## Changelog

### v1.0 13102019 DN
-Added turtlebreedset variable and iterated through it to create non-breed-specific functions. FutureNote : try to get rid of turtlebreedset and get it dynamically.
-Added 4 breeds Namely Cars,Trucks,Bikes and Rickshaws
-Wrote spawn function that spawns a turtle of the argument breed.
-Added free function that reports patches where the turtle will not be in the future tick, or the current tick or one patch behind the turtle.
-Revamped create-or-remove-vehicles function so that it now spawns one of each breed first to allow equal chances.
-Commented selected vehicle for convenience.

### v1.1 14102019 DN
-Rewrote changelane to provide smooth transition.
-Added Crashcheck function.
-reduced y-distance parameter in move-forward for more realistic mid-lane overtaking.
-Added probability-of-late-detection
-Added increased-variety
-Rewrote spawn-vehicles function to spawn vehicles using probability.
-Removed wraparound
-Vehicles now spawn with equal probability and die at the end of world.
-There is a 1 patch buffer after the spawn point of vehicles to avoid clogging.
-Removed selected vehicle.
-Removed free function.

### 1.2 15102019 DN
-Fixed bug where cars could pass through truck if they were fast enough.
-Removed all traces of selected vehicle.
-Bokare-values button is now called "Reset Vehicle Characteristics".
-Probability sliders are now used instead of hard-coded values.
-Everybody now starts with constant patience.
-Now bokare values include real deceleration.

### 1.3 16102019 DN
-Removed rickshaw-probability(redundant).
-Added crash count for each vehicle type.
-Removed all experiments and created new one named "Main".

### 1.4 18102019 DN
-All vehicles start with same probability-of-late-detection
-Added new breed : bus
-Added Chooser for preset setups(decide-vehicles, setprobs)

### 1.5 19102019 DN
-Removed start-speed
-Added Bus Shape

### 1.6 26102019 DN
-Fixed bug where crash checking was being done before moving forward.


## RELATED MODELS

- "Traffic Basic": a simple model of the movement of cars on a highway.

- "Traffic Basic Utility": a version of "Traffic Basic" including a utility function for the cars.

- "Traffic Basic Adaptive": a version of "Traffic Basic" where cars adapt their acceleration to try and maintain a smooth flow of traffic.

- "Traffic Basic Adaptive Individuals": a version of "Traffic Basic Adaptive" where each car adapts individually, instead of all cars adapting in unison.

- "Traffic Intersection": a model of cars traveling through a single intersection.

- "Traffic Grid": a model of traffic moving in a city grid, with stoplights at the intersections.

- "Traffic Grid Goal": a version of "Traffic Grid" where the cars have goals, namely to drive to and from work.

- "Gridlock HubNet": a version of "Traffic Grid" where students control traffic lights in real-time.

- "Gridlock Alternate HubNet": a version of "Gridlock HubNet" where students can enter NetLogo code to plot custom metrics.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. & Payette, N. (1998).  NetLogo Traffic 2 Lanes model.  http://ccl.northwestern.edu/netlogo/models/Traffic2Lanes.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1998 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 2001.

<!-- 1998 2001 Cite: Wilensky, U. & Payette, N. -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bike-top
true
0
Polygon -7500403 true true 135 180 120 135 120 105 135 90 165 90 180 105 180 135 165 180 135 180
Polygon -16777216 true false 165 285 135 285 120 195 135 165 165 165 180 195 165 285
Rectangle -16777216 true false 142 25 158 63
Polygon -7500403 true true 120 90 180 90 165 60 135 60 120 90
Polygon -7500403 true true 136 91 107 106 106 102 137 82 138 90
Polygon -7500403 true true 163 82 194 103 191 107 159 88 163 83
Polygon -16777216 true false 193 106 214 125 214 113 194 102
Polygon -16777216 true false 107 106 86 125 86 113 106 102

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

bus-top
true
0
Polygon -7500403 true true 150 15 120 15 90 30 90 45 90 225 90 270 105 285 150 285 195 285 210 270 210 225 210 45 210 30 180 15
Polygon -16777216 true false 106 58 194 58 204 44 182 36 153 32 120 36 98 44
Polygon -1 true false 205 29 180 30 182 16
Polygon -1 true false 95 29 120 30 118 16

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

car-top
true
0
Polygon -7500403 true true 151 8 119 10 98 25 86 48 82 225 90 270 105 289 150 294 195 291 210 270 219 225 214 47 201 24 181 11
Polygon -16777216 true false 210 195 195 210 195 135 210 105
Polygon -16777216 true false 105 255 120 270 180 270 195 255 195 225 105 225
Polygon -16777216 true false 90 195 105 210 105 135 90 105
Polygon -1 true false 205 29 180 30 181 11
Line -7500403 true 210 165 195 165
Line -7500403 true 90 165 105 165
Polygon -16777216 true false 121 135 180 134 204 97 182 89 153 85 120 89 98 97
Line -16777216 false 210 90 195 30
Line -16777216 false 90 90 105 30
Polygon -1 true false 95 29 120 30 119 11

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fire
false
0
Polygon -7500403 true true 151 286 134 282 103 282 59 248 40 210 32 157 37 108 68 146 71 109 83 72 111 27 127 55 148 11 167 41 180 112 195 57 217 91 226 126 227 203 256 156 256 201 238 263 213 278 183 281
Polygon -955883 true false 126 284 91 251 85 212 91 168 103 132 118 153 125 181 135 141 151 96 185 161 195 203 193 253 164 286
Polygon -2674135 true false 155 284 172 268 172 243 162 224 148 201 130 233 131 260 135 282

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

rickshaw-top
true
4
Rectangle -16777216 true false 60 210 75 270
Rectangle -16777216 true false 225 210 240 270
Polygon -1184463 true true 240 270 225 90 210 60 180 45 120 45 90 60 75 90 60 270 225 270 225 270
Rectangle -16777216 true false 144 6 157 31
Polygon -7500403 true false 120 45 135 30 165 30 180 45 120 45

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

truck-top
true
0
Polygon -7500403 true true 150 15 135 15 118 23 109 45 104 75 105 114 150 114
Polygon -7500403 true true 150 15 165 15 182 23 191 45 196 75 195 114 150 114
Rectangle -7500403 true true 90 120 210 285
Rectangle -7500403 true true 135 120 165 120
Rectangle -7500403 true true 135 105 165 135
Rectangle -16777216 true false 120 60 180 75
Polygon -16777216 true false 180 60 164 51 148 51 149 61
Polygon -16777216 true false 120 60 136 51 152 51 151 61
Polygon -1184463 true false 137 16 137 26 120 25
Polygon -1184463 true false 163 16 163 26 180 25
Line -16777216 false 193 136 194 275
Line -16777216 false 107 136 106 275
Line -16777216 false 177 139 177 279
Line -16777216 false 123 139 123 279
Line -16777216 false 158 143 157 279
Line -16777216 false 142 143 143 279

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Ratio" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>crashcount / spawncount</metric>
    <enumeratedValueSet variable="crash-deceleration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bike-cruising-speed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-cruising-speed">
      <value value="0.894"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bike-probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-cruising-speed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-acceleration">
      <value value="0.028"/>
    </enumeratedValueSet>
    <steppedValueSet variable="probability-of-late-detection" first="0.01" step="0.01" last="0.05"/>
    <enumeratedValueSet variable="vehicle-deceleration">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-cruising-speed">
      <value value="0.766"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-acceleration">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="world-setup">
      <value value="&quot;S1- US speeds, Decreased variance&quot;"/>
      <value value="&quot;S2 - Indian speeds, Increased variance&quot;"/>
      <value value="&quot;S3 - Indian speeds, Decreased variance&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-acceleration">
      <value value="0.017"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-patience" first="1" step="1" last="5"/>
    <enumeratedValueSet variable="bike-acceleration">
      <value value="0.015"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Crashes" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>crashcount</metric>
    <enumeratedValueSet variable="crash-deceleration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bike-cruising-speed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-cruising-speed">
      <value value="0.894"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bike-probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-cruising-speed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-acceleration">
      <value value="0.028"/>
    </enumeratedValueSet>
    <steppedValueSet variable="probability-of-late-detection" first="0.01" step="0.01" last="0.05"/>
    <enumeratedValueSet variable="vehicle-deceleration">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-cruising-speed">
      <value value="0.766"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-acceleration">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="world-setup">
      <value value="&quot;S1- US speeds, Decreased variance&quot;"/>
      <value value="&quot;S2 - Indian speeds, Increased variance&quot;"/>
      <value value="&quot;S3 - Indian speeds, Decreased variance&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-acceleration">
      <value value="0.017"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-patience" first="1" step="1" last="5"/>
    <enumeratedValueSet variable="bike-acceleration">
      <value value="0.015"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Spawns" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>spawncount</metric>
    <enumeratedValueSet variable="crash-deceleration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bike-cruising-speed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-cruising-speed">
      <value value="0.894"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bike-probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-cruising-speed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-acceleration">
      <value value="0.028"/>
    </enumeratedValueSet>
    <steppedValueSet variable="probability-of-late-detection" first="0.01" step="0.01" last="0.05"/>
    <enumeratedValueSet variable="vehicle-deceleration">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-cruising-speed">
      <value value="0.766"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-acceleration">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="world-setup">
      <value value="&quot;S1- US speeds, Decreased variance&quot;"/>
      <value value="&quot;S2 - Indian speeds, Increased variance&quot;"/>
      <value value="&quot;S3 - Indian speeds, Decreased variance&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-acceleration">
      <value value="0.017"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-patience" first="1" step="1" last="5"/>
    <enumeratedValueSet variable="bike-acceleration">
      <value value="0.015"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LaneChanges" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>lanechangeattempts</metric>
    <enumeratedValueSet variable="crash-deceleration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bike-cruising-speed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-cruising-speed">
      <value value="0.894"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bike-probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-cruising-speed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-acceleration">
      <value value="0.028"/>
    </enumeratedValueSet>
    <steppedValueSet variable="probability-of-late-detection" first="0.01" step="0.01" last="0.05"/>
    <enumeratedValueSet variable="vehicle-deceleration">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-cruising-speed">
      <value value="0.766"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-acceleration">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="world-setup">
      <value value="&quot;S1- US speeds, Decreased variance&quot;"/>
      <value value="&quot;S2 - Indian speeds, Increased variance&quot;"/>
      <value value="&quot;S3 - Indian speeds, Decreased variance&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-acceleration">
      <value value="0.017"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-patience" first="1" step="1" last="5"/>
    <enumeratedValueSet variable="bike-acceleration">
      <value value="0.015"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Ratio-long p1" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>crashcount / spawncount</metric>
    <enumeratedValueSet variable="crash-deceleration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bike-cruising-speed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-cruising-speed">
      <value value="0.894"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bike-probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-cruising-speed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-acceleration">
      <value value="0.028"/>
    </enumeratedValueSet>
    <steppedValueSet variable="probability-of-late-detection" first="0.01" step="0.01" last="0.1"/>
    <enumeratedValueSet variable="vehicle-deceleration">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-cruising-speed">
      <value value="0.766"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-acceleration">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="world-setup">
      <value value="&quot;S1- US speeds, Decreased variance&quot;"/>
      <value value="&quot;S2 - Indian speeds, Increased variance&quot;"/>
      <value value="&quot;S3 - Indian speeds, Decreased variance&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-acceleration">
      <value value="0.017"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-patience" first="1" step="1" last="5"/>
    <enumeratedValueSet variable="bike-acceleration">
      <value value="0.015"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Ratio-long p2" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>crashcount / spawncount</metric>
    <enumeratedValueSet variable="crash-deceleration">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bike-cruising-speed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-cruising-speed">
      <value value="0.894"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bike-probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-cruising-speed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-acceleration">
      <value value="0.028"/>
    </enumeratedValueSet>
    <steppedValueSet variable="probability-of-late-detection" first="0.01" step="0.01" last="0.1"/>
    <enumeratedValueSet variable="vehicle-deceleration">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-cruising-speed">
      <value value="0.766"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-acceleration">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="world-setup">
      <value value="&quot;S1- US speeds, Decreased variance&quot;"/>
      <value value="&quot;S2 - Indian speeds, Increased variance&quot;"/>
      <value value="&quot;S3 - Indian speeds, Decreased variance&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="truck-acceleration">
      <value value="0.017"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-patience" first="6" step="1" last="10"/>
    <enumeratedValueSet variable="bike-acceleration">
      <value value="0.015"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
