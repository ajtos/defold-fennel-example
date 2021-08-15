; Translated using antifennel and formated with fnlfmt

(local normal-scale 0.45)
(local zoomed-scale 0.6)

(local colors {(hash :green) :green
               (hash :yellow) :yellow
               (hash :blue) :blue
               (hash :orange) :orange
               (hash :red) :red
               (hash :purple) :purple})

(local type-plain (hash :plain))
(local type-striped-h (hash :striped-h))
(local type-striped-v (hash :striped-v))
(local type-wrapped (hash :wrapped))
(local type-bomb (hash :bomb))

(fn blink [self]
  (var t nil)
  (if self.blinking (set t (+ (/ (math.random) 5) 0.1))
      (set t (+ (math.random 4) 3)))
  (go.animate "#" :blink go.PLAYBACK_ONCE_FORWARD 1 go.EASING_LINEAR t 0
              (fn [self]
                (if (not self.blinking) (msg.post "#sprite-eyes" :disable)
                    (msg.post "#sprite-eyes" :enable))
                (set self.blinking (not self.blinking))
                (blink self))))

(fn _G.init [self]
  (set self.rot (go.get_rotation))
  (go.set_scale normal-scale)
  (msg.post "#" :sway)
  (if (not= self.color nil)
      (let [c (. colors self.color)]
        (msg.post "#sprite" :play_animation {:id (hash (.. :fish- c))})
        (msg.post "#sprite-eyes" :play_animation {:id (hash (.. :eyes- c))}))
      (msg.post "#sprite" :disable))
  (set self.blinking false)
  (blink self)
  (values))

(fn _G.on_message [self message-id message sender]
  (if (= message-id (hash :respawn))
      (do
        (particlefx.stop "#explosion")
        (go.set_position message.position)
        (msg.post "#sprite" :enable)
        (msg.post "#sprite-eyes" :enable)
        (var c (. colors message.color))
        (var e (. colors message.color))
        (if (= message.type type-striped-h)
            (do
              (set e (.. :eyes- e))
              (set c (.. :fish- c :-h)))
            (= message.type type-striped-v)
            (do
              (set e (.. :eyes- e))
              (set c (.. :fish- c :-v)))
            (= message.type type-wrapped)
            (do
              (msg.post "#sprite-eyes" :disable)
              (go.cancel_animations "#" :blink)
              (set e (.. :eyes- c))
              (set c (.. :fish- c :-w)))
            (= message.type type-bomb)
            (do
              (set e :eyes-starfish)
              (set c :fish-starfish)))
        (msg.post "#sprite" :play_animation {:id (hash c)})
        (msg.post "#sprite-eyes" :play_animation {:id (hash e)}))
      (= message-id (hash :sway))
      (let [rot (go.get "." :euler.z)]
        (go.set "." :euler.z (- rot 1))
        (local t (+ (* (math.random) 2) 2))
        (go.cancel_animations "." :euler.z)
        (go.animate "." :euler.z go.PLAYBACK_LOOP_PINGPONG (+ rot 1)
                    go.EASING_INOUTQUAD t))
      (= message-id (hash :zoom_and_wobble))
      (do
        (go.animate "." :scale go.PLAYBACK_ONCE_FORWARD zoomed-scale
                    go.EASING_INOUTSINE 0.1)
        (local rot (go.get "." :euler.z))
        (local r (/ (math.random) 50))
        (go.cancel_animations "." :euler.z)
        (go.animate "." :euler.z go.PLAYBACK_LOOP_PINGPONG (- rot 4)
                    go.EASING_INOUTSINE (+ 0.1 r) 0.1))
      (= message-id (hash :reset))
      (do
        (go.cancel_animations "." :scale)
        (go.animate "." :scale go.PLAYBACK_ONCE_FORWARD normal-scale
                    go.EASING_INOUTSINE 0.1)
        (go.cancel_animations "." :euler.z)
        (go.set_rotation self.rot)
        (msg.post "#" :sway))
      (= message-id (hash :remove))
      (do
        (particlefx.play "#explosion")
        (go.delete)))
  (values))
