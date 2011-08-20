module Minecraft
  # Contains all the methods for console commands executed by a connected
  # player.
  module Commands
    include Data

    # Gives half-op privileges to the target user.
    #
    # @param [String] user The requesting user.
    # @param [String] target_user The target user to be hop'ed.
    # @example
    #   hop("basicxman", "blizzard4U")
    def hop(user, target_user)
      @hops << target_user.downcase unless @hops.include? target_user.downcase
      @server.puts "#{target_user} is now a hop, thanks #{user}!"
    end

    # De-half-ops the target user.
    #
    # @param [String] user The requesting user.
    # @param [String] target_user The target user to be de-hop'ed.
    # @example
    #   dehop("basicxman", "blizzard4U")
    def dehop(user, target_user)
      @hops.reject! { |u| u == target_user.downcase }
      @server.puts "#{target_user} has been de-hoped, thanks #{user}!"
    end

    # Give command takes an item name or numeric id and a quantifier.  If a
    # quantifier is not specified then the quantity defaults to 1.  Items will
    # try to resolved if they are not an exact match.
    #
    # @param [String] user Target user of the command.
    # @example
    #   give("basicxman", "cobblestone")
    #   give("basicxman", "cobblestone", "9m")
    #   give("basicxman", "flint", "and", "steel", "1")
    #   give("basicxman", "4")
    def give(user, *args)
      item, quantity = items_arg(1, args)
      item = resolve_item(item)

      construct_give(user, item, quantity)
    end

    # Validates a kit group, if the kit cannot be found it executes the
    # !kitlist command.
    def validate_kit(group = "")
      return true if KITS.include? group.to_sym
      @server.puts "say #{group} is not a valid kit."
      kitlist
    end

    # Kit command takes a group name and gives the contents of the kit to the
    # target user.
    #
    # @param [String] user Target user of the command.
    # @param [String] group Label of the kit.
    # @example
    #   give("basicxman", "diamond")
    def kit(user, group)
      KITS[group.to_sym].each do |item|
        if item.is_a? Array
          @server.puts construct_give(user, item.first, item.last)
        else
          @server.puts "give #{user} #{item} 1"
        end
      end
    end

    # Teleports the current user to the target user.
    #
    # @param [String] user Current user.
    # @param [String] target User to teleport to.
    # @example
    #   tp("basicxman", "mike_n_7")
    def tp(user, target)
      @server.puts "tp #{user} #{target}"
    end

    # Teleports all users to the target user.  Overrides !tpall.
    #
    # @param [String] user Current (target) user.
    # @example
    #   tp("basicxman")
    def tpall(user, *args)
      @users.each { |u| tp(u, user) }
    end

    # Gives a golden apple to the specified user.
    #
    # @param [String] user Target user.
    # @example
    #   nom("basicxman")
    def nom(user)
      @server.puts "give #{user} 322 1"
    end

    # Outputs the current value of a server property.
    #
    # @param [String] user The requesting user.
    # @param [String] key The server property requested.
    # @example
    #   property("basicxman", "spawn-monsters")
    def property(user, key)
      @server.puts "say #{key} is currently #{@server_properties[key]}" if @server_properties.include? key
    end

    # Checks the current uptime of the current or target user.  Prints their
    # connected uptime and their total uptime.  If no target user is specified
    # it will check the requesting user.
    #
    # @param [String] user The requesting user.
    # @param [String] target_user The user to check.
    # @example
    #   uptime("basicxman")
    #   uptime("basicxman", "mike_n_7")
    def uptime(user, target_user = nil)
      target_user ||= user
      unless @users.include? target_user
        if @userlog.has_key? target_user
          @server.puts "say #{target_user} has #{format_uptime(@userlog[target_user])} minutes of logged time."
        else
          @server.puts "say #{target_user} Does not exist."
        end
        return
      end

      time_spent = calculate_uptime(target_user)
      if @userlog.has_key? target_user
        total = "  Out of a total of #{format_uptime(@userlog[target_user] + time_spent)} minutes."
      end
      @server.puts "say #{target_user} has been online for #{format_uptime(time_spent)} minutes.#{total}"
    end

    # Will print the server rules to all connected players.
    #
    # @example
    #   rules()
    def rules(*args)
      @server.puts "say #{@rules}"
    end

    # Lists the currently connecting players, noting which is the requesting
    # user and which users are ops.
    #
    # @param [String] user The requesting user.
    # @example
    #   list("basicxman")
    def list(user)
      l = @users.inject("") do |s, u|
        pre, suf = "", ""
        if u == user
          pre = "["
          suf = "]"
        end
        pre = pre + "@" if is_op? u
        pre = pre + "%" if is_hop? u
        s + "#{", " unless s.empty?}#{pre}#{u}#{suf}"
      end

      @server.puts "say #{l}"
    end

    # Adds a timer to the requesting users timers, the item and frequency in
    # seconds of the timer should be specified.  If the timer already exists
    # for that item, the frequency is re-assigned.  If the frequency is
    # unspecified, it will default to 30.
    #
    # @param [String] user The requesting user.
    # @param args item, frequency
    # @example
    #   addtimer("basicxman", "cobblestone")
    #   addtimer("basicxman", "arrow", "10")
    def addtimer(user, *args)
      item, duration = items_arg(30, args)
      item = resolve_item(item)
      @timers[user] ||= {}
      @timers[user][item] = duration
      @server.puts "say Timer added for #{user}.  Giving item id #{item} every #{duration} seconds."
    end

    # Deletes a timer from the requesting user.
    #
    # @param [String] user The requesting user.
    # @param args item
    # @example
    #   deltimer("basicxman", "cobblestone")
    def deltimer(user, *args)
      item = args.join(" ")
      item = resolve_item(item)
      @timers[user][item] = nil if @timers.has_key? user
    end

    # Prints the requesting users current timers.
    #
    # @param [String] user The requesting user.
    # @example
    #   printtimer("basicxman")
    def printtimer(user)
      unless @timers.has_key? user || @timers[user].length == 0
        @server.puts "say No timers have been added for #{user}."
        return
      end
      @timers[user].each do |item, frequency|
        @server.puts "say #{item} every #{frequency} seconds."
      end
    end

    # Prints the current value of the counter (seconds since server
    # initialized).
    #
    # @example
    #   printtimer("basicxman")
    def printtime(user)
      @server.puts "say Timer is at #{@counter}."
    end

    # Adds a shortcut for the user with a given label.  Shortcuts can only be
    # given for custom commands.  If only a label is given, the shortcut is
    # executed.
    #
    # @param [String] user The requesting user.
    # @param args label, command array
    # @example
    #   s("basicxman", "cobble", "give", "cobblestone", "64")
    #   s("basicxman", "mike", "tp", "mike_n_7")
    def s(user, *args)
      return @server.puts "say You need to specify a shortcut silly!" if args.length == 0

      shortcut_name = args.slice! 0
      if args.length == 0
        @server.puts "say #{shortcut_name} is not a valid shortcut for #{user}." unless @shortcuts.has_key? user and @shortcuts[user].has_key? shortcut_name
        return call_command(user, @shortcuts[user][shortcut_name].first, *@shortcuts[user][shortcut_name][1..-1]) if args.length == 0
      end

      command_string = args
      @shortcuts[user] ||= {}
      @shortcuts[user][shortcut_name] = command_string
      @server.puts "say Shortcut labelled #{shortcut_name} for #{user} has been added."
    end

    # Prints the requested users shortcuts.
    #
    # @param [String] user The requesting user.
    # @example
    #   shortcuts("basicxman")
    def shortcuts(user, *args)
      labels = @shortcuts[user].keys.join(", ") if @shortcuts.has_key? user
      @server.puts "say Shortcuts for #{user}: #{labels}."
    end

    # Prints the help contents.
    #
    # @example
    #   help()
    def help(*args)
      @server.puts <<-eof
say !tp target_user
say !kit kit_name
say !give item quantity
say !nom
say !list
say !addtimer item frequency
say !deltimer item
      eof
    end

    # Prints the list of available kits to the connected players.
    #
    # @example
    #   kitlist()
    def kitlist(*args)
      @server.puts "say Kits: #{KITS.keys.join(", ")}"
    end

    # Helper method for printing the final give statements to the server.  If a
    # quantity is above the default upper bound (64) it will print multiple
    # statements.
    #
    # @param [String] user The requesting user.
    # @param [Integer] item The item id.
    # @param [Integer] quantity The quantity of the item to give.
    # @example
    #   construct_give("basicxman", 4, 64)
    #   construct_give("basicxman", 4, 2560)
    def construct_give(user, item, quantity)
      if quantity <= 64
        @server.puts "give #{user} #{item} #{quantity}"
        return
      end

      quantity = 2560 if quantity > 2560
      full_quantity = (quantity / 64.0).floor
      sub_quantity  = quantity % 64
      @server.puts "give #{user} #{item} 64\n" * full_quantity
      @server.puts "give #{user} #{item} #{sub_quantity}" if sub_quantity > 0
    end

    # Takes an array and decides if a quantifier is specified or not, returns
    # the quantity and full item name.
    #
    # @param [Integer] default The default quantity to give if none is given.
    # @return [Array] full_item_name, quantity
    # @example
    #   items_arg(1, ["flint", "and", "steel"])
    #   items_arg(1, ["4"])
    #   items_arg(1, ["4", "1"])
    #   items_arg(1, ["flint", "and", "steel", "32"])
    def items_arg(default, args)
      if args.length == 1
        second = default
        first  = args.first
      else
        if is_quantifier? args.last
          second = quantify(args.last)
          first  = args[0..-2].join(" ")
        else
          second = default
          first = args[0..-1].join(" ")
        end
      end
      return [first, second]
    end

    # Resolves a full item name, checks if it is a numeric value and if not
    # attempts an approximate match on the key and gets the value from the
    # data value hash.
    #
    # @param [String] item The full item name.
    # @return [String] The resolved item id.
    # @example
    #   resolve_item("4")
    #   resolve_item("cobb")
    #   resolve_item("cobblestone")
    def resolve_item(item)
      item.to_i.to_s == item ? item : DATA_VALUE_HASH[resolve_key(item.downcase)]
    end

    # Looks for an approximate match of a key, prints an error message to
    # the player if the key does not exist.
    #
    # @param [String] key The approximate item name.
    # @return [String] The proper item id.
    # @example
    #   resolve_key("cobb")
    #   resolve_key("cobblestone")
    #   resolve_key("torches")
    def resolve_key(key)
      bucket = key[0]
      return no_key(key) unless ITEM_BUCKETS.include? bucket
      return key if ITEM_BUCKETS[bucket].include? key

      shortest_diff = nil
      shortest_key  = nil
      ITEM_BUCKETS[bucket].each do |test_key|
        if test_key.length > key.length
          diff = test_key.length - key.length if test_key.index(key)
        else
          diff = key.length - test_key.length if key.index(test_key)
        end
        next if diff.nil?

        if shortest_diff.nil? or diff < shortest_diff
          shortest_key = test_key
          shortest_diff = diff
        end
      end

      no_key(key) if shortest_key.nil?
      return shortest_key
    end

    # Prints a no key error the server.
    def no_key(key)
      @server.puts "say No item #{key} found."
    end

    # Checks if a value is a valid quantifier or not.
    #
    # @param [String] quantity The potential quantifier.
    # @return [Boolean]
    # @example
    #   is_quantifier? "x"
    #   is_quantifier? "1m"
    #   is_quantifier? "2d"
    #   is_quantifier? "1s"
    #   is_quantifier? "1"
    #   is_quantifier? "steel"
    def is_quantifier?(quantity)
      quantity.index(/[0-9]+[a-z]?/) == 0
    end

    # Compute a final quantity from a quantifier value.
    #
    # @param [String] value The quantifier.
    # @return [Integer] The resulting quantity, upper bounded to 2560.
    # @example
    #   quantify("1m")
    #   quantify("2d")
    #   quantify("34s")
    #   quantify("8m2d")
    #   quantify("64")
    def quantify(value)
      quantity = value.scan(/[0-9]+[a-z]?/).inject(0) do |total, term|
        quantity, flag = term.match(/([0-9]+)([a-z]?)/)[1..2]
        quantity = quantity.to_i
        return total + quantity if flag.nil?

        total + case flag
        when 'm' then quantity * 64
        when 'd' then (64.0 / [1, quantity].max).round
        when 's' then [1, 64 - quantity].max
        else quantity
        end
      end
      return [2560, quantity].min
    end
  end
end
