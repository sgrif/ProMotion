module ProMotion
  module ScreenNavigation

    def open_screen(screen, args = {})
      
      # Apply properties to instance
      screen = setup_screen_for_open(screen, args)
      ensure_wrapper_controller_in_place(screen, args)

      screen.send(:on_load) if screen.respond_to?(:on_load)      
      animated = args[:animated] || true

      if args[:close_all]
        open_root_screen screen

      elsif args[:modal]
        present_modal_view_controller screen, animated

      elsif args[:in_tab] && self.tab_bar
        present_view_controller_in_tab_bar_controller screen, args[:in_tab]

      elsif self.navigation_controller
        push_view_controller screen

      elsif screen.respond_to?(:main_controller)
        open_view_controller screen.main_controller

      else
        open_view_controller screen

      end

    end
    alias :open :open_screen

    def open_root_screen(screen)
      app_delegate.open_root_screen(screen)
    end
    alias :fresh_start :open_root_screen

    def app_delegate
      UIApplication.sharedApplication.delegate
    end
    
    # TODO: De-uglify this method.
    def close_screen(args = {})
      args ||= {}
      args[:animated] ||= true
      
      # Pop current view, maybe with arguments, if in navigation controller
      if self.is_modal?
        close_modal_screen args

      elsif self.navigation_controller
        close_nav_screen args
        send_on_return(args) # TODO: this would be better implemented in a callback or view_did_disappear.

      else
        Console.log("Tried to close #{self.to_s}; however, this screen isn't modal or in a nav bar.", withColor: Console::PURPLE_COLOR)
        
      end
    end
    alias :close :close_screen

    def send_on_return(args = {})
      if self.parent_screen && self.parent_screen.respond_to?(:on_return)
        if args
          self.parent_screen.send(:on_return, args)
        else
          self.parent_screen.send(:on_return)
        end
        ProMotion::Screen.current_screen = self.parent_screen
      end
    end

    def open_view_controller(vc)
      app_delegate.load_root_view vc
    end

    def push_view_controller(vc, nav_controller=nil)
      Console.log(" You need a nav_bar if you are going to push #{vc.to_s} onto it.", withColor: Console::RED_COLOR) unless self.navigation_controller
      nav_controller ||= self.navigation_controller
      nav_controller.pushViewController(vc, animated: true)
    end




    protected

    def setup_screen_for_open(screen, args={})

      # Instantiate screen if given a class
      screen = screen.new if screen.respond_to?(:new)

      # Set parent, title & modal properties
      screen.parent_screen = self if screen.respond_to?("parent_screen=")
      screen.title = args[:title] if args[:title] && screen.respond_to?("title=")
      screen.modal = args[:modal] if args[:modal] && screen.respond_to?("modal=")
      
      # Hide bottom bar?
      screen.hidesBottomBarWhenPushed = args[:hide_tab_bar] == true

      # Wrap in a PM::NavigationController?
      screen.add_nav_bar if args[:nav_bar] && screen.respond_to?(:add_nav_bar)

      # Return modified screen instance
      screen

    end

    def ensure_wrapper_controller_in_place(screen, args={})
      unless args[:close_all] || args[:modal]
        screen.navigation_controller ||= self.navigation_controller if screen.respond_to?("navigation_controller=")
        screen.tab_bar ||= self.tab_bar if screen.respond_to?("tab_bar=")
      end
    end

    def present_modal_view_controller(screen, animated)
      vc = screen
      vc = screen.main_controller if screen.respond_to?(:main_controller)
      self.presentModalViewController(vc, animated:animated)
    end

    def present_view_controller_in_tab_bar_controller(screen, tab_name)
      vc = open_tab tab_name
      if vc

        if vc.is_a?(UINavigationController)
          screen.navigation_controller = vc if screen.respond_to?("navigation_controller=")
          push_view_controller(screen, vc)
        else
          self.tab_bar.selectedIndex = vc.tabBarItem.tag
        end

      else
        Console.log("No tab bar item '#{tab_name}'", with_color: Console::RED_COLOR)
      end
    end

    def close_modal_screen(args={})
      args[:animated] ||= true
      self.parent_screen.dismissViewControllerAnimated(args[:animated], completion: lambda {
        send_on_return(args)
      })
    end

    def close_nav_screen(args={})
      args[:animated] ||= true
      if args[:to_screen] && args[:to_screen].is_a?(UIViewController)
        self.parent_screen = args[:to_screen]
        self.navigation_controller.popToViewController(args[:to_screen], animated: args[:animated])
      else
        self.navigation_controller.popViewControllerAnimated(args[:animated])
      end
    end

  end
end
