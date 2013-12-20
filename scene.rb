class Scene
  Exit = :exit
  def self.run(scene)
    scene.init
    Window.loop do
      next_scene = scene.update
      if Scene === next_scene
        scene.quit
        scene = next_scene
        scene.init
      elsif next_scene == Exit
        scene.quit
        break
      end
    end
  end
  def init
  end
  def resume
  end
  def quit
  end
end
