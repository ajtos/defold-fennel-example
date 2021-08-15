; Translated using antifennel and formated with fnlfmt

(local blocksize 96)
(local edge 80)
(local bottom-edge 80)
(local boardwidth 9)
(local boardheight 9)

(local colors {1 (hash :yellow)
               2 (hash :blue)
               3 (hash :orange)
               4 (hash :purple)
               5 (hash :green)
               6 (hash :red)})

(local type-plain (hash :plain))
(local type-striped-h (hash :striped-h))
(local type-striped-v (hash :striped-v))
(local type-wrapped (hash :wrapped))
(local type-bomb (hash :bomb))

(fn is-striped [fish]
  (or (= fish.type type-striped-v) (= fish.type type-striped-h)))

(fn is-wrapped [fish]
  (= fish.type type-wrapped))

(fn _G.init [self]
  (set self.board {})
  (set self.link {})
  (msg.post "#" :start_level)
  (msg.post "." :acquire_input_focus)
  (values))

(fn build-board []
  (let [board {}]
    (math.randomseed (os.time))
    (local pos (vmath.vector3))
    (local x 0)
    (local y 0)
    (for [x 0 (- boardwidth 1) 1]
      (set pos.x (+ (+ edge (/ blocksize 2)) (* blocksize x)))
      (tset board x {})
      (for [y 0 (- boardheight 1) 1]
        (set pos.y (+ (+ bottom-edge (/ blocksize 2)) (* blocksize y)))
        (local color (. colors (math.random (length colors))))
        (local type type-plain)
        (local id (factory.create "#fish_factory" pos null {: color}))
        (tset (. board x) y {: x : color : y : type : id})))
    board))

(fn collapse-board [board callback]
  (let [duration 0.3]
    (var dy 0)
    (local pos (vmath.vector3))
    (for [x 0 (- boardwidth 1) 1]
      (set dy 0)
      (for [y 0 (- boardheight 1) 1]
        (if (not= (. (. board x) y) nil)
            (when (> dy 0)
              (tset (. board x) (- y dy) (. (. board x) y))
              (tset (. board x) y nil)
              (tset (. (. board x) (- y dy)) :y
                    (- (. (. (. board x) (- y dy)) :y) dy))
              (go.animate (. (. (. board x) (- y dy)) :id) :position.y
                          go.PLAYBACK_ONCE_FORWARD
                          (+ (+ bottom-edge (/ blocksize 2))
                             (* blocksize (- y dy)))
                          go.EASING_OUTBOUNCE duration))
            (set dy (+ dy 1)))))
    (go.animate "#" :timer go.PLAYBACK_ONCE_FORWARD 1 go.EASING_LINEAR duration
                0 callback)))

(fn iterate-fishes [board]
  (var x 0)
  (var y (- 1))
  (fn []
    (while true
      (set y (+ y 1))
      (when (and (= x (- boardwidth 1)) (= y boardheight))
        (lua "return nil"))
      (when (= y boardheight)
        (set y 0)
        (set x (+ x 1)))
      (when (. (. board x) y)
        (lua :break)))
    (. (. board x) y)))

(fn remove-fish [board fish]
  (when (not (. (. board fish.x) fish.y))
    (lua "return "))
  (msg.post fish.id :remove)
  (tset (. board fish.x) fish.y nil)
  (if (= fish.type type-striped-h)
      (for [x 0 (- boardwidth 1) 1]
        (when (. (. board x) fish.y)
          (remove-fish board (. (. board x) fish.y))))
      (= fish.type type-striped-v)
      (for [y 0 (- boardheight 1) 1]
        (when (. (. board fish.x) y)
          (remove-fish board (. (. board fish.x) y))))
      (= fish.type type-wrapped)
      (for [x (- fish.x 1) (+ fish.x 1) 1]
        (for [y (- fish.y 1) (+ fish.y 1) 1]
          (when (and (. board x) (. (. board x) y))
            (remove-fish board (. (. board x) y)))))
      (= fish.type type-bomb)
      (print "removing bomb - add code to remove fishes of the color that is most common")))

(fn remove-fishes [board fishes]
  (each [_ fish (pairs fishes)]
    (remove-fish board fish)))

(fn respawn [fish type color]
  (set fish.color color)
  (set fish.type type)
  (set fish.neighbors_vertical {})
  (set fish.neighbors_horisontal {})
  (msg.post fish.id :respawn {:type fish.type
                              :position (go.get_position fish.id)
                              :color fish.color}))

(fn remove-link [board link callback]
  (each [_ slot (pairs link)]
    (msg.post slot.id :reset))
  (when (< (length link) 3)
    (callback)
    (lua "return "))
  (when (> (length link) 6)
    (local fish (table.remove link))
    (respawn fish type-wrapped fish.color))
  (remove-fishes board link)
  (local duration 0.3)
  (go.animate "#" :timer go.PLAYBACK_ONCE_FORWARD 1 go.EASING_LINEAR duration 0
              callback))

(fn add-to-link [self x y]
  (when (or (or (or (or (< x 0) (>= x boardwidth)) (< y 0)) (>= y boardheight))
            (= (. (. self.board x) y) nil))
    (lua "return "))
  (local slot (. (. self.board x) y))
  (when (= (length self.link) 0)
    (msg.post slot.id :zoom_and_wobble)
    (table.insert self.link slot)
    (lua "return "))
  (local last (. self.link (length self.link)))
  (local previous (. self.link (- (length self.link) 1)))
  (local distance (math.max (math.abs (- last.x x)) (math.abs (- last.y y))))
  (when (not= distance 1)
    (lua "return "))
  (when (not= last.color slot.color)
    (lua "return "))
  (when (= previous slot)
    (tset self.link (length self.link) nil)
    (msg.post last.id :reset)
    (lua "return "))
  (for [i 1 (length self.link) 1]
    (when (= (. self.link i) slot)
      (lua "return ")))
  (msg.post slot.id :zoom_and_wobble)
  (table.insert self.link slot))

(fn empty-slots [board]
  (let [slots {}]
    (for [x 0 (- boardwidth 1) 1]
      (for [y 0 (- boardheight 1) 1]
        (when (= (. (. board x) y) nil)
          (table.insert slots {: y : x}))))
    slots))

(fn fill-slots [board empty-slots callback]
  (let [duration 0.3
        pos (vmath.vector3)]
    (each [i s (pairs empty-slots)]
      (set pos.x (+ (+ edge (/ blocksize 2)) (* blocksize s.x)))
      (set pos.y 1000)
      (local color (. colors (math.random (length colors))))
      (local type type-plain)
      (local id (factory.create "#fish_factory" pos null {: color}))
      (go.animate id :position.y go.PLAYBACK_ONCE_FORWARD
                  (+ (+ bottom-edge (/ blocksize 2)) (* blocksize s.y))
                  go.EASING_OUTBOUNCE duration)
      (tset (. board s.x) s.y {:x s.x : color : type :y s.y : id}))
    (go.animate "#" :timer go.PLAYBACK_ONCE_FORWARD 1 go.EASING_LINEAR duration
                0 callback)))

(fn _G.on_message [self message-id message sender]
  (if (= message-id (hash :start_level)) (set self.board (build-board))
      (= message-id (hash :post-reaction))
      (collapse-board self.board
                      (fn []
                        (let [s (empty-slots self.board)]
                          (when (> (length s) 0)
                            (fill-slots self.board s (fn [])))))))
  (values))

(fn _G.on_input [self action-id action]
  (when (or (= action-id (hash :touch)) self.linking)
    (local x (math.floor (/ (- action.x edge) blocksize)))
    (local y (math.floor (/ (- action.y edge) blocksize)))
    (add-to-link self x y)
    (if action.pressed (set self.linking true) action.released
        (remove-link self.board self.link
                     (fn []
                       (set self.linking false)
                       (set self.link {})
                       (msg.post "#" :post-reaction)))))
  (values))