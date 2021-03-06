include OSX if Puppet.features.rubycocoa?

Puppet::Type.type(:property_list_key).provide(:rubycocoa) do
  desc 'An OS X provider for creating property list keys and values'

  confine feature: :rubycocoa

  def exists?
    return false unless File.file? resource[:path]
    if resource[:path].nil? || resource[:key].nil?
      raise("The 'key' and 'path' parameters are required for the property_list_key type")
    end

    plist = read_plist_file(resource[:path])
    plist.include? resource[:key]
  end

  def create
    if resource[:value_type] == :boolean
      unless resource[:value].first.to_s =~ /(true|false)/i
        raise Puppet::Error, "Valid boolean values are 'true' or 'false', you specified '#{resource[:value].first}'"
      end
    end

    plist = if File.file? resource[:path]
              read_plist_file(resource[:path])
            else
              OSX::NSMutableDictionary.alloc.init
            end

    case resource[:value_type]
    when :integer
      plist_value = Integer(resource[:value].first)
    when :real
      plist_value = Float(resource[:value].first)
    when :boolean
      plist_value = if resource[:value].to_s =~ /false/i
                      false
                    else
                      true
                    end
    when :hash, :string
      plist_value = resource[:value].first
    else
      plist_value = resource[:value]
    end

    plist[resource[:key]] = plist_value

    write_plist_file(plist, resource[:path])
  end

  def destroy
    if File.file?(resource[:path])
      plist = read_plist_file(resource[:path])
    else
      return true
    end

    plist.delete(resource[:key])

    write_plist_file(plist, resource[:path])
  end

  def value
    read_plist_file(resource[:path])[resource[:key]].to_ruby
  end

  def value=(item_value)
    if resource[:value_type] == :boolean
      unless item_value.to_s =~ /(true|false)/i
        raise Puppet::Error, "Valid boolean values are 'true' or 'false', you specified '#{item_value}'"
      end
    end
    plist = read_plist_file(resource[:path])

    # Values out of Puppet are usually strings...except when they aren't.
    # They need to be massaged before writing to the plist
    case resource[:value_type]
    when :integer
      plist[resource[:key]] = Integer(item_value.first)
    when :real
      plist[resource[:key]] = Float(item_value.first)
    when :array
      plist[resource[:key]] = item_value
    when :boolean
      plist[resource[:key]] = if item_value.to_s =~ /false/i
                                false
                              else
                                true
                              end
    else
      plist[resource[:key]] = item_value.first
    end

    write_plist_file(plist, resource[:path])
  end

  def read_plist_file(file_path)
    OSX::NSMutableDictionary.dictionaryWithContentsOfFile(file_path)
  rescue => e
    raise("Unable to open the file #{file_path}.  #{e.class}: #{e.inspect}")
  end

  def write_plist_file(plist, file_path)
    plist.writeToFile_atomically(file_path, true)
  rescue
    raise("Unable to write the file #{file_path}.  #{e.class}: #{e.inspect}")
  end
end
