require 'dxruby'
require_relative 'gui'
require_relative 'score'
require_relative 'controller'
require_relative 'model'
require_relative 'view'
require_relative 'scene'
Font.install("font/FAMania2.6.TTF")
Font.default = "FAMania"
Score.setup

class TitleScene < Scene
  attr_accessor :game, :controller, :view
  def initialize
    @next_scene = nil
    @model = TitleMenu.new
    @view = UIView.new(@model)
    @bg = Image.load("title.png")
    @controller = GameController.new(@model)
    start, score, quit = @model.container.selectable_components
    start.add_event_handler(:push) do |k|
      case k
      when K_Z then true.tap { @next_scene = go_to_intermission }
      else false
      end
    end
    score.add_event_handler(:push) do |k|
      case k
      when K_Z then true.tap { @next_scene = go_to_score }
      else false
      end
    end
    quit.add_event_handler(:push) do |k|
      case k
      when K_Z then true.tap { @next_scene = Exit }
      else false
      end
    end
  end
  def init
    [K_DOWN, K_UP].each {|key|
      Input.set_key_repeat(key, 24, 8)
    }
  end
  def update
    controller.update
    Window.draw(0, 0, @bg)
    view.draw
    @next_scene
  end
  def go_to_score
    ResultScene.new
  end
  def go_to_intermission
    explorers = Array.new(4){ Explorer.new }
    party = Party.new(explorers, 10, 5)
    game = Intermission.new(party)
    view = IntermissionView.new(game, Font.instance(16))
    IntermissionScene.new(game, view)
  end
end

class GameScene < Scene
  attr_accessor :game, :controller, :view
  def initialize(game, view)
    @next_scene = nil
    @game = game
    @view = view
    @controller = GameController.new(@game)
  end
  def update
    controller.update
    game.update
    view.draw
    @next_scene
  end
end

class IntermissionScene < GameScene
  def init
    [K_DOWN, K_UP].each {|key|
      Input.set_key_repeat(key, 24, 8)
    }
    inn, food, oil, explore = @game.container.selectable_components
    inn.add_event_handler(:push) do |k|
      case k
      when K_Z then true.tap { @game.inn }
      else false
      end
    end
    food.add_event_handler(:push) do |k|
      case k
      when K_Z then true.tap { @game.buy_food }
      else false
      end
    end
    oil.add_event_handler(:push) do |k|
      case k
      when K_Z then true.tap { @game.buy_oil }
      else false
      end
    end
    explore.add_event_handler(:push) do |k|
      case k
      when K_Z then true.tap { @next_scene = go_to_exploration }
      else false
      end
    end
  end
  def go_to_exploration
    game = Exploration.new(@game.party)
    view = ExplorationView.new(game, Font.instance(16))
    ExplorationScene.new(game, view)
  end
end

class ExplorationScene < GameScene
  def init
    [K_LEFT, K_RIGHT].each {|key|
      Input.set_key_repeat(key, 1, 3)
    }
    @game.add_event_handler(:event) do |ev|
      case ev
      when :go_to_intermission then true.tap { @next_scene = go_to_intermission }
      when :go_to_result       then true.tap { @next_scene = go_to_result }
      else false
      end
    end
  end
  def go_to_intermission
    @game.exploration_ended
    game = Intermission.new(@game.party)
    view = IntermissionView.new(game, Font.instance(16))
    IntermissionScene.new(game, view)
  end
  def go_to_result
    Score.registar(Score.new(@game.party.score, @game.party.frontier))
    Score.save
    ResultScene.new
  end
end

class ResultScene < Scene
  attr_accessor :controller, :view
  def initialize
    @model = ScoreList.new
    @view = UIView.new(@model)
    @controller = GameController.new(@model)
    title = @model.container.selectable_components.last
    title.add_event_handler(:push) do |k|
      case k
      when K_Z then true.tap { @next_scene = go_to_title }
      else false
      end
    end
  end
  def init
    [K_DOWN, K_UP].each {|key|
      Input.set_key_repeat(key, 24, 8)
    }
  end
  def update
    controller.update
    view.draw
    @next_scene
  end
  def go_to_title
    TitleScene.new
  end
end

Scene.run TitleScene.new
