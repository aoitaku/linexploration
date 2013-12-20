class Model
  def initialize
    @idol = false
  end
  def idol
    @idol = true
  end
  def idol?
    @idol
  end
  def update
    @idol = false
  end
  def accept_key_push?(key)
    respond_to?(:"#{key}_pushed")
  end
  def accept_key_down?(key)
    respond_to?(:"#{key}_pressed")
  end
end

class Exploration < Model
  include UI::Controllable
  attr_accessor :party, :dungeon
  def initialize(party)
    super()
    @party = party
    party.x = 0
    party.y = 238
    party.destination = Window.width
    puts "enemy_level : #{10 + Math.log(party.score + 1).floor - 9}"
    @dungeon = Dungeon.new(10 + (Math.log(party.score + 1).floor))
    @clock = Fiber.new {
      loop do
        59.times {|i| Fiber.yield nil }
        Fiber.yield true
      end
    }
  end
  def update
    begin
      return if party.dead?
      if @clock.resume
        party.update
        party.rest if idol? && dungeon.torch?(party)
      end
    ensure
      super
    end
  end
  def left_key_pushed
    return false if party.dead?
    if party.x == 0
      handle_event(:event, :go_to_intermission)
    else
      party.move_left
    end
    true
  end
  def right_key_pushed
    return false if party.dead?
    party.move_right
    dungeon.battle(party) if dungeon.encounter?
    true
  end
  def z_key_pushed
    if party.dead?
      handle_event(:event, :go_to_result)
    else
      dungeon.points << party.torch if party.oil?
    end
    true
  end
  def exploration_ended
    party.score += (party.treasure * dungeon.enemy_level / 10.0).floor
    party.gold += party.treasure
    party.treasure = 0
  end
end

class Dungeon
  attr_accessor :enemy_level, :points
  def initialize(enemy_level=10)
    @points = []
    @enemy_level = enemy_level
  end
  def battle(party)
    party.alive_member.each do |explorer|
      explorer.fight([Math.log(party.x),  @enemy_level].max - party.alive_member.size)
    end
    return if party.dead?
    party.food += rand(11) / 7 + rand(13) / 9 + rand(15) / 11
    party.treasure += rand(party.x * @enemy_level / 10)
    party.battled ||= true
    party.total_battled += 1
  end
  def encounter?
    rand(20) == 1
  end
  def torch?(party)
    Torchlight === party.check(@points).first
  end
end

class Torchlight < Sprite
  def initialize(x, y)
    self.x = x
    self.y = y
    self.collision = [0,0,10]
  end
end

class Party < Sprite
  attr_accessor :explorers
  attr_accessor :departure, :frontier, :destination
  attr_accessor :food, :oil, :gold, :treasure, :max_food, :max_oil
  attr_accessor :score, :level, :battled, :total_battled
  def initialize(explorers, food=10, oil=5, gold=0, x=0, y=0)
    @explorers = explorers
    @departure = 0
    @destination = 0
    @frontier = 0
    @food = @max_food = food
    @oil = @max_oil = oil
    @gold = @treasure = gold
    @score = 0
    @level = 1
    @battled = false
    @total_battled = 0
    self.x = x
    self.y = y
    self.collision = [0,0]
  end
  def move_left
    self.x -= 1
    self.x = 0 if self.x < @departure
  end
  def move_right
    self.x += 1
    @frontier = self.x if self.x > @frontier
    self.x = @destination if self.x > @destination
  end
  def food?
    @food > 0
  end
  def oil?
    @oil > 0
  end
  def torch
    @oil -= 1
    Torchlight.new(self.x, self.y)
  end
  def need_rest?
    @explorers.inject(false) do |need_rest, explorer|
      need_rest || explorer.damaged? || explorer.wearied?
    end
  end
  def battled?
    @battled
  end
  def alive?
    @explorers.inject(false) do |life, explorer|
      life || explorer.alive?
    end
  end
  def alive_member
    @explorers.find_all(&:alive?)
  end
  def dead?
    not alive?
  end
  def update
    @explorers.each do |explorer|
      next if explorer.dead?
      explorer.stamina += 1 if food?
      explorer.update
    end
    @food -= 1 if food?
  end
  def rest
    @explorers.each do |explorer|
      if explorer.need_rest? && food?
        explorer.rest
      end
    end
  end
end

class Explorer
  attr_accessor :life, :max_life
  attr_accessor :stamina, :max_stamina
  def initialize(max_life=10, max_stamina=10)
    @life = @max_life = max_life
    @stamina = @max_stamina = max_stamina
  end
  def alive?
    @life > 0
  end
  def dead?
    not alive?
  end
  def stamina?
    @stamina > 0
  end
  def fight(opposition)
    @life -= [rand([2, opposition / 5].max),
              rand([2, opposition - @stamina].max)].max
    if stamina?
      @stamina -= 1
    else
      @life -= 1
    end
    @life = 0 if @life < 0
  end
  def update
    @stamina -= 1 if stamina?
    @life -= 1 unless stamina?
  end
  def damaged?
    @life < max_life
  end
  def wearied?
    @stamina < max_stamina
  end
  def need_rest?
    alive? && (damaged? || wearied?)
  end
  def rest
    @life += (@max_life / 10.0).ceil if damaged?
    @stamina += (@max_stamina / 10.0).ceil if wearied?
  end
end

class UIModel < Model
  attr_accessor :container
  def initialize
    container.add_event_handler(:push) do |k|
      case k
      when K_UP   then true.tap { container.backward_cursor }
      when K_DOWN then true.tap { container.forward_cursor  }
      else false
      end
    end
    container.relayout_components
  end
  def up_key_pushed
    container.handle_event(:push, K_UP)
  end
  def down_key_pushed
    container.handle_event(:push, K_DOWN)
  end
  def z_key_pushed
    container.handle_event(:push, K_Z)
  end
  def x_key_pushed
    container.handle_event(:push, K_X)
  end
end

class TitleMenu < UIModel
  def initialize
    @container = UI.create do
      container {
        x 280
        y 320
        text_button {
          text "はじめる"
          font_size 16
          padding 8
        }
        text_button {
          text "スコア"
          font_size 16
          padding 8
        }
        text_button {
          text "おわる"
          font_size 16
          padding 8
        }
      }
    end
    super
  end
end

class ScoreList < UIModel
  def initialize
    last_score = Score.last ? Score.last.detail_info : ''
    @container = UI.create do
      container {
        container {
          x 104
          y 24
          text_label {
            text "　　　　　　　　ランキング 　　　　　さいだいきょり"
            font_size 16
            padding 8
          }
          Score.data.each_with_index {|score, i|
            rank = (i + 1).to_s + ["ST", "ND", "RD", "TH"][[i, 3].min]
            text_label {
              text rank.rjust(4, '　') + score.to_s
              font_size 16
              padding 8
            }
          }
        }
        container {
          x 104
          y 352
          text_label {
            text last_score
            font_size 16
            padding 8
          }
        }
        text_button {
          text "タイトルへ"
          font_size 16
          padding 8
        }
      }
    end
    super()
    title = @container.components.last
    title.x = 440
    title.y = 388
  end
  def load_score
  end
end


class Intermission < UIModel
  attr_accessor :party
  def initialize(party)
    @party = party
    @container = UI.create do
      container {
        x 48
        y 176
        text_button {
          text "やどにとまる"
          font_size 16
          padding 8
        }
        text_button {
          text "しょくりょうのほじゅう"
          font_size 16
          padding 8
        }
        text_button {
          text "ねんりょうのほじゅう"
          font_size 16
          padding 8
        }
        text_button {
          text "たんさくかいし!"
          font_size 16
          padding 8
        }
      }
    end
    super()
    @container.selectable_components.last.y = 420
  end
  def inn
    if @party.gold >= 200 && (@party.need_rest? || @party.battled?)
      if @party.battled? && @party.level ** 2 < @party.total_battled
        (@party.total_battled - @party.level ** 2).times do
          @party.explorers.each do |explorer|
            explorer.max_life += rand(11) / 7
            explorer.max_stamina += rand(15) / 11
          end
          @party.level += 1
        end
        @party.battled = false
      end
      if @party.need_rest?
        @party.explorers.each do |explorer|
          explorer.life = explorer.max_life
          explorer.stamina = explorer.max_stamina
        end
        @party.gold -= 200
      end
    end
  end
  def buy_food
    if @party.gold >= 20 && @party.food < @party.max_food
      @party.food += 1
      @party.gold -= 20
    end
  end
  def buy_oil
    if @party.gold >= 100 && @party.oil < @party.max_oil
      @party.oil += 1
      @party.gold -= 100
    end
  end
end
