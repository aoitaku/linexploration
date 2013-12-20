class GameController
  Keys = {
    K_UP    => 'up_key',
    K_LEFT  => 'left_key',
    K_DOWN  => 'down_key',
    K_RIGHT => 'right_key',
    K_Z     => 'z_key',
    K_X     => 'x_key',
    K_C     => 'c_key'
  }
  def initialize(game)
    @game = game
  end
  def update
    Input.keys.any? {|key|
      if accept_key_push?(key)
        @game.__send__ :"#{Keys[key]}_pushed"
      elsif accept_key_down?(key)
        @game.__send__ :"#{Keys[key]}_pressed"
      else
        false
      end
    } or @game.idol
  end
  def accept_key_push?(key)
    Input.key_push?(key) && @game.accept_key_push?(Keys[key])
  end
  def accept_key_down?(key)
    Input.key_down?(key) && @game.accept_key_down?(Keys[key])
  end
end
