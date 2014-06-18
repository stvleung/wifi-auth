# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def stylesheet_auto_link_tags
    stylesheet_path = "#{Rails.root}/public/stylesheets/"

    candidates = [ "#{controller.controller_name}",
                   "#{controller.controller_name}_#{controller.action_name}" ]

    candidates.inject("") do |buf, css|
      buf << stylesheet_link_tag(css) if FileTest.exist?("#{stylesheet_path}/#{css}.css")
      buf
    end
  end

  def javascript_auto_link_tags
    javascript_path = "#{Rails.root}/public/javascripts/"

    candidates = [ "#{controller.controller_name}",
                   "#{controller.controller_name}_#{controller.action_name}" ]

    candidates.inject("") do |buf, js|
      buf << javascript_include_tag(js) if FileTest.exist?("#{javascript_path}/#{js}.js")
      buf
    end
  end

  def javascript(*files)
    content_for(:head) { javascript_include_tag(*files) }
  end

  # Mark new
  def mark_as_new(object)
    return '<span class="new">new</span>' if object.new?
  end

  # Return a linked email address of a user
  def user_email(u, encrypt = 'true')
    return 'system' unless u
    user = User.find(:first, :conditions => ['login = ?', u])
    if user
      if encrypt == false
        return mail_to(user.email, user.login)
      else
        return mail_to(user.email, user.login, :encode => 'javascript')
      end
    else
      return u
    end
  end

  # Display analytics beacon in production environment
  def analytics_beacon
    if Rails.env.production?
      "<script type=\"text/javascript\">

        var _gaq = _gaq || [];
        _gaq.push(['_setAccount', 'UA-97361-15']);
        _gaq.push(['_setDomainName', '.gracepointonline.org']);
        _gaq.push(['_trackPageview']);

        (function() {
          var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
          ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
          var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
        })();

      </script>"
    end
  end
end

# Add additional methods to base class
class String
  # Truncate from the center
  def ellipsisize(minimum_length=4,edge_length=3)
    return self if self.length < minimum_length or self.length <= edge_length*2
    edge = '.'*edge_length
    mid_length = self.length - edge_length*2
    gsub(/(#{edge}).{#{mid_length},}(#{edge})/, '\1...\2')
  end

  # Remove html tags, entities and carriage returns
  def strip_html
    self.gsub(/<\/?[^>]*>|&[a-z]+;|[\r\n]*/, "")
  end

  # Convert to boolean
  def to_bool
      return true if self == true || self =~ /^true$/i
      return false if self == false || self.empty? || self.nil? || self =~ /^false$/i
      raise ArgumentError.new("invalid value for to_bool: \"#{self}\"")
  end

  # Turn string into title case
  def titlecase
    small_words = %w(a an and as at but by en for if in of on or the to v v. via vs vs.)

    x = split(" ").map do |word|
      # note: word could contain non-word characters!
      # downcase all small_words, capitalize the rest
      small_words.include?(word.gsub(/\W/, "").downcase) ? word.downcase! : word.smart_capitalize!
      word
    end
    # capitalize first and last words
    x.first.smart_capitalize!
    x.last.smart_capitalize!
    # small words after colons are capitalized
    x.join(" ").gsub(/:\s?(\W*#{small_words.join("|")}\W*)\s/) { ": #{$1.smart_capitalize} " }
  end

  def smart_capitalize
    # ignore any leading crazy characters and capitalize the first real character
    if self =~ /^['"\(\[']*([a-z])/
      i = index($1)
      x = self[i,self.length]
      # word with capitals and periods mid-word are left alone
      self[i,1] = self[i,1].upcase unless x =~ /[A-Z]/ or x =~ /\.\w+/
    end
    self
  end

  def smart_capitalize!
    replace(smart_capitalize)
  end

end

module Html5Helpers
  module FormHelper
    def number_field(object_name, method, options = {})
      ActionView::Helpers::InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("number", options)
    end
  end
  
  class FormBuilder < ::ActionView::Helpers::FormBuilder
    #this was based on the ::ActionView::Helpers::FormBuilder class in the Rails code
    FormHelper.instance_methods.each do |selector|
      src, line = <<-end_src, __LINE__ + 1
        def #{selector}(method, options = {})  # def text_field(method, options = {})
          @template.send(                      #   @template.send(
            #{selector.inspect},               #     "text_field",
            @object_name,                      #     @object_name,
            method,                            #     method,
            objectify_options(options))        #     objectify_options(options))
        end                                    # end
      end_src
      class_eval src, __FILE__, line
    end
    
    # Adds the methods to the field_helpers which is part of the "magic" that helps render the tag
    # This was the key I was missing that was handled in the Rails code
    self.field_helpers << FormHelper.instance_methods
  end
end

ActionView::Helpers::FormTagHelper.class_eval do
  def number_field_tag(name, value = nil, options = {})
    tag :input, { "type" => "number", "name" => name, "id" => sanitize_to_id(name), "value" => value }.update(options.stringify_keys)
  end
end

# Set CustomBuilder as default FormBuilder
::ActionView::Base.class_eval do
  include Html5Helpers::FormHelper
  cattr_accessor :default_form_builder
  self.default_form_builder = Html5Helpers::FormBuilder
end
